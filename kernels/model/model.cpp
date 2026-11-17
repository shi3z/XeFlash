// XeFlash model pass for Qwen3.8-27B (model_type qwen3_5): 64 layers,
// 3 x (Gated DeltaNet + MLP) then 1 x (gated attention + MLP), repeated.
//
// The Rust host builds an xf_model (pointers to resident weights, state and
// one workspace block) once. xf_forward() submits every kernel of a pass of
// M <= 16 consecutive tokens; nothing is read back until the host asks.
//
// A pass never modifies committed recurrent state. It records what is needed
// (normalised keys, deltas, decays, raw conv inputs) and xf_commit(n) applies
// the first n tokens. KV rows are written past the committed length, which is
// harmless. That is all speculative decoding needs for rollback.
//
// This is the correctness-first baseline: one simple kernel per step, no
// fusion. Float math is FP32 throughout; GEMMs are exact integer DPAS on
// 16-bit activations.
#include <sycl/ext/intel/esimd.hpp>

#include <chrono>
#include <cstdio>
#include <cstdlib>

#include "../ctx.hpp"

namespace es = sycl::ext::intel::esimd;
using es::simd;

namespace {

constexpr int MAXM = 16;
constexpr int D = 5120, FF = 17408, QKV = 10240, VD = 6144, QP = 12288, KVD = 1024, VOCAB = 248320;
constexpr int KH = 16, VH = 48, HD = 128;      // DeltaNet heads
constexpr int AH = 24, AKH = 4, AD = 256;      // attention heads
constexpr int QKVZ = QKV + VD, AQKV = QP + 2 * KVD; // row-stacked matrices sharing an input
constexpr int PS = 320;                        // row stride of per-64-column partials (>= FF / 64)
constexpr int AMC = 97, AMB = 40;              // argmax: 97 chunks of 40 x 64 logits per token
constexpr float EPS = 1e-6f;

template <int N> ESIMD_INLINE float hsum(simd<float, N> v) SYCL_ESIMD_FUNCTION {
  if constexpr (N == 1) {
    return v[0];
  } else {
    simd<float, N / 2> a = v.template select<N / 2, 1>(0);
    simd<float, N / 2> b = v.template select<N / 2, 1>(N / 2);
    return hsum<N / 2>(a + b);
  }
}
template <int N> ESIMD_INLINE float hmax(simd<float, N> v) SYCL_ESIMD_FUNCTION {
  if constexpr (N == 1) {
    return v[0];
  } else {
    simd<float, N / 2> a = v.template select<N / 2, 1>(0);
    simd<float, N / 2> b = v.template select<N / 2, 1>(N / 2);
    return hmax<N / 2>(es::max(a, b));
  }
}
ESIMD_INLINE float sexp(float x) SYCL_ESIMD_FUNCTION { return es::exp(simd<float, 8>(x))[0]; }
ESIMD_INLINE float srsqrt(float x) SYCL_ESIMD_FUNCTION {
  simd<float, 8> v(x);
  return (simd<float, 8>(1.0f) / es::sqrt(v))[0];
}
template <int N> ESIMD_INLINE simd<float, N> sigmoid(simd<float, N> x) SYCL_ESIMD_FUNCTION {
  return simd<float, N>(1.0f) / (es::exp(-x) + 1.0f);
}
ESIMD_INLINE float loadf(const float *p) SYCL_ESIMD_FUNCTION {
  simd<float, 1> v;
  v.copy_from(p);
  return v[0];
}
ESIMD_INLINE void storef(float *p, float x) SYCL_ESIMD_FUNCTION {
  simd<float, 1> v(x);
  v.copy_to(p);
}

// ---------------------------------------------------------------- memory map
struct WS {
  int32_t *ids; // io block: [0,16) pass ids, [16,32) verify ids (next + drafts), [32,48) greedy ids, [48,64) greedy logits (f32)
  float *sk_z, *sk_s, *candv;
  float *cap; // residual stream after layers 5, 19, 33, 47, 61: [5][MAXM][D]
  int32_t *cand, *candi;
  float *inv, *ts, *toff, *pmax, *psum, *h, *xn, *y;
  int8_t *xhi;
  uint8_t *xlo;
  void *ypart;
  float *act, *yz, *yab, *qn, *gout, *go, *yq, *yk, *yv, *qr, *g, *u, *logits, *amv;
  int32_t *ami;
  float *pm, *pd, *pv;
  // MTP scratch
  float *mh, *me;
  size_t total;
};

struct Bump {
  char *base;
  size_t off = 0;
  template <typename T> T *take(size_t count) {
    size_t at = off;
    off = (off + count * sizeof(T) + 4095) / 4096 * 4096;
    return reinterpret_cast<T *>(base + at);
  }
};

WS carve_ws(void *base, int ctx) {
  Bump b{static_cast<char *>(base)};
  const size_t nb = size_t(ctx) / 64 + 1;
  WS w;
  w.ids = b.take<int32_t>(64);
  w.inv = b.take<float>(MAXM);
  w.ts = b.take<float>(MAXM);
  w.toff = b.take<float>(MAXM);
  w.pmax = b.take<float>(MAXM * PS);
  w.psum = b.take<float>(MAXM * PS);
  w.h = b.take<float>(MAXM * D);
  w.xn = b.take<float>(MAXM * D);
  w.y = b.take<float>(MAXM * D);
  w.xhi = b.take<int8_t>(size_t(FF / 32) * MAXM * 32);
  w.xlo = b.take<uint8_t>(size_t(FF / 32) * MAXM * 32);
  w.ypart = b.take<int32_t>(size_t(4) * 2 * MAXM * VD);
  w.act = b.take<float>(MAXM * QKV);
  w.yz = b.take<float>(MAXM * VD);
  w.yab = b.take<float>(MAXM * 128);
  w.qn = b.take<float>(MAXM * KH * HD);
  w.gout = b.take<float>(MAXM * VD);
  w.go = b.take<float>(MAXM * VD);
  w.yq = b.take<float>(MAXM * AQKV);
  w.yk = b.take<float>(MAXM * KVD);
  w.yv = b.take<float>(MAXM * KVD);
  w.qr = b.take<float>(MAXM * AH * AD);
  w.g = b.take<float>(size_t(MAXM) * 2 * FF);
  w.u = b.take<float>(size_t(MAXM) * 2 * FF);
  w.logits = b.take<float>(size_t(MAXM) * VOCAB);
  w.amv = b.take<float>(MAXM * AMC * 64);
  w.ami = b.take<int32_t>(MAXM * AMC * 64);
  w.pm = b.take<float>(MAXM * AH * nb);
  w.pd = b.take<float>(MAXM * AH * nb);
  w.pv = b.take<float>(MAXM * AH * nb * AD);
  w.mh = b.take<float>(MAXM * D);
  w.me = b.take<float>(MAXM * 2 * D);
  w.cap = b.take<float>(size_t(5) * MAXM * D);
  w.sk_z = b.take<float>(2048);
  w.sk_s = b.take<float>(VOCAB);
  w.cand = b.take<int32_t>(4096);
  w.candi = b.take<int32_t>(4096);
  w.candv = b.take<float>(4096);
  w.total = b.off;
  return w;
}

struct GdnState {
  float *S, *hist, *raw, *kn, *dsave, *beta, *decay;
  size_t total;
};
GdnState carve_gdn(void *base) {
  Bump b{static_cast<char *>(base)};
  GdnState s;
  s.S = b.take<float>(size_t(VH) * HD * HD); // [value head][value column j][key row i]
  s.hist = b.take<float>(3 * QKV);
  s.raw = b.take<float>(MAXM * QKVZ);
  s.kn = b.take<float>(MAXM * KH * HD);
  s.dsave = b.take<float>(MAXM * VD);
  s.beta = b.take<float>(MAXM * 64);
  s.decay = b.take<float>(MAXM * 64);
  s.total = b.off;
  return s;
}
struct AttnState {
  float *K, *V;
  size_t total;
};
AttnState carve_attn(void *base, int ctx) {
  Bump b{static_cast<char *>(base)};
  AttnState s;
  s.K = b.take<float>(size_t(ctx) * AKH * AD);
  s.V = b.take<float>(size_t(ctx) * AKH * AD);
  s.total = b.off;
  return s;
}

// ------------------------------------------------------------------- kernels
using Q = sycl::queue;

void k_embed(Q &q, const uint16_t *embed, const int32_t *ids, float *h, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * (D / 64)), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / (D / 64), c = id[0] % (D / 64);
    simd<int32_t, 1> t;
    t.copy_from(ids + mi);
    simd<uint16_t, 64> e;
    e.copy_from(embed + size_t(t[0]) * D + c * 64);
    simd<uint32_t, 64> u = es::convert<uint32_t>(e) << 16;
    simd<float, 64> f = u.template bit_cast_view<float>();
    f.copy_to(h + mi * D + c * 64);
  });
}

