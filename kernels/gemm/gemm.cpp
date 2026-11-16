// XeFlash GEMM for Xe2: weights stored in XMX tile order and fed to DPAS
// without any decode step.
//
// One hardware thread owns one block of 16 output rows (the DPAS execution
// size) and TPT = R*G tokens, and streams the column tiles of its row block:
//
//   for each tile:   W tile  -> 1 block load  (s4: 256 B = 4 GRF, s2: 128 B)
//                    x chunk -> 1 block load  (TPT * 32 B)
//                    G x dpas(repeat R)       (512 * R MACs each)
//
// R is the DPAS repeat count (tokens per instruction), G the number of
// 8-token groups per thread and U the number of tiles per loop trip (each with
// its own accumulators, so consecutive DPAS do not depend on each other).
//
//   decode   (1 token)      R=1 G=1 U=4   memory-bandwidth bound
//   verify   (<= 8 tokens)  R=8 G=1 U=2
//   verify   (<= 16 tokens) R=8 G=2 U=1
//   prefill  (many tokens)  R=8 G=4 U=1   XMX bound, weights reused from cache
#include <sycl/ext/intel/esimd.hpp>

#include "../ctx.hpp"

using namespace sycl::ext::intel::esimd;
namespace xmx = sycl::ext::intel::esimd::xmx;
using PT = xmx::dpas_argument_type;

namespace {

// Storage / operand geometry of a weight format.
template <int WF> struct Fmt;
template <> struct Fmt<XF_W_S4> {
  static constexpr int tile_cols = 32, stored_dw = 64, opnd_dw = 64;
  static constexpr bool is_float = false;
};
template <> struct Fmt<XF_W_S2> {
  static constexpr int tile_cols = 32, stored_dw = 32, opnd_dw = 32;
  static constexpr bool is_float = false;
};
template <> struct Fmt<XF_W_S8> {
  static constexpr int tile_cols = 32, stored_dw = 128, opnd_dw = 128;
  static constexpr bool is_float = false;
};
template <> struct Fmt<XF_W_BF16> {
  static constexpr int tile_cols = 16, stored_dw = 128, opnd_dw = 128;
  static constexpr bool is_float = true;
};
template <> struct Fmt<XF_W_S4_EXP8> {
  static constexpr int tile_cols = 32, stored_dw = 64, opnd_dw = 128;
  static constexpr bool is_float = false;
};

// Packed s4 tile (4 registers) -> s8 tile (8 registers), entirely in GRF.
// Only used by the XF_W_S4_EXP8 comparison variant.
ESIMD_INLINE simd<int32_t, 128> expand_s4_to_s8(simd<int32_t, 64> p) SYCL_ESIMD_FUNCTION {
  simd<int32_t, 128> out;
  auto words = p.template bit_cast_view<uint16_t>();
#pragma unroll
  for (int r = 0; r < 4; r++) {
#pragma unroll
    for (int half = 0; half < 2; half++) {
      simd<uint16_t, 16> w = words.template select<16, 2>(32 * r + half);
      simd<uint32_t, 16> v = convert<uint32_t>(w);
      simd<uint32_t, 16> e =
          (v & 0xFu) | ((v & 0xF0u) << 4) | ((v & 0xF00u) << 8) | ((v & 0xF000u) << 12);
      simd<int8_t, 64> b = e.template bit_cast_view<int8_t>();
      b = (b ^ int8_t(8)) - int8_t(8); // sign-extend each nibble
      out.template select<16, 1>(16 * (2 * r + half)) = b.template bit_cast_view<int32_t>();
    }
  }
  return out;
}

template <int WF, int R>
ESIMD_INLINE simd<int32_t, 16 * R> mac(simd<int32_t, 16 * R> acc, simd<int32_t, Fmt<WF>::stored_dw> w,
                                       simd<int32_t, 8 * R> a, bool a_unsigned) SYCL_ESIMD_FUNCTION {
  if constexpr (WF == XF_W_S4) {
    if (a_unsigned) return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(acc, w, a);
    return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc, w, a);
  } else if constexpr (WF == XF_W_S2) {
    if (a_unsigned) return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s2, PT::u8>(acc, w, a);
    return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s2, PT::s8>(acc, w, a);
  } else if constexpr (WF == XF_W_S8) {
    if (a_unsigned) return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s8, PT::u8>(acc, w, a);
    return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s8, PT::s8>(acc, w, a);
  } else { // XF_W_S4_EXP8
    simd<int32_t, 128> w8 = expand_s4_to_s8(w);
    if (a_unsigned) return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s8, PT::u8>(acc, w8, a);
    return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s8, PT::s8>(acc, w8, a);
  }
}

