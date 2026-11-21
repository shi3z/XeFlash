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
#include <cstdlib>
#include <cstring>
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

template <> struct Fmt<XF_W_S3> {
  static constexpr int tile_cols = 32, stored_dw = 48, opnd_dw = 64;
  static constexpr bool is_float = false;
};

// S3P: 3-bit codes in 4-bit nibble registers that carry their own fourth register: per tile three registers r0..r2 [lane] where nibble i of rx holds the low 3 bits of the
// code of column 8x+i and bit 3 holds bit x of the code of column 24+i. The u4 operand is r0 & 0x77777777, r1 & ..., r2 & ..., and
// r3 = ((r0 >> 3) & 0x11111111) | ((r1 >> 2) & 0x22222222) | ((r2 >> 1) & 0x44444444): 9 instructions of 16 lanes per tile (the generic spread needs about 32) and the same
// number of DPAS as the 4-bit format. Memory: per 16-row block super-tiles of 4 tiles, 768 bytes = three 256-byte loads, [tile][x][lane].
template <> struct Fmt<XF_W_S3P> {
  static constexpr int tile_cols = 32, stored_dw = 48, opnd_dw = 64;
  static constexpr bool is_float = false;
};
ESIMD_INLINE simd<int32_t, 64> expand_s3p(simd<int32_t, 48> p) SYCL_ESIMD_FUNCTION {
  simd<uint32_t, 48> v = p.template bit_cast_view<uint32_t>();
  simd<uint32_t, 64> o;
  o.template select<48, 1>(0) = v & 0x77777777u;
  simd<uint32_t, 16> r0 = v.template select<16, 1>(0), r1 = v.template select<16, 1>(16), r2 = v.template select<16, 1>(32);
  o.template select<16, 1>(48) = ((r0 >> 3) & 0x11111111u) | ((r1 >> 2) & 0x22222222u) | ((r2 >> 1) & 0x44444444u);
  return o.template bit_cast_view<int32_t>();
}

// Packed 3-bit tile (3 registers: per lane a 96-bit stream of 32 unsigned
// codes) -> u4 tile (4 registers), entirely in GRF. Codes are offset binary,
// so no sign extension is needed; the offset is folded into the token offset.
ESIMD_INLINE simd<int32_t, 64> expand_s3_to_u4(simd<int32_t, 48> p) SYCL_ESIMD_FUNCTION {
  auto v = p.template bit_cast_view<uint32_t>();
  simd<uint32_t, 16> d0 = v.template select<16, 1>(0);
  simd<uint32_t, 16> d1 = v.template select<16, 1>(16);
  simd<uint32_t, 16> d2 = v.template select<16, 1>(32);
  // Four 24-bit groups (8 codes each) per lane; the top byte is masked below.
  simd<uint32_t, 64> g;
  g.template select<16, 1>(0) = d0;
  g.template select<16, 1>(16) = (d0 >> 24) | (d1 << 8);
  g.template select<16, 1>(32) = (d1 >> 16) | (d2 << 16);
  g.template select<16, 1>(48) = d2 >> 8;
  // 8 x 3 bits -> 8 x 4 bits: spread by 12, then 6, then 3 bits. Written on
  // the whole tile so the compiler emits 32-lane instructions.
  simd<uint32_t, 64> y = (g & 0x000FFFu) | ((g & 0xFFF000u) << 4);
  simd<uint32_t, 64> z = (y & 0x003F003Fu) | ((y & 0x0FC00FC0u) << 2);
  simd<uint32_t, 64> o = (z & 0x07070707u) | ((z & 0x38383838u) << 1);
  return o.template bit_cast_view<int32_t>();
}

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

// Stored tile -> DPAS weight operand. Identity for the native formats.
template <int WF>
ESIMD_INLINE simd<int32_t, Fmt<WF>::opnd_dw> operand(simd<int32_t, Fmt<WF>::stored_dw> w) SYCL_ESIMD_FUNCTION {
  if constexpr (WF == XF_W_S3) return expand_s3_to_u4(w);
  else if constexpr (WF == XF_W_S4_EXP8) return expand_s4_to_s8(w);
  else return w;
}

template <int WF, int R>
ESIMD_INLINE simd<int32_t, 16 * R> mac(simd<int32_t, 16 * R> acc, simd<int32_t, Fmt<WF>::opnd_dw> w,
                                       simd<int32_t, 8 * R> a, bool a_unsigned) SYCL_ESIMD_FUNCTION {
  constexpr PT WP = WF == XF_W_S4 ? PT::s4 : WF == XF_W_S2 ? PT::s2 : (WF == XF_W_S3 || WF == XF_W_S3P) ? PT::u4 : PT::s8;
  if (a_unsigned) return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, WP, PT::u8>(acc, w, a);
  return xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, WP, PT::s8>(acc, w, a);
}

// int32 accumulators -> scaled float output. Shared by the direct path and by
// the segment combiner so both produce bit-identical results:
//   y = (acc [* 256 + acc_lo] + token_offset) * row_scale * token_scale + row_bias
template <bool A16>
ESIMD_INLINE simd<float, 16> finish(simd<int32_t, 16> si, simd<int32_t, 16> li, simd<float, 16> rsv, float ts,
                                    float off, simd<float, 16> bias) SYCL_ESIMD_FUNCTION {
  simd<float, 16> f = convert<float>(si);
  if constexpr (A16) f = f * 256.0f + convert<float>(li);
  f = f + off;
  return f * rsv * ts + bias;
}