// inv[m] = rsqrt(mean(x^2) + eps)
void k_rms(Q &q, const float *x, float *inv, int m) {
  q.parallel_for(sycl::range<1>(m), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0];
    simd<float, 64> acc(0.0f);
    for (int c = 0; c < D / 64; c++) {
      simd<float, 64> v;
      v.copy_from(x + mi * D + c * 64);
      acc += v * v;
    }
    storef(inv + mi, srsqrt(hsum<64>(acc) * (1.0f / D) + EPS));
  });
}

// xn = x * inv[m] * gain ; pmax per 64 columns.  (gain already holds 1 + w)
void k_norm_apply(Q &q, const float *x, const float *inv, const float *gain, float *xn, float *pmax, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * (D / 64)), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / (D / 64), c = id[0] % (D / 64);
    simd<float, 64> v, g;
    v.copy_from(x + mi * D + c * 64);
    g.copy_from(gain + c * 64);
    v = v * loadf(inv + mi) * g;
    v.copy_to(xn + mi * D + c * 64);
    storef(pmax + mi * PS + c, hmax<64>(es::abs(v)));
  });
}

// Fused residual add + RMSNorm. One work-group of 40 threads per token: each
// thread owns 128 columns, publishes its partial sum of squares through SLM,
// and after one barrier every thread knows the token's norm.
//   h += y (if y)   ;   xn = h * rsqrt(mean(h^2) + eps) * gain   ;   pmax per 64 columns
void k_addnorm(Q &q, float *h, const float *y, const float *gain, float *xn, float *pmax, int m) {
  constexpr int LT = D / 128; // 40 threads
  q.parallel_for(sycl::nd_range<1>(size_t(m) * LT, LT), [=](sycl::nd_item<1> it) SYCL_ESIMD_KERNEL {
    es::slm_init<256>();
    const size_t mi = it.get_group(0), t = it.get_local_id(0);
    simd<float, 64> a[2];
#pragma unroll
    for (int i = 0; i < 2; i++) {
      a[i].copy_from(h + mi * D + t * 128 + i * 64);
      if (y) {
        simd<float, 64> b;
        b.copy_from(y + mi * D + t * 128 + i * 64);
        a[i] += b;
        a[i].copy_to(h + mi * D + t * 128 + i * 64);
      }
    }
    es::slm_scalar_store<float>(uint32_t(t * 4), hsum<64>(a[0] * a[0] + a[1] * a[1]));
    es::barrier();
    simd<float, 64> part = es::slm_block_load<float, 64>(0);
    part.merge(simd<float, 64>(0.0f), simd<int32_t, 64>(0, 1) >= LT);
    const float inv = srsqrt(hsum<64>(part) * (1.0f / D) + EPS);
#pragma unroll
    for (int i = 0; i < 2; i++) {
      simd<float, 64> g;
      g.copy_from(gain + t * 128 + i * 64);
      simd<float, 64> v = a[i] * inv * g;
      v.copy_to(xn + mi * D + t * 128 + i * 64);
      storef(pmax + mi * PS + t * 2 + i, hmax<64>(es::abs(v)));
    }
  });
}

// Activation quantisation for one GEMM: x' = v * col_scale, 16-bit, two byte
// planes in DPAS tile order. step = max|v| * max(col_scale) / 32767.
void k_quant(Q &q, const float *v, size_t vs, int n, const float *cs, float cmax, const float *pmax, int m, int mpad,
             int8_t *xhi, uint8_t *xlo, float *ts, float *toff) {
  const int nc = n / 64;
  // One work-group per token, at most 64 threads, each owning `cpt` chunks of 64 columns.
  int cpt = 1;
  while (nc / cpt > 64 || nc % cpt != 0) cpt *= 2;
  const int lt = nc / cpt;
  q.parallel_for(sycl::nd_range<1>(size_t(m) * lt, lt), [=](sycl::nd_item<1> it) SYCL_ESIMD_KERNEL {
    es::slm_init<256>();
    const size_t mi = it.get_group(0), t = it.get_local_id(0);
    const simd<int32_t, 64> iota(0, 1);
    simd<float, 64> mx(0.0f);
    for (int k = 0; k * 64 < nc; k++) {
      simd<float, 64> p;
      p.copy_from(pmax + mi * PS + k * 64);
      p.merge(simd<float, 64>(0.0f), (iota + k * 64) >= nc);
      mx = es::max(mx, p);
    }
    float step = hmax<64>(mx) * cmax * (1.0f / 32767.0f);
    if (!(step > 0.0f)) step = 1.0f;
    const float istep = 1.0f / step;
    simd<float, 64> sum(0.0f);
    for (int k = 0; k < cpt; k++) {
      const size_t c = t * cpt + k;
      simd<float, 64> x, sc;
      x.copy_from(v + mi * vs + c * 64);
      sc.copy_from(cs + c * 64);
      simd<float, 64> r = es::rnde<float>(x * sc * istep);
      r = es::max(es::min(r, simd<float, 64>(32767.0f)), simd<float, 64>(-32767.0f));
      sum += r;
      simd<int32_t, 64> xi = es::convert<int32_t>(r);
      simd<int8_t, 64> hb = es::convert<int8_t>(xi >> 8);
      simd<uint8_t, 64> lb = es::convert<uint8_t>(xi & 0xFF);
#pragma unroll
      for (int half = 0; half < 2; half++) {
        simd<int8_t, 32> a = hb.template select<32, 1>(32 * half);
        simd<uint8_t, 32> b = lb.template select<32, 1>(32 * half);
        a.copy_to(xhi + ((2 * c + half) * mpad + mi) * 32);
        b.copy_to(xlo + ((2 * c + half) * mpad + mi) * 32);
      }
    }
    // Per-thread sums are exact integers below 2^24; publish, then thread 0
    // totals them: toff = 0.5 * sum of quantised activations.
    es::slm_scalar_store<float>(uint32_t(t * 4), hsum<64>(sum));
    es::barrier();
    if (t == 0) {
      simd<float, 64> part = es::slm_block_load<float, 64>(0);
      part.merge(simd<float, 64>(0.0f), iota >= lt);
      storef(toff + mi, 0.5f * hsum<64>(part));
      storef(ts + mi, step);
    }
  });
}

// y[m][r] = dot(W[r], x[m]) in FP32, W row-major [rows][D]. For the two tiny
// DeltaNet gate projections (96 rows).
void k_gemv_f32(Q &q, const float *w, const float *x, float *y, int rows, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * rows), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / rows, r = id[0] % rows;
    simd<float, 64> acc(0.0f);
    for (int c = 0; c < D / 64; c++) {
      simd<float, 64> a, b;
      a.copy_from(w + r * D + c * 64);
      b.copy_from(x + mi * D + c * 64);
      acc += a * b;
    }
    // a: rows 0..47 -> 0..47 ; b: rows 48..95 -> 64..111
    storef(y + mi * 128 + (r < 48 ? r : r + 16), hsum<64>(acc));
  });
}

// y[m][r] = dot(W[r], x[m]) in FP32 for a dense row-major matrix (mtp.fc).
void k_gemv_dense(Q &q, const float *w, const float *x, float *y, int rows, int cols, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * rows), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / rows, r = id[0] % rows;
    simd<float, 64> acc(0.0f);
    for (int c = 0; c < cols / 64; c++) {
      simd<float, 64> a, b;
      a.copy_from(w + r * cols + c * 64);
      b.copy_from(x + mi * cols + c * 64);
      acc += a * b;
    }
    storef(y + mi * rows + r, hsum<64>(acc));
  });
}

// MTP input: cat[m] = [ norm_e(embedding) , norm_h(hidden) ], both zero-centred
// RMSNorms (gains hold 1 + w). hid == nullptr means a zero hidden state.
void k_mtp_cat(Q &q, const float *emb, const float *inv_e, const float *ge, const float *hid, const float *inv_h,
               const float *gh, float *cat, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * (2 * D / 64)), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / (2 * D / 64), c = id[0] % (2 * D / 64);
    simd<float, 64> v(0.0f), g;
    if (c < D / 64) {
      v.copy_from(emb + mi * D + c * 64);
      g.copy_from(ge + c * 64);
      v = v * loadf(inv_e + mi) * g;
    } else if (hid) {
      v.copy_from(hid + mi * D + (c - D / 64) * 64);
      g.copy_from(gh + (c - D / 64) * 64);
      v = v * loadf(inv_h + mi) * g;
    }
    v.copy_to(cat + mi * 2 * D + c * 64);
  });
}

// dst = h (+ y): a copy of the residual stream for an external consumer.
void k_capture(Q &q, const float *h, const float *y, float *dst, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * (D / 64)), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    simd<float, 64> a;
    a.copy_from(h + id[0] * 64);
    if (y) {
      simd<float, 64> b;
      b.copy_from(y + id[0] * 64);
      a += b;
    }
    a.copy_to(dst + id[0] * 64);
  });
}