template <int WF, int R, int G, int U, bool A16> sycl::event submit(sycl::queue &q, const xf_gemm_desc &d) {
  using F = Fmt<WF>;
  constexpr int TPT = R * G;
  constexpr int WDW = F::stored_dw;
  constexpr int XDW = 8 * TPT; // activation dwords per tile per thread

  const int32_t *W = static_cast<const int32_t *>(d.w);
  const int32_t *X = static_cast<const int32_t *>(d.x);
  const int32_t *XL = static_cast<const int32_t *>(d.xlo);
  const float *RS = d.rs;
  const float *TS = d.ts;
  const size_t rows = d.rows;
  const size_t rowblks = rows / 16;
  const size_t tiles = size_t(d.cols) / F::tile_cols;
  const size_t segs = d.segs;
  const size_t tps = tiles / segs; // tiles per segment
  const size_t mpad = (size_t(d.m) + TPT - 1) / TPT * TPT;
  const size_t tgroups = mpad / TPT;
  float *Y = segs == 1 ? d.y : d.ypart;

  return q.parallel_for(sycl::range<1>(rowblks * tgroups * segs), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t idx = id[0];
    const size_t rb = idx % rowblks;
    const size_t tg = (idx / rowblks) % tgroups;
    const size_t seg = idx / (rowblks * tgroups);

    const int32_t *wp = W + (rb * tiles + seg * tps) * WDW;
    const size_t xoff = (seg * tps * mpad + tg * TPT) * 8; // dwords
    const size_t xstride = mpad * 8;                       // dwords per tile

    if constexpr (F::is_float) {
      simd<float, 16 * R> acc[U][G];
#pragma unroll
      for (int u = 0; u < U; u++)
#pragma unroll
        for (int g = 0; g < G; g++) acc[u][g] = 0.0f;

      for (size_t t = 0; t < tps; t += U) {
#pragma unroll
        for (int u = 0; u < U; u++) {
          simd<int32_t, WDW> w;
          w.copy_from(wp + (t + u) * WDW);
          simd<int32_t, XDW> xv;
          xv.copy_from(X + xoff + (t + u) * xstride);
#pragma unroll
          for (int g = 0; g < G; g++) {
            simd<int32_t, 8 * R> a = xv.template select<8 * R, 1>(g * 8 * R);
            acc[u][g] = xmx::dpas<8, R, float, float, int32_t, int32_t, PT::bf16, PT::bf16>(acc[u][g], w, a);
          }
        }
      }
      simd<float, 16> rsv;
      rsv.copy_from(RS + rb * 16);
      simd<float, TPT> tsv;
      tsv.copy_from(TS + tg * TPT);
#pragma unroll
      for (int g = 0; g < G; g++) {
        simd<float, 16 * R> s = acc[0][g];
#pragma unroll
        for (int u = 1; u < U; u++) s += acc[u][g];
#pragma unroll
        for (int m = 0; m < R; m++) {
          simd<float, 16> f = s.template select<16, 1>(16 * m);
          f = f * rsv * float(tsv[g * R + m]);
          f.copy_to(Y + (seg * mpad + tg * TPT + g * R + m) * rows + rb * 16);
        }
      }
    } else {
      simd<int32_t, 16 * R> acc[U][G];
      simd<int32_t, 16 * R> accl[U][G];
#pragma unroll
      for (int u = 0; u < U; u++)
#pragma unroll
        for (int g = 0; g < G; g++) {
          acc[u][g] = 0;
          accl[u][g] = 0;
        }

      for (size_t t = 0; t < tps; t += U) {
#pragma unroll
        for (int u = 0; u < U; u++) {
          simd<int32_t, WDW> w;
          w.copy_from(wp + (t + u) * WDW);
          simd<int32_t, XDW> xv;
          xv.copy_from(X + xoff + (t + u) * xstride);
#pragma unroll
          for (int g = 0; g < G; g++) {
            simd<int32_t, 8 * R> a = xv.template select<8 * R, 1>(g * 8 * R);
            acc[u][g] = mac<WF, R>(acc[u][g], w, a, false);
          }
          if constexpr (A16) {
            simd<int32_t, XDW> xl;
            xl.copy_from(XL + xoff + (t + u) * xstride);
#pragma unroll
            for (int g = 0; g < G; g++) {
              simd<int32_t, 8 * R> a = xl.template select<8 * R, 1>(g * 8 * R);
              accl[u][g] = mac<WF, R>(accl[u][g], w, a, true);
            }
          }
        }
      }
      simd<float, 16> rsv;
      rsv.copy_from(RS + rb * 16);
      simd<float, TPT> tsv;
      tsv.copy_from(TS + tg * TPT);
#pragma unroll
      for (int g = 0; g < G; g++) {
        simd<int32_t, 16 * R> s = acc[0][g];
        simd<int32_t, 16 * R> sl = accl[0][g];
#pragma unroll
        for (int u = 1; u < U; u++) {
          s += acc[u][g];
          sl += accl[u][g];
        }
#pragma unroll
        for (int m = 0; m < R; m++) {
          simd<int32_t, 16> si = s.template select<16, 1>(16 * m);
          simd<float, 16> f = convert<float>(si);
          if constexpr (A16) {
            simd<int32_t, 16> li = sl.template select<16, 1>(16 * m);
            f = f * 256.0f + convert<float>(li);
          }
          f = f * rsv * float(tsv[g * R + m]);
          f.copy_to(Y + (seg * mpad + tg * TPT + g * R + m) * rows + rb * 16);
        }
      }
    }
  });
}

