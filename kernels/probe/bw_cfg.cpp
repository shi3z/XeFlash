// bw_cfg: pure weight read of gate+up (34816 x 5120, 4-bit, 89.1 MB), cold (rotating buffers), back to back, in the configurations between the
// old read-only probe (bw_shapes: 2176 threads, 1 stream each, 128 GRF, plain launch, 2 loads in flight) and the GEMM (4352 threads, 2 per stream, 256 GRF, WG 4, 1 load ahead).
//   build: icpx -fsycl -O2 -std=c++20 bw_cfg.cpp -o bw_cfg      run: ./bw_cfg
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <chrono>
#include <cstdio>
#include <random>
#include <vector>
using namespace sycl;
using namespace sycl::ext::intel::esimd;
namespace sx = sycl::ext::oneapi::experimental;
// SH = threads per stream (they read the same addresses), U = loads in flight per iteration (unrolled), WG = work-group size (0 = plain range), L = 256 GRF
template <int SH, int U, int WG, bool L>
static double run(queue &q, std::vector<int32_t *> &bufs, int32_t *out, size_t chunks, size_t streams) {
  const size_t per = chunks / streams, T = streams * SH;
  auto body = [=](size_t gid, const int32_t *buf) SYCL_ESIMD_FUNCTION {
    const size_t s = gid / SH;
    simd<int32_t, 64> acc(0);
    for (size_t i = 0; i < per; i += U) {
#pragma unroll
      for (int u = 0; u < U; u++) {
        simd<int32_t, 64> v;
        v.copy_from(buf + (s * per + i + u) * 64);
        acc ^= v;
      }
    }
    acc.copy_to(out + gid * 64);
  };
  auto one = [&](size_t r) {
    const int32_t *buf = bufs[r % bufs.size()];
    if constexpr (WG == 0) {
      q.parallel_for(range<1>(T), [=](id<1> id) SYCL_ESIMD_KERNEL { body(id[0], buf); });
    } else if constexpr (L) {
      sx::properties props{sycl::ext::intel::experimental::grf_size<256>};
      q.parallel_for(nd_range<1>(T, WG), props, [=](nd_item<1> it) SYCL_ESIMD_KERNEL { body(it.get_global_id(0), buf); });
    } else {
      q.parallel_for(nd_range<1>(T, WG), [=](nd_item<1> it) SYCL_ESIMD_KERNEL { body(it.get_global_id(0), buf); });
    }
  };
  for (int r = 0; r < 20; r++) one(r);
  q.wait();
  const int reps = 200;
  auto t0 = std::chrono::steady_clock::now();
  for (int r = 0; r < reps; r++) one(r);
  q.wait();
  return std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count() / reps;
}
int main() {
  queue q(gpu_selector_v, property::queue::in_order{});
  const size_t rows = 34816, cols = 5120, bytes = rows * cols / 2, chunks = bytes / 256, streams = rows / 16;
  std::mt19937_64 rng(7);
  const size_t nbuf = (400u << 20) / bytes;
  std::vector<int32_t *> bufs;
  std::vector<int32_t> h(bytes / 4);
  for (size_t b = 0; b < nbuf; b++) {
    for (auto &x : h) x = int32_t(rng());
    int32_t *p = malloc_device<int32_t>(bytes / 4, q);
    q.memcpy(p, h.data(), bytes).wait();
    bufs.push_back(p);
  }
  int32_t *out = malloc_device<int32_t>(64 * 65536, q);
  printf("gate+up weights %.1f MB, %zu streams (16 rows each, contiguous), cold, back to back\n%-52s %9s %8s\n", bytes / 1e6, streams, "configuration", "us", "GB/s");
  auto rep = [&](const char *n, double us) { printf("%-52s %9.1f %8.0f\n", n, us, bytes / us / 1e3); fflush(stdout); };
  rep("probe: 1 thr/stream, U=2, plain launch, 128 GRF", run<1, 2, 0, false>(q, bufs, out, chunks, streams));
  rep("1 thr/stream, U=1, plain", run<1, 1, 0, false>(q, bufs, out, chunks, streams));
  rep("1 thr/stream, U=4, plain", run<1, 4, 0, false>(q, bufs, out, chunks, streams));
  rep("1 thr/stream, U=2, WG 4, 128 GRF", run<1, 2, 4, false>(q, bufs, out, chunks, streams));
  rep("1 thr/stream, U=2, WG 4, 256 GRF", run<1, 2, 4, true>(q, bufs, out, chunks, streams));
  rep("2 thr/stream, U=2, plain", run<2, 2, 0, false>(q, bufs, out, chunks, streams));
  rep("2 thr/stream, U=2, WG 4, 128 GRF", run<2, 2, 4, false>(q, bufs, out, chunks, streams));
  rep("2 thr/stream, U=2, WG 4, 256 GRF (GEMM config)", run<2, 2, 4, true>(q, bufs, out, chunks, streams));
  rep("2 thr/stream, U=1, WG 4, 256 GRF", run<2, 1, 4, true>(q, bufs, out, chunks, streams));
  rep("2 thr/stream, U=4, WG 4, 256 GRF", run<2, 4, 4, true>(q, bufs, out, chunks, streams));
  rep("2 thr/stream, U=8, WG 4, 256 GRF", run<2, 8, 4, true>(q, bufs, out, chunks, streams));
}