void k_add(Q &q, float *h, const float *y, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * (D / 64)), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    simd<float, 64> a, b;
    a.copy_from(h + id[0] * 64);
    b.copy_from(y + id[0] * 64);
    (a + b).copy_to(h + id[0] * 64);
  });
}

// Depthwise causal conv (4 taps, tap-major weights [4][QKV]) + SiLU.
void k_conv(Q &q, const float *raw, size_t rs, const float *hist, const float *taps, float *act, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * (QKV / 64)), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const int mi = int(id[0] / (QKV / 64));
    const size_t c = id[0] % (QKV / 64);
    simd<float, 64> acc(0.0f);
#pragma unroll
    for (int k = 0; k < 4; k++) {
      const int r = mi - 3 + k;
      simd<float, 64> x, w;
      x.copy_from(r >= 0 ? raw + size_t(r) * rs + c * 64 : hist + size_t(3 + r) * QKV + c * 64);
      w.copy_from(taps + size_t(k) * QKV + c * 64);
      acc += x * w;
    }
    (acc * sigmoid<64>(acc)).copy_to(act + size_t(mi) * QKV + c * 64);
  });
}

// q = l2norm(q) / sqrt(128), k = l2norm(k), per key head.
void k_gdn_qk(Q &q, const float *act, float *qn, float *kn, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * KH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / KH, kh = id[0] % KH;
    simd<float, HD> a, b;
    a.copy_from(act + mi * QKV + kh * HD);
    b.copy_from(act + mi * QKV + KH * HD + kh * HD);
    a = a * (srsqrt(hsum<HD>(a * a) + EPS) * 0.08838834764831845f);
    b = b * srsqrt(hsum<HD>(b * b) + EPS);
    a.copy_to(qn + (mi * KH + kh) * HD);
    b.copy_to(kn + (mi * KH + kh) * HD);
  });
}

// beta = sigmoid(b), decay = exp(-exp(A_log) * softplus(a + dt_bias)).
void k_gdn_gate(Q &q, const float *yab, const float *nega, const float *dtb, float *beta, float *decay, int m) {
  q.parallel_for(sycl::range<1>(m), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0];
    simd<float, 64> a, b, na, dt;
    a.copy_from(yab + mi * 128);
    b.copy_from(yab + mi * 128 + 64);
    na.copy_from(nega);
    dt.copy_from(dtb);
    simd<float, 64> x = a + dt;
    simd<float, 64> sp = es::log(es::exp(x) + 1.0f);
    sp.merge(x, x > 20.0f);
    sigmoid<64>(b).copy_to(beta + mi * 64);
    es::exp(na * sp).copy_to(decay + mi * 64);
  });
}

// The delta rule. One thread owns one value column j of one head: 128 state
// values stay in registers while the thread walks the tokens of the pass.
//   S <- decay * S ; kv = S . k ; d = (v - kv) * beta ; S <- S + k * d ; o = S . q
// The committed state is read, never written.
void k_gdn_core(Q &q, const float *S, const float *act, const float *qn, const float *kn, const float *beta,
                const float *decay, float *dsave, float *gout, int m) {
  q.parallel_for(sycl::range<1>(size_t(VH) * HD), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t h = id[0] / HD, j = id[0] % HD, kh = h / 3;
    simd<float, HD> s;
    s.copy_from(S + id[0] * HD);
    for (int mi = 0; mi < m; mi++) {
      simd<float, HD> k, qq;
      k.copy_from(kn + (size_t(mi) * KH + kh) * HD);
      qq.copy_from(qn + (size_t(mi) * KH + kh) * HD);
      s = s * loadf(decay + mi * 64 + h);
      const float kv = hsum<HD>(s * k);
      const float d = (loadf(act + size_t(mi) * QKV + 2 * KH * HD + h * HD + j) - kv) * loadf(beta + mi * 64 + h);
      s = s + k * d;
      storef(dsave + size_t(mi) * VD + h * HD + j, d);
      storef(gout + size_t(mi) * VD + h * HD + j, hsum<HD>(s * qq));
    }
  });
}

// Apply the first n recorded tokens to the committed state.
void k_gdn_commit(Q &q, float *S, const float *kn, const float *decay, const float *dsave, int n) {
  q.parallel_for(sycl::range<1>(size_t(VH) * HD), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t h = id[0] / HD, j = id[0] % HD, kh = h / 3;
    simd<float, HD> s;
    s.copy_from(S + id[0] * HD);
    for (int mi = 0; mi < n; mi++) {
      simd<float, HD> k;
      k.copy_from(kn + (size_t(mi) * KH + kh) * HD);
      s = s * loadf(decay + mi * 64 + h) + k * loadf(dsave + size_t(mi) * VD + h * HD + j);
    }
    s.copy_to(S + id[0] * HD);
  });
}

// hist <- last three rows of (hist ++ raw[0..n)).
void k_hist_commit(Q &q, float *hist, const float *raw, size_t rs, int n) {
  q.parallel_for(sycl::range<1>(QKV / 64), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t c = id[0];
    simd<float, 64> r[3];
#pragma unroll
    for (int i = 0; i < 3; i++) {
      const int x = n + i; // index into hist ++ raw
      r[i].copy_from(x < 3 ? hist + size_t(x) * QKV + c * 64 : raw + size_t(x - 3) * rs + c * 64);
    }
#pragma unroll
    for (int i = 0; i < 3; i++) r[i].copy_to(hist + size_t(i) * QKV + c * 64);
  });
}

// out = w * rmsnorm_128(o) * silu(z), per value head.
void k_gdn_post(Q &q, const float *gout, const float *z, size_t zs, const float *gw, float *go, float *pmax, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * VH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / VH, h = id[0] % VH;
    simd<float, HD> o, zz, w;
    o.copy_from(gout + mi * VD + h * HD);
    zz.copy_from(z + mi * zs + h * HD);
    w.copy_from(gw);
    o = o * srsqrt(hsum<HD>(o * o) * (1.0f / HD) + EPS) * w * (zz * sigmoid<HD>(zz));
    o.copy_to(go + mi * VD + h * HD);
    simd<float, HD> a = es::abs(o);
    storef(pmax + mi * PS + h * 2, hmax<64>(a.template select<64, 1>(0)));
    storef(pmax + mi * PS + h * 2 + 1, hmax<64>(a.template select<64, 1>(64)));
  });
}

// Head-wise RMSNorm (gain holds 1 + w) and RoPE on the first 64 dims.
ESIMD_INLINE void norm_rope(simd<float, 64> *v, const float *gain, const float *cs, const float *sn) SYCL_ESIMD_FUNCTION {
  simd<float, 64> ss = v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3];
  const float inv = srsqrt(hsum<64>(ss) * (1.0f / AD) + EPS);
#pragma unroll
  for (int i = 0; i < 4; i++) {
    simd<float, 64> g;
    g.copy_from(gain + i * 64);
    v[i] = v[i] * inv * g;
  }
  simd<float, 32> c, s;
  c.copy_from(cs);
  s.copy_from(sn);
  simd<float, 32> lo = v[0].template select<32, 1>(0), hi = v[0].template select<32, 1>(32);
  v[0].template select<32, 1>(0) = lo * c - hi * s;
  v[0].template select<32, 1>(32) = hi * c + lo * s;
}

void k_attn_q(Q &q, const float *yq, size_t qs, const float *gain, const float *cs, const float *sn, float *qr, int m, int pos0) {
  q.parallel_for(sycl::range<1>(size_t(m) * AH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / AH, h = id[0] % AH;
    simd<float, 64> v[4];
#pragma unroll
    for (int i = 0; i < 4; i++) v[i].copy_from(yq + mi * qs + h * 2 * AD + i * 64);
    norm_rope(v, gain, cs + (pos0 + mi) * 32, sn + (pos0 + mi) * 32);
#pragma unroll
    for (int i = 0; i < 4; i++) v[i].copy_to(qr + (mi * AH + h) * AD + i * 64);
  });
}

void k_attn_kv(Q &q, const float *yk, const float *yv, size_t ks, const float *gain, const float *cs, const float *sn, float *K,
               float *V, int m, int pos0, bool kt = false) {
  q.parallel_for(sycl::range<1>(size_t(m) * AKH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / AKH, kh = id[0] % AKH;
    simd<float, 64> v[4];
#pragma unroll
    for (int i = 0; i < 4; i++) v[i].copy_from(yk + mi * ks + kh * AD + i * 64);
    norm_rope(v, gain, cs + (pos0 + mi) * 32, sn + (pos0 + mi) * 32);
#pragma unroll
    for (int i = 0; i < 4; i++) {
      if (kt) {
        // K^T layout: [block of 64 positions][kv head][dim][position in block]
        const size_t pos = pos0 + mi;
        float *base = K + ((pos / 64) * AKH + kh) * size_t(AD) * 64 + pos % 64;
        simd<uint32_t, 64> off(i * 64 * 64, 64);
        off = off * 4u;
        es::scatter<float, 64>(base, off, v[i]);
      } else {
        v[i].copy_to(K + ((pos0 + mi) * AKH + kh) * AD + i * 64);
      }
      simd<float, 64> x;
      x.copy_from(yv + mi * ks + kh * AD + i * 64);
      x.copy_to(V + ((pos0 + mi) * AKH + kh) * AD + i * 64);
    }
  });
}