// PIPE: software-pipelined integer loop: the weight / activation tiles of the next U tiles are requested before the DPAS of the current U tiles
// (two register sets A / B), so that memory requests stay in flight during the arithmetic. Needs cols / tile_cols / segs to be a multiple of 2 * U.
// Work-group size (threads) of the pointer-bumped loop launch: XF_GEMM_WG=0 or 1 gives the previous plain-range launch (runtime-chosen work-group of 32).
inline size_t wg_size() {
  static const size_t w = std::getenv("XF_GEMM_WG") ? size_t(std::atoi(std::getenv("XF_GEMM_WG"))) : size_t(4);
  return w;
}
// Experiment only: work-group size for the 1-row-per-thread kernel (XF_GEMM_WG_M1, default 0 = plain launch, which is the fastest for 1 row).
inline size_t wg1_size() {
  static const size_t w = std::getenv("XF_GEMM_WG_M1") ? size_t(std::atoi(std::getenv("XF_GEMM_WG_M1"))) : size_t(0);
  return w;
}
// Experiment only: work-group size for the 32-rows-per-thread kernel (XF_GEMM_WG32, default 0 = plain launch, the runtime picks 32 threads).
inline size_t wg32_size() {
  static const size_t w = std::getenv("XF_GEMM_WG32") ? size_t(std::atoi(std::getenv("XF_GEMM_WG32"))) : size_t(0);
  return w;
}
// PIPE: 0 = plain loop, 1 = software-pipelined loop with every tile address recomputed from the 64-bit tile index (the previous production loop),
//       2 = software-pipelined loop with pointer-bumped addresses: all addresses are formed once before the loop and every tile load adds a constant
//           (weights) or the activation stride to a running pointer; 32-bit loop counters and thread index (no 64-bit multiply, division or modulo in the loop).
//           The caller guarantees the 32-bit ranges (addr32_ok); the pointers themselves stay 64-bit.
template <int WF, int R, int G, int U, bool A16, int PIPE = 0> sycl::event submit(sycl::queue &q, const xf_gemm_desc &d) {
  using F = Fmt<WF>;
  constexpr int TPT = R * G;
  constexpr int WDW = F::stored_dw;
  constexpr int XDW = 8 * TPT; // activation dwords per tile per thread

  const int32_t *W = static_cast<const int32_t *>(d.w);
  const int32_t *X = static_cast<const int32_t *>(d.x);
  const int32_t *XL = static_cast<const int32_t *>(d.xlo);
  const float *RS = d.rs;
  const float *TS = d.ts;
  constexpr float OFFMUL = (WF == XF_W_S3 || WF == XF_W_S3P) ? -7.0f : 1.0f; // see combine_int
  const float *TO = d.toff;
  const float *RB = d.bias;
  const size_t rows = d.rows;
  const size_t rowblks = rows / 16;
  const size_t tiles = size_t(d.cols) / F::tile_cols;
  const size_t segs = d.segs;
  const size_t tps = tiles / segs; // tiles per segment
  const size_t mpad = (size_t(d.m) + TPT - 1) / TPT * TPT;
  const size_t tgroups = mpad / TPT;
  float *YF = static_cast<float *>(d.ypart);     // float partials (bf16) when segs > 1
  int32_t *YI = static_cast<int32_t *>(d.ypart); // exact integer partials when segs > 1
  float *Y = segs == 1 ? d.y : YF;
  constexpr size_t PLANES = A16 ? 2 : 1;

  // The thread body is shared by the two launch forms below. A plain range lets the runtime pick a work-group of 32 threads; a work-group cannot span Xe cores, so a launch of 320
  // threads (the 5,120-row matrices) filled only about half of the 20 cores. PIPE == 2 launches small work-groups (XF_GEMM_WG threads, default 4) which the dispatcher spreads over all cores.
  const auto run = [=](const size_t gid) SYCL_ESIMD_FUNCTION {
    size_t rb, tg, seg;
    if constexpr (PIPE == 2) {
      if (segs == 1 && tgroups == 1) { // every engine shape at 1 / 8 / 16 tokens: the thread index is the row block
        rb = uint32_t(gid);
        tg = 0;
        seg = 0;
      } else { // 32-bit index arithmetic (the thread count is below 2^31, checked by addr32_ok)
        const uint32_t i32 = uint32_t(gid), rq = uint32_t(rowblks), tq = uint32_t(tgroups);
        // token groups of one row block are adjacent threads: they read the same weight tiles at about the same time (cache hits); for one group (every shape up to 16 rows) this is the old order
        tg = i32 % tq;
        rb = (i32 / tq) % rq;
        seg = i32 / (rq * tq);
      }
    } else {
      const size_t idx = gid;
      rb = idx % rowblks;
      tg = (idx / rowblks) % tgroups;
      seg = idx / (rowblks * tgroups);
    }

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

      if constexpr (PIPE == 2 && WF == XF_W_S3P) {
        // Super-tiles of 4 tiles, NS = 4 / U stages of U tiles. Weights are prefetched two super-tiles ahead (buffers 0 / 1, 12 registers each, three 256-byte loads per
        // super-tile): a 3-bit thread holds only 768 bytes per super-tile, so with a one-super-tile prefetch it keeps 25% fewer bytes in flight than the 4-bit loop and the
        // memory latency, not the bandwidth, limits it. Activations (served from the cache) are prefetched one stage ahead as in the other loops.
        static_assert(U == 1 || U == 2, "S3P: one or two tiles per stage");
        constexpr int NS = 4 / U;
        simd<int32_t, 64> pw[2][3]; // the 192 dwords of a super-tile in three 256-byte loads: tile j = dwords 48 j .. 48 j + 47
        simd<int32_t, XDW> xs[2][U], xls[2][U];
        const int32_t *wq = wp, *xq = X + xoff, *xlq = XL + xoff;
#define XF_S3P_W(B)                                                                   \
  pw[B][0].copy_from(wq);                                                             \
  pw[B][1].copy_from(wq + 64);                                                        \
  pw[B][2].copy_from(wq + 128);                                                       \
  wq += 192;
#define XF_S3P_ACT(PAR)                                                               \
  _Pragma("unroll") for (int u = 0; u < U; u++) {                                    \
    xs[PAR][u].copy_from(xq);                                                         \
    xq += xstride;                                                                    \
    if constexpr (A16) {                                                              \
      xls[PAR][u].copy_from(xlq);                                                     \
      xlq += xstride;                                                                 \
    }                                                                                 \
  }
        // tile j = dwords 48 j .. 48 j + 47 of the super-tile = pieces of the three load registers (j = 0: p0[0,48); 1: p0[48,64)+p1[0,32); 2: p1[32,64)+p2[0,16); 3: p2[16,64))
#define XF_S3P_TILE(B, J)                                                             \
  if ((J) == 0) tj = pw[B][0].template select<48, 1>(0);                              \
  else if ((J) == 1) {                                                                \
    tj.template select<16, 1>(0) = pw[B][0].template select<16, 1>(48);               \
    tj.template select<32, 1>(16) = pw[B][1].template select<32, 1>(0);              \
  } else if ((J) == 2) {                                                              \
    tj.template select<32, 1>(0) = pw[B][1].template select<32, 1>(32);              \
    tj.template select<16, 1>(32) = pw[B][2].template select<16, 1>(0);              \
  } else tj = pw[B][2].template select<48, 1>(16);
        // one super-tile out of buffer B; NEXT: whether a following super-tile exists (its first activation stage is requested during the last stage)
#define XF_S3P_SUPER(B, NEXT)                                                         \
  _Pragma("unroll") for (int k = 0; k < NS; k++) {                                   \
    if (k + 1 < NS) {                                                                 \
      XF_S3P_ACT((k + 1) & 1)                                                         \
    } else if (NEXT) {                                                                \
      XF_S3P_ACT(0)                                                                   \
    }                                                                                 \
    _Pragma("unroll") for (int u = 0; u < U; u++) {                                  \
      const int j = k * U + u;                                                        \
      simd<int32_t, 48> tj;                                                           \
      XF_S3P_TILE(B, j)                                                               \
      simd<int32_t, 64> hj = expand_s3p(tj);                                          \
      _Pragma("unroll") for (int g = 0; g < G; g++) {                                \
        simd<int32_t, 8 * R> a = xs[k & 1][u].template select<8 * R, 1>(g * 8 * R);  \
        acc[u][g] = mac<WF, R>(acc[u][g], hj, a, false);                         \
      }                                                                               \
      if constexpr (A16) {                                                            \
        _Pragma("unroll") for (int g = 0; g < G; g++) {                              \
          simd<int32_t, 8 * R> a = xls[k & 1][u].template select<8 * R, 1>(g * 8 * R); \
          accl[u][g] = mac<WF, R>(accl[u][g], hj, a, true);                      \
        }                                                                             \
      }                                                                               \
    }                                                                                 \
  }
        const uint32_t nst = uint32_t(tps) / 4;
        XF_S3P_W(0)
        if (nst > 1) {
          XF_S3P_W(1)
        }
        XF_S3P_ACT(0)
        for (uint32_t st = 0; st < nst; st += 2) {
          XF_S3P_SUPER(0, st + 1 < nst)
          if (st + 2 < nst) {
            XF_S3P_W(0)
          }
          if (st + 1 < nst) {
            XF_S3P_SUPER(1, st + 2 < nst)
            if (st + 3 < nst) {
              XF_S3P_W(1)
            }
          }
        }
#undef XF_S3P_W
#undef XF_S3P_ACT
#undef XF_S3P_SUPER
#undef XF_S3P_TILE
      } else if constexpr (PIPE == 2) {
        simd<int32_t, WDW> wa[U], wb[U];
        simd<int32_t, XDW> xa[U], xb[U], xla[U], xlb[U];
        const int32_t *wq = wp, *xq = X + xoff, *xlq = XL + xoff;
#define XF_PL3(WV, XV, XLV)                                                           \
  _Pragma("unroll") for (int u = 0; u < U; u++) {                                    \
    WV[u].copy_from(wq);                                                              \
    wq += WDW;                                                                        \
    XV[u].copy_from(xq);                                                              \
    xq += xstride;                                                                    \
    if constexpr (A16) {                                                              \
      XLV[u].copy_from(xlq);                                                          \
      xlq += xstride;                                                                 \
    }                                                                                 \
  }
#define XF_PC3(WV, XV, XLV)                                                           \
  _Pragma("unroll") for (int u = 0; u < U; u++) {                                    \
    simd<int32_t, F::opnd_dw> w = operand<WF>(WV[u]);                                \
    _Pragma("unroll") for (int g = 0; g < G; g++) {                                  \
      simd<int32_t, 8 * R> a = XV[u].template select<8 * R, 1>(g * 8 * R);          \
      acc[u][g] = mac<WF, R>(acc[u][g], w, a, false);                                \
    }                                                                                 \
    if constexpr (A16) {                                                              \
      _Pragma("unroll") for (int g = 0; g < G; g++) {                                \
        simd<int32_t, 8 * R> a = XLV[u].template select<8 * R, 1>(g * 8 * R);       \
        accl[u][g] = mac<WF, R>(accl[u][g], w, a, true);                             \
      }                                                                               \
    }                                                                                 \
  }
        const uint32_t tps32 = uint32_t(tps);
        XF_PL3(wa, xa, xla)
        for (uint32_t t32 = 0; t32 < tps32; t32 += 2 * U) {
          XF_PL3(wb, xb, xlb)
          XF_PC3(wa, xa, xla)
          if (t32 + 2 * U < tps32) XF_PL3(wa, xa, xla)
          XF_PC3(wb, xb, xlb)
        }
#undef XF_PL3
#undef XF_PC3
      } else if constexpr (PIPE == 1) {
        simd<int32_t, WDW> wa[U], wb[U];
        simd<int32_t, XDW> xa[U], xb[U], xla[U], xlb[U];
#define XF_PL(WV, XV, XLV, T)                                         \
  _Pragma("unroll") for (int u = 0; u < U; u++) {                    \
    WV[u].copy_from(wp + ((T) + u) * WDW);                           \
    XV[u].copy_from(X + xoff + ((T) + u) * xstride);                 \
    if constexpr (A16) XLV[u].copy_from(XL + xoff + ((T) + u) * xstride); \
  }
#define XF_PC(WV, XV, XLV)                                                              \
  _Pragma("unroll") for (int u = 0; u < U; u++) {                                        \
    simd<int32_t, F::opnd_dw> w = operand<WF>(WV[u]);                                    \
    _Pragma("unroll") for (int g = 0; g < G; g++) {                                      \
      simd<int32_t, 8 * R> a = XV[u].template select<8 * R, 1>(g * 8 * R);              \
      acc[u][g] = mac<WF, R>(acc[u][g], w, a, false);                                    \
    }                                                                                    \
    if constexpr (A16) {                                                                 \
      _Pragma("unroll") for (int g = 0; g < G; g++) {                                    \
        simd<int32_t, 8 * R> a = XLV[u].template select<8 * R, 1>(g * 8 * R);          \
        accl[u][g] = mac<WF, R>(accl[u][g], w, a, true);                                 \
      }                                                                                  \
    }                                                                                    \
  }
        XF_PL(wa, xa, xla, 0)
        for (size_t t = 0; t < tps; t += 2 * U) {
          XF_PL(wb, xb, xlb, t + U)
          XF_PC(wa, xa, xla)
          if (t + 2 * U < tps) XF_PL(wa, xa, xla, t + 2 * U)
          XF_PC(wb, xb, xlb)
        }
#undef XF_PL
#undef XF_PC
      } else
      for (size_t t = 0; t < tps; t += U) {
#pragma unroll
        for (int u = 0; u < U; u++) {
          simd<int32_t, WDW> ws;
          ws.copy_from(wp + (t + u) * WDW);
          simd<int32_t, F::opnd_dw> w = operand<WF>(ws);
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
      simd<float, TPT> tov(0.0f);
      if (TO) tov.copy_from(TO + tg * TPT);
      simd<float, 16> rbv(0.0f);
      if (RB) rbv.copy_from(RB + rb * 16);
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
          simd<int32_t, 16> li = sl.template select<16, 1>(16 * m);
          const size_t tok = tg * TPT + g * R + m;
          if (segs == 1) {
            simd<float, 16> f = finish<A16>(si, li, rsv, float(tsv[g * R + m]), float(tov[g * R + m]) * OFFMUL, rbv);
            f.copy_to(Y + tok * rows + rb * 16);
          } else {
            // Exact integer partial sums; the combiner converts and scales.
            si.copy_to(YI + ((seg * PLANES) * mpad + tok) * rows + rb * 16);
            if constexpr (A16) li.copy_to(YI + ((seg * PLANES + 1) * mpad + tok) * rows + rb * 16);
          }
        }
      }
    }
  };
  const size_t nthreads = rowblks * tgroups * segs;
  const size_t wg = PIPE == 2 ? (TPT > 1 ? wg_size() : wg1_size()) : (TPT >= 32 ? wg32_size() : 0); // 1 row per thread: the plain launch is fastest (50 against 56 us for the out projection)
  if (wg > 1 && nthreads % wg == 0)
    return q.parallel_for(sycl::nd_range<1>(nthreads, wg), [=](sycl::nd_item<1> it) SYCL_ESIMD_KERNEL { run(it.get_global_id(0)); });
  return q.parallel_for(sycl::range<1>(nthreads), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL { run(id[0]); });
}

