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
  struct Shape { const char *name; size_t rows, cols; };
  const Shape shapes[] = {{"gate+up 34816x5120", 34816, 5120}, {"down 5120x17408", 5120, 17408}, {"GDN in 16384x5120", 16384, 5120},
                          {"attn qkv 14336x5120", 14336, 5120}, {"out proj 5120x6144", 5120, 6144}};
  std::mt19937_64 rng(7);
  printf("pure read of the weight bytes of each shape (4-bit), one stream per 16-row block, cold, back to back\n%-22s %8s %8s %12s %14s\n", "shape", "MB", "threads", "read us", "GB/s");
  for (const Shape &sh : shapes) {
    const size_t bytes = sh.rows * sh.cols / 2, chunks = bytes / 256, T = sh.rows / 16;
    size_t nbuf = std::max<size_t>(2, (400u << 20) / bytes);
    std::vector<int32_t *> bufs;
    std::vector<int32_t> h(bytes / 4);
    for (size_t b = 0; b < nbuf; b++) {
      for (auto &x : h) x = int32_t(rng());
      int32_t *p = malloc_device<int32_t>(bytes / 4, q);
      q.memcpy(p, h.data(), bytes).wait();
      bufs.push_back(p);
    }
    int32_t *out = malloc_device<int32_t>(64 * 65536, q);
    for (int U : {2}) {
      auto one = [&](size_t r) { launch<2>(q, bufs[r % nbuf], out, chunks, T); };
      for (int r = 0; r < 20; r++) one(r);
      q.wait();
      const int reps = 200;
      auto t0 = std::chrono::steady_clock::now();
      for (int r = 0; r < reps; r++) one(r);
      q.wait();
      const double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count() / reps;
      printf("%-22s %8.1f %8zu %12.1f %14.0f\n", sh.name, bytes / 1e6, T, us, bytes / us / 1e3);
    }
    for (auto p : bufs) free(p, q);
    free(out, q);
  }
}