// Scores and value sums over one block of 64 keys with a running-max softmax.
// Partial result per (token, head, block): max, denominator, weighted V.
void k_attn_part(Q &q, const float *qr, const float *K, const float *V, float *pm, float *pd, float *pv, int m,
                 int pos0, size_t nbs) {
  const size_t nb = size_t(pos0 + m - 1) / 64 + 1;
  q.parallel_for(sycl::range<1>(size_t(m) * AH * nb), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t b = id[0] % nb, mh = id[0] / nb, mi = mh / AH, h = mh % AH, kh = h / (AH / AKH);
    const size_t last = pos0 + mi; // causal: keys 0..last inclusive
    simd<float, 64> qv[4], acc[4];
#pragma unroll
    for (int i = 0; i < 4; i++) {
      qv[i].copy_from(qr + mh * AD + i * 64);
      acc[i] = 0.0f;
    }
    float mx = -1e30f, den = 0.0f;
    for (size_t t = b * 64; t < b * 64 + 64 && t <= last; t++) {
      simd<float, 64> k[4];
#pragma unroll
      for (int i = 0; i < 4; i++) k[i].copy_from(K + (t * AKH + kh) * AD + i * 64);
      const float s = hsum<64>(qv[0] * k[0] + qv[1] * k[1] + qv[2] * k[2] + qv[3] * k[3]) * 0.0625f;
      if (s > mx) {
        const float e = sexp(mx - s);
        den *= e;
#pragma unroll
        for (int i = 0; i < 4; i++) acc[i] = acc[i] * e;
        mx = s;
      }
      const float w = sexp(s - mx);
      den += w;
#pragma unroll
      for (int i = 0; i < 4; i++) {
        simd<float, 64> v;
        v.copy_from(V + (t * AKH + kh) * AD + i * 64);
        acc[i] += v * w;
      }
    }
    storef(pm + mh * nbs + b, mx);
    storef(pd + mh * nbs + b, den);
#pragma unroll
    for (int i = 0; i < 4; i++) acc[i].copy_to(pv + (mh * nbs + b) * AD + i * 64);
  });
}


// Variant B/D: one thread per (kv head, group of HG query heads, block of 64 keys); the thread walks all tokens of
// the pass over that block, so a K/V row is loaded once per HG heads and the block stays in L1 across tokens.
// Scores of a block are formed first, then one vectorised softmax, then the weighted V sum. Output format as k_attn_part.
template <int HG>
void k_attn_part2(Q &q, const float *qr, const float *K, const float *V, float *pm, float *pd, float *pv, int m,
                  int pos0, size_t nbs) {
  constexpr int GRP = AH / AKH / HG; // thread groups per kv head
  const size_t nb = size_t(pos0 + m - 1) / 64 + 1;
  q.parallel_for(sycl::range<1>(AKH * GRP * nb), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t b = id[0] % nb, g = id[0] / nb % GRP, kh = id[0] / nb / GRP;
    for (int mi = 0; mi < m; mi++) {
      const size_t last = pos0 + mi;
      if (b * 64 > last) break;
      const int nk = int(std::min<size_t>(64, last - b * 64 + 1));
      simd<float, 64> qv[HG][4], s[HG];
#pragma unroll
      for (int h = 0; h < HG; h++) {
        const size_t hh = kh * (AH / AKH) + g * HG + h;
#pragma unroll
        for (int i = 0; i < 4; i++) qv[h][i].copy_from(qr + (size_t(mi) * AH + hh) * AD + i * 64);
        s[h] = -1e30f;
      }
      for (int t = 0; t < nk; t++) {
        simd<float, 64> k[4];
        const float *kp = K + ((b * 64 + t) * AKH + kh) * AD;
#pragma unroll
        for (int i = 0; i < 4; i++) k[i].copy_from(kp + i * 64);
#pragma unroll
        for (int h = 0; h < HG; h++)
          s[h][t] = hsum<64>(qv[h][0] * k[0] + qv[h][1] * k[1] + qv[h][2] * k[2] + qv[h][3] * k[3]) * 0.0625f;
      }
      simd<float, 64> acc[HG][4];
#pragma unroll
      for (int h = 0; h < HG; h++) {
        const float mx = hmax<64>(s[h]);
        s[h] = es::exp(s[h] - mx);
        const size_t mh = size_t(mi) * AH + kh * (AH / AKH) + g * HG + h;
        storef(pm + mh * nbs + b, mx);
        storef(pd + mh * nbs + b, hsum<64>(s[h]));
#pragma unroll
        for (int i = 0; i < 4; i++) acc[h][i] = 0.0f;
      }
      for (int t = 0; t < nk; t++) {
        simd<float, 64> v[4];
        const float *vp = V + ((b * 64 + t) * AKH + kh) * AD;
#pragma unroll
        for (int i = 0; i < 4; i++) v[i].copy_from(vp + i * 64);
#pragma unroll
        for (int h = 0; h < HG; h++) {
          const simd<float, 64> w = float(s[h][t]);
#pragma unroll
          for (int i = 0; i < 4; i++) acc[h][i] += v[i] * w;
        }
      }
#pragma unroll
      for (int h = 0; h < HG; h++) {
        const size_t mh = size_t(mi) * AH + kh * (AH / AKH) + g * HG + h;
#pragma unroll
        for (int i = 0; i < 4; i++) acc[h][i].copy_to(pv + (mh * nbs + b) * AD + i * 64);
      }
    }
  });
}


// Variant C/D (transposed K): K is stored [block of 64 keys][kv head][dim][key], so the 64 keys of a block are the SIMD
// lanes: a score needs no horizontal reduction, and one K^T vector load feeds TG tokens x HG heads of FMAs
// (the query element is a scalar broadcast). Causal mask by lane. Output format as k_attn_part.
template <int HG, int TG>
void k_attn_part3(Q &q, const float *qr, const float *KT, const float *V, float *pm, float *pd, float *pv, int m,
                  int pos0, size_t nbs, int gper) {
  // gper = token groups handled by one thread (>= ceil(m / TG): one thread walks them all, 1: one group per thread)
  constexpr int GRP = AH / AKH / HG;
  const size_t nb = size_t(pos0 + m - 1) / 64 + 1;
  const int ngrp = (m + TG - 1) / TG, nsplit = (ngrp + gper - 1) / gper;
  q.parallel_for(sycl::range<1>(AKH * GRP * nb * nsplit), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t b = id[0] % nb, g = id[0] / nb % GRP, kh = id[0] / nb / GRP % AKH, sp = id[0] / nb / GRP / AKH;
    const float *kb = KT + (b * AKH + kh) * size_t(AD) * 64;
    const simd<int, 64> lane(0, 1);
    for (int t0 = int(sp) * gper * TG; t0 < std::min(m, int(sp + 1) * gper * TG); t0 += TG) {
      const int nt = std::min(TG, m - t0);
      const int lastg = pos0 + t0 + nt - 1; // last position seen by the last token of the group
      if (int(b) * 64 > lastg) continue;
      simd<float, 64> s[TG][HG];
#pragma unroll
      for (int tt = 0; tt < TG; tt++)
#pragma unroll
        for (int h = 0; h < HG; h++) s[tt][h] = 0.0f;
      for (int dc = 0; dc < AD / 16; dc++) {
        simd<float, 16> qc[TG][HG];
#pragma unroll
        for (int tt = 0; tt < TG; tt++)
#pragma unroll
          for (int h = 0; h < HG; h++) {
            if (tt < nt) qc[tt][h].copy_from(qr + (size_t(t0 + tt) * AH + kh * (AH / AKH) + g * HG + h) * AD + dc * 16);
            else qc[tt][h] = 0.0f;
          }
#pragma unroll
        for (int dd = 0; dd < 16; dd++) {
          simd<float, 64> k;
          k.copy_from(kb + size_t(dc * 16 + dd) * 64);
#pragma unroll
          for (int tt = 0; tt < TG; tt++)
#pragma unroll
            for (int h = 0; h < HG; h++) s[tt][h] += k * float(qc[tt][h][dd]);
        }
      }
#pragma unroll
      for (int tt = 0; tt < TG; tt++) {
        const int lim = pos0 + t0 + tt - int(b) * 64; // lanes 0..lim visible
#pragma unroll
        for (int h = 0; h < HG; h++) {
          simd<float, 64> x = s[tt][h] * 0.0625f;
          x.merge(simd<float, 64>(-1e30f), lane > lim);
          const float mx = hmax<64>(x);
          x = es::exp(x - mx);
          s[tt][h] = x;
          if (tt < nt && lim >= 0) {
            const size_t mh = size_t(t0 + tt) * AH + kh * (AH / AKH) + g * HG + h;
            storef(pm + mh * nbs + b, mx);
            storef(pd + mh * nbs + b, hsum<64>(x));
          }
        }
      }
      const int kmax = std::min(64, lastg - int(b) * 64 + 1);
      for (int i = 0; i < 4; i++) {
        simd<float, 64> acc[TG][HG];
#pragma unroll
        for (int tt = 0; tt < TG; tt++)
#pragma unroll
          for (int h = 0; h < HG; h++) acc[tt][h] = 0.0f;
        for (int t = 0; t < kmax; t++) {
          simd<float, 64> v;
          v.copy_from(V + ((b * 64 + t) * AKH + kh) * AD + i * 64);
#pragma unroll
          for (int tt = 0; tt < TG; tt++)
#pragma unroll
            for (int h = 0; h < HG; h++) acc[tt][h] += v * float(s[tt][h][t]);
        }
#pragma unroll
        for (int tt = 0; tt < TG; tt++)
#pragma unroll
          for (int h = 0; h < HG; h++)
            if (tt < nt && pos0 + t0 + tt >= int(b) * 64) {
              const size_t mh = size_t(t0 + tt) * AH + kh * (AH / AKH) + g * HG + h;
              acc[tt][h].copy_to(pv + (mh * nbs + b) * AD + i * 64);
            }
      }
    }
  });
}