// Float formats: sum the per-segment partial outputs into y.
sycl::event combine_float(sycl::queue &q, const float *ypart, float *y, size_t n, size_t segs) {
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

// Integer formats: sum the int32 partials of all segments, then convert and
// scale exactly like the direct path.
template <bool A16> sycl::event combine_int(sycl::queue &q, const xf_gemm_desc &d, size_t mpad) {
  const float offmul = (d.wfmt == XF_W_S3 || d.wfmt == XF_W_S3P) ? -7.0f : 1.0f; // unsigned codes u = q + 4: sum(q x) + 0.5 sum(x) = sum(u x) - 3.5 sum(x), and toff holds 0.5 sum(x)
  const int32_t *YI = static_cast<const int32_t *>(d.ypart);
  float *Y = d.y;
  const float *RS = d.rs;
  const float *TS = d.ts;
  const float *TO = d.toff;
  const float *RB = d.bias;
  const size_t rows = d.rows, rowblks = rows / 16, segs = d.segs;
  constexpr size_t PLANES = A16 ? 2 : 1;
  return q.parallel_for(sycl::range<1>(mpad * rowblks), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t tok = id[0] / rowblks, rb = id[0] % rowblks;
    simd<int32_t, 16> si(0), li(0);
    for (size_t k = 0; k < segs; k++) {
      simd<int32_t, 16> v;
      v.copy_from(YI + ((k * PLANES) * mpad + tok) * rows + rb * 16);
      si += v;
      if constexpr (A16) {
        simd<int32_t, 16> l;
        l.copy_from(YI + ((k * PLANES + 1) * mpad + tok) * rows + rb * 16);
        li += l;
      }
    }
    simd<float, 16> rsv;
    rsv.copy_from(RS + rb * 16);
    simd<float, 1> ts, to(0.0f);
    ts.copy_from(TS + tok);
    if (TO) to.copy_from(TO + tok);
    simd<float, 16> rbv(0.0f);
    if (RB) rbv.copy_from(RB + rb * 16);
    simd<float, 16> f = finish<A16>(si, li, rsv, float(ts[0]), float(to[0]) * offmul, rbv);
    f.copy_to(Y + tok * rows + rb * 16);
  });
}


