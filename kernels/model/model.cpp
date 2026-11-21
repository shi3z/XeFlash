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
#include <cstring>
#include <map>
#include <string>

#include "../ctx.hpp"

namespace es = sycl::ext::intel::esimd;
namespace xmx = sycl::ext::intel::esimd::xmx;
using es::simd;

namespace {

constexpr int MAXM = 64;
constexpr int IDV = MAXM, IDG = 2 * MAXM, IDL = 3 * MAXM; // io block: pass ids [0,MAXM), verify ids [IDV,..), greedy ids [IDG,..), greedy logits (f32) [IDL,..)
// Rows per pass: 64 up to a context of 32,768 positions; above that the workspace (logits, MLP activations, attention partials: pseg alone is 4 x groups x (blocks / 4 + 2) x 4096 floats = 380 MB at 60K for 64 rows)
// would eat the 0.4 GiB that is left for the drafter at 60K (benchmarks/results/m34/fit60k_bdraft2.log), so passes are limited to 16 rows there as before the 32/64-row change.
constexpr int rows_cap(int ctx) { return ctx > 32768 ? 16 : MAXM; }
constexpr int gmax_of(int ctx) { return (6 * rows_cap(ctx) + 15) / 16; } // attention row groups of 16 (token, head) rows
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
  int32_t *ids; // io block (4 x MAXM words): pass ids, verify ids (next + drafts), greedy ids, greedy logits (f32)
  float *sk_z, *sk_s, *candv;
  float *cap; // residual stream after layers 5, 19, 33, 47, 61: blocks of 16 rows, each [5][16][D]
  int32_t *cand, *candi;
  float *inv, *ts, *toff, *pmax, *psum, *h, *xn, *y;
  int8_t *xhi;
  uint8_t *xlo;
  void *ypart;
  float *act, *yz, *yab, *qn, *gout, *go, *yq, *yk, *yv, *qr, *g, *u, *logits, *amv;
  int32_t *ami;
  float *pm, *pd, *pv;
  uint16_t *q16; // XMX attention: Q^T operand tiles (fp16)
  float *pseg, *psm, *psd; // XMX attention: combined partials per segment of XSEG blocks
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

int kv_mode();
WS carve_ws(void *base, int ctx) {
  Bump b{static_cast<char *>(base)};
  const size_t nb = size_t(ctx) / 64 + 1;
  WS w;
  const int MX = rows_cap(ctx); // rows per pass this workspace is sized for
  w.ids = b.take<int32_t>(4 * MAXM); // io block: fixed size, offsets IDV/IDG/IDL
  w.inv = b.take<float>(MX);
  w.ts = b.take<float>(MX);
  w.toff = b.take<float>(MX);
  w.pmax = b.take<float>(MX * PS);
  w.psum = b.take<float>(MX * PS);
  w.h = b.take<float>(MX * D);
  w.xn = b.take<float>(MX * D);
  w.y = b.take<float>(MX * D);
  w.xhi = b.take<int8_t>(size_t(FF / 32) * MX * 32);
  w.xlo = b.take<uint8_t>(size_t(FF / 32) * MX * 32);
  w.ypart = b.take<int32_t>(size_t(4) * 2 * MX * VD);
  w.act = b.take<float>(MX * QKV);
  w.yz = b.take<float>(MX * VD);
  w.yab = b.take<float>(MX * 128);
  w.qn = b.take<float>(MX * KH * HD);
  w.gout = b.take<float>(MX * VD);
  w.go = b.take<float>(MX * VD);
  w.yq = b.take<float>(MX * AQKV);
  w.yk = b.take<float>(MX * KVD);
  w.yv = b.take<float>(MX * KVD);
  w.qr = b.take<float>(MX * AH * AD);
  w.g = b.take<float>(size_t(MX) * 2 * FF);
  w.u = b.take<float>(size_t(MX) * 2 * FF);
  w.logits = b.take<float>(size_t(MX) * VOCAB);
  w.amv = b.take<float>(MX * AMC * 64);
  w.ami = b.take<int32_t>(MX * AMC * 64);
  w.pm = b.take<float>(MX * AH * nb);
  w.pd = b.take<float>(MX * AH * nb);
  // XF_KV=xmx uses the fused kernel (segment partials in pseg), so the 378 MB (at 60K) block-partial buffer is only kept for XF_XMX_OLD
  w.pv = b.take<float>(((kv_mode() == 3 && !std::getenv("XF_XMX_OLD")) || kv_mode() == 4) ? size_t(4096) : size_t(MX) * AH * nb * AD);
  w.mh = b.take<float>(MX * D);
  w.me = b.take<float>(MX * 2 * D);
  w.cap = b.take<float>(size_t(5) * MX * D);
  w.sk_z = b.take<float>(2048);
  w.sk_s = b.take<float>(VOCAB);
  w.cand = b.take<int32_t>(4096);
  w.candi = b.take<int32_t>(4096);
  w.candv = b.take<float>(4096);
  w.q16 = b.take<uint16_t>(size_t(AKH) * gmax_of(ctx) * 16 * 256);
  w.pseg = b.take<float>(size_t(AKH) * gmax_of(ctx) * (nb / 4 + 2) * 4096);
  w.psm = b.take<float>(size_t(AKH) * gmax_of(ctx) * (nb / 4 + 2) * 16);
  w.psd = b.take<float>(size_t(AKH) * gmax_of(ctx) * (nb / 4 + 2) * 16);
  w.total = b.off;
  return w;
}

struct GdnState {
  float *S, *hist, *raw, *kn, *dsave, *beta, *decay;
  size_t total;
};
GdnState carve_gdn(void *base, int ctx) {
  const int MX = rows_cap(ctx); // rows per pass; the per-layer scratch below is replicated in all 48 DeltaNet layers
  Bump b{static_cast<char *>(base)};
  GdnState s;
  s.S = b.take<float>(size_t(VH) * HD * HD); // [value head][value column j][key row i]
  s.hist = b.take<float>(3 * QKV);
  s.raw = b.take<float>(MX * QKVZ);
  s.kn = b.take<float>(MX * KH * HD);
  s.dsave = b.take<float>(MX * VD);
  s.beta = b.take<float>(MX * 64);
  s.decay = b.take<float>(MX * 64);
  s.total = b.off;
  return s;
}
// KV storage: 0 = FP32 (default), 1 = BF16, 2 = FP16, 3 = FP16 tile layouts for the XMX attention (XF_KV=bf16|fp16|xmx; experimental, not bit-identical to FP32).
int kv_mode() {
  static const int m = [] {
    const char *e = std::getenv("XF_KV");
    if (!e) return 0;
    if (!std::strcmp(e, "bf16")) return 1;
    if (!std::strcmp(e, "fp16")) return 2;
    if (!std::strcmp(e, "xmx")) return 3; // FP16 KV in DPAS tile layouts + XMX attention
    if (!std::strcmp(e, "int8")) return 4; // INT8 KV (one scale per position and kv head) in the DPAS tile layouts + XMX attention
    return 0;
  }();
  return m;
}
struct AttnState {
  void *K, *V;
  float *ks, *vs; // INT8 KV: scale per [kv head][position]
  size_t total;
};
AttnState carve_attn(void *base, int ctx) {
  Bump b{static_cast<char *>(base)};
  AttnState s;
  s.ks = s.vs = nullptr;
  if (kv_mode() == 0) {
    s.K = b.take<float>(size_t(ctx) * AKH * AD);
    s.V = b.take<float>(size_t(ctx) * AKH * AD);
  } else if (kv_mode() == 4) {
    s.K = b.take<int8_t>(size_t(ctx) * AKH * AD);
    s.V = b.take<int8_t>(size_t(ctx) * AKH * AD);
    s.ks = b.take<float>(size_t(ctx) * AKH);
    s.vs = b.take<float>(size_t(ctx) * AKH);
  } else {
    s.K = b.take<uint16_t>(size_t(ctx) * AKH * AD);
    s.V = b.take<uint16_t>(size_t(ctx) * AKH * AD);
  }
  s.total = b.off;
  return s;
}
// 64 KV elements at element index `at` as FP32 (KV: 0 FP32, 1 BF16, 2 FP16) and the reverse.
template <int KV> inline simd<float, 64> ld64(const void *base, size_t at) {
  if constexpr (KV == 0) {
    simd<float, 64> x;
    x.copy_from(static_cast<const float *>(base) + at);
    return x;
  } else {
    simd<uint16_t, 64> e;
    e.copy_from(static_cast<const uint16_t *>(base) + at);
    if constexpr (KV == 1) {
      simd<uint32_t, 64> u = es::convert<uint32_t>(e) << 16;
      return u.template bit_cast_view<float>();
    } else {
      simd<sycl::half, 64> hh = e.template bit_cast_view<sycl::half>();
      return es::convert<float>(hh);
    }
  }
}
template <int KV> inline simd<uint16_t, 64> to16(simd<float, 64> x) {
  if constexpr (KV == 1) { // round to nearest even
    simd<uint32_t, 64> u = x.template bit_cast_view<uint32_t>();
    u = (u + 0x7fffu + ((u >> 16) & 1u)) >> 16;
    return es::convert<uint16_t>(u);
  } else {
    simd<sycl::half, 64> hh = es::convert<sycl::half>(x);
    return hh.template bit_cast_view<uint16_t>();
  }
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


// RMSNorm + activation quantisation of the next GEMM in one kernel: the work-group of a token already holds the normalised row, so after the
// norm it finds the row maximum (SLM), quantises its own 128 columns with the next matrix's column scales and writes the two byte planes and
// the token constants exactly as k_quant would (same expressions, same order: bit-identical). xn is still written (the f32 gate gemv reads it).
void k_addnorm_quant(Q &q, float *h, const float *y, const float *gain, float *xn, const float *cs, float cmax, int8_t *xhi, uint8_t *xlo, float *ts,
                     float *toff, int m, int mpad) {
  constexpr int LT = D / 128; // 40 threads
  q.parallel_for(sycl::nd_range<1>(size_t(m) * LT, LT), [=](sycl::nd_item<1> it) SYCL_ESIMD_KERNEL {
    es::slm_init<1024>();
    const size_t mi = it.get_group(0), t = it.get_local_id(0);
    const simd<int32_t, 64> iota(0, 1);
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
    part.merge(simd<float, 64>(0.0f), iota >= LT);
    const float inv = srsqrt(hsum<64>(part) * (1.0f / D) + EPS);
    simd<float, 64> v[2];
    float lmax = 0.0f;
#pragma unroll
    for (int i = 0; i < 2; i++) {
      simd<float, 64> g;
      g.copy_from(gain + t * 128 + i * 64);
      v[i] = a[i] * inv * g;
      v[i].copy_to(xn + mi * D + t * 128 + i * 64);
      lmax = std::max(lmax, hmax<64>(es::abs(v[i])));
    }
    es::slm_scalar_store<float>(uint32_t(256 + t * 4), lmax);
    es::barrier();
    simd<float, 64> pm = es::slm_block_load<float, 64>(256);
    pm.merge(simd<float, 64>(0.0f), iota >= LT);
    float step = hmax<64>(pm) * cmax * (1.0f / 32767.0f);
    if (!(step > 0.0f)) step = 1.0f;
    const float istep = 1.0f / step;
    simd<float, 64> sum(0.0f);
#pragma unroll
    for (int i = 0; i < 2; i++) {
      const size_t c = t * 2 + i;
      simd<float, 64> sc;
      sc.copy_from(cs + c * 64);
      simd<float, 64> r = es::rnde<float>(v[i] * sc * istep);
      r = es::max(es::min(r, simd<float, 64>(32767.0f)), simd<float, 64>(-32767.0f));
      sum += r;
      simd<int32_t, 64> xi = es::convert<int32_t>(r);
      simd<int8_t, 64> hb = es::convert<int8_t>(xi >> 8);
      simd<uint8_t, 64> lb = es::convert<uint8_t>(xi & 0xFF);
#pragma unroll
      for (int half = 0; half < 2; half++) {
        simd<int8_t, 32> aa = hb.template select<32, 1>(32 * half);
        simd<uint8_t, 32> bb = lb.template select<32, 1>(32 * half);
        aa.copy_to(xhi + ((2 * c + half) * mpad + mi) * 32);
        bb.copy_to(xlo + ((2 * c + half) * mpad + mi) * 32);
      }
    }
    es::slm_scalar_store<float>(uint32_t(512 + t * 4), hsum<64>(sum));
    es::barrier();
    if (t == 0) {
      simd<float, 64> ps = es::slm_block_load<float, 64>(512);
      ps.merge(simd<float, 64>(0.0f), iota >= LT);
      storef(toff + mi, 0.5f * hsum<64>(ps));
      storef(ts + mi, step);
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
    // The 80 chunks are requested 8 at a time before they are used (the loads of a chunk no longer wait for the multiply-add of the previous one);
    // the multiply-adds keep the original order, so the result is bit-identical.
    for (int c0 = 0; c0 < D / 64; c0 += 8) {
      simd<float, 64> a[8], b[8];
#pragma unroll
      for (int u = 0; u < 8; u++) {
        a[u].copy_from(w + r * D + (c0 + u) * 64);
        b[u].copy_from(x + mi * D + (c0 + u) * 64);
      }
#pragma unroll
      for (int u = 0; u < 8; u++) acc += a[u] * b[u];
    }
    // a: rows 0..47 -> 0..47 ; b: rows 48..95 -> 64..111
    storef(y + mi * 128 + (r < 48 ? r : r + 16), hsum<64>(acc));
  });
}

// Same arithmetic as k_gemv_f32 per (token, row); one thread handles a row for TB tokens, so every weight chunk is loaded once for TB tokens.
template <int TB> void k_gemv_f32_tb(Q &q, const float *w, const float *x, float *y, int rows, int m) {
  const int nt = (m + TB - 1) / TB;
  q.parallel_for(sycl::range<1>(size_t(nt) * rows), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t r = id[0] % rows;
    const int t0 = int(id[0] / rows) * TB;
    const int tn = std::min(TB, m - t0);
    simd<float, 64> acc[TB];
#pragma unroll
    for (int t = 0; t < TB; t++) acc[t] = 0.0f;
    for (int c0 = 0; c0 < D / 64; c0 += 4) {
      simd<float, 64> a[4];
#pragma unroll
      for (int u = 0; u < 4; u++) a[u].copy_from(w + r * D + (c0 + u) * 64);
#pragma unroll
      for (int t = 0; t < TB; t++) {
        if (t < tn) {
          simd<float, 64> b[4];
#pragma unroll
          for (int u = 0; u < 4; u++) b[u].copy_from(x + size_t(t0 + t) * D + (c0 + u) * 64);
#pragma unroll
          for (int u = 0; u < 4; u++) acc[t] += a[u] * b[u];
        }
      }
    }
#pragma unroll
    for (int t = 0; t < TB; t++)
      if (t < tn) storef(y + size_t(t0 + t) * 128 + (r < 48 ? r : r + 16), hsum<64>(acc[t]));
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
// Row r of tap `tap` goes to cap + (r / 16) * 5 * 16 * D + tap * 16 * D + (r % 16) * D: blocks of 16 rows, each laid out [5][16][D] (the layout an external drafter reads).
void k_capture(Q &q, const float *h, const float *y, float *cap, int tap, int m) {
  q.parallel_for(sycl::range<1>(size_t(m) * (D / 64)), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t row = id[0] / (D / 64), ch = id[0] % (D / 64);
    float *const o = cap + (row / 16) * size_t(5) * 16 * D + size_t(tap) * 16 * D + (row % 16) * D + ch * 64;
    simd<float, 64> a;
    a.copy_from(h + id[0] * 64);
    if (y) {
      simd<float, 64> b;
      b.copy_from(y + id[0] * 64);
      a += b;
    }
    a.copy_to(o);
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

// Same arithmetic as k_conv (acc = ((x0 w0 + x1 w1) + x2 w2) + x3 w3, then silu), but one thread handles up to TB consecutive tokens of a 64-channel chunk:
// the 4 weight vectors are loaded once and every input row of the window once (k_conv reloads each row for 4 outputs).
template <int TB> void k_conv_tb(Q &q, const float *raw, size_t rs, const float *hist, const float *taps, float *act, int m) {
  const int nt = (m + TB - 1) / TB;
  q.parallel_for(sycl::range<1>(size_t(nt) * (QKV / 64)), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t c = id[0] % (QKV / 64);
    const int t0 = int(id[0] / (QKV / 64)) * TB;
    const int tn = std::min(TB, m - t0);
    simd<float, 64> w[4], x[TB + 3];
#pragma unroll
    for (int k = 0; k < 4; k++) w[k].copy_from(taps + size_t(k) * QKV + c * 64);
#pragma unroll
    for (int i = 0; i < TB + 3; i++) {
      if (i < tn + 3) {
        const int r = t0 - 3 + i;
        x[i].copy_from(r >= 0 ? raw + size_t(r) * rs + c * 64 : hist + size_t(3 + r) * QKV + c * 64);
      }
    }
#pragma unroll
    for (int t = 0; t < TB; t++) {
      if (t < tn) {
        simd<float, 64> acc(0.0f);
#pragma unroll
        for (int k = 0; k < 4; k++) acc += x[t + k] * w[k];
        (acc * sigmoid<64>(acc)).copy_to(act + size_t(t0 + t) * QKV + c * 64);
      }
    }
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

// Same arithmetic as k_gdn_core per column; one thread owns CB adjacent value columns of one head, so the k and q rows of a token are loaded once for CB columns
// (k_gdn_core reloads them in all 128 threads of the head) and CB independent update chains run side by side.
template <int CB>
void k_gdn_core_cb(Q &q, const float *S, const float *act, const float *qn, const float *kn, const float *beta, const float *decay, float *dsave, float *gout, int m) {
  q.parallel_for(sycl::range<1>(size_t(VH) * HD / CB), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t col0 = id[0] * CB;
    const size_t h = col0 / HD, j0 = col0 % HD, kh = h / 3;
    simd<float, HD> s[CB];
#pragma unroll
    for (int c = 0; c < CB; c++) s[c].copy_from(S + (col0 + c) * HD);
    for (int mi = 0; mi < m; mi++) {
      simd<float, HD> k, qq;
      k.copy_from(kn + (size_t(mi) * KH + kh) * HD);
      qq.copy_from(qn + (size_t(mi) * KH + kh) * HD);
      const float dec = loadf(decay + mi * 64 + h), bet = loadf(beta + mi * 64 + h);
#pragma unroll
      for (int c = 0; c < CB; c++) {
        s[c] = s[c] * dec;
        const float kv = hsum<HD>(s[c] * k);
        const float d = (loadf(act + size_t(mi) * QKV + 2 * KH * HD + h * HD + j0 + c) - kv) * bet;
        s[c] = s[c] + k * d;
        storef(dsave + size_t(mi) * VD + h * HD + j0 + c, d);
        storef(gout + size_t(mi) * VD + h * HD + j0 + c, hsum<HD>(s[c] * qq));
      }
    }
  });
}

template <int CB>
void k_gdn_commit_cb(Q &q, float *S, const float *kn, const float *decay, const float *dsave, int n) {
  q.parallel_for(sycl::range<1>(size_t(VH) * HD / CB), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t col0 = id[0] * CB;
    const size_t h = col0 / HD, j0 = col0 % HD, kh = h / 3;
    simd<float, HD> s[CB];
#pragma unroll
    for (int c = 0; c < CB; c++) s[c].copy_from(S + (col0 + c) * HD);
    for (int mi = 0; mi < n; mi++) {
      simd<float, HD> k;
      k.copy_from(kn + (size_t(mi) * KH + kh) * HD);
      const float dec = loadf(decay + mi * 64 + h);
#pragma unroll
      for (int c = 0; c < CB; c++) s[c] = s[c] * dec + k * loadf(dsave + size_t(mi) * VD + h * HD + j0 + c);
    }
#pragma unroll
    for (int c = 0; c < CB; c++) s[c].copy_to(S + (col0 + c) * HD);
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


// XF_GDN_OLD=1: the original one-token-per-thread GDN kernels (for A/B tests); XF_GDN_CB (columns per thread of the core, 1|2|4), XF_GDN_CONV_TB (1|4|8), XF_GDN_GEMV_TB (1|4|8).
int env_int(const char *name, int dflt) {
  const char *e = std::getenv(name);
  return e ? std::atoi(e) : dflt;
}
bool gdn_old() {
  static const bool o = env_int("XF_GDN_OLD", 0) != 0;
  return o;
}
void gdn_core(Q &q, const float *S, const float *act, const float *qn, const float *kn, const float *beta, const float *decay, float *dsave, float *gout, int m) {
  static const int cb = env_int("XF_GDN_CB", 2);
  if (gdn_old() || cb == 1) k_gdn_core(q, S, act, qn, kn, beta, decay, dsave, gout, m);
  else if (cb == 4) k_gdn_core_cb<4>(q, S, act, qn, kn, beta, decay, dsave, gout, m);
  else k_gdn_core_cb<2>(q, S, act, qn, kn, beta, decay, dsave, gout, m);
}
void gdn_commit(Q &q, float *S, const float *kn, const float *decay, const float *dsave, int n) {
  static const int cb = env_int("XF_GDN_CB", 2);
  if (gdn_old() || cb == 1) k_gdn_commit(q, S, kn, decay, dsave, n);
  else if (cb == 4) k_gdn_commit_cb<4>(q, S, kn, decay, dsave, n);
  else k_gdn_commit_cb<2>(q, S, kn, decay, dsave, n);
}
void gdn_conv(Q &q, const float *raw, size_t rs, const float *hist, const float *taps, float *act, int m) {
  static const int tb = env_int("XF_GDN_CONV_TB", 8);
  if (gdn_old() || tb <= 1 || m == 1) k_conv(q, raw, rs, hist, taps, act, m);
  else if (tb == 2) k_conv_tb<2>(q, raw, rs, hist, taps, act, m);
  else if (tb == 4) k_conv_tb<4>(q, raw, rs, hist, taps, act, m);
  else if (tb == 16) k_conv_tb<16>(q, raw, rs, hist, taps, act, m);
  else k_conv_tb<8>(q, raw, rs, hist, taps, act, m);
}
void gdn_gemv_ab(Q &q, const float *w, const float *x, float *y, int rows, int m) {
  // Default token block by the measured optimum (benchmarks/results/m32/gdn_sweep.md): the gemv has only 96 x m / TB threads, so wide blocks leave the GPU idle.
  static const int tbe = env_int("XF_GDN_GEMV_TB", 0);
  const int tb = tbe ? tbe : (m > 16 && m <= 32) ? 4 : 2;
  if (gdn_old() || tb <= 1 || m == 1) k_gemv_f32(q, w, x, y, rows, m);
  else if (tb == 2) k_gemv_f32_tb<2>(q, w, x, y, rows, m);
  else if (tb == 8) k_gemv_f32_tb<8>(q, w, x, y, rows, m);
  else if (tb == 16) k_gemv_f32_tb<16>(q, w, x, y, rows, m);
  else k_gemv_f32_tb<4>(q, w, x, y, rows, m);
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

void k_attn_kv(Q &q, const float *yk, const float *yv, size_t ks, const float *gain, const float *cs, const float *sn, void *K,
               void *V, int m, int pos0, bool kt = false, int kvm = 0) {
  q.parallel_for(sycl::range<1>(size_t(m) * AKH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / AKH, kh = id[0] % AKH;
    simd<float, 64> v[4];
#pragma unroll
    for (int i = 0; i < 4; i++) v[i].copy_from(yk + mi * ks + kh * AD + i * 64);
    norm_rope(v, gain, cs + (pos0 + mi) * 32, sn + (pos0 + mi) * 32);
#pragma unroll
    for (int i = 0; i < 4; i++) {
      simd<float, 64> x;
      x.copy_from(yv + mi * ks + kh * AD + i * 64);
      if (kvm == 0) {
        float *Kf = static_cast<float *>(K);
        if (kt) {
          // K^T layout: [block of 64 positions][kv head][dim][position in block]
          const size_t pos = pos0 + mi;
          float *base = Kf + ((pos / 64) * AKH + kh) * size_t(AD) * 64 + pos % 64;
          simd<uint32_t, 64> off(i * 64 * 64, 64);
          off = off * 4u;
          es::scatter<float, 64>(base, off, v[i]);
        } else {
          v[i].copy_to(Kf + ((pos0 + mi) * AKH + kh) * AD + i * 64);
        }
        x.copy_to(static_cast<float *>(V) + ((pos0 + mi) * AKH + kh) * AD + i * 64);
      } else { // 16-bit KV (K^T layout only)
        const size_t pos = pos0 + mi;
        uint16_t *base = static_cast<uint16_t *>(K) + ((pos / 64) * AKH + kh) * size_t(AD) * 64 + pos % 64;
        simd<uint32_t, 64> off(i * 64 * 64, 64);
        off = off * 2u;
        simd<uint16_t, 64> k16 = kvm == 1 ? to16<1>(v[i]) : to16<2>(v[i]);
        es::scatter<uint16_t, 64>(base, off, k16);
        simd<uint16_t, 64> v16 = kvm == 1 ? to16<1>(x) : to16<2>(x);
        v16.copy_to(static_cast<uint16_t *>(V) + ((pos0 + mi) * AKH + kh) * AD + i * 64);
      }
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
template <int HG, int TG, int KV = 0>
void k_attn_part3(Q &q, const float *qr, const void *KT, const void *V, float *pm, float *pd, float *pv, int m,
                  int pos0, size_t nbs, int gper) {
  // gper = token groups handled by one thread (>= ceil(m / TG): one thread walks them all, 1: one group per thread)
  constexpr int GRP = AH / AKH / HG;
  const size_t nb = size_t(pos0 + m - 1) / 64 + 1;
  const int ngrp = (m + TG - 1) / TG, nsplit = (ngrp + gper - 1) / gper;
  q.parallel_for(sycl::range<1>(AKH * GRP * nb * nsplit), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t b = id[0] % nb, g = id[0] / nb % GRP, kh = id[0] / nb / GRP % AKH, sp = id[0] / nb / GRP / AKH;
    const size_t kb = (b * AKH + kh) * size_t(AD) * 64; // element offset of this block's K^T tile
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
          simd<float, 64> k = ld64<KV>(KT, kb + size_t(dc * 16 + dd) * 64);
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
          simd<float, 64> v = ld64<KV>(V, ((b * 64 + t) * AKH + kh) * AD + i * 64);
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


// Work-group attention: one work-group per (kv head, 64-key block) stages the block's K^T tile and then its V tile in SLM once
// (64 KiB each, reused), so every K/V byte is read from global memory once for all 6 GQA heads and all m tokens.
// Thread = (token, part of the 6 heads): NP = 6/HPT threads per token, HPT heads per thread, m*NP threads per group.
// Same pm/pd/pv output as k_attn_part3. Two separate phases (scores, then V sums); no fusion across blocks.
template <int HPT, int KV, int NCK>
void k_attn_slm(Q &q, const float *qr, const void *KT, const void *V, float *pm, float *pd, float *pv, int m, int pos0, size_t nbs) {
  // NCK: the K^T tile is staged in NCK chunks of 256/NCK dims; V in 4 chunks of 64 dims (16 KiB). SLM = max(64 KiB / NCK, 16 KiB).
  constexpr int NP = AH / AKH / HPT;
  constexpr int KD = AD / NCK;                   // dims per K chunk
  constexpr uint32_t SLMB = (KD * 256 > 16384) ? KD * 256 : 16384;
  const size_t nb = size_t(pos0 + m - 1) / 64 + 1;
  const int LT = m * NP;
  q.parallel_for(sycl::nd_range<1>(AKH * nb * LT, LT), [=](sycl::nd_item<1> it) SYCL_ESIMD_KERNEL {
    es::slm_init<SLMB>();
    const size_t grp = it.get_group(0);
    const int lt = int(it.get_local_id(0));
    const size_t b = grp % nb, kh = grp / nb;
    const int tok = lt / NP, hp = lt % NP;
    const simd<int, 64> lane(0, 1);
    const size_t kb = (b * AKH + kh) * size_t(AD) * 64;
    simd<float, 64> s[HPT];
#pragma unroll
    for (int h = 0; h < HPT; h++) s[h] = 0.0f;
    const size_t qrow = (size_t(tok) * AH + kh * (AH / AKH) + hp * HPT) * AD;
    for (int c = 0; c < NCK; c++) {
      for (int d = lt; d < KD; d += LT) es::slm_block_store<float, 64>(uint32_t(d) * 256u, ld64<KV>(KT, kb + size_t(c * KD + d) * 64));
      es::barrier();
      for (int dc = 0; dc < KD / 16; dc++) {
        simd<float, 16> qc[HPT];
#pragma unroll
        for (int h = 0; h < HPT; h++) qc[h].copy_from(qr + qrow + size_t(h) * AD + c * KD + dc * 16);
#pragma unroll
        for (int dd = 0; dd < 16; dd++) {
          simd<float, 64> k = es::slm_block_load<float, 64>(uint32_t(dc * 16 + dd) * 256u);
#pragma unroll
          for (int h = 0; h < HPT; h++) s[h] += k * float(qc[h][dd]);
        }
      }
      es::barrier();
    }
    const int lim = pos0 + tok - int(b) * 64; // lanes 0..lim visible to this token
#pragma unroll
    for (int h = 0; h < HPT; h++) {
      simd<float, 64> x = s[h] * 0.0625f;
      x.merge(simd<float, 64>(-1e30f), lane > lim);
      const float mx = hmax<64>(x);
      x = es::exp(x - mx);
      s[h] = x;
      if (lim >= 0) {
        const size_t mh = size_t(tok) * AH + kh * (AH / AKH) + hp * HPT + h;
        storef(pm + mh * nbs + b, mx);
        storef(pd + mh * nbs + b, hsum<64>(x));
      }
    }
    const int nvalid = std::min(64, pos0 + m - 1 - int(b) * 64 + 1); // keys that exist for the last token of the group
    const int kmax = std::min(64, lim + 1);
    for (int i = 0; i < 4; i++) {
      for (int t = lt; t < 64; t += LT) {
        simd<float, 64> v(0.0f);
        if (t < nvalid) v = ld64<KV>(V, ((b * 64 + t) * AKH + kh) * AD + i * 64);
        es::slm_block_store<float, 64>(uint32_t(t) * 256u, v);
      }
      es::barrier();
      simd<float, 64> acc[HPT];
#pragma unroll
      for (int h = 0; h < HPT; h++) acc[h] = 0.0f;
      for (int t = 0; t < kmax; t++) {
        simd<float, 64> v = es::slm_block_load<float, 64>(uint32_t(t) * 256u);
#pragma unroll
        for (int h = 0; h < HPT; h++) acc[h] += v * float(s[h][t]);
      }
      es::barrier();
      if (lim >= 0) {
#pragma unroll
        for (int h = 0; h < HPT; h++) {
          const size_t mh = size_t(tok) * AH + kh * (AH / AKH) + hp * HPT + h;
          acc[h].copy_to(pv + (mh * nbs + b) * AD + i * 64);
        }
      }
    }
  });
}


// ---------------------------------------------------------------- XMX (DPAS) attention, FP16 operands, FP32 accumulation
// Layouts (16-bit elements). K: [block of 64 keys][kv head][key tile of 8][dim chunk of 16][8 keys][16 dims] (DPAS A operand, 8 keys x 16 dims).
// V: [block][kv head][key chunk of 16][dim tile of 8][8 dims][16 keys] (A operand of V^T, 8 dims x 16 keys). Q^T (B operand, VNNI) per
// (kv head, row group of 16 rows = (token, head) pairs, dim chunk): [8 dim pairs][16 rows][2]; pre-scaled by 1/16 (exact).
// S^T[key][row] = K . Q^T (DPAS), softmax down the key axis in registers, P^T (FP16) is the B operand of O^T[dim][row] = V^T . P^T.
// Output partials: pm/pd as before, pvx[(kv head, row group, block)][dim][16 rows] FP32.
using XT = xmx::dpas_argument_type;
void k_attn_q16(Q &q, const float *qr, uint16_t *Q16, int m) {
  const int G = (6 * m + 15) / 16;
  q.parallel_for(sycl::range<1>(size_t(AKH) * G * 16), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t c = id[0] % 16, g = id[0] / 16 % G, kh = id[0] / 16 / G;
    simd<uint16_t, 256> tile(0);
#pragma unroll
    for (int n = 0; n < 16; n++) {
      const int r = int(g) * 16 + n;
      if (r < 6 * m) {
        const int tok = r / 6, hh = r % 6;
        simd<float, 16> row;
        row.copy_from(qr + (size_t(tok) * AH + kh * 6 + hh) * AD + c * 16);
        simd<sycl::half, 16> hv = es::convert<sycl::half>(simd<float, 16>(row * 0.0625f));
        simd<uint16_t, 16> u = hv.template bit_cast_view<uint16_t>();
        tile.template select<8, 32>(n * 2 + 0) = u.template select<8, 2>(0);
        tile.template select<8, 32>(n * 2 + 1) = u.template select<8, 2>(1);
      }
    }
    tile.copy_to(Q16 + ((kh * G + g) * 16 + c) * 256);
  });
}

void k_attn_kv_x(Q &q, const float *yk, const float *yv, size_t ks, const float *gain, const float *cs, const float *sn, uint16_t *K,
                 uint16_t *V, int m, int pos0) {
  q.parallel_for(sycl::range<1>(size_t(m) * AKH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / AKH, kh = id[0] % AKH;
    simd<float, 64> v[4];
#pragma unroll
    for (int i = 0; i < 4; i++) v[i].copy_from(yk + mi * ks + kh * AD + i * 64);
    norm_rope(v, gain, cs + (pos0 + mi) * 32, sn + (pos0 + mi) * 32);
    const size_t pos = pos0 + mi, b = pos / 64;
    const int j = int(pos % 64);
    uint16_t *kt = K + ((b * AKH + kh) * 8 + j / 8) * 16 * 128 + (j % 8) * 16;
#pragma unroll
    for (int c = 0; c < 16; c++) {
      simd<float, 16> t = v[c / 4].template select<16, 1>((c % 4) * 16);
      simd<sycl::half, 16> h16 = es::convert<sycl::half>(t);
      simd<uint16_t, 16> u = h16.template bit_cast_view<uint16_t>();
      u.copy_to(kt + c * 128);
    }
    uint16_t *vt = V + (b * AKH + kh) * 4 * 32 * 128;
#pragma unroll
    for (int i = 0; i < 4; i++) {
      simd<float, 64> x;
      x.copy_from(yv + mi * ks + kh * AD + i * 64);
      simd<uint32_t, 64> d(i * 64, 1);
      simd<uint32_t, 64> off = (((d >> 3) + uint32_t(j / 16) * 32u) * 128u + (d & 7u) * 16u + uint32_t(j % 16)) * 2u;
      simd<sycl::half, 64> h64 = es::convert<sycl::half>(x);
      simd<uint16_t, 64> u = h64.template bit_cast_view<uint16_t>();
      es::scatter<uint16_t, 64>(vt, off, u);
    }
  });
}


// INT8 KV write: one scale per (position, kv head) for K and for V (max |x| / 127), values rounded to nearest, same tile layouts as the FP16 version.
void k_attn_kv_x8(Q &q, const float *yk, const float *yv, size_t ks, const float *gain, const float *cs, const float *sn, int8_t *K, int8_t *V,
                  float *ksc, float *vsc, int ctx, int m, int pos0) {
  q.parallel_for(sycl::range<1>(size_t(m) * AKH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mi = id[0] / AKH, kh = id[0] % AKH;
    simd<float, 64> v[4], x[4];
#pragma unroll
    for (int i = 0; i < 4; i++) v[i].copy_from(yk + mi * ks + kh * AD + i * 64);
    norm_rope(v, gain, cs + (pos0 + mi) * 32, sn + (pos0 + mi) * 32);
#pragma unroll
    for (int i = 0; i < 4; i++) x[i].copy_from(yv + mi * ks + kh * AD + i * 64);
    const size_t pos = pos0 + mi, b = pos / 64;
    const int j = int(pos % 64);
    float sk, sv;
    {
      simd<float, 64> mx = es::abs(v[0]), mv = es::abs(x[0]);
#pragma unroll
      for (int i = 1; i < 4; i++) {
        mx = es::max(mx, simd<float, 64>(es::abs(v[i])));
        mv = es::max(mv, simd<float, 64>(es::abs(x[i])));
      }
      const float ak = hmax<64>(mx), av = hmax<64>(mv);
      sk = ak > 0.0f ? ak * (1.0f / 127.0f) : 1.0f;
      sv = av > 0.0f ? av * (1.0f / 127.0f) : 1.0f;
    }
    const float ik = 1.0f / sk, iv = 1.0f / sv;
    int8_t *kt = K + ((b * AKH + kh) * 8 + j / 8) * 16 * 128 + (j % 8) * 16;
#pragma unroll
    for (int c = 0; c < 16; c++) {
      simd<float, 16> t = simd<float, 16>(v[c / 4].template select<16, 1>((c % 4) * 16)) * ik;
      simd<float, 16> hf(0.5f);
      hf.merge(simd<float, 16>(-0.5f), t < 0.0f);
      simd<float, 16> r = t + hf; // round to nearest, ties away; the conversion truncates
      simd<int8_t, 16> qv = es::convert<int8_t>(simd<int32_t, 16>(r));
      qv.copy_to(kt + c * 128);
    }
    int8_t *vt = V + (b * AKH + kh) * 4 * 32 * 128;
#pragma unroll
    for (int i = 0; i < 4; i++) {
      simd<uint32_t, 64> d(i * 64, 1);
      simd<uint32_t, 64> off = ((d >> 3) + uint32_t(j / 16) * 32u) * 128u + (d & 7u) * 16u + uint32_t(j % 16);
      simd<float, 64> t = x[i] * iv;
      simd<float, 64> hf(0.5f);
      hf.merge(simd<float, 64>(-0.5f), t < 0.0f);
      simd<float, 64> r = t + hf;
      simd<int8_t, 64> qv = es::convert<int8_t>(simd<int32_t, 64>(r));
      es::scatter<int8_t, 64>(vt, off, qv);
    }
    ksc[kh * size_t(ctx) + pos] = sk;
    vsc[kh * size_t(ctx) + pos] = sv;
  });
}

void k_attn_xmx(Q &q, const uint16_t *Q16, const uint16_t *K, const uint16_t *V, float *pm, float *pd, float *pvx, int m, int pos0,
                size_t nbs) {
  const int G = (6 * m + 15) / 16;
  const size_t nb = size_t(pos0 + m - 1) / 64 + 1;
  q.parallel_for(sycl::range<1>(AKH * size_t(G) * nb), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t g = id[0] % G, b = id[0] / G % nb, kh = id[0] / G / nb; // row groups of one tile are adjacent threads (L2 sharing)
    simd<int, 16> limv(-1);
    simd<uint32_t, 16> mhv(0);
#pragma unroll
    for (int n = 0; n < 16; n++) {
      const int r = int(g) * 16 + n;
      if (r < 6 * m) {
        limv[n] = pos0 + r / 6 - int(b) * 64;
        mhv[n] = uint32_t((r / 6) * AH + kh * 6 + r % 6);
      }
    }
    const uint16_t *qt = Q16 + (kh * G + g) * 16 * 256;
    const uint16_t *kbase = K + (b * AKH + kh) * 8 * 16 * 128;
    simd<float, 128> S[8];
#pragma unroll
    for (int jt = 0; jt < 8; jt++) S[jt] = 0.0f;
    for (int c = 0; c < 16; c++) {
      simd<int32_t, 128> w;
      w.copy_from(reinterpret_cast<const int32_t *>(qt + c * 256));
#pragma unroll
      for (int jt = 0; jt < 8; jt++) {
        simd<int32_t, 64> a;
        a.copy_from(reinterpret_cast<const int32_t *>(kbase + (jt * 16 + c) * 128));
        S[jt] = xmx::dpas<8, 8, float, float, int32_t, int32_t, XT::fp16, XT::fp16>(S[jt], w, a);
      }
    }
    // causal mask + softmax down the key axis (rows of the S^T tiles)
    simd<int, 128> kidx;
#pragma unroll
    for (int i = 0; i < 8; i++) kidx.template select<16, 1>(i * 16) = i;
    const simd<int, 128> limr = limv.template replicate<8>();
    simd<float, 16> mx(-1e30f);
#pragma unroll
    for (int jt = 0; jt < 8; jt++) {
      S[jt].merge(simd<float, 128>(-1e30f), (kidx + jt * 8) > limr);
#pragma unroll
      for (int i = 0; i < 8; i++) mx = es::max(mx, simd<float, 16>(S[jt].template select<16, 1>(i * 16)));
    }
    const simd<float, 128> mxr = mx.template replicate<8>();
    simd<sycl::half, 128> P[8];
    simd<float, 16> den(0.0f);
#pragma unroll
    for (int jt = 0; jt < 8; jt++) {
      simd<float, 128> e = es::exp(S[jt] - mxr);
      P[jt] = es::convert<sycl::half>(e);
      simd<float, 128> er = es::convert<float>(P[jt]); // the weights PV really uses
#pragma unroll
      for (int i = 0; i < 8; i++) den += er.template select<16, 1>(i * 16);
    }
    simd<uint32_t, 16> off = (mhv * uint32_t(nbs) + uint32_t(b)) * 4u;
    const es::simd_mask<16> ok = limv >= 0;
    es::scatter<float, 16>(pm, off, mx, ok);
    es::scatter<float, 16>(pd, off, den, ok);
    // P^T as VNNI B operands: key chunk kc = rows (2p, 2p+1) of S^T tiles 2kc and 2kc+1, interleaved per row lane
    simd<sycl::half, 256> Bp[4];
#pragma unroll
    for (int kc = 0; kc < 4; kc++)
#pragma unroll
      for (int p = 0; p < 8; p++) {
        const int tile = 2 * kc + p / 4, r0 = 2 * (p % 4);
        Bp[kc].template select<16, 2>(p * 32 + 0) = P[tile].template select<16, 1>(r0 * 16);
        Bp[kc].template select<16, 2>(p * 32 + 1) = P[tile].template select<16, 1>((r0 + 1) * 16);
      }
    float *pvb = pvx + ((kh * G + g) * nb + b) * 4096;
    const uint16_t *vbase = V + (b * AKH + kh) * 4 * 32 * 128;
    for (int pass = 0; pass < 4; pass++) {
      simd<float, 128> acc[8];
#pragma unroll
      for (int tt = 0; tt < 8; tt++) acc[tt] = 0.0f;
#pragma unroll
      for (int kc = 0; kc < 4; kc++) {
        simd<int32_t, 128> bw = Bp[kc].template bit_cast_view<int32_t>();
#pragma unroll
        for (int tt = 0; tt < 8; tt++) {
          simd<int32_t, 64> a;
          a.copy_from(reinterpret_cast<const int32_t *>(vbase + (kc * 32 + pass * 8 + tt) * 128));
          acc[tt] = xmx::dpas<8, 8, float, float, int32_t, int32_t, XT::fp16, XT::fp16>(acc[tt], bw, a);
        }
      }
#pragma unroll
      for (int tt = 0; tt < 8; tt++) acc[tt].copy_to(pvb + (pass * 8 + tt) * 128);
    }
  });
}

void k_attn_comb_x(Q &q, const float *pm, const float *pd, const float *pvx, const float *yq, size_t qs, float *ao, float *pmax, int m,
                   int pos0, size_t nbs) {
  const int G = (6 * m + 15) / 16;
  const size_t nball = size_t(pos0 + m - 1) / 64 + 1;
  q.parallel_for(sycl::range<1>(size_t(m) * AH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mh = id[0], mi = mh / AH, h = mh % AH, kh = h / 6;
    const int r = int(mi) * 6 + int(h % 6);
    const size_t g = r / 16, n = r % 16;
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
      const float *base = pvx + ((kh * G + g) * nball + b) * 4096 + n;
#pragma unroll
      for (int i = 0; i < 4; i++) {
        simd<uint32_t, 64> d(i * 64, 1);
        simd<float, 64> v = es::gather<float, 64>(base, d * 64u);
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


constexpr int XSEG = 16; // blocks per combine segment
// Stage 1: per (kv head, row group, segment of XSEG blocks) merge the block partials with contiguous reads of the [dim][16 rows] tiles.
void k_attn_comb1(Q &q, const float *pm, const float *pd, const float *pvx, float *pseg, float *psm, float *psd, int m, int pos0, size_t nbs) {
  const int G = (6 * m + 15) / 16;
  const size_t nball = size_t(pos0 + m - 1) / 64 + 1, NS = (nball + XSEG - 1) / XSEG;
  q.parallel_for(sycl::range<1>(AKH * size_t(G) * NS), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t seg = id[0] % NS, g = id[0] / NS % G, kh = id[0] / NS / G;
    simd<uint32_t, 16> mhv(0);
    simd<int, 16> nbt(0);
#pragma unroll
    for (int n = 0; n < 16; n++) {
      const int r = int(g) * 16 + n;
      if (r < 6 * m) {
        mhv[n] = uint32_t((r / 6) * AH + kh * 6 + r % 6);
        nbt[n] = (pos0 + r / 6) / 64 + 1;
      }
    }
    const size_t b0 = seg * XSEG, b1 = std::min(nball, b0 + XSEG);
    simd<float, 16> pmb[XSEG], e[XSEG];
    simd<float, 16> mx(-1e30f);
#pragma unroll
    for (int bi = 0; bi < XSEG; bi++) {
      pmb[bi] = -1e30f;
      if (b0 + bi < b1) {
        pmb[bi] = es::gather<float, 16>(pm, (mhv * uint32_t(nbs) + uint32_t(b0 + bi)) * 4u);
        pmb[bi].merge(simd<float, 16>(-1e30f), nbt <= simd<int, 16>(int(b0) + bi));
        mx = es::max(mx, pmb[bi]);
      }
    }
    simd<float, 16> den(0.0f);
#pragma unroll
    for (int bi = 0; bi < XSEG; bi++) {
      e[bi] = 0.0f;
      if (b0 + bi < b1) {
        e[bi] = es::exp(pmb[bi] - mx);
        e[bi].merge(simd<float, 16>(0.0f), nbt <= simd<int, 16>(int(b0) + bi));
        den += e[bi] * es::gather<float, 16>(pd, (mhv * uint32_t(nbs) + uint32_t(b0 + bi)) * 4u);
      }
    }
    const size_t sidx = (kh * G + g) * NS + seg;
    mx.copy_to(psm + sidx * 16);
    den.copy_to(psd + sidx * 16);
    for (int pass = 0; pass < 4; pass++) {
      simd<float, 16> acc[64];
#pragma unroll
      for (int d = 0; d < 64; d++) acc[d] = 0.0f;
      for (size_t bi = 0; bi < XSEG && b0 + bi < b1; bi++) {
        const float *tile = pvx + ((kh * G + g) * nball + b0 + bi) * 4096 + pass * 1024;
        simd<float, 16> ev = e[0];
#pragma unroll
        for (int k = 1; k < XSEG; k++)
          if (int(bi) == k) ev = e[k];
#pragma unroll
        for (int d = 0; d < 64; d++) {
          simd<float, 16> v;
          v.copy_from(tile + d * 16);
          acc[d] += v * ev;
        }
      }
#pragma unroll
      for (int d = 0; d < 64; d++) acc[d].copy_to(pseg + sidx * 4096 + pass * 1024 + d * 16);
    }
  });
}

// Stage 2: per (token, head) merge the segments, gate and write the attention output.
void k_attn_comb2(Q &q, const float *psm, const float *psd, const float *pseg, const float *yq, size_t qs, float *ao, float *pmax, int m,
                  int pos0, int xb = XSEG) {
  const int G = (6 * m + 15) / 16;
  const size_t nball = size_t(pos0 + m - 1) / 64 + 1, NS = (nball + xb - 1) / xb;
  q.parallel_for(sycl::range<1>(size_t(m) * AH), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t mh = id[0], mi = mh / AH, h = mh % AH, kh = h / 6;
    const int r = int(mi) * 6 + int(h % 6);
    const size_t g = r / 16, n = r % 16;
    const size_t sbase = (kh * G + g) * NS;
    float mx = -1e30f;
    for (size_t s = 0; s < NS; s++) mx = std::max(mx, loadf(psm + (sbase + s) * 16 + n));
    simd<float, 64> acc[4];
#pragma unroll
    for (int i = 0; i < 4; i++) acc[i] = 0.0f;
    float den = 0.0f;
    for (size_t s = 0; s < NS; s++) {
      const float w = sexp(loadf(psm + (sbase + s) * 16 + n) - mx);
      den += w * loadf(psd + (sbase + s) * 16 + n);
      const float *base = pseg + (sbase + s) * 4096 + n;
#pragma unroll
      for (int i = 0; i < 4; i++) {
        simd<uint32_t, 64> d(i * 64, 1);
        simd<float, 64> v = es::gather<float, 64>(base, d * 64u);
        acc[i] += v * w;
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


// Fused XMX attention: one thread = (kv head, row group of 16 (token, head) rows, segment of XB blocks, part of the 256 V dims).
// Sub-blocks of 32 keys are processed in order with an online softmax kept in registers (running max, denominator and the O^T accumulators of
// the thread's 256/DQ dims), so only one partial per segment is written. The QK^T DPAS work is repeated by the DQ threads of a segment
// (they sit next to each other, sharing the K tiles in cache). Partial layout = comb2's: pseg[(kv head, group, segment)][dim][16 rows].
// skip (timing studies only): 8 = no QK dpas, 16 = no PV dpas.
template <int XB, int DQ>
void k_attn_xmx2(Q &q, const uint16_t *Q16, const uint16_t *K, const uint16_t *V, float *pseg, float *psm, float *psd, int m, int pos0, int skip) {
  constexpr int NT = 32 / DQ; // 8-dim tiles per thread
  const int G = (6 * m + 15) / 16;
  const size_t nb = size_t(pos0 + m - 1) / 64 + 1, NS = (nb + XB - 1) / XB;
  q.parallel_for(sycl::range<1>(AKH * size_t(G) * NS * DQ), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t dq = id[0] % DQ, g = id[0] / DQ % G, seg = id[0] / DQ / G % NS, kh = id[0] / DQ / G / NS;
    simd<int, 16> limv(-1);
#pragma unroll
    for (int n = 0; n < 16; n++) {
      const int r = int(g) * 16 + n;
      if (r < 6 * m) limv[n] = pos0 + r / 6; // position of the row's token
    }
    const simd<int, 128> limr = limv.template replicate<8>();
    simd<int, 128> kidx;
#pragma unroll
    for (int i = 0; i < 8; i++) kidx.template select<16, 1>(i * 16) = i;
    const uint16_t *qt = Q16 + (kh * G + g) * 16 * 256;
    simd<float, 16> mrun(-1e30f), den(0.0f);
    simd<float, 128> acc[NT];
#pragma unroll
    for (int tt = 0; tt < NT; tt++) acc[tt] = 0.0f;
    const size_t sb0 = seg * XB * 2, sb1 = std::min(nb * 2, (seg + 1) * XB * 2);
    for (size_t sbi = sb0; sbi < sb1; sbi++) {
      const int key0 = int(sbi) * 32;
      if (key0 > pos0 + m - 1) break;
      const size_t b = sbi >> 1, h2 = sbi & 1;
      const uint16_t *kbase = K + ((b * AKH + kh) * 8 + h2 * 4) * 16 * 128;
      simd<float, 128> S[4];
#pragma unroll
      for (int jt = 0; jt < 4; jt++) S[jt] = 0.0f;
      if (!(skip & 8))
        for (int c = 0; c < 16; c++) {
          simd<int32_t, 128> w;
          w.copy_from(reinterpret_cast<const int32_t *>(qt + c * 256));
#pragma unroll
          for (int jt = 0; jt < 4; jt++) {
            simd<int32_t, 64> a;
            a.copy_from(reinterpret_cast<const int32_t *>(kbase + (jt * 16 + c) * 128));
            S[jt] = xmx::dpas<8, 8, float, float, int32_t, int32_t, XT::fp16, XT::fp16>(S[jt], w, a);
          }
        }
      simd<float, 16> mxb(-1e30f);
#pragma unroll
      for (int jt = 0; jt < 4; jt++) {
        S[jt].merge(simd<float, 128>(-1e30f), (kidx + (key0 + jt * 8)) > limr);
#pragma unroll
        for (int i = 0; i < 8; i++) mxb = es::max(mxb, simd<float, 16>(S[jt].template select<16, 1>(i * 16)));
      }
      const simd<float, 16> mnew = es::max(mrun, mxb);
      const simd<float, 16> sc = es::exp(mrun - mnew);
      const simd<float, 128> mnr = mnew.template replicate<8>();
      simd<sycl::half, 128> P[4];
      simd<float, 16> denb(0.0f);
#pragma unroll
      for (int jt = 0; jt < 4; jt++) {
        simd<float, 128> e = es::exp(S[jt] - mnr);
        P[jt] = es::convert<sycl::half>(e);
        simd<float, 128> er = es::convert<float>(P[jt]);
#pragma unroll
        for (int i = 0; i < 8; i++) denb += er.template select<16, 1>(i * 16);
      }
      den = den * sc + denb;
      mrun = mnew;
      const simd<float, 128> scr = sc.template replicate<8>();
#pragma unroll
      for (int tt = 0; tt < NT; tt++) acc[tt] *= scr;
      simd<sycl::half, 256> Bp[2];
#pragma unroll
      for (int kc = 0; kc < 2; kc++)
#pragma unroll
        for (int p = 0; p < 8; p++) {
          const int tile = 2 * kc + p / 4, r0 = 2 * (p % 4);
          Bp[kc].template select<16, 2>(p * 32 + 0) = P[tile].template select<16, 1>(r0 * 16);
          Bp[kc].template select<16, 2>(p * 32 + 1) = P[tile].template select<16, 1>((r0 + 1) * 16);
        }
      if (!(skip & 16)) {
        const uint16_t *vbase = V + ((b * AKH + kh) * 4 + h2 * 2) * 32 * 128 + dq * NT * 128;
#pragma unroll
        for (int kc = 0; kc < 2; kc++) {
          simd<int32_t, 128> bw = Bp[kc].template bit_cast_view<int32_t>();
#pragma unroll
          for (int tt = 0; tt < NT; tt++) {
            simd<int32_t, 64> a;
            a.copy_from(reinterpret_cast<const int32_t *>(vbase + (kc * 32 + tt) * 128));
            acc[tt] = xmx::dpas<8, 8, float, float, int32_t, int32_t, XT::fp16, XT::fp16>(acc[tt], bw, a);
          }
        }
      }
    }
    const size_t sidx = (kh * G + g) * NS + seg;
    if (dq == 0) {
      mrun.copy_to(psm + sidx * 16);
      den.copy_to(psd + sidx * 16);
    }
#pragma unroll
    for (int tt = 0; tt < NT; tt++) acc[tt].copy_to(pseg + sidx * 4096 + (dq * NT + tt) * 128);
  });
}


// Fused XMX attention with a shared QK^T (DQ = 8 threads per work-group, no register spill unlike DQ = 4): per 32-key sub-block the 4 key tiles are split
// over the 8 threads (thread t: tile t/2, dim chunks 8*(t%2)..+8 = 8 DPAS), the partial S^T tiles go through SLM (double-buffered, one barrier per
// sub-block, the two halves are added in a fixed order so results do not depend on the pass), then every thread does the softmax update and the PV DPAS
// of its own 32 V dims. QK DPAS per thread: 8 per sub-block instead of 64. SLM = 2 x 8 x 512 B = 8 KiB. skip: 8 = no QK dpas, 16 = no PV dpas.
// KQ = 1: the K and V tiles are INT8 (one scale per position and kv head, ksc / vsc [kv head][ctx]); they are converted to FP16 for the DPAS,
// S^T rows are multiplied by the key's scale and P rows by the value's scale (the denominator uses the unscaled FP16 weights).
template <int XB, int KQ = 0>
void k_attn_xmx3(Q &q, const uint16_t *Q16, const void *Kv, const void *Vv, const float *ksc, const float *vsc, int ctxcap, float *pseg, float *psm, float *psd, int m, int pos0, int skip) {
  constexpr int DQ = 8, NT = 4;
  const int G = (6 * m + 15) / 16;
  const size_t nb = size_t(pos0 + m - 1) / 64 + 1, NS = (nb + XB - 1) / XB;
  q.parallel_for(sycl::nd_range<1>(AKH * size_t(G) * NS * DQ, DQ), [=](sycl::nd_item<1> it) SYCL_ESIMD_KERNEL {
    es::slm_init<8192>();
    const size_t wg = it.get_group(0);
    const int dq = int(it.get_local_id(0));
    const size_t g = wg % G, seg = wg / G % NS, kh = wg / G / NS;
    simd<int, 16> limv(-1);
#pragma unroll
    for (int n = 0; n < 16; n++) {
      const int r = int(g) * 16 + n;
      if (r < 6 * m) limv[n] = pos0 + r / 6;
    }
    const simd<int, 128> limr = limv.template replicate<8>();
    simd<int, 128> kidx;
#pragma unroll
    for (int i = 0; i < 8; i++) kidx.template select<16, 1>(i * 16) = i;
    const uint16_t *qt = Q16 + (kh * G + g) * 16 * 256;
    simd<float, 16> mrun(-1e30f), den(0.0f);
    simd<float, 128> acc[NT];
#pragma unroll
    for (int tt = 0; tt < NT; tt++) acc[tt] = 0.0f;
    const size_t sb0 = seg * XB * 2, sb1 = std::min(nb * 2, (seg + 1) * XB * 2);
    int buf = 0;
    for (size_t sbi = sb0; sbi < sb1; sbi++) {
      const int key0 = int(sbi) * 32;
      if (key0 > pos0 + m - 1) break; // uniform over the work-group
      const size_t b = sbi >> 1, h2 = sbi & 1;
      simd<float, 128> st(0.0f);
      if (!(skip & 8)) {
        const int jt = dq >> 1, c0 = (dq & 1) * 8;
        const size_t ktile = ((b * AKH + kh) * 8 + h2 * 4 + jt) * 16 * 128;
        for (int c = c0; c < c0 + 8; c++) {
          simd<int32_t, 128> w;
          w.copy_from(reinterpret_cast<const int32_t *>(qt + c * 256));
          simd<int32_t, 64> a;
          if constexpr (KQ) {
            simd<int8_t, 128> kq;
            kq.copy_from(static_cast<const int8_t *>(Kv) + ktile + c * 128);
            simd<sycl::half, 128> kh16 = es::convert<sycl::half>(kq);
            a = kh16.template bit_cast_view<int32_t>();
          } else {
            a.copy_from(reinterpret_cast<const int32_t *>(static_cast<const uint16_t *>(Kv) + ktile + c * 128));
          }
          st = xmx::dpas<8, 8, float, float, int32_t, int32_t, XT::fp16, XT::fp16>(st, w, a);
        }
      }
      es::slm_block_store<float, 128>(uint32_t((buf * DQ + dq) * 512), st);
      es::barrier();
      simd<float, 128> S[4];
#pragma unroll
      for (int jt = 0; jt < 4; jt++) {
        S[jt] = es::slm_block_load<float, 128>(uint32_t((buf * DQ + 2 * jt) * 512));
        S[jt] += es::slm_block_load<float, 128>(uint32_t((buf * DQ + 2 * jt + 1) * 512));
        if constexpr (KQ) {
          simd<float, 8> k8;
          k8.copy_from(ksc + kh * size_t(ctxcap) + key0 + jt * 8);
#pragma unroll
          for (int i = 0; i < 8; i++) S[jt].template select<16, 1>(i * 16) = simd<float, 16>(S[jt].template select<16, 1>(i * 16)) * float(k8[i]);
        }
      }
      buf ^= 1;
      simd<float, 16> mxb(-1e30f);
#pragma unroll
      for (int jt = 0; jt < 4; jt++) {
        S[jt].merge(simd<float, 128>(-1e30f), (kidx + (key0 + jt * 8)) > limr);
#pragma unroll
        for (int i = 0; i < 8; i++) mxb = es::max(mxb, simd<float, 16>(S[jt].template select<16, 1>(i * 16)));
      }
      const simd<float, 16> mnew = es::max(mrun, mxb);
      const simd<float, 16> sc = es::exp(mrun - mnew);
      const simd<float, 128> mnr = mnew.template replicate<8>();
      simd<sycl::half, 128> P[4];
      simd<float, 16> denb(0.0f);
#pragma unroll
      for (int jt = 0; jt < 4; jt++) {
        simd<float, 128> e = es::exp(S[jt] - mnr);
        simd<sycl::half, 128> ph = es::convert<sycl::half>(e);
        simd<float, 128> er = es::convert<float>(ph);
#pragma unroll
        for (int i = 0; i < 8; i++) denb += er.template select<16, 1>(i * 16);
        if constexpr (KQ) {
          simd<float, 8> v8;
          v8.copy_from(vsc + kh * size_t(ctxcap) + key0 + jt * 8);
#pragma unroll
          for (int i = 0; i < 8; i++) e.template select<16, 1>(i * 16) = simd<float, 16>(e.template select<16, 1>(i * 16)) * float(v8[i]);
          P[jt] = es::convert<sycl::half>(e);
        } else {
          P[jt] = ph;
        }
      }
      den = den * sc + denb;
      mrun = mnew;
      const simd<float, 128> scr = sc.template replicate<8>();
#pragma unroll
      for (int tt = 0; tt < NT; tt++) acc[tt] *= scr;
      simd<sycl::half, 256> Bp[2];
#pragma unroll
      for (int kc = 0; kc < 2; kc++)
#pragma unroll
        for (int p = 0; p < 8; p++) {
          const int tile = 2 * kc + p / 4, r0 = 2 * (p % 4);
          Bp[kc].template select<16, 2>(p * 32 + 0) = P[tile].template select<16, 1>(r0 * 16);
          Bp[kc].template select<16, 2>(p * 32 + 1) = P[tile].template select<16, 1>((r0 + 1) * 16);
        }
      if (!(skip & 16)) {
        const size_t vbase = ((b * AKH + kh) * 4 + h2 * 2) * 32 * 128 + size_t(dq) * NT * 128;
#pragma unroll
        for (int kc = 0; kc < 2; kc++) {
          simd<int32_t, 128> bw = Bp[kc].template bit_cast_view<int32_t>();
#pragma unroll
          for (int tt = 0; tt < NT; tt++) {
            simd<int32_t, 64> a;
            if constexpr (KQ) {
              simd<int8_t, 128> vq;
              vq.copy_from(static_cast<const int8_t *>(Vv) + vbase + (kc * 32 + tt) * 128);
              simd<sycl::half, 128> v16 = es::convert<sycl::half>(vq);
              a = v16.template bit_cast_view<int32_t>();
            } else {
              a.copy_from(reinterpret_cast<const int32_t *>(static_cast<const uint16_t *>(Vv) + vbase + (kc * 32 + tt) * 128));
            }
            acc[tt] = xmx::dpas<8, 8, float, float, int32_t, int32_t, XT::fp16, XT::fp16>(acc[tt], bw, a);
          }
        }
      }
    }
    const size_t sidx = (kh * G + g) * NS + seg;
    if (dq == 0) {
      mrun.copy_to(psm + sidx * 16);
      den.copy_to(psd + sidx * 16);
    }
#pragma unroll
    for (int tt = 0; tt < NT; tt++) acc[tt].copy_to(pseg + sidx * 4096 + (dq * NT + tt) * 128);
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
// XF_PROF_DETAIL=1 (with a profiled forward): per-kernel / per-GEMM-shape accounting with a synchronisation after every kernel, dumped at exit.
// The cost of one empty synchronisation is measured once and printed so that it can be subtracted (calls x sync_us).
struct DetAcc {
  double ms = 0, bytes = 0;
  long calls = 0;
};
struct DetReg {
  std::map<std::string, DetAcc> t;
  double sync_us = 0;
  ~DetReg() {
    if (t.empty()) return;
    std::fprintf(stderr, "[prof-detail] empty queue synchronisation: %.1f us per tick\n", sync_us);
    std::fprintf(stderr, "[prof-detail] %-44s %8s %10s %10s %10s %9s\n", "key (rows | kernel)", "calls", "total ms", "us/call", "net us", "GB/s");
    for (auto &kv : t) {
      const DetAcc &a = kv.second;
      const double net = a.ms * 1e3 / a.calls - sync_us;
      std::fprintf(stderr, "[prof-detail] %-44s %8ld %10.3f %10.1f %10.1f %9.1f\n", kv.first.c_str(), a.calls, a.ms, a.ms * 1e3 / a.calls, net,
                   a.bytes > 0 ? a.bytes / a.calls / (net > 0.1 ? net : 0.1) / 1e3 : 0.0);
    }
  }
};
DetReg &detreg() {
  static DetReg r;
  return r;
}
struct Timer {
  Q &q;
  double *prof;
  bool trace; // XF_TRACE_STAGES: wait and print a marker after every stage
  bool detail;
  int mrows = 0;
  std::chrono::steady_clock::time_point t0;
  Timer(Q &queue, double *p) : q(queue), prof(p), trace(std::getenv("XF_TRACE_STAGES") != nullptr), detail(p && std::getenv("XF_PROF_DETAIL")) {
    if (detail && detreg().sync_us == 0) {
      q.wait_and_throw();
      const auto a = std::chrono::steady_clock::now();
      for (int i = 0; i < 500; i++) q.wait_and_throw();
      detreg().sync_us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - a).count() / 500;
    }
    if (prof) t0 = std::chrono::steady_clock::now();
  }
  // Attribute everything submitted since the last call to category `cat` (and, with XF_PROF_DETAIL, to `tag`).
  void tick(int cat, const char *tag = nullptr, double bytes = 0) {
    if (!prof && !trace) return;
    if (trace) std::fprintf(stderr, "%d", cat);
    q.wait_and_throw();
    if (trace) std::fprintf(stderr, ". ");
    if (!prof) return;
    const auto t1 = std::chrono::steady_clock::now();
    const double dt = std::chrono::duration<double, std::milli>(t1 - t0).count();
    prof[cat] += dt;
    if (detail && tag) {
      char key[96];
      std::snprintf(key, sizeof key, "m=%02d %s", mrows, tag);
      DetAcc &a = detreg().t[key];
      a.ms += dt;
      a.calls++;
      a.bytes += bytes;
    }
    t0 = t1;
  }
  // Extra tick used only for the detailed profile (adds no synchronisation otherwise).
  void dtick(int cat, const char *tag) {
    if (detail) tick(cat, tag);
  }
};
enum { P_NORM = 0, P_QUANT, P_GEMM, P_GDN, P_ATTN, P_MLP, P_HEAD, P_COUNT };

// XF_SKIP (timing ablation only, the outputs are meaningless): bit 0 activation quantisation, 1 RMSNorm kernels, 2 GDN conv / qk-norm / gate / post, 3 GDN gemv a/b,
// 4 GDN core, 5 MLP activation, 6 attention kernels (all of them), 7 the GEMMs of the layers
int skip_mask() {
  static const int v = std::getenv("XF_SKIP") ? std::atoi(std::getenv("XF_SKIP")) : 0;
  return v;
}
struct Pass {
  xf_ctx *ctx;
  const xf_model *md;
  WS ws;
  int m, mpad, tpt;
  Timer tm;
  bool pending = false; // ws.y still has to be added to ws.h
  int gemm_cat = P_GEMM; // profile category of the next GEMM (the head has its own)
  const xf_mat *quantised = nullptr; // matrix whose quantised input the last norm kernel already wrote

  // y[m][rows] = mat (v[m][cols]) ; pmax must describe v.
  // `vs` is the row stride of v (0 = mat.cols). The output row stride is mat.rows.
  // `one` runs a single row (v points at it, pm at its pmax row) regardless of the pass size.
  // `plain` = codes are plain integers (no +0.5 level offset), as in the head sketch table.
  int gemm(const xf_mat &mat, const float *v, float *y, size_t vs = 0, bool one = false, const float *pm = nullptr,
           bool plain = false) {
    Q &q = ctx->q;
    const int m = one ? 1 : this->m, mpad = one ? 1 : this->mpad, tpt = one ? 1 : this->tpt;
    const float *pmax = pm ? pm : ws.pmax;
    if (quantised == &mat && v == ws.xn) {
      quantised = nullptr; // the norm kernel already produced the byte planes of this matrix
    } else if (skip_mask() & 1) {
    } else {
      k_quant(q, v, vs ? vs : size_t(mat.cols), mat.cols, mat.cs, mat.cmax, pmax, m, mpad, ws.xhi, ws.xlo, ws.ts, ws.toff);
      tm.tick(P_QUANT, "act-quant");
    }
    xf_gemm_desc d{};
    d.wfmt = mat.fmt;
    d.rows = mat.rows;
    d.cols = mat.cols;
    d.m = m;
    d.tokens_per_thread = tpt;
    // Column segments (partial sums over K, merged by a combine kernel): narrow matrices have few row blocks. With the software-pipelined loop of the GEMM
    // (default) the out projections (5120 x 6144) are fastest with 1 segment and 5120 x 17408 (down) with 2 (xf-bench --cold, benchmarks/results/m12/gemm_pipe_sweep.txt);
    // with XF_GEMM_PIPE=0 the earlier rule applies (4, or 2 / 1 for the out projections). Integer partial sums are exact: no result depends on the segment count.
    static const bool pipe_on = !(std::getenv("XF_GEMM_PIPE") && std::getenv("XF_GEMM_PIPE")[0] == '0');
    static const bool seg_old = std::getenv("XF_GEMM_SEGS_OLD") != nullptr;
    d.segs = (mat.rows < 8192 && m > 1) ? 4 : 1;
    if (mat.rows < 8192 && m > 1) {
      // With the small work-group launch of the pipelined GEMM (XF_GEMM_WG, default on for 8 / 16 rows per thread) the 320 threads of a 5,120-row matrix spread over all
      // Xe cores and one segment is fastest for down as well (no combine kernel); XF_GEMM_WG=0 restores the plain launch and the 2 segments.
      static const bool wg_on = !(std::getenv("XF_GEMM_WG") && std::atoi(std::getenv("XF_GEMM_WG")) <= 1);
      if (pipe_on && !seg_old) d.segs = (mat.cols <= 8192 || wg_on) ? 1 : 2;
      else if (!seg_old && mat.cols <= 8192) d.segs = m <= 8 ? 2 : 1;
      // More than 16 rows: with the split 16-bit-activation kernel (adjacent token groups) one segment is fastest for every shape (xf-bench --cold, benchmarks/results/m28/unit_final2.json: down 0.179 ms with 1 segment, 0.198 with 4).
    }
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
    const int st = (skip_mask() & 128) ? XF_OK : xf_gemm(ctx, &d);
    if (tm.detail) {
      const int bits = mat.fmt == XF_W_S2 ? 2 : mat.fmt == XF_W_S3 ? 3 : 4;
      char tag[64];
      std::snprintf(tag, sizeof tag, "gemm %5dx%-5d %s", mat.rows, mat.cols, gemm_cat == P_HEAD ? "(head)" : "");
      tm.tick(gemm_cat, tag, double(mat.rows) * mat.cols * bits / 8.0);
    } else {
      tm.tick(gemm_cat);
    }
    return st;
  }

  // RMSNorm of the residual stream; folds in the pending residual add.
  void norm(const float *gain, const xf_mat *next = nullptr) {
    static const bool fuse = !(std::getenv("XF_FUSE") && std::getenv("XF_FUSE")[0] == '0'); // XF_FUSE=0: separate norm and quantisation kernels
    if (skip_mask() & 2) {
      pending = false;
      return;
    }
    if (fuse && next && next->rows > 0 && next->cols == D) {
      k_addnorm_quant(ctx->q, ws.h, pending ? ws.y : nullptr, gain, ws.xn, next->cs, next->cmax, ws.xhi, ws.xlo, ws.ts, ws.toff, m, mpad);
      pending = false;
      quantised = next;
      tm.tick(P_NORM, "addnorm+quant");
      return;
    }
    k_addnorm(ctx->q, ws.h, pending ? ws.y : nullptr, gain, ws.xn, ws.pmax, m);
    pending = false;
    tm.tick(P_NORM, "addnorm");
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
    norm(L.ln2, &L.m[gi]);
    if (merged) {
      if (int st = gemm(L.m[gi], ws.xn, ws.g)) return st; // rows = 2 * FF: [gate | up] per token
    } else {
      // Two launches; each writes its own contiguous [m][FF] block, so stage
      // them and interleave is avoided by giving up its own buffer.
      if (int st = gemm(L.m[gi], ws.xn, ws.u)) return st;
      if (int st = gemm(L.m[gi + 1], ws.xn, ws.u + size_t(rows_cap(md->ctx)) * FF)) return st;
    }
    const float *gptr = merged ? ws.g : ws.u;
    const float *uptr = merged ? ws.g + FF : ws.u + size_t(rows_cap(md->ctx)) * FF;
    const size_t stride = merged ? gs : size_t(FF);
    if (!(skip_mask() & 32)) k_mlp_act(q, const_cast<float *>(gptr), uptr, stride, ws.pmax, m);
    tm.tick(P_MLP, "mlp-act");
    if (int st = gemm(L.m[gi + 2], gptr, ws.y, stride)) return st;
    pending = true;
    return XF_OK;
  }

  int gdn(const xf_layer &L) {
    Q &q = ctx->q;
    GdnState s = carve_gdn(L.state, md->ctx);
    const bool merged = L.m[1].rows == 0; // m[0] is qkv+z stacked
    const size_t rs = merged ? QKVZ : QKV;
    const float *z = merged ? s.raw + QKV : ws.yz;
    const size_t zs = merged ? QKVZ : VD;
    norm(L.ln1, &L.m[0]);
    if (int st = gemm(L.m[0], ws.xn, s.raw)) return st;
    if (!merged)
      if (int st = gemm(L.m[1], ws.xn, ws.yz)) return st;
    const int sk = skip_mask();
    if (!(sk & 8)) gdn_gemv_ab(q, L.aux[0], ws.xn, ws.yab, 96, m);
    tm.dtick(P_GDN, "gdn:gemv-ab");
    if (!(sk & 4)) gdn_conv(q, s.raw, rs, s.hist, L.aux[1], ws.act, m);
    tm.dtick(P_GDN, "gdn:conv");
    if (!(sk & 4)) k_gdn_qk(q, ws.act, ws.qn, s.kn, m);
    tm.dtick(P_GDN, "gdn:qk-norm");
    if (!(sk & 4)) k_gdn_gate(q, ws.yab, L.aux[2], L.aux[3], s.beta, s.decay, m);
    tm.dtick(P_GDN, "gdn:gate");
    if (!(sk & 16)) gdn_core(q, s.S, ws.act, ws.qn, s.kn, s.beta, s.decay, s.dsave, ws.gout, m);
    tm.dtick(P_GDN, "gdn:core");
    if (!(sk & 4)) k_gdn_post(q, ws.gout, z, zs, L.aux[4], ws.go, ws.pmax, m);
    tm.tick(P_GDN, "gdn:post");
    if (int st = gemm(L.m[2], ws.go, ws.y)) return st;
    pending = true;
    return mlp(L, 3);
  }

  int attn(const xf_layer &L, int pos0) {
    Q &q = ctx->q;
    AttnState s = carve_attn(L.state, md->ctx);
    const size_t nbs = size_t(md->ctx) / 64 + 1;
    const bool merged = L.m[1].rows == 0; // m[0] is q+k+v stacked
    norm(L.ln1, &L.m[0]);
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
    if (skip_mask() & 64) { // ablation: no attention kernels
      tm.tick(P_ATTN);
      if (int st = gemm(L.m[3], ws.go, ws.y)) return st;
      pending = true;
      return mlp(L, 4);
    }
    k_attn_q(q, ws.yq, qs, L.aux[0], md->rope_cos, md->rope_sin, ws.qr, m, pos0);
    tm.dtick(P_ATTN, "attn:q-prep");
    static const bool kt = !(std::getenv("XF_ATTN_KT") && std::getenv("XF_ATTN_KT")[0] == '0') && md->ctx % 64 == 0; // default on; XF_ATTN_KT=0 = legacy
    const int kvm = kv_mode();
    if (kvm == 4) {
      // INT8 KV: shared XMX kernel only
      k_attn_q16(q, ws.qr, ws.q16, m);
      tm.dtick(P_ATTN, "attn:q16");
      k_attn_kv_x8(q, yk, yv, ks, L.aux[1], md->rope_cos, md->rope_sin, static_cast<int8_t *>(s.K), static_cast<int8_t *>(s.V), s.ks, s.vs, md->ctx, m, pos0);
      tm.dtick(P_ATTN, "attn:kv-store");
      static const int xb8 = std::getenv("XF_XMX_XB") ? std::atoi(std::getenv("XF_XMX_XB")) : 8;
      if (xb8 == 4) k_attn_xmx3<4, 1>(q, ws.q16, s.K, s.V, s.ks, s.vs, md->ctx, ws.pseg, ws.psm, ws.psd, m, pos0, 0);
      else k_attn_xmx3<8, 1>(q, ws.q16, s.K, s.V, s.ks, s.vs, md->ctx, ws.pseg, ws.psm, ws.psd, m, pos0, 0);
      tm.dtick(P_ATTN, "attn:xmx-main");
      k_attn_comb2(q, ws.psm, ws.psd, ws.pseg, ws.yq, qs, ws.go, ws.pmax, m, pos0, xb8 == 4 ? 4 : 8);
      tm.tick(P_ATTN, "attn:combine");
      if (int st = gemm(L.m[3], ws.go, ws.y)) return st;
      pending = true;
      return mlp(L, 4);
    }
    if (kvm == 3) {
      const size_t nbx = size_t(pos0 + m - 1) / 64 + 1;
      (void)nbx;
      // XF_XMX_SKIP (timing studies only, outputs are wrong): bit 0 = no q16/kv-store, 1 = no main kernel, 2 = no combine
      static const int skip = std::getenv("XF_XMX_SKIP") ? std::atoi(std::getenv("XF_XMX_SKIP")) : 0;
      static const bool old_xmx = std::getenv("XF_XMX_OLD") != nullptr;
      if (!old_xmx) {
        // fused kernel (default for XF_KV=xmx): XF_XMX_XB = blocks per thread (4|8), XF_XMX_DQ = V dim parts (4|8)
        const int xb = std::getenv("XF_XMX_XB") ? std::atoi(std::getenv("XF_XMX_XB")) : 8;
        const int dqn = std::getenv("XF_XMX_DQ") ? std::atoi(std::getenv("XF_XMX_DQ")) : 4;
        k_attn_q16(q, ws.qr, ws.q16, m);
        tm.dtick(P_ATTN, "attn:q16");
        k_attn_kv_x(q, yk, yv, ks, L.aux[1], md->rope_cos, md->rope_sin, static_cast<uint16_t *>(s.K), static_cast<uint16_t *>(s.V), m, pos0);
        tm.dtick(P_ATTN, "attn:kv-store");
        const uint16_t *Kc = static_cast<const uint16_t *>(s.K), *Vc = static_cast<const uint16_t *>(s.V);
        static const bool share = !(std::getenv("XF_XMX_SHARE") && std::getenv("XF_XMX_SHARE")[0] == '0'); // default on; XF_XMX_SHARE=0 = unshared kernel // QK shared through SLM (DQ = 8 threads per work-group)
        if (share) {
          if (xb == 4) k_attn_xmx3<4>(q, ws.q16, Kc, Vc, nullptr, nullptr, 0, ws.pseg, ws.psm, ws.psd, m, pos0, skip);
          else k_attn_xmx3<8>(q, ws.q16, Kc, Vc, nullptr, nullptr, 0, ws.pseg, ws.psm, ws.psd, m, pos0, skip);
        } else if (xb == 4) {
          if (dqn == 8) k_attn_xmx2<4, 8>(q, ws.q16, Kc, Vc, ws.pseg, ws.psm, ws.psd, m, pos0, skip);
          else k_attn_xmx2<4, 4>(q, ws.q16, Kc, Vc, ws.pseg, ws.psm, ws.psd, m, pos0, skip);
        } else {
          if (dqn == 8) k_attn_xmx2<8, 8>(q, ws.q16, Kc, Vc, ws.pseg, ws.psm, ws.psd, m, pos0, skip);
          else k_attn_xmx2<8, 4>(q, ws.q16, Kc, Vc, ws.pseg, ws.psm, ws.psd, m, pos0, skip);
        }
        tm.dtick(P_ATTN, "attn:xmx-main");
        k_attn_comb2(q, ws.psm, ws.psd, ws.pseg, ws.yq, qs, ws.go, ws.pmax, m, pos0, xb == 4 ? 4 : 8);
        tm.tick(P_ATTN, "attn:combine");
        if (int st = gemm(L.m[3], ws.go, ws.y)) return st;
        pending = true;
        return mlp(L, 4);
      }
      if (!(skip & 1)) {
        k_attn_q16(q, ws.qr, ws.q16, m);
        k_attn_kv_x(q, yk, yv, ks, L.aux[1], md->rope_cos, md->rope_sin, static_cast<uint16_t *>(s.K), static_cast<uint16_t *>(s.V), m, pos0);
      }
      if (!(skip & 2)) k_attn_xmx(q, ws.q16, static_cast<const uint16_t *>(s.K), static_cast<const uint16_t *>(s.V), ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      if (!(skip & 4)) {
        // one-stage combine (gathers the [dim][row] tiles) is cheaper for short contexts, the two-stage one for long ones
        const bool two = std::getenv("XF_XMX_COMB") ? std::atoi(std::getenv("XF_XMX_COMB")) == 2
                                                    : (size_t(pos0 + m - 1) / 64 + 1 >= (m == 1 ? 192u : 96u));
        if (!two) {
          k_attn_comb_x(q, ws.pm, ws.pd, ws.pv, ws.yq, qs, ws.go, ws.pmax, m, pos0, nbs); // one-stage combine (gather), for comparison
        } else {
          k_attn_comb1(q, ws.pm, ws.pd, ws.pv, ws.pseg, ws.psm, ws.psd, m, pos0, nbs);
          k_attn_comb2(q, ws.psm, ws.psd, ws.pseg, ws.yq, qs, ws.go, ws.pmax, m, pos0);
        }
      }
      tm.tick(P_ATTN);
      if (int st = gemm(L.m[3], ws.go, ws.y)) return st;
      pending = true;
      return mlp(L, 4);
    }
    if (kvm && !kt) { xf_set_error("XF_KV needs the K^T layout (ctx multiple of 64, XF_ATTN_KT != 0)"); return XF_ERR_INVALID; }
    k_attn_kv(q, yk, yv, ks, L.aux[1], md->rope_cos, md->rope_sin, s.K, s.V, m, pos0, kt, kvm);
    tm.dtick(P_ATTN, "attn:kv-store");
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
      const char *esl = std::getenv("XF_ATTN_SLM");
      const bool autoslm = !esl;
      int slm = esl ? std::atoi(esl) : ((m >= 2 && m <= 32 && !(m <= 8 && nbk >= 48 && nbk < 112)) ? 3 : 0); // m <= 32: the work-group (m * 2 threads) is limited to 64 threads
      if (std::getenv("XF_ATTN_LOG") && !(slm && m >= 2)) {
        static unsigned seen = 0;
        const unsigned key = unsigned(m) * 4u + (nbk < 24 ? 0u : nbk < 48 ? 1u : 2u);
        if (key < 64 && !(seen >> key & 1u)) { seen |= 1u << key; std::fprintf(stderr, "[attn] part3<HG=%d,TG=%d> gper=%d rows=%d blocks=%d\n", hg, tg, gp, m, nbk); }
      }
      // SLM work-group attention: automatic for m >= 2 (HPT=3, K tile in 4 chunks), except 8 rows or fewer at 3K-7K tokens where the
      // register-tile kernel is a little faster (benchmarks/results/m7). XF_ATTN_SLM=0 forces the old kernel, =2/3/6 forces HPT.
      if (slm && m >= 2) {
        if (std::getenv("XF_ATTN_LOG")) {
          static unsigned seen = 0;
          const unsigned key = unsigned(m) * 4u + (nbk < 24 ? 0u : nbk < 48 ? 1u : 2u);
          if (key < 64 && !(seen >> key & 1u)) { seen |= 1u << key; std::fprintf(stderr, "[attn] slm<HPT=%d,KV=%d> rows=%d blocks=%d\n", slm, kvm, m, nbk); }
        }
        const char *esc = std::getenv("XF_ATTN_SLMC");
        const int nck = esc ? std::atoi(esc) : (autoslm ? 4 : 1);
#define XF_SLM(KVM, H, C) k_attn_slm<H, KVM, C>(q, ws.qr, s.K, s.V, ws.pm, ws.pd, ws.pv, m, pos0, nbs)
#define XF_SLMC(KVM, H) { if (nck >= 4) XF_SLM(KVM, H, 4); else if (nck == 2) XF_SLM(KVM, H, 2); else XF_SLM(KVM, H, 1); }
        if (kvm == 0) { if (slm >= 6) XF_SLMC(0, 6) else if (slm >= 3) XF_SLMC(0, 3) else XF_SLMC(0, 2) }
        else if (kvm == 1) XF_SLM(1, 3, 4);
        else XF_SLM(2, 3, 4);
#undef XF_SLM
#undef XF_SLMC
      } else
#define XF_P3(H, T) k_attn_part3<H, T, 0>(q, ws.qr, s.K, s.V, ws.pm, ws.pd, ws.pv, m, pos0, nbs, gp)
#define XF_P3K(KVM, H, T) k_attn_part3<H, T, KVM>(q, ws.qr, s.K, s.V, ws.pm, ws.pd, ws.pv, m, pos0, nbs, gp)
#define XF_P3KT(KVM, H) { if (tg <= 2) XF_P3K(KVM, H, 2); else XF_P3K(KVM, H, 4); }
      if (kvm) {
        // 16-bit KV: reduced instantiation set (HG 1/3/6, TG 2/4)
        const int hq = hg >= 6 ? 6 : hg >= 3 ? 3 : 1;
        if (kvm == 1) { if (hq == 6) XF_P3KT(1, 6) else if (hq == 3) XF_P3KT(1, 3) else XF_P3KT(1, 1) }
        else { if (hq == 6) XF_P3KT(2, 6) else if (hq == 3) XF_P3KT(2, 3) else XF_P3KT(2, 1) }
      } else
      if (hg == 6) { if (tg == 1) XF_P3(6, 1); else if (tg == 2) XF_P3(6, 2); else if (tg == 4) XF_P3(6, 4); else XF_P3(6, 8); }
      else if (hg == 1) { if (tg == 1) XF_P3(1, 1); else if (tg == 2) XF_P3(1, 2); else if (tg == 4) XF_P3(1, 4); else XF_P3(1, 8); }
      else if (hg == 2) { if (tg == 1) XF_P3(2, 1); else if (tg == 2) XF_P3(2, 2); else if (tg == 4) XF_P3(2, 4); else XF_P3(2, 8); }
      else { if (tg == 1) XF_P3(3, 1); else if (tg == 2) XF_P3(3, 2); else if (tg == 4) XF_P3(3, 4); else XF_P3(3, 8); }
#undef XF_P3
#undef XF_P3K
#undef XF_P3KT
      (void)nbk;
    } else {
      static const int hg = std::getenv("XF_ATTN_HG") ? std::atoi(std::getenv("XF_ATTN_HG")) : 0;
      if (hg == 6) k_attn_part2<6>(q, ws.qr, static_cast<const float *>(s.K), static_cast<const float *>(s.V), ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      else if (hg == 3) k_attn_part2<3>(q, ws.qr, static_cast<const float *>(s.K), static_cast<const float *>(s.V), ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      else if (hg == 2) k_attn_part2<2>(q, ws.qr, static_cast<const float *>(s.K), static_cast<const float *>(s.V), ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      else if (hg == 1) k_attn_part2<1>(q, ws.qr, static_cast<const float *>(s.K), static_cast<const float *>(s.V), ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      else k_attn_part(q, ws.qr, static_cast<const float *>(s.K), static_cast<const float *>(s.V), ws.pm, ws.pd, ws.pv, m, pos0, nbs);
      static const bool alog = std::getenv("XF_ATTN_LOG") != nullptr;
      static unsigned seen = 0;
      if (alog && !(seen >> m & 1u)) {
        seen |= 1u << m;
        std::fprintf(stderr, "[attn] legacy path (hg=%d), rows=%d, pos0=%d, row-major K\n", hg, m, pos0);
      }
    }
    tm.dtick(P_ATTN, "attn:main");
    k_attn_comb(q, ws.pm, ws.pd, ws.pv, ws.yq, qs, ws.go, ws.pmax, m, pos0, nbs);
    tm.tick(P_ATTN, "attn:combine");
    if (int st = gemm(L.m[3], ws.go, ws.y)) return st;
    pending = true;
    return mlp(L, 4);
  }
};

} // namespace

extern "C" {

size_t xf_ws_bytes(int ctx) { return carve_ws(nullptr, ctx).total; }

size_t xf_state_bytes(int kind, int ctx) {
  return kind == XF_LAYER_GDN ? carve_gdn(nullptr, ctx).total : carve_attn(nullptr, ctx).total;
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
  const int slot = (flags & XF_FWD_IDS_SLOT1) ? IDV : 0;
  if (!ctx || !md || m < 1 || m > rows_cap(md->ctx) || pos0 < 0 || pos0 + m > md->ctx || l0 < 0 || l1 > md->nlayers) {
    xf_set_error("xf_forward: invalid arguments (token count, position or layer range)");
    return XF_ERR_INVALID;
  }
  return xf_guard("xf_forward", [&]() -> int {
    const int tpt = m == 1 ? 1 : m <= 8 ? 8 : m <= 16 ? 16 : 32;
    Pass p{ctx, md, carve_ws(md->ws, md->ctx), m, (m + tpt - 1) / tpt * tpt, tpt, Timer(ctx->q, prof)};
    p.tm.mrows = p.m;
    Q &q = ctx->q;
    if (flags & XF_FWD_EMBED) {
      k_embed(q, md->embed, p.ws.ids + slot, p.ws.h, m);
      p.tm.tick(P_NORM, "embed");
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
        k_capture(q, p.ws.h, p.pending ? p.ws.y : nullptr, p.ws.cap, l / 14, m);
      if (sync_every > 0 && (l + 1) % sync_every == 0) q.wait_and_throw();
    }
    if (flags & XF_FWD_HEAD) {
      p.norm(md->fnorm);
      p.gemm_cat = P_HEAD;
      if (int st = p.gemm(md->head, p.ws.xn, p.ws.logits)) return st;
      k_argmax(q, p.ws.logits, p.ws.amv, p.ws.ami, m);
      k_amax_final(q, p.ws.amv, p.ws.ami, m, p.ws.ids + IDG, reinterpret_cast<float *>(p.ws.ids + IDL), nullptr, nullptr);
      p.tm.tick(P_HEAD, "head:argmax");
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
    k_amax_final(q, w.amv, w.ami, 1, w.ids + IDG, reinterpret_cast<float *>(w.ids + IDL), dst0, dst1);
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
    k_pick(q, w.candv, w.candi, npad, w.ids + IDG, dst0, dst1);
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
    const int tpt = m == 1 ? 1 : m <= 8 ? 8 : m <= 16 ? 16 : 32;
    Pass p{ctx, md, carve_ws(md->ws, md->ctx), m, tpt, tpt, Timer(ctx->q, prof)};
    p.tm.mrows = p.m;
    return mtp_step(p, mtp, nullptr, pos0, src_row, m - 1, nullptr, nullptr);
  });
}

// Whole draft phase of a speculative cycle in one submission.
//   n      rows committed by the last trunk pass; their final-norm hidden
//          states are still in the workspace, ids[0..n) hold the token that
//          follows each row (the last one is the certain next token, which the
//          host also put in the verify slot ids[IDV]).
//   pos0   MTP position of the first of those rows.
//   k      drafts to produce; draft j (1-based) is written to ids[IDV + j].
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
    p.tm.mrows = p.m;
      if (int st = mtp_step(p, mtp, sk, pos0, 0, n - 1, w.ids, w.ids + IDV + 1)) return st;
    }
    for (int j = 2; j <= k; j++) {
      Pass p{ctx, md, w, 1, 1, 1, Timer(ctx->q, prof)};
    p.tm.mrows = p.m;
      // input: token d_{j-1} (in ids[0]) and the MTP hidden state that produced it
      if (int st = mtp_step(p, mtp, sk, pos0 + n - 1 + (j - 1), j == 2 ? n - 1 : 0, 0, w.ids, w.ids + IDV + j)) return st;
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
      GdnState s = carve_gdn(L.state, md->ctx);
      gdn_commit(ctx->q, s.S, s.kn, s.decay, s.dsave, n);
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