// Combine block partials, apply the sigmoid output gate.
void k_attn_comb(Q &q, const float *pm, const float *pd, const float *pv, const float *yq, size_t qs, float *ao, float *pmax,
                 int m, int pos0, size_t nbs) {
  q.parallel_for(sycl::range<1>(size_t(m) * AH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mh = id[0], mi = mh / AH, h = mh % AH;
    const size_t nb = size_t(pos0 + mi) / 64 + 1;
    float mx = -1e30f;
    for (size_t b = 0; b < nb; b++) {
      const float v = loadf(pm + mh * nbs + b);
      if (v > mx) mx = v;
    }
    simd<float, 64> acc[4];
#pragma unroll
    for (int i = 0; i < 4; i++) acc[i] = 0.0f;
    float den = 0.0f;
    for (size_t b = 0; b < nb; b++) {
      const float e = sexp(loadf(pm + mh * nbs + b) - mx);
      den += e * loadf(pd + mh * nbs + b);
#pragma unroll
      for (int i = 0; i < 4; i++) {
        simd<float, 64> v;
        v.copy_from(pv + (mh * nbs + b) * AD + i * 64);
        acc[i] += v * e;
      }
    }
    const float inv = 1.0f / den;
#pragma unroll
    for (int i = 0; i < 4; i++) {
      simd<float, 64> gate;
      gate.copy_from(yq + mi * qs + h * 2 * AD + AD + i * 64);
      simd<float, 64> o = acc[i] * inv * sigmoid<64>(gate);
      o.copy_to(ao + mi * VD + h * AD + i * 64);
      storef(pmax + mi * PS + h * 4 + i, hmax<64>(es::abs(o)));
    }
  });
}

// a = silu(gate) * up, in place into g.
void k_mlp_act(Q &q, float *g, const float *u, size_t gs, float *pmax, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * (FF / 64)), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / (FF / 64), c = id[0] % (FF / 64);
    simd<float, 64> a, b;
    a.copy_from(g + mi * gs + c * 64);
    b.copy_from(u + mi * gs + c * 64);
    a = a * sigmoid<64>(a) * b;
    a.copy_to(g + mi * gs + c * 64);
    storef(pmax + mi * PS + c, hmax<64>(es::abs(a)));
  });
}

// Per token, 97 chunks of 2560 logits: per-lane running maximum and its index
// (first occurrence). The host finishes the reduction.
void k_argmax(Q &q, const float *logits, float *amv, int32_t *ami, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * AMC), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / AMC, c = id[0] % AMC;
    const float *p = logits + mi * VOCAB + c * (AMB * 64);
    simd<float, 64> best;
    best.copy_from(p);
    simd<int32_t, 64> idx(int32_t(c * AMB * 64), 1), cur = idx;
    for (int b = 1; b < AMB; b++) {
      simd<float, 64> v;
      v.copy_from(p + b * 64);
      cur += 64;
      auto gt = v > best;
      best.merge(v, gt);
      idx.merge(cur, gt);
    }
    best.copy_to(amv + id[0] * 64);
    idx.copy_to(ami + id[0] * 64);
  });
}

template <int N> ESIMD_INLINE int32_t hmin_i(simd<int32_t, N> v) SYCL_ESIMD_FUNCTION {
  if constexpr (N == 1) {
    return v[0];
  } else {
    simd<int32_t, N / 2> a = v.template select<N / 2, 1>(0);
    simd<int32_t, N / 2> b = v.template select<N / 2, 1>(N / 2);
    return hmin_i<N / 2>(es::min(a, b));
  }
}
ESIMD_INLINE void storei(int32_t *p, int32_t x) SYCL_ESIMD_FUNCTION {
  simd<int32_t, 1> v(x);
  v.copy_to(p);
}
// Largest value of 64 lanes and the smallest index that attains it.
ESIMD_INLINE void lane_best(simd<float, 64> v, simd<int32_t, 64> idx, float &bv, int32_t &bi) SYCL_ESIMD_FUNCTION {
  bv = hmax<64>(v);
  idx.merge(simd<int32_t, 64>(0x7fffffff), v < bv);
  bi = hmin_i<64>(idx);
}

// Finish the argmax on the device: one thread per token reduces the 97 x 64
// partials of k_argmax to (token, logit); ties go to the lowest token id.
// Optionally forwards row 0's token to two more places (draft chaining).
void k_amax_final(Q &q, const float *amv, const int32_t *ami, int m, int32_t *out_i, float *out_v, int32_t *dst0,
                  int32_t *dst1) {
  q.parallel_for(sycl::range<1>(m), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0];
    simd<float, 64> bv;
    simd<int32_t, 64> bi;
    bv.copy_from(amv + mi * AMC * 64);
    bi.copy_from(ami + mi * AMC * 64);
    for (int c = 1; c < AMC; c++) {
      simd<float, 64> v;
      simd<int32_t, 64> i;
      v.copy_from(amv + (mi * AMC + c) * 64);
      i.copy_from(ami + (mi * AMC + c) * 64);
      auto gt = v > bv; // within a lane indices only grow, so strict > keeps the first
      bv.merge(v, gt);
      bi.merge(i, gt);
    }
    float v;
    int32_t i;
    lane_best(bv, bi, v, i);
    if (out_i) storei(out_i + mi, i);
    if (out_v) storef(out_v + mi, v);
    if (mi == 0) {
      if (dst0) storei(dst0, i);
      if (dst1) storei(dst1, i);
    }
  });
}

// pmax of a plain vector (one row), per 64 columns.
void k_pmax(Q &q, const float *v, int n, float *pmax) {
  q.parallel_for(sycl::range<1>(n / 64), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    simd<float, 64> x;
    x.copy_from(v + id[0] * 64);
    storef(pmax + id[0], hmax<64>(es::abs(x)));
  });
}

// Sketch selection. The vocabulary is cut into `groups` contiguous parts; in
// each part every lane (token id mod 64) keeps its best-scoring token, giving
// groups * 64 candidates. Splitting by id mod 64 matters: tokens with adjacent
// ids are often near-duplicates with similar scores, and one candidate per
// contiguous range lets them knock each other out.
void k_sk_select(Q &q, const float *scores, int groups, int32_t *cand) {
  const int nb = VOCAB / 64 / groups; // 64-token blocks per group
  q.parallel_for(sycl::range<1>(groups), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t c = id[0];
    const float *p = scores + c * nb * 64;
    simd<float, 64> best;
    best.copy_from(p);
    simd<int32_t, 64> idx(int32_t(c * nb * 64), 1), cur = idx;
    for (int b = 1; b < nb; b++) {
      simd<float, 64> v;
      v.copy_from(p + b * 64);
      cur += 64;
      auto gt = v > best;
      best.merge(v, gt);
      idx.merge(cur, gt);
    }
    idx.copy_to(cand + c * 64);
  });
}