// ---- Controlled experiment kernel (XF_GEMM_EXP=A..H, s4 + 16-bit activations, 8 tokens per thread): the same thread layout, tile loop and epilogue
// for every mode; only the body of the tile loop changes. Results are meaningless (no combine kernel is run); times are for the main kernel only.
//   A read the weight tiles only         B read + s4 -> s8 expansion (no DPAS)          C weights resident in registers + DPAS, activations from memory
//   D read + DPAS (= the real kernel)    E = D with next-tile loads issued before the DPAS   F = D without activation loads
//   G = D without DPAS (reads W and X)   H = DPAS only, weights and activations in registers
template <int WF, int MODE> sycl::event submit_exp(sycl::queue &q, const xf_gemm_desc &d) {
  using F = Fmt<WF>;
  constexpr int R = 8, U = 2, WDW = F::stored_dw, ODW = F::opnd_dw, XDW = 64;
  const int32_t *W = static_cast<const int32_t *>(d.w), *X = static_cast<const int32_t *>(d.x), *XL = static_cast<const int32_t *>(d.xlo);
  const size_t rows = d.rows, rowblks = rows / 16, tiles = size_t(d.cols) / F::tile_cols, segs = d.segs, tps = tiles / segs;
  const size_t mpad = (size_t(d.m) + 7) / 8 * 8, tgroups = mpad / 8;
  int32_t *YI = d.segs > 1 ? static_cast<int32_t *>(d.ypart) : reinterpret_cast<int32_t *>(d.y);
  const bool multi = d.segs > 1;
  return q.parallel_for(sycl::range<1>(rowblks * tgroups * segs), [=](sycl::id<1> id) SYCL_ESIMD_KERNEL {
    const size_t idx = id[0], rb = idx % rowblks, tg = (idx / rowblks) % tgroups, seg = idx / (rowblks * tgroups);
    const int32_t *wp = W + (rb * tiles + seg * tps) * WDW;
    const size_t xoff = (seg * tps * mpad + tg * 8) * 8, xstride = mpad * 8;
    simd<int32_t, 16 * R> acc[U], accl[U];
#pragma unroll
    for (int u = 0; u < U; u++) acc[u] = accl[u] = 0;
    simd<int32_t, 16> fold(0);
    simd<int32_t, WDW> wreg(0);
    simd<int32_t, XDW> xreg(0), xlreg(0);
    if constexpr (MODE == 2 || MODE == 7) wreg.copy_from(wp);
    if constexpr (MODE == 5 || MODE == 7) {
      xreg.copy_from(X + xoff);
      xlreg.copy_from(XL + xoff);
    }
    auto keep = [&](auto v) SYCL_ESIMD_FUNCTION {
#pragma unroll
      for (int i = 0; i < int(decltype(v)::length); i += 16) fold ^= v.template select<16, 1>(i);
    };
    if constexpr (MODE == 4) {
      simd<int32_t, WDW> wa[U], wb[U];
      simd<int32_t, XDW> xa[U], xb[U], xla[U], xlb[U];
#pragma unroll
      for (int u = 0; u < U; u++) {
        wa[u].copy_from(wp + u * WDW);
        xa[u].copy_from(X + xoff + u * xstride);
        xla[u].copy_from(XL + xoff + u * xstride);
      }
      for (size_t t = 0; t < tps; t += 2 * U) {
#pragma unroll
        for (int u = 0; u < U; u++) {
          wb[u].copy_from(wp + (t + U + u) * WDW);
          xb[u].copy_from(X + xoff + (t + U + u) * xstride);
          xlb[u].copy_from(XL + xoff + (t + U + u) * xstride);
        }
#pragma unroll
        for (int u = 0; u < U; u++) {
          simd<int32_t, ODW> wo = operand<WF>(wa[u]);
          acc[u] = mac<WF, R>(acc[u], wo, xa[u].template select<8 * R, 1>(0), false);
          accl[u] = mac<WF, R>(accl[u], wo, xla[u].template select<8 * R, 1>(0), true);
        }
        if (t + 2 * U < tps) {
#pragma unroll
          for (int u = 0; u < U; u++) {
            wa[u].copy_from(wp + (t + 2 * U + u) * WDW);
            xa[u].copy_from(X + xoff + (t + 2 * U + u) * xstride);
            xla[u].copy_from(XL + xoff + (t + 2 * U + u) * xstride);
          }
        }
#pragma unroll
        for (int u = 0; u < U; u++) {
          simd<int32_t, ODW> wo = operand<WF>(wb[u]);
          acc[u] = mac<WF, R>(acc[u], wo, xb[u].template select<8 * R, 1>(0), false);
          accl[u] = mac<WF, R>(accl[u], wo, xlb[u].template select<8 * R, 1>(0), true);
        }
      }
    } else {
      for (size_t t = 0; t < tps; t += U) {
#pragma unroll
        for (int u = 0; u < U; u++) {
          simd<int32_t, WDW> ws = wreg;
          if constexpr (MODE == 0 || MODE == 1 || MODE == 3 || MODE == 5 || MODE == 6) ws.copy_from(wp + (t + u) * WDW);
          if constexpr (MODE == 0) {
            keep(ws);
          } else if constexpr (MODE == 1) {
            simd<int32_t, ODW> w8 = operand<WF>(ws);
#pragma unroll
            for (int i = 0; i < ODW; i += 16) fold ^= w8.template select<16, 1>(i);
          } else {
            simd<int32_t, XDW> xv = xreg, xl = xlreg;
            if constexpr (MODE == 2 || MODE == 3 || MODE == 6) {
              xv.copy_from(X + xoff + (t + u) * xstride);
              xl.copy_from(XL + xoff + (t + u) * xstride);
            }
            if constexpr (MODE == 6) {
              keep(ws);
              keep(xv);
              keep(xl);
            } else {
              simd<int32_t, ODW> wo = operand<WF>(ws);
              acc[u] = mac<WF, R>(acc[u], wo, xv.template select<8 * R, 1>(0), false);
              accl[u] = mac<WF, R>(accl[u], wo, xl.template select<8 * R, 1>(0), true);
            }
          }
        }
      }
    }
    simd<int32_t, 16 * R> s = acc[0] + acc[1], sl = accl[0] + accl[1];
#pragma unroll
    for (int m = 0; m < R; m++) {
      simd<int32_t, 16> si = s.template select<16, 1>(16 * m) ^ fold, li = sl.template select<16, 1>(16 * m);
      const size_t tok = tg * 8 + m;
      if (multi) {
        si.copy_to(YI + ((seg * 2) * mpad + tok) * rows + rb * 16);
        li.copy_to(YI + ((seg * 2 + 1) * mpad + tok) * rows + rb * 16);
      } else {
        (si ^ li).copy_to(YI + tok * rows + rb * 16);
      }
    }
  });
}