// Sum the per-segment partial outputs into y.
sycl::event combine(sycl::queue &q, const float *ypart, float *y, size_t n, size_t segs) {
  return q.parallel_for(sycl::range<1>(n / 16), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t i = id[0] * 16;
    simd<float, 16> s;
    s.copy_from(ypart + i);
    for (size_t k = 1; k < segs; k++) {
      simd<float, 16> v;
      v.copy_from(ypart + k * n + i);
      s += v;
    }
    s.copy_to(y + i);
  });
}

template <int WF, bool A16> int dispatch(sycl::queue &q, const xf_gemm_desc &d) {
  switch (d.tokens_per_thread) {
  case 1: submit<WF, 1, 1, 4, A16>(q, d); return XF_OK;
  case 8: submit<WF, 8, 1, 2, A16>(q, d); return XF_OK;
  case 16: submit<WF, 8, 2, 1, A16>(q, d); return XF_OK;
  case 32: submit<WF, 8, 4, 1, A16>(q, d); return XF_OK;
  }
  xf_set_error("xf_gemm: tokens_per_thread must be 1, 8, 16 or 32");
  return XF_ERR_INVALID;
}

int unroll_of(int tpt) { return tpt == 1 ? 4 : tpt == 8 ? 2 : 1; }

} // namespace

extern "C" int xf_gemm(xf_ctx *ctx, const xf_gemm_desc *dp) {
  if (!ctx || !dp) return XF_ERR_INVALID;
  const xf_gemm_desc d = *dp;
  const int tc = d.wfmt == XF_W_BF16 ? 16 : 32;
  if (!d.w || !d.x || !d.rs || !d.ts || !d.y || d.rows <= 0 || d.cols <= 0 || d.m <= 0 || d.segs < 1 ||
      d.rows % 16 != 0 || (d.a16 && (!d.xlo || d.wfmt == XF_W_BF16)) || (d.segs > 1 && !d.ypart)) {
    xf_set_error("xf_gemm: invalid descriptor");
    return XF_ERR_INVALID;
  }
  if (d.cols % (tc * unroll_of(d.tokens_per_thread) * d.segs) != 0) {
    xf_set_error("xf_gemm: cols must be a multiple of tile_cols * unroll * segs");
    return XF_ERR_INVALID;
  }
  return xf_guard("xf_gemm", [&]() -> int {
    int st = XF_ERR_INVALID;
    switch (d.wfmt) {
    case XF_W_S4: st = d.a16 ? dispatch<XF_W_S4, true>(ctx->q, d) : dispatch<XF_W_S4, false>(ctx->q, d); break;
    case XF_W_S2: st = d.a16 ? dispatch<XF_W_S2, true>(ctx->q, d) : dispatch<XF_W_S2, false>(ctx->q, d); break;
    case XF_W_S8: st = dispatch<XF_W_S8, false>(ctx->q, d); break;
    case XF_W_BF16: st = dispatch<XF_W_BF16, false>(ctx->q, d); break;
    case XF_W_S4_EXP8: st = dispatch<XF_W_S4_EXP8, false>(ctx->q, d); break;
    default: xf_set_error("xf_gemm: weight format not implemented"); return XF_ERR_INVALID;
    }
    if (st != XF_OK) return st;
    if (d.segs > 1) {
      const int tpt = d.tokens_per_thread;
      const size_t mpad = (size_t(d.m) + tpt - 1) / tpt * tpt;
      combine(ctx->q, d.ypart, d.y, mpad * size_t(d.rows), d.segs);
    }
    return XF_OK;
  });
}
