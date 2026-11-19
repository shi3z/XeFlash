// gemm_variants: experimental copies of the 8/16-token s4 GEMM loop (NOT the production kernel) that share libxfk's queue, so that their outputs and times
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

template <int R, int G, int U, int RB, bool MULTI, int ADDR>
static void body(const Args &a, size_t idx) {
  constexpr int WDW = 64, TPT = R * G, XDW = 8 * TPT;
  const uint32_t rbq32 = uint32_t(a.rows / 16 / RB);
  const uint32_t idx32 = uint32_t(idx);
  const size_t rbq = rbq32, rbi = ADDR >= 2 ? (MULTI ? idx32 % rbq32 : idx32) : idx % rbq, seg = ADDR >= 2 ? (MULTI ? idx32 / rbq32 : 0u) : idx / rbq;
  const size_t tps = ADDR >= 2 ? size_t(uint32_t(a.tiles) / uint32_t(a.segs)) : a.tiles / a.segs, xstride = a.mpad * 8;
  simd<int32_t, 16 * R> acc[RB][U][G], accl[RB][U][G];
#pragma unroll
  for (int r = 0; r < RB; r++)
#pragma unroll
    for (int u = 0; u < U; u++)
#pragma unroll
      for (int g = 0; g < G; g++) acc[r][u][g] = accl[r][u][g] = 0;
  const int32_t *wp[RB];
#pragma unroll
  for (int r = 0; r < RB; r++) wp[r] = a.W + ((rbi * RB + r) * a.tiles + seg * tps) * WDW;
  const size_t xoff = seg * tps * xstride;
  const int32_t *xp = a.X + xoff, *xlp = a.XL + xoff;
  simd<int32_t, WDW> wa[RB][U], wb[RB][U];
  simd<int32_t, XDW> xa[U], xb[U], xla[U], xlb[U];
  // tile (t + u) of the stage: ADDR 0 = base + constant offsets (the pointers move by constants per trip), ADDR 1 = multiplied from the run-time tile index and strides
#define LD(WV, XV, XLV, T)                                                                                   \
  _Pragma("unroll") for (int u = 0; u < U; u++) {                                                           \
    _Pragma("unroll") for (int r = 0; r < RB; r++) {                                                        \
      if constexpr (ADDR == 3) { WV[r][u].copy_from(wq[r]); wq[r] += WDW; }                                 \
      else if constexpr (ADDR != 1) WV[r][u].copy_from(wp[r] + (T - t) * WDW + u * WDW);                   \
      else WV[r][u].copy_from(a.W + ((rbi * RB + r) * a.tiles + seg * tps + (T) + u) * size_t(WDW));       \
    }                                                                                                       \
    if constexpr (ADDR == 3) { XV[u].copy_from(xq); XLV[u].copy_from(xlq); xq += xstride; xlq += xstride; } \
    else if constexpr (ADDR != 1) { XV[u].copy_from(xp + (T - t + u) * xstride); XLV[u].copy_from(xlp + (T - t + u) * xstride); } \
    else { XV[u].copy_from(a.X + xoff + ((T) + u) * xstride); XLV[u].copy_from(a.XL + xoff + ((T) + u) * xstride); }       \
  }
#define MM(WV, XV, XLV)                                                                                        \
  _Pragma("unroll") for (int r = 0; r < RB; r++)                                                               \
  _Pragma("unroll") for (int u = 0; u < U; u++)                                                                \
  _Pragma("unroll") for (int g = 0; g < G; g++) {                                                              \
    acc[r][u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc[r][u][g], WV[r][u], simd<int32_t, 8 * R>(XV[u].template select<8 * R, 1>(g * 8 * R)));   \
    accl[r][u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(accl[r][u][g], WV[r][u], simd<int32_t, 8 * R>(XLV[u].template select<8 * R, 1>(g * 8 * R))); \
  }
  const int32_t *wq[RB];
#pragma unroll
  for (int r = 0; r < RB; r++) wq[r] = wp[r];
  const int32_t *xq = xp, *xlq = xlp; // ADDR 3: running pointers, bumped by the stride after every tile load
  size_t t = 0;
  LD(wa, xa, xla, 0)
  if constexpr (ADDR >= 2) {
    const uint32_t tps32 = uint32_t(tps);
    for (uint32_t t32 = 0; t32 < tps32; t32 += 2 * U) {
      t = t32;
      LD(wb, xb, xlb, t + U)
      MM(wa, xa, xla)
      if (t32 + 2 * U < tps32) { LD(wa, xa, xla, t + 2 * U) }
      MM(wb, xb, xlb)
      if constexpr (ADDR == 2) {
#pragma unroll
        for (int r = 0; r < RB; r++) wp[r] += 2 * U * WDW;
        xp += 2 * U * xstride;
        xlp += 2 * U * xstride;
      }
    }
  } else
  for (t = 0; t < tps; t += 2 * U) {
    LD(wb, xb, xlb, t + U)
    MM(wa, xa, xla)
    if (t + 2 * U < tps) { LD(wa, xa, xla, t + 2 * U) }
    MM(wb, xb, xlb)
    if constexpr (ADDR == 0) {
#pragma unroll
      for (int r = 0; r < RB; r++) wp[r] += size_t(2 * U) * WDW;
      xp += size_t(2 * U) * xstride;
      xlp += size_t(2 * U) * xstride;
    }
  }
#undef LD
#undef MM
#pragma unroll
  for (int r = 0; r < RB; r++) {
    const size_t rb = rbi * RB + r;
    simd<float, 16> rsv; rsv.copy_from(a.RS + rb * 16);
#pragma unroll
    for (int g = 0; g < G; g++) {
      simd<int32_t, 16 * R> s = acc[r][0][g], sl = accl[r][0][g];
#pragma unroll
      for (int u = 1; u < U; u++) { s += acc[r][u][g]; sl += accl[r][u][g]; }
#pragma unroll
      for (int m = 0; m < R; m++) {
        simd<int32_t, 16> si = s.template select<16, 1>(16 * m), li = sl.template select<16, 1>(16 * m);
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
}

template <int R, int G, int U, int RB, bool MULTI, int ADDR>
static void launch(queue &q, const Args &a, size_t local) {
  const size_t n = a.rows / 16 / RB * a.segs;
  if (local == 0) q.parallel_for(range<1>(n), [=](id<1> id) SYCL_ESIMD_KERNEL { body<R, G, U, RB, MULTI, ADDR>(a, id[0]); });
  else q.parallel_for(nd_range<1>(n, local), [=](nd_item<1> it) SYCL_ESIMD_KERNEL { body<R, G, U, RB, MULTI, ADDR>(a, it.get_global_id(0)); });
}
// combine of the segment partials (as production: sum the int32 partials, then finish)
static void combine(queue &q, const Args &a, int mt) {
  const size_t rowblks = a.rows / 16, mpad = a.mpad, segs = a.segs;
  q.parallel_for(range<1>(mpad * rowblks), [=](id<1> id) SYCL_ESIMD_KERNEL {
    const size_t tok = id[0] / rowblks, rb = id[0] % rowblks;
    simd<int32_t, 16> si(0), li(0);
    for (size_t k = 0; k < segs; k++) {
      simd<int32_t, 16> x, y;
      x.copy_from(a.YP + ((k * 2) * mpad + tok) * a.rows + rb * 16);
      y.copy_from(a.YP + ((k * 2 + 1) * mpad + tok) * a.rows + rb * 16);
      si += x; li += y;
    }
    simd<float, 16> rsv; rsv.copy_from(a.RS + rb * 16);
    simd<float, 16> f = convert<float>(si);
    f = f * 256.0f + convert<float>(li);
    f = f + float(a.TO[tok]);
    f = f * rsv * float(a.TS[tok]);
    f.copy_to(a.Y + tok * a.rows + rb * 16);
  });
  (void)mt;
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
  if (m == 1) { printf("m=1 not covered by this sweep\n"); return 0; }
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
  const int pseg = narrow ? (cols > 8192 ? 2 : 1) : 1; // the segment count the engine uses for this shape (pipelined loop)
  prod(0, pseg, Yp); q.wait();
  std::vector<float> yref(size_t(mpad) * rows);
  q.memcpy(yref.data(), Yp, yref.size() * 4).wait();
  const double tprod = timeit([&](size_t i) { prod(i, pseg, Yp); });
  printf("== rows=%d cols=%d m=%d (%.1f MB, %d row blocks): production xf_gemm (segs %d): %.1f us\n", rows, cols, m, bytes / 1e6, rows / 16, pseg, tprod);
  printf("%-4s %-3s %-3s %-4s %-5s %9s %7s  %s\n", "U", "RB", "seg", "addr", "local", "us", "vs prod", "output vs xf_gemm");
  struct Res { double us; std::string cfg; };
  std::vector<Res> all;
  auto one = [&](auto run, int U, int RB, int seg, int addr, size_t local) {
    Args a{W[0], X, XL, RS, TS, TO, Yv, YP, size_t(rows), tiles, size_t(seg), size_t(mpad)};
    if ((tiles / seg) % (2 * U) != 0 || (rows / 16) % RB != 0) return;
    q.memset(Yv, 0, size_t(mpad) * rows * 4).wait();
    run(a, 0);
    q.wait();
    std::vector<float> y(size_t(mpad) * rows);
    q.memcpy(y.data(), Yv, y.size() * 4).wait();
    const bool same = std::memcmp(y.data(), yref.data(), y.size() * 4) == 0;
    const double us = timeit([&](size_t i) { Args b = a; b.W = W[i % nbuf]; run(b, 0); });
    char buf[64];
    snprintf(buf, sizeof buf, "U=%d RB=%d seg=%d addr=%d local=%zu", U, RB, seg, addr, local);
    printf("%-4d %-3d %-3d %-4d %-5zu %9.1f %6.0f%%  %s\n", U, RB, seg, addr, local, us, 100 * us / tprod, same ? "bit-identical" : "DIFFERENT");
    all.push_back({us, same ? buf : std::string(buf) + " (output differs)"});
  };
  // sweep (instantiations for m = 8: R=8,G=1; m = 16: R=8,G=2)
#define SWEEP(RR, GG, UU, RBB, ADD)                                                                                            \
  for (int seg : {1, 2, 4})                                                                                                    \
    for (size_t local : {size_t(0), size_t(1), size_t(2), size_t(4), size_t(5), size_t(8), size_t(10), size_t(16), size_t(20), size_t(32), size_t(64)}) {                                                       \
      if (seg > 1 && !narrow) continue;                                                                                        \
      if (seg == 1)                                                                                                            \
        one([&](const Args &a, int) { launch<RR, GG, UU, RBB, false, ADD>(q, a, local); }, UU, RBB, 1, ADD, local);           \
      else                                                                                                                     \
        one([&](const Args &a, int) { launch<RR, GG, UU, RBB, true, ADD>(q, a, local); combine(q, a, 0); }, UU, RBB, seg, ADD, local); \
    }
  if (m <= 8) {
    SWEEP(8, 1, 2, 1, 3) SWEEP(8, 1, 1, 1, 3)
  } else {
    SWEEP(8, 2, 1, 1, 3)
  }
  double best = 1e9; std::string bc;
  for (auto &r : all) if (r.us < best && r.cfg.find("differs") == std::string::npos) { best = r.us; bc = r.cfg; }
  printf("best bit-identical variant: %s: %.1f us (%.0f%% of production %.1f us)\n", bc.c_str(), best, 100 * best / tprod, tprod);
}