// Which integer loop: 0 plain, 1 pipelined with per-tile 64-bit address arithmetic, 2 pipelined with pointer-bumped addresses (default).
// XF_GEMM_PIPE=0 -> 0; XF_GEMM_ADDR=old -> 1 (switch back to the previous loop without rebuilding).
bool pipe_mode() {
  static const bool on = !(std::getenv("XF_GEMM_PIPE") && std::getenv("XF_GEMM_PIPE")[0] == '0'); // default on; XF_GEMM_PIPE=0 = the previous loop
  return on;
}
bool addr_new() {
  static const bool on = !(std::getenv("XF_GEMM_ADDR") && std::strcmp(std::getenv("XF_GEMM_ADDR"), "old") == 0);
  return on;
}
int pipe_u() {
  static const int u = std::getenv("XF_GEMM_PU") ? std::atoi(std::getenv("XF_GEMM_PU")) : 2;
  return u == 1 ? 1 : 2;
}
// How 16-bit-activation passes of 32 rows run (default "split"): "old" = plain 4-group loop, "pipe" = pipelined 4-group loop, "split" = the 16-row pipelined kernel for two token groups with the groups adjacent (XF_GEMM_A16_32).
int a16_32_mode() {
  static const int m = [] { const char *e = std::getenv("XF_GEMM_A16_32"); return !e ? 2 : !std::strcmp(e, "pipe") ? 1 : !std::strcmp(e, "old") ? 0 : 2; }();
  return m;
}
bool p32_on() {
  static const bool on = !(std::getenv("XF_GEMM_P32") && std::getenv("XF_GEMM_P32")[0] == '0');
  return on;
}
constexpr bool F_IS_FLOAT(int wf) { return wf == XF_W_BF16; }

