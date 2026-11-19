// call_xfgemm: time the production kernel (libxfk.so, xf_gemm) with the same harness as xmx_probe: random weights rotated over several buffers, in-order queue,
// back-to-back calls, read-back only at the end. Isolates "the kernel" from "the xf-bench path".
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <vector>
#include "../include/xfk.h"
int main(int argc, char **argv) {
  const int rows = argc > 1 ? atoi(argv[1]) : 34816, cols = argc > 2 ? atoi(argv[2]) : 5120, m = argc > 3 ? atoi(argv[3]) : 8, segs = argc > 4 ? atoi(argv[4]) : 1;
  xf_ctx *ctx = nullptr;
  if (xf_ctx_create(&ctx)) { printf("no device: %s\n", xf_last_error()); return 1; }
  const size_t bytes = size_t(rows) * cols / 2;
  const size_t nbuf = std::max<size_t>(2, (400u << 20) / bytes);
  std::mt19937_64 rng(3);
  std::vector<uint32_t> h(bytes / 4);
  std::vector<void *> W;
  for (size_t b = 0; b < nbuf; b++) {
    for (auto &x : h) x = uint32_t(rng());
    void *p = xf_alloc(ctx, bytes);
    xf_write(ctx, p, h.data(), bytes);
    W.push_back(p);
  }
  const int tpt = m == 1 ? 1 : m <= 8 ? 8 : 16, mpad = (m + tpt - 1) / tpt * tpt;
  const size_t tiles = cols / 32, xbytes = tiles * mpad * 32;
  std::vector<uint8_t> hx(xbytes);
  for (auto &x : hx) x = uint8_t(rng());
  void *X = xf_alloc(ctx, xbytes), *XL = xf_alloc(ctx, xbytes);
  xf_write(ctx, X, hx.data(), xbytes);
  xf_write(ctx, XL, hx.data(), xbytes);
  std::vector<float> rs(rows, 0.01f), ts(mpad, 0.02f), to(mpad, 0.0f);
  float *RS = (float *)xf_alloc(ctx, rows * 4), *TS = (float *)xf_alloc(ctx, mpad * 4), *TO = (float *)xf_alloc(ctx, mpad * 4);
  float *Y = (float *)xf_alloc(ctx, size_t(mpad) * rows * 4);
  void *YP = segs > 1 ? xf_alloc(ctx, size_t(segs) * 2 * mpad * rows * 4) : nullptr;
  xf_write(ctx, RS, rs.data(), rows * 4); xf_write(ctx, TS, ts.data(), mpad * 4); xf_write(ctx, TO, to.data(), mpad * 4);
  auto call = [&](size_t i) {
    xf_gemm_desc d{};
    d.wfmt = XF_W_S4; d.rows = rows; d.cols = cols; d.m = m; d.tokens_per_thread = tpt; d.segs = segs; d.a16 = 1;
    d.w = W[i % nbuf]; d.x = X; d.xlo = XL; d.rs = RS; d.ts = TS; d.y = Y; d.ypart = YP; d.toff = TO; d.bias = nullptr;
    return xf_gemm(ctx, &d);
  };
  for (int i = 0; i < 20; i++) if (call(i)) { printf("xf_gemm failed: %s\n", xf_last_error()); return 1; }
  xf_read(ctx, h.data(), W[0], 4);
  const int reps = 300;
  auto t0 = std::chrono::steady_clock::now();
  for (int i = 0; i < reps; i++) call(i);
  xf_read(ctx, h.data(), W[0], 4); // waits for the queue
  const double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count() / reps;
  printf("xf_gemm (libxfk, production kernel) rows=%d cols=%d m=%d segs=%d: %.1f us per call, %.0f GB/s of 4-bit weights\n", rows, cols, m, segs, us, bytes / us / 1e3);
}
