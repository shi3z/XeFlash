// gemm_modes (derived from gemm_variants):  experimental copies of the 8/16-token s4 GEMM loop (NOT the production kernel) that share libxfk's queue, so that their outputs and times
// can be set directly against xf_gemm on the same buffers. Parameters swept per shape:
//   U      tiles per stage (software pipeline of 2 stages)        RB    row blocks (16 rows each) per thread: the activation tiles are loaded once for RB blocks
//   SEG    column segments (K split; partial int32 sums + combine kernel as in production)     LOCAL  work-group size (threads per work-group; 0 = plain range)
//   ADDR   0 = pointers advanced by constants (32-bit trip increments), 1 = production style (64-bit multiplies from run-time strides every tile)
// Output y[token][row] = (si * 256 + li + offset) * row_scale * token_scale (exactly production's finish); compared bit for bit with xf_gemm.
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <vector>
#include "../ctx.hpp"
using namespace sycl;
using namespace sycl::ext::intel::esimd;
namespace xmx = sycl::ext::intel::esimd::xmx;
namespace es = sycl::ext::intel::esimd;
using PT = xmx::dpas_argument_type;

struct Args {
  const int32_t *W, *X, *XL;
  const float *RS, *TS, *TO;
  float *Y;
  int32_t *YP;
  size_t rows, tiles, segs, mpad;
};