// The 32-bit quantities of the pointer-bumped loop: the thread index (rowblks * tgroups * segs), the tile counters (tiles) and the per-trip tile count.
// Weight / activation addresses are 64-bit pointers (the base is formed in 64-bit arithmetic once per thread, the loop only adds constants or the stride),
// so tensor sizes do not enter any 32-bit computation. Largest case in the model: head 248,320 x 5,120: 15,520 threads, 160 tiles; limits below are 2^31.
bool addr32_ok(const xf_gemm_desc &d, int tpt) {
  const uint64_t rowblks = uint64_t(d.rows) / 16, segs = uint64_t(d.segs);
  const uint64_t mpad = (uint64_t(d.m) + tpt - 1) / tpt * tpt, tgroups = mpad / tpt;
  const uint64_t tiles = uint64_t(d.cols) / (d.wfmt == XF_W_BF16 ? 16 : 32);
  return rowblks * tgroups * segs < (1ull << 31) && tiles < (1ull << 30) && tiles * mpad * 8 < (1ull << 31) && rowblks < (1ull << 20) && tgroups < (1ull << 10) && segs < (1ull << 10);
}
// pipe kind for this call: 2 pointer-bumped (default), 1 per-tile 64-bit addresses, 0 plain; float formats and s8 + 16-bit activations stay plain
int pipe_kind(const xf_gemm_desc &d, int tpt) {
  if (!pipe_mode()) return 0;
  if (!addr_new() || !addr32_ok(d, tpt)) return 1;
  return 2;
}

