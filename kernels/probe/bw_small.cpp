// bw_small: one small read-only kernel (the size of a narrow GEMM's weights, 16 MiB), cold (rotating over 24 buffers), back to back as in the engine.
//   pattern S (stream per thread), T threads, U loads in flight, CH = chunks (256 B) per load group.
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <chrono>
#include <cstdio>
#include <random>
#include <vector>
using namespace sycl;
using namespace sycl::ext::intel::esimd;
template <int U>
static void launch(queue &q, const int32_t *buf, int32_t *out, size_t chunks, size_t T) {
  const size_t per = chunks / T;
  q.parallel_for(range<1>(T), [=](id<1> id) SYCL_ESIMD_KERNEL {
    const size_t t = id[0];
    simd<int32_t, 64> acc(0);
    for (size_t i = 0; i < per; i += U) {
#pragma unroll
      for (int u = 0; u < U; u++) {
        simd<int32_t, 64> v;
        v.copy_from(buf + (t * per + i + u) * 64);
        acc ^= v;
      }
    }
    acc.copy_to(out + t * 64);
  });
}
int main() {
  queue q(gpu_selector_v, property::queue::in_order{});
  const size_t mb = 16, bytes = mb << 20, nbuf = 24;
  std::vector<int32_t *> bufs;
  std::vector<int32_t> h(bytes / 4);
  std::mt19937_64 rng(7);
  for (size_t b = 0; b < nbuf; b++) {
    for (auto &x : h) x = int32_t(rng());
    int32_t *p = malloc_device<int32_t>(bytes / 4, q);
    q.memcpy(p, h.data(), bytes).wait();
    bufs.push_back(p);
  }
  int32_t *out = malloc_device<int32_t>(64 * 65536, q);
  const size_t chunks = bytes / 256;
  printf("16 MiB per kernel, cold, back to back: us per kernel (GB/s)\n%8s %9s %9s %9s %9s\n", "threads", "U=1", "U=2", "U=4", "U=8");
  for (size_t T : {256, 512, 1024, 2048, 4096, 8192, 16384}) {
    printf("%8zu", T);
    for (int U : {1, 2, 4, 8}) {
      auto one = [&](size_t r) {
        const int32_t *b = bufs[r % nbuf];
        if (U == 1) launch<1>(q, b, out, chunks, T);
        if (U == 2) launch<2>(q, b, out, chunks, T);
        if (U == 4) launch<4>(q, b, out, chunks, T);
        if (U == 8) launch<8>(q, b, out, chunks, T);
      };
      for (int r = 0; r < 30; r++) one(r);
      q.wait();
      const int reps = 480;
      auto t0 = std::chrono::steady_clock::now();
      for (int r = 0; r < reps; r++) one(r);
      q.wait();
      double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count() / reps;
      printf(" %5.1f(%3.0f)", us, bytes / us / 1e3);
    }
    printf("\n");
  }
}