// MODE 0 full (W + X + XL loads, DPAS)       1 weights read only            2 all loads (W, X, XL), no DPAS
//      3 DPAS only (operands in registers)   4 weights read + DPAS, activations resident in registers
// Same thread layout, tile loop (2-stage software pipeline, pointer-bumped 32-bit addressing = the new production loop) and epilogue as xf_gemm; outputs of modes 1-4 are meaningless.
template <int R, int G, int U, int MODE, bool MULTI>
static void body(const Args &a, size_t idx) {
  constexpr int WDW = 64, TPT = R * G, XDW = 8 * TPT;
  const uint32_t rbq32 = uint32_t(a.rows / 16);
  const size_t rbi = MULTI ? uint32_t(idx) % rbq32 : uint32_t(idx), seg = MULTI ? uint32_t(idx) / rbq32 : 0u;
  const uint32_t tps32 = uint32_t(a.tiles) / uint32_t(a.segs);
  const size_t xstride = a.mpad * 8;
  simd<int32_t, 16 * R> acc[U][G], accl[U][G];
#pragma unroll
  for (int u = 0; u < U; u++)
#pragma unroll
    for (int g = 0; g < G; g++) acc[u][g] = accl[u][g] = 0;
  const int32_t *wq = a.W + (rbi * a.tiles + seg * tps32) * WDW;
  const size_t xoff = seg * tps32 * xstride;
  const int32_t *xq = a.X + xoff, *xlq = a.XL + xoff;
  simd<int32_t, WDW> wa[U], wb[U];
  simd<int32_t, XDW> xa[U], xb[U], xla[U], xlb[U];
  simd<int32_t, 16> fold(0);
  constexpr bool LW = MODE == 0 || MODE == 1 || MODE == 2 || MODE == 4, LX = MODE == 0 || MODE == 2, DP = MODE == 0 || MODE == 3 || MODE == 4;
#define KEEP(V) { _Pragma("unroll") for (int i = 0; i < int(std::remove_reference_t<decltype(V)>::length); i += 16) fold ^= V.template select<16, 1>(i); }
  if constexpr (!LW) { for (int u = 0; u < U; u++) { wa[u].copy_from(wq + u * WDW); wb[u] = wa[u] + 1; } }
  if constexpr (!LX) {
    for (int u = 0; u < U; u++) { xa[u].copy_from(xq + u * xstride); xla[u].copy_from(xlq + u * xstride); xb[u] = xa[u] + 1; xlb[u] = xla[u] + 1; }
  }
#define LD(WV, XV, XLV)                                          \
  _Pragma("unroll") for (int u = 0; u < U; u++) {               \
    if constexpr (LW) { WV[u].copy_from(wq); wq += WDW; }        \
    if constexpr (LX) { XV[u].copy_from(xq); XLV[u].copy_from(xlq); xq += xstride; xlq += xstride; } \
  }
#define MM(WV, XV, XLV)                                          \
  _Pragma("unroll") for (int u = 0; u < U; u++) {               \
    if constexpr (DP) {                                          \
      _Pragma("unroll") for (int g = 0; g < G; g++) {            \
        acc[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc[u][g], WV[u], simd<int32_t, 8 * R>(XV[u].template select<8 * R, 1>(g * 8 * R))); \
        accl[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(accl[u][g], WV[u], simd<int32_t, 8 * R>(XLV[u].template select<8 * R, 1>(g * 8 * R))); \
      }                                                          \
    } else {                                                     \
      if constexpr (LW) KEEP(WV[u]) if constexpr (LX) { KEEP(XV[u]) KEEP(XLV[u]) } \
    }                                                            \
  }
  LD(wa, xa, xla)
  for (uint32_t t32 = 0; t32 < tps32; t32 += 2 * U) {
    LD(wb, xb, xlb)
    MM(wa, xa, xla)
    if (t32 + 2 * U < tps32) { LD(wa, xa, xla) }
    MM(wb, xb, xlb)
  }
#undef LD
#undef MM
  const size_t rb = rbi;
  simd<float, 16> rsv; rsv.copy_from(a.RS + rb * 16);
#pragma unroll
  for (int g = 0; g < G; g++) {
    simd<int32_t, 16 * R> s = acc[0][g], sl = accl[0][g];
#pragma unroll
    for (int u = 1; u < U; u++) { s += acc[u][g]; sl += accl[u][g]; }
#pragma unroll
    for (int m = 0; m < R; m++) {
      simd<int32_t, 16> si = s.template select<16, 1>(16 * m), li = sl.template select<16, 1>(16 * m);
      if constexpr (!DP) { si = fold; li = fold; } else { si ^= fold; }
      const size_t tok = g * R + m;
      if constexpr (MULTI) {
        si.copy_to(a.YP + ((seg * 2) * a.mpad + tok) * a.rows + rb * 16);
        li.copy_to(a.YP + ((seg * 2 + 1) * a.mpad + tok) * a.rows + rb * 16);
      } else {
        simd<float, 16> f = convert<float>(si);
        f = f * 256.0f + convert<float>(li);
        f = f + float(a.TO[tok]);
        f = f * rsv * float(a.TS[tok]);
        f.copy_to(a.Y + tok * a.rows + rb * 16);
      }
    }
  }
}

template <int R, int G, int U, int MODE, bool MULTI>
static void launch(queue &q, const Args &a) {
  const size_t n = a.rows / 16 * a.segs;
  q.parallel_for(range<1>(n), [=](id<1> id) SYCL_ESIMD_KERNEL { body<R, G, U, MODE, MULTI>(a, id[0]); });
}

#include "../include/xfk.h"
int main(int argc, char **argv) {
  const int rows = argc > 1 ? atoi(argv[1]) : 34816, cols = argc > 2 ? atoi(argv[2]) : 5120, m = argc > 3 ? atoi(argv[3]) : 8;
  const bool narrow = argc > 4 ? atoi(argv[4]) : (rows < 8192);
  xf_ctx *ctx = nullptr;
  if (xf_ctx_create(&ctx)) { printf("no device\n"); return 1; }
  queue &q = ctx->q;
  const size_t bytes = size_t(rows) * cols / 2, nbuf = std::max<size_t>(2, (400u << 20) / bytes);
  std::mt19937_64 rng(3);
  std::vector<uint32_t> h(bytes / 4);
  std::vector<int32_t *> W;
  for (size_t b = 0; b < nbuf; b++) {
    for (auto &x : h) x = uint32_t(rng());
    int32_t *p = (int32_t *)xf_alloc(ctx, bytes);
    xf_write(ctx, p, h.data(), bytes);
    W.push_back(p);
  }
  const int tpt = m == 1 ? 1 : m <= 8 ? 8 : 16, mpad = (m + tpt - 1) / tpt * tpt;
  const size_t tiles = cols / 32, xbytes = tiles * mpad * 32;
  std::vector<uint8_t> hx(xbytes);
  for (auto &x : hx) x = uint8_t(rng());
  int32_t *X = (int32_t *)xf_alloc(ctx, xbytes), *XL = (int32_t *)xf_alloc(ctx, xbytes);
  xf_write(ctx, X, hx.data(), xbytes);
  for (auto &x : hx) x = uint8_t(rng());
  xf_write(ctx, XL, hx.data(), xbytes);
  std::vector<float> rs(rows), ts(mpad), to(mpad);
  for (auto &x : rs) x = 0.005f + 0.01f * float(rng() % 100) / 100;
  for (auto &x : ts) x = 0.01f + 0.01f * float(rng() % 100) / 100;
  for (auto &x : to) x = float(int(rng() % 2000)) - 1000.f;
  float *RS = (float *)xf_alloc(ctx, rows * 4), *TS = (float *)xf_alloc(ctx, mpad * 4), *TO = (float *)xf_alloc(ctx, mpad * 4);
  float *Yp = (float *)xf_alloc(ctx, size_t(mpad) * rows * 4), *Yv = (float *)xf_alloc(ctx, size_t(mpad) * rows * 4);
  xf_write(ctx, RS, rs.data(), rows * 4); xf_write(ctx, TS, ts.data(), mpad * 4); xf_write(ctx, TO, to.data(), mpad * 4);
  int32_t *YP = (int32_t *)xf_alloc(ctx, size_t(8) * 2 * mpad * rows * 4);
  auto prod = [&](size_t i, int segs, float *y) {
    xf_gemm_desc d{};
    d.wfmt = XF_W_S4; d.rows = rows; d.cols = cols; d.m = m; d.tokens_per_thread = tpt; d.segs = segs; d.a16 = 1;
    d.w = W[i % nbuf]; d.x = X; d.xlo = XL; d.rs = RS; d.ts = TS; d.y = y; d.ypart = YP; d.toff = TO; d.bias = nullptr;
    return xf_gemm(ctx, &d);
  };
  auto timeit = [&](auto &&fn) {
    for (int i = 0; i < 10; i++) fn(i);
    q.wait();
    const int reps = 150;
    auto t0 = std::chrono::steady_clock::now();
    for (int i = 0; i < reps; i++) fn(i);
    q.wait();
    return std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count() / reps;
  };
  const int pseg = (rows < 8192 && m > 1) ? (cols > 8192 ? 2 : 1) : 1; // the engine's segment count
  const double tprod = timeit([&](size_t i) { prod(i, pseg, Yp); });
  const size_t tpsv = tiles / pseg;
  const double tflop = 2.0 * rows * cols * m;
  printf("== rows=%d cols=%d m=%d segs=%d (%.1f MB weights, %d threads): production xf_gemm %.1f us\n", rows, cols, m, pseg, bytes / 1e6, rows / 16 * pseg, tprod);
  printf("%-34s %9s %9s %9s\n", "mode (main kernel only, no combine)", "us", "GB/s(W)", "TFLOPS(F)");
  auto run_mode = [&](const char *name, auto fn) {
    Args a{W[0], X, XL, RS, TS, TO, Yv, YP, size_t(rows), tiles, size_t(pseg), size_t(mpad)};
    if ((tpsv % 4) != 0) { printf("%-34s tiles/seg not a multiple of 4\n", name); return; }
    const double us = timeit([&](size_t i) { Args b = a; b.W = W[i % nbuf]; fn(b); });
    printf("%-34s %9.1f %9.1f %9.2f\n", name, us, bytes / us / 1e3, tflop / us / 1e6);
  };
#define MODES(RR, GG, UU)                                                                                                       \
  if (pseg == 1) {                                                                                                              \
    run_mode("0 full (W+X+XL loads, DPAS)", [&](const Args &a) { launch<RR, GG, UU, 0, false>(q, a); });                      \
    run_mode("1 weights read only", [&](const Args &a) { launch<RR, GG, UU, 1, false>(q, a); });                              \
    run_mode("2 all loads, no DPAS", [&](const Args &a) { launch<RR, GG, UU, 2, false>(q, a); });                             \
    run_mode("3 DPAS only (registers)", [&](const Args &a) { launch<RR, GG, UU, 3, false>(q, a); });                          \
    run_mode("4 weights read + DPAS (X resident)", [&](const Args &a) { launch<RR, GG, UU, 4, false>(q, a); });               \
  } else {                                                                                                                      \
    run_mode("0 full (W+X+XL loads, DPAS)", [&](const Args &a) { launch<RR, GG, UU, 0, true>(q, a); });                       \
    run_mode("1 weights read only", [&](const Args &a) { launch<RR, GG, UU, 1, true>(q, a); });                               \
    run_mode("2 all loads, no DPAS", [&](const Args &a) { launch<RR, GG, UU, 2, true>(q, a); });                              \
    run_mode("3 DPAS only (registers)", [&](const Args &a) { launch<RR, GG, UU, 3, true>(q, a); });                           \
    run_mode("4 weights read + DPAS (X resident)", [&](const Args &a) { launch<RR, GG, UU, 4, true>(q, a); });                \
  }
  if (m == 1) { MODES(1, 1, 2) }
  else if (m <= 8) { MODES(8, 1, 2) }
  else { MODES(8, 2, 1) }
}