template <int WF, bool A16> int dispatch(sycl::queue &q, const xf_gemm_desc &d) {
  if constexpr (WF == XF_W_S3P) {
    // only the pointer-bumped pipelined loop exists for this format (4 tiles per super-tile; U tiles per stage)
    if (pipe_kind(d, d.tokens_per_thread) != 2) {
      xf_set_error("xf_gemm: s3p needs the pipelined 32-bit-address loop");
      return XF_ERR_INVALID;
    }
    switch (d.tokens_per_thread) {
    case 1: submit<WF, 1, 1, 2, A16, 2>(q, d); return XF_OK;
    case 8: submit<WF, 8, 1, 2, A16, 2>(q, d); return XF_OK;
    case 16: submit<WF, 8, 2, 1, A16, 2>(q, d); return XF_OK;
    }
    xf_set_error("xf_gemm: s3p supports 1, 8 or 16 tokens per thread");
    return XF_ERR_INVALID;
  } else
  switch (d.tokens_per_thread) {
  case 1: {
    // s8 with 16-bit activations and four tiles per trip (32 weight registers
    // plus two activation planes) never finishes on the B60: the kernel spins
    // at full clock. One tile per trip is fine. Observed, not understood; see
    // docs/EXPERIMENTS.md.
    const int pk = (F_IS_FLOAT(WF) || WF == XF_W_S8) ? 0 : pipe_kind(d, 1);
    if constexpr (WF == XF_W_S8 && A16) submit<WF, 1, 1, 1, A16>(q, d);
    else if (pk == 2) submit<WF, 1, 1, 2, A16, 2>(q, d);
    else if (pk == 1) submit<WF, 1, 1, 2, A16, 1>(q, d);
    else submit<WF, 1, 1, 4, A16>(q, d);
    return XF_OK;
  }
  case 8: {
    const int pk = F_IS_FLOAT(WF) ? 0 : pipe_kind(d, 8);
    if (pk == 2) {
      if (pipe_u() == 1) submit<WF, 8, 1, 1, A16, 2>(q, d);
      else submit<WF, 8, 1, 2, A16, 2>(q, d);
    } else if (pk == 1) {
      if (pipe_u() == 1) submit<WF, 8, 1, 1, A16, 1>(q, d);
      else submit<WF, 8, 1, 2, A16, 1>(q, d);
    } else submit<WF, 8, 1, 2, A16>(q, d);
    return XF_OK;
  }
  case 16: {
    const int pk = F_IS_FLOAT(WF) ? 0 : pipe_kind(d, 16);
    if (pk == 2) submit<WF, 8, 2, 1, A16, 2>(q, d);
    else if (pk == 1) submit<WF, 8, 2, 1, A16, 1>(q, d);
    else submit<WF, 8, 2, 1, A16>(q, d);
    return XF_OK;
  }
  case 32: {
    // 32 rows per thread: the software-pipelined, pointer-bumped loop (XF_GEMM_P32=0 restores the plain loop)
    const int pk = F_IS_FLOAT(WF) ? 0 : pipe_kind(d, 32);
    if (pk == 2 && p32_on() && !A16) submit<WF, 8, 4, 1, A16, 2>(q, d);
    else if (pk == 2 && p32_on() && A16 && a16_32_mode() == 1) submit<WF, 8, 4, 1, A16, 2>(q, d);
    else if (pk == 2 && p32_on() && A16 && a16_32_mode() == 2) {
      // The activation tiles are laid out for a pad of 32 tokens (tokens_per_thread == 32), the 16-token kernel pads to 16: give it the padded count (rows 33..48 would otherwise stride wrongly)
      xf_gemm_desc d2 = d;
      d2.m = (d.m + 31) / 32 * 32;
      submit<WF, 8, 2, 1, A16, 2>(q, d2);
    }
    else submit<WF, 8, 4, 1, A16>(q, d);
    return XF_OK;
  }
  }
  xf_set_error("xf_gemm: tokens_per_thread must be 1, 8, 16 or 32");
  return XF_ERR_INVALID;
}