// Exact logits for the 16-row block of every candidate, with the same integer
// arithmetic and the same finishing formula as the full lm_head GEMM
// (s4 weights, 16-bit activations, one token). Threads past `n` pad the
// result arrays so the picker can read whole vectors.
void k_rescore(Q &q, const xf_mat &head, const int8_t *xhi, const uint8_t *xlo, const float *ts, const float *toff,
               const int32_t *cand, int n, int npad, float *candv, int32_t *candi) {
  namespace xmx = sycl::ext::intel::esimd::xmx;
  using PT = xmx::dpas_argument_type;
  const int32_t *W = static_cast<const int32_t *>(head.w);
  const int32_t *XH = reinterpret_cast<const int32_t *>(xhi);
  const int32_t *XL = reinterpret_cast<const int32_t *>(xlo);
  const float *RS = head.rs, *RB = head.bias;
  const size_t tiles = size_t(head.cols) / 32;
  q.parallel_for(sycl::range<1>(npad), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t c = id[0];
    if (int(c) >= n) {
      storef(candv + c, -3.0e38f);
      storei(candi + c, 0x7fffffff);
      return;
    }
    simd<int32_t, 1> tk;
    tk.copy_from(cand + c);
    const size_t rb = size_t(tk[0]) / 16;
    const int32_t *wp = W + rb * tiles * 64;
    simd<int32_t, 16> hi(0), lo(0);
    for (size_t t = 0; t < tiles; t++) {
      simd<int32_t, 64> w;
      w.copy_from(wp + t * 64);
      simd<int32_t, 8> a, b;
      a.copy_from(XH + t * 8);
      b.copy_from(XL + t * 8);
      hi = xmx::dpas<8, 1, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(hi, w, a);
      lo = xmx::dpas<8, 1, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(lo, w, b);
    }
    simd<float, 16> rsv, rbv(0.0f);
    rsv.copy_from(RS + rb * 16);
    if (RB) rbv.copy_from(RB + rb * 16);
    simd<float, 16> f = es::convert<float>(hi);
    f = f * 256.0f + es::convert<float>(lo);
    f = f + loadf(toff);
    f = f * rsv * loadf(ts) + rbv;
    const float bv = hmax<16>(f);
    simd<int32_t, 16> idx(int32_t(rb * 16), 1);
    idx.merge(simd<int32_t, 16>(0x7fffffff), f < bv);
    storef(candv + c, bv);
    storei(candi + c, hmin_i<16>(idx));
  });
}

// Best candidate (highest exact logit, lowest id on ties) -> token id.
void k_pick(Q &q, const float *candv, const int32_t *candi, int npad, int32_t *dst0, int32_t *dst1, int32_t *dst2) {
  q.single_task([=]() SYCL_ESIMD_KERNEL {
    float bv = -3.0e38f;
    int32_t bi = 0x7fffffff;
    for (int k = 0; k < npad / 64; k++) {
      simd<float, 64> v;
      simd<int32_t, 64> i;
      v.copy_from(candv + k * 64);
      i.copy_from(candi + k * 64);
      float cv;
      int32_t ci;
      lane_best(v, i, cv, ci);
      if (cv > bv || (cv == bv && ci < bi)) {
        bv = cv;
        bi = ci;
      }
    }
    if (dst0) storei(dst0, bi);
    if (dst1) storei(dst1, bi);
    if (dst2) storei(dst2, bi);
  });
}

// -------------------------------------------------------------- pass driver
struct Timer {
  Q &q;
  double *prof;
  bool trace; // XF_TRACE_STAGES: wait and print a marker after every stage
  std::chrono::steady_clock::time_point t0;
  Timer(Q &queue, double *p) : q(queue), prof(p), trace(std::getenv("XF_TRACE_STAGES") != nullptr) {
    if (prof) t0 = std::chrono::steady_clock::now();
  }
  // Attribute everything submitted since the last call to category `cat`.
  void tick(int cat) {
    if (!prof && !trace) return;
    if (trace) std::fprintf(stderr, "%d", cat);
    q.wait_and_throw();
    if (trace) std::fprintf(stderr, ". ");
    if (!prof) return;
    const auto t1 = std::chrono::steady_clock::now();
    prof[cat] += std::chrono::duration<double, std::milli>(t1 - t0).count();
    t0 = t1;
  }
};
enum { P_NORM = 0, P_QUANT, P_GEMM, P_GDN, P_ATTN, P_MLP, P_HEAD, P_COUNT };

struct Pass {
  xf_ctx *ctx;
  const xf_model *md;
  WS ws;
  int m, mpad, tpt;
  Timer tm;
  bool pending = false; // ws.y still has to be added to ws.h
  int gemm_cat = P_GEMM; // profile category of the next GEMM (the head has its own)

  // y[m][rows] = mat (v[m][cols]) ; pmax must describe v.
  // `vs` is the row stride of v (0 = mat.cols). The output row stride is mat.rows.
  // `one` runs a single row (v points at it, pm at its pmax row) regardless of the pass size.
  // `plain` = codes are plain integers (no +0.5 level offset), as in the head sketch table.
  int gemm(const xf_mat &mat, const float *v, float *y, size_t vs = 0, bool one = false, const float *pm = nullptr,
           bool plain = false) {
    Q &q = ctx->q;
    const int m = one ? 1 : this->m, mpad = one ? 1 : this->mpad, tpt = one ? 1 : this->tpt;
    const float *pmax = pm ? pm : ws.pmax;
    k_quant(q, v, vs ? vs : size_t(mat.cols), mat.cols, mat.cs, mat.cmax, pmax, m, mpad, ws.xhi, ws.xlo, ws.ts, ws.toff);
    tm.tick(P_QUANT);
    xf_gemm_desc d{};
    d.wfmt = mat.fmt;
    d.rows = mat.rows;
    d.cols = mat.cols;
    d.m = m;
    d.tokens_per_thread = tpt;
    d.segs = (mat.rows < 8192 && m > 1) ? 4 : 1;
    d.a16 = 1;
    d.w = mat.w;
    d.x = ws.xhi;
    d.xlo = ws.xlo;
    d.rs = mat.rs;
    d.ts = ws.ts;
    d.y = y;
    d.ypart = ws.ypart;
    d.toff = plain ? nullptr : ws.toff;
    static const bool no_bias = std::getenv("XF_NO_BIAS") != nullptr; // diagnostic
    d.bias = no_bias ? nullptr : mat.bias;
    const int st = xf_gemm(ctx, &d);
    tm.tick(gemm_cat);
    return st;
  }

  // RMSNorm of the residual stream; folds in the pending residual add.
  void norm(const float *gain) {
    k_addnorm(ctx->q, ws.h, pending ? ws.y : nullptr, gain, ws.xn, ws.pmax, m);
    pending = false;
    tm.tick(P_NORM);
  }
  void flush() {
    if (pending) k_add(ctx->q, ws.h, ws.y, m);
    pending = false;
  }

  // gi = index of gate_proj. Merged containers hold gate+up as one matrix in
  // that slot (up slot empty); either way gate and up outputs sit side by side.
  int mlp(const xf_layer &L, int gi) {
    Q &q = ctx->q;
    const bool merged = L.m[gi + 1].rows == 0;
    const size_t gs = 2 * FF;
    norm(L.ln2);
    if (merged) {
      if (int st = gemm(L.m[gi], ws.xn, ws.g)) return st; // rows = 2 * FF: [gate | up] per token
    } else {
      // Two launches; each writes its own contiguous [m][FF] block, so stage
      // them and interleave is avoided by giving up its own buffer.
      if (int st = gemm(L.m[gi], ws.xn, ws.u)) return st;
      if (int st = gemm(L.m[gi + 1], ws.xn, ws.u + size_t(MAXM) * FF)) return st;
    }
    const float *gptr = merged ? ws.g : ws.u;
    const float *uptr = merged ? ws.g + FF : ws.u + size_t(MAXM) * FF;
    const size_t stride = merged ? gs : size_t(FF);
    k_mlp_act(q, const_cast<float *>(gptr), uptr, stride, ws.pmax, m);
    tm.tick(P_MLP);
    if (int st = gemm(L.m[gi + 2], gptr, ws.y, stride)) return st;
    pending = true;
    return XF_OK;
  }

  int gdn(const xf_layer &L) {
    Q &q = ctx->q;
    GdnState s = carve_gdn(L.state);
    const bool merged = L.m[1].rows == 0; // m[0] is qkv+z stacked
    const size_t rs = merged ? QKVZ : QKV;
    const float *z = merged ? s.raw + QKV : ws.yz;
    const size_t zs = merged ? QKVZ : VD;
    norm(L.ln1);
    if (int st = gemm(L.m[0], ws.xn, s.raw)) return st;
    if (!merged)
      if (int st = gemm(L.m[1], ws.xn, ws.yz)) return st;
    k_gemv_f32(q, L.aux[0], ws.xn, ws.yab, 96, m);
    k_conv(q, s.raw, rs, s.hist, L.aux[1], ws.act, m);
    k_gdn_qk(q, ws.act, ws.qn, s.kn, m);
    k_gdn_gate(q, ws.yab, L.aux[2], L.aux[3], s.beta, s.decay, m);
    k_gdn_core(q, s.S, ws.act, ws.qn, s.kn, s.beta, s.decay, s.dsave, ws.gout, m);
    k_gdn_post(q, ws.gout, z, zs, L.aux[4], ws.go, ws.pmax, m);
    tm.tick(P_GDN);
    if (int st = gemm(L.m[2], ws.go, ws.y)) return st;
    pending = true;
    return mlp(L, 3);
  }

  int attn(const xf_layer &L, int pos0) {
    Q &q = ctx->q;
    AttnState s = carve_attn(L.state, md->ctx);
    const size_t nbs = size_t(md->ctx) / 64 + 1;
    const bool merged = L.m[1].rows == 0; // m[0] is q+k+v stacked
    norm(L.ln1);
    const float *yk, *yv;
    size_t qs, ks;
    if (merged) {
      if (int st = gemm(L.m[0], ws.xn, ws.yq)) return st;
      qs = ks = AQKV;
      yk = ws.yq + QP;
      yv = ws.yq + QP + KVD;
    } else {
      if (int st = gemm(L.m[0], ws.xn, ws.yq)) return st;
      if (int st = gemm(L.m[1], ws.xn, ws.yk)) return st;
      if (int st = gemm(L.m[2], ws.xn, ws.yv)) return st;
      qs = QP;
      ks = KVD;
      yk = ws.yk;
      yv = ws.yv;
    }
    k_attn_q(q, ws.yq, qs, L.aux[0], md->rope_cos, md->rope_sin, ws.qr, m, pos0);
    static const bool kt = !(std::getenv("XF_ATTN_KT") && std::getenv("XF_ATTN_KT")[0] == '0') && md->ctx % 64 == 0; // default on; XF_ATTN_KT=0 = legacy
    k_attn_kv(q, yk, yv, ks, L.aux[1], md->rope_cos, md->rope_sin, s.K, s.V, m, pos0, kt);
    if (kt) {
      // Re-read each pass so a sweep can change them between passes (cheap).
      const char *eh = std::getenv("XF_ATTN_HG"), *et = std::getenv("XF_ATTN_TG"), *eg = std::getenv("XF_ATTN_GP");
      const int nbk = int(size_t(pos0 + m - 1) / 64 + 1);
      int hg = eh ? std::atoi(eh) : 3;
      int tgo = et ? std::atoi(et) : 0;
      int gp = eg ? std::atoi(eg) : 0;
      if (!eh && !et && !eg) {
        // Automatic choice, from the sweep in PERFORMANCE.md (best HG:TG, one token group per thread):
        // short contexts need more threads (small HG/TG), long ones more reuse (HG=3, TG=4).
        if (m == 1) { hg = nbk < 24 ? 1 : nbk < 200 ? 3 : 6; tgo = 2; }
        else if (m <= 8) { hg = 3; tgo = nbk < 48 ? 2 : 4; }
        else if (nbk < 24) { hg = 3; tgo = 2; }
        else if (nbk < 48) { hg = 6; tgo = 2; }
        else { hg = 3; tgo = 4; }
        gp = 1;
      }
      const int tg = tgo ? tgo : (m <= 1 ? 1 : m <= 2 ? 2 : 4);
      if (gp == 0) gp = 1000;
      if (std::getenv("XF_ATTN_LOG")) {
        static unsigned seen = 0;
        const unsigned key = unsigned(m) * 4u + (nbk < 24 ? 0u : nbk < 48 ? 1u : 2u);
        if (key < 64 && !(seen >> key & 1u)) { seen |= 1u << key; std::fprintf(stderr, "[attn] part3<HG=%d,TG=%d> gper=%d rows=%d blocks=%d\n", hg, tg, gp, m, nbk); }
      }
#define XF_P3(H, T) k_attn_part3<H, T>(q, ws.qr, s.K, s.V, ws.pm, ws.pd, ws.pv, m, pos0, nbs, gp)
      if (hg == 6) { if (tg == 1) XF_P3(6, 1); else if (tg == 2) XF_P3(6, 2); else if (tg == 4) XF_P3(6, 4); else XF_P3(6, 8); }
      else if (hg == 1) { if (tg == 1) XF_P3(1, 1); else if (tg == 2) XF_P3(1, 2); else if (tg == 4) XF_P3(1, 4); else XF_P3(1, 8); }
      else if (hg == 2) { if (tg == 1) XF_P3(2, 1); else if (tg == 2) XF_P3(2, 2); else if (tg == 4) XF_P3(2, 4); else XF_P3(2, 8); }
      else { if (tg == 1) XF_P3(3, 1); else if (tg == 2) XF_P3(3, 2); else if (tg == 4) XF_P3(3, 4); else XF_P3(3, 8); }
#undef XF_P3
      (void)nbk;
    } else {
      static const int hg = std::getenv("XF_ATTN_HG") ? std::atoi(std::getenv("XF_ATTN_HG")) : 0;
      if (hg == 6) k_attn_part2<6>(q, ws.qr, s.K, s.V, ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      else if (hg == 3) k_attn_part2<3>(q, ws.qr, s.K, s.V, ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      else if (hg == 2) k_attn_part2<2>(q, ws.qr, s.K, s.V, ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      else if (hg == 1) k_attn_part2<1>(q, ws.qr, s.K, s.V, ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      else k_attn_part(q, ws.qr, s.K, s.V, ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      static const bool alog = std::getenv("XF_ATTN_LOG") != nullptr;
      static unsigned seen = 0;
      if (alog && !(seen >> m & 1u)) {
        seen |= 1u << m;
        std::fprintf(stderr, "[attn] legacy path (hg=%d), rows=%d, pos0=%d, row-major K\n", hg, m, pos0);
      }
    }
    k_attn_comb(q, ws.pm, ws.pd, ws.pv, ws.yq, qs, ws.go, ws.pmax, m, pos0, nbs);
    tm.tick(P_ATTN);
    if (int st = gemm(L.m[3], ws.go, ws.y)) return st;
    pending = true;
    return mlp(L, 4);
  }
};

} // namespace

extern "C" {

size_t xf_ws_bytes(int ctx) { return carve_ws(nullptr, ctx).total; }

size_t xf_state_bytes(int kind, int ctx) {
  return kind == XF_LAYER_GDN ? carve_gdn(nullptr).total : carve_attn(nullptr, ctx).total;
}

size_t xf_ws_offset(int which, int ctx) {
  const WS w = carve_ws(nullptr, ctx);
  const void *p = nullptr;
  switch (which) {
  case XF_WS_IDS: p = w.ids; break;
  case XF_WS_H: p = w.h; break;
  case XF_WS_XN: p = w.xn; break;
  case XF_WS_LOGITS: p = w.logits; break;
  case XF_WS_AMAX_V: p = w.amv; break;
  case XF_WS_AMAX_I: p = w.ami; break;
  case XF_WS_MTP_H: p = w.mh; break;
  case XF_WS_CAP: p = w.cap; break;
  default: return SIZE_MAX;
  }
  return size_t(static_cast<const char *>(p) - static_cast<const char *>(nullptr));
}

int xf_forward(xf_ctx *ctx, const xf_model *md, int m, int pos0, int l0, int l1, int flags, double *prof) {
  const int slot = (flags & XF_FWD_IDS_SLOT1) ? 16 : 0;
  if (!ctx || !md || m < 1 || m > MAXM || pos0 < 0 || pos0 + m > md->ctx || l0 < 0 || l1 > md->nlayers) {
    xf_set_error("xf_forward: invalid arguments (token count, position or layer range)");
    return XF_ERR_INVALID;
  }
  return xf_guard("xf_forward", [&]() -> int {
    const int tpt = m == 1 ? 1 : m <= 8 ? 8 : 16;
    Pass p{ctx, md, carve_ws(md->ws, md->ctx), m, tpt, tpt, Timer(ctx->q, prof)};
    Q &q = ctx->q;
    if (flags & XF_FWD_EMBED) {
      k_embed(q, md->embed, p.ws.ids + slot, p.ws.h, m);
      p.tm.tick(P_NORM);
    }
    // XF_SYNC_LAYERS=n: wait for the queue every n layers (diagnostic / workaround knob).
    static const int sync_every = [] {
      const char *e = std::getenv("XF_SYNC_LAYERS");
      return e ? std::atoi(e) : 0;
    }();
    for (int l = l0; l < l1; l++) {
      const xf_layer &L = md->layers[l];
      if (p.tm.trace) std::fprintf(stderr, "\nL%d: ", l);
      const int st = L.kind == XF_LAYER_GDN ? p.gdn(L) : p.attn(L, pos0);
      if (st != XF_OK) return st;
      if ((flags & XF_FWD_CAPTURE) && l % 14 == 5) // hidden_states[l + 1] for l = 5, 19, 33, 47, 61
        k_capture(q, p.ws.h, p.pending ? p.ws.y : nullptr, p.ws.cap + size_t(l / 14) * MAXM * D, m);
      if (sync_every > 0 && (l + 1) % sync_every == 0) q.wait_and_throw();
    }
    if (flags & XF_FWD_HEAD) {
      p.norm(md->fnorm);
      p.gemm_cat = P_HEAD;
      if (int st = p.gemm(md->head, p.ws.xn, p.ws.logits)) return st;
      k_argmax(q, p.ws.logits, p.ws.amv, p.ws.ami, m);
      k_amax_final(q, p.ws.amv, p.ws.ami, m, p.ws.ids + 32, reinterpret_cast<float *>(p.ws.ids + 48), nullptr, nullptr);
      p.tm.tick(P_HEAD);
    }
    p.flush();
    return XF_OK;
  });
}

} // extern "C"

namespace {
// One MTP pass over m rows. Row i pairs hidden state `src_row + i` of the
// previous pass (the final-norm output still in the workspace; src_row < 0 =
// zeros) with token ids[i], at MTP position pos0 + i. Then the draft head on
// row `hrow` only: mtp.norm, logits, argmax.
//   sk == nullptr: the full shared lm_head, argmax finished on the device.
//   sk != nullptr: low-rank sketch scores -> groups * 64 candidates ->
//                  exact lm_head logits for the candidates' row blocks.
// The winning token goes to the greedy slot [32], and to dst0 / dst1 if given
// (next step's input id, verify-pass id). No host round trip.
int mtp_step(Pass &p, const xf_mtp *mtp, const xf_sketch *sk, int pos0, int src_row, int hrow, int32_t *dst0,
             int32_t *dst1) {
  Q &q = p.ctx->q;
  WS &w = p.ws;
  const xf_model *md = p.md;
  const int m = p.m;
  const float *hid = src_row < 0 ? nullptr : w.xn + size_t(src_row) * D;
  k_embed(q, md->embed, w.ids, w.y, m);
  k_rms(q, w.y, w.inv, m);
  if (hid) k_rms(q, hid, w.toff, m);
  k_mtp_cat(q, w.y, w.inv, mtp->gain_e, hid, w.toff, mtp->gain_h, w.me, m);
  k_gemv_dense(q, mtp->fc, w.me, w.h, D, 2 * D, m);
  p.tm.tick(P_NORM);
  if (int st = p.attn(mtp->layer, pos0)) return st;
  p.norm(mtp->norm);
  const float *hv = w.xn + size_t(hrow) * D;
  const float *hpm = w.pmax + size_t(hrow) * PS;
  p.gemm_cat = P_HEAD;
  if (!sk) {
    if (int st = p.gemm(md->head, hv, w.logits, 0, true, hpm)) return st;
    k_argmax(q, w.logits, w.amv, w.ami, 1);
    k_amax_final(q, w.amv, w.ami, 1, w.ids + 32, reinterpret_cast<float *>(w.ids + 48), dst0, dst1);
  } else {
    // 1. sketch scores for the whole vocabulary: A (B h)
    k_gemv_dense(q, sk->b, hv, w.sk_z, sk->rank, D, 1);
    k_pmax(q, w.sk_z, sk->rank, w.psum); // psum is free scratch here
    if (int st = p.gemm(sk->a, w.sk_z, w.sk_s, 0, true, w.psum, true)) return st;
    // 2. one candidate per chunk
    const int npad = sk->groups * 64;
    k_sk_select(q, w.sk_s, sk->groups, w.cand);
    // 3. exact logits of the candidates' row blocks, with the head's own quantised input
    k_quant(q, hv, D, D, md->head.cs, md->head.cmax, hpm, 1, 1, w.xhi, w.xlo, w.ts, w.toff);
    k_rescore(q, md->head, w.xhi, w.xlo, w.ts, w.toff, w.cand, npad, npad, w.candv, w.candi);
    k_pick(q, w.candv, w.candi, npad, w.ids + 32, dst0, dst1);
  }
  p.gemm_cat = P_GEMM;
  p.tm.tick(P_HEAD);
  return XF_OK;
}
} // namespace

extern "C" {

// Host-driven single MTP pass (kept for tools and tests): head on the last row.
int xf_mtp_step(xf_ctx *ctx, const xf_model *md, const xf_mtp *mtp, int m, int pos0, int src_row, double *prof) {
  if (!ctx || !md || !mtp || m < 1 || m > MAXM || pos0 < 0 || pos0 + m > md->ctx || src_row + m > MAXM) {
    xf_set_error("xf_mtp_step: invalid arguments");
    return XF_ERR_INVALID;
  }
  return xf_guard("xf_mtp_step", [&]() -> int {
    const int tpt = m == 1 ? 1 : m <= 8 ? 8 : 16;
    Pass p{ctx, md, carve_ws(md->ws, md->ctx), m, tpt, tpt, Timer(ctx->q, prof)};
    return mtp_step(p, mtp, nullptr, pos0, src_row, m - 1, nullptr, nullptr);
  });
}

// Whole draft phase of a speculative cycle in one submission.
//   n      rows committed by the last trunk pass; their final-norm hidden
//          states are still in the workspace, ids[0..n) hold the token that
//          follows each row (the last one is the certain next token, which the
//          host also put in the verify slot ids[16]).
//   pos0   MTP position of the first of those rows.
//   k      drafts to produce; draft j (1-based) is written to ids[16 + j].
// Step 1 rewrites the MTP cache entries of the n committed rows from trunk
// hidden states and drafts d1 from the last one; steps 2..k chain on the MTP's
// own output with the token ids staying on the device.
int xf_spec_draft(xf_ctx *ctx, const xf_model *md, const xf_mtp *mtp, const xf_sketch *sk, int n, int pos0, int k,
                  double *prof) {
  if (!ctx || !md || !mtp || n < 1 || n > MAXM || k < 1 || k > MAXM - 1 || pos0 < 0 || pos0 + n + k > md->ctx) {
    xf_set_error("xf_spec_draft: invalid arguments");
    return XF_ERR_INVALID;
  }
  if (sk && (md->head.fmt != XF_W_S4 || sk->groups < 1 || sk->groups > 64 || (VOCAB / 64) % sk->groups != 0 ||
             sk->rank > 2048 || sk->rank % 128 != 0)) {
    xf_set_error("xf_spec_draft: unsupported sketch configuration");
    return XF_ERR_INVALID;
  }
  return xf_guard("xf_spec_draft", [&]() -> int {
    WS w = carve_ws(md->ws, md->ctx);
    {
      const int tpt = n == 1 ? 1 : n <= 8 ? 8 : 16;
      Pass p{ctx, md, w, n, tpt, tpt, Timer(ctx->q, prof)};
      if (int st = mtp_step(p, mtp, sk, pos0, 0, n - 1, w.ids, w.ids + 16 + 1)) return st;
    }
    for (int j = 2; j <= k; j++) {
      Pass p{ctx, md, w, 1, 1, 1, Timer(ctx->q, prof)};
      // input: token d_{j-1} (in ids[0]) and the MTP hidden state that produced it
      if (int st = mtp_step(p, mtp, sk, pos0 + n - 1 + (j - 1), j == 2 ? n - 1 : 0, 0, w.ids, w.ids + 16 + j)) return st;
    }
    return XF_OK;
  });
}

int xf_commit(xf_ctx *ctx, const xf_model *md, int n) {
  if (!ctx || !md || n < 0 || n > MAXM) return XF_ERR_INVALID;
  return xf_guard("xf_commit", [&]() -> int {
    if (n == 0) return XF_OK;
    for (int l = 0; l < md->nlayers; l++) {
      const xf_layer &L = md->layers[l];
      if (L.kind != XF_LAYER_GDN) continue;
      GdnState s = carve_gdn(L.state);
      k_gdn_commit(ctx->q, s.S, s.kn, s.decay, s.dsave, n);
      k_hist_commit(ctx->q, s.hist, s.raw, L.m[1].rows == 0 ? size_t(QKVZ) : size_t(QKV), n);
    }
    return XF_OK;
  });
}

int xf_copy(xf_ctx *ctx, void *dst, const void *src, size_t bytes) {
  if (!ctx || !dst || !src) return XF_ERR_INVALID;
  return xf_guard("xf_copy", [&]() -> int {
    ctx->q.memcpy(dst, src, bytes);
    return XF_OK;
  });
}

int xf_zero(xf_ctx *ctx, void *dst, size_t bytes) {
  if (!ctx || !dst) return XF_ERR_INVALID;
  return xf_guard("xf_zero", [&]() -> int {
    ctx->q.memset(dst, 0, bytes);
    return XF_OK;
  });
}

} // extern "C"