int unroll_of(int tpt, int wfmt = 0) {
  if (wfmt == XF_W_S3P) return 4; // one super-tile per trip
  if (pipe_mode()) return tpt == 8 ? 2 * pipe_u() : tpt == 16 ? 2 : tpt == 1 ? 4 : (tpt == 32 && p32_on()) ? 2 : 1; // the pipelined loop handles 2 * U tiles per trip
  return tpt == 1 ? 4 : tpt == 8 ? 2 : 1;
}

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
  if (d.cols % (tc * unroll_of(d.tokens_per_thread, d.wfmt) * d.segs) != 0) {
    xf_set_error("xf_gemm: cols must be a multiple of tile_cols * unroll * segs");
    return XF_ERR_INVALID;
  }
  if (const char *ex = std::getenv("XF_GEMM_EXP"); ex && d.a16 && d.tokens_per_thread == 8 && (d.wfmt == XF_W_S4 || d.wfmt == XF_W_S3 || d.wfmt == XF_W_S4_EXP8)) {
#define XF_EXP(M) { if (d.wfmt == XF_W_S3) submit_exp<XF_W_S3, M>(ctx->q, d); else if (d.wfmt == XF_W_S4_EXP8) submit_exp<XF_W_S4_EXP8, M>(ctx->q, d); else submit_exp<XF_W_S4, M>(ctx->q, d); return XF_OK; }
    switch (ex[0]) {
    case 'A': XF_EXP(0)
    case 'B': XF_EXP(1)
    case 'C': XF_EXP(2)
    case 'D': XF_EXP(3)
    case 'E': XF_EXP(4)
    case 'F': XF_EXP(5)
    case 'G': XF_EXP(6)
    case 'H': XF_EXP(7)
    }
#undef XF_EXP
  }
  return xf_guard("xf_gemm", [&]() -> int {
    int st = XF_ERR_INVALID;
    switch (d.wfmt) {
    case XF_W_S4: st = d.a16 ? dispatch<XF_W_S4, true>(ctx->q, d) : dispatch<XF_W_S4, false>(ctx->q, d); break;
    case XF_W_S2: st = d.a16 ? dispatch<XF_W_S2, true>(ctx->q, d) : dispatch<XF_W_S2, false>(ctx->q, d); break;
    case XF_W_S8: st = d.a16 ? dispatch<XF_W_S8, true>(ctx->q, d) : dispatch<XF_W_S8, false>(ctx->q, d); break;
    case XF_W_BF16: st = dispatch<XF_W_BF16, false>(ctx->q, d); break;
    case XF_W_S4_EXP8: st = dispatch<XF_W_S4_EXP8, false>(ctx->q, d); break;
    case XF_W_S3P: st = d.a16 ? dispatch<XF_W_S3P, true>(ctx->q, d) : dispatch<XF_W_S3P, false>(ctx->q, d); break;
    case XF_W_S3: st = d.a16 ? dispatch<XF_W_S3, true>(ctx->q, d) : dispatch<XF_W_S3, false>(ctx->q, d); break;
    default: xf_set_error("xf_gemm: weight format not implemented"); return XF_ERR_INVALID;
    }
    if (st != XF_OK) return st;
    if (d.segs > 1) {
      const int tpt = d.tokens_per_thread;
      const size_t mpad = (size_t(d.m) + tpt - 1) / tpt * tpt;
      if (d.wfmt == XF_W_BF16) combine_float(ctx->q, static_cast<const float *>(d.ypart), d.y, mpad * size_t(d.rows), d.segs);
      else if (d.a16) combine_int<true>(ctx->q, d, mpad);
      else combine_int<false>(ctx->q, d, mpad);
    }
    return XF_OK;
  });
}
