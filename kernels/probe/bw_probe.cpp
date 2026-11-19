// bw_probe: what read bandwidth does the B60 reach for the access patterns of the GEMM weight stream?
//   threads T, bytes per load (CH), loads in flight per thread (U), pattern:
//     S = one contiguous stream per thread (the current weight layout: [row block][tile][256 B], thread = row block)
//     I = interleaved (step i: thread t reads chunk i*T + t), tile-major
//     G = groups of GS threads interleave inside a window of GS streams (compromise)
// ESIMD, 256 B per block load (simd<int32_t, 64>), data XOR-folded so that the loads cannot be removed. 512 MiB of data, read once per pass.
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <vector>
using namespace sycl;
using namespace sycl::ext::intel::esimd;

template <int U>
static double run(queue &q, const int32_t *buf, int32_t *out, size_t total_chunks, size_t T, int pattern, size_t GS, int reps) {
  // chunk = 256 B = 64 dwords. Each thread reads total_chunks / T chunks.
  const size_t per = total_chunks / T;
  auto go = [&] {
    q.parallel_for(range<1>(T), [=](id<1> id) SYCL_ESIMD_KERNEL {
      const size_t t = id[0];
      simd<int32_t, 64> acc(0);
      for (size_t i = 0; i < per; i += U) {
#pragma unroll
        for (int u = 0; u < U; u++) {
          size_t chunk;
          if (pattern == 0) chunk = t * per + i + u;                       // S
          else if (pattern == 1) chunk = (i + u) * T + t;                  // I
          else chunk = ((t / GS) * per + (i + u)) * GS + (t % GS);         // G
          simd<int32_t, 64> v;
          v.copy_from(buf + chunk * 64);
          acc ^= v;
        }
      }
      acc.copy_to(out + t * 64);
    });
  };
  go();
  q.wait();
  auto t0 = std::chrono::steady_clock::now();
  for (int r = 0; r < reps; r++) go();
  q.wait();
  return std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count() / reps;
}

int main(int argc, char **argv) {
  queue q(gpu_selector_v);
  const size_t bytes = 512ull << 20;
  int32_t *buf = malloc_device<int32_t>(bytes / 4, q);
  std::vector<int32_t> h(bytes / 4);
  { std::mt19937_64 rng(12345); for (size_t i = 0; i < h.size(); i += 2) { uint64_t r = rng(); h[i] = int32_t(r); if (i + 1 < h.size()) h[i + 1] = int32_t(r >> 32); } } // random bytes: no compression / cache tricks
  q.memcpy(buf, h.data(), bytes).wait();
  int32_t *out = malloc_device<int32_t>(64 * 65536, q);
  const size_t chunks = bytes / 256;
  printf("device %s\n%-4s %7s %3s %4s %9s %8s\n", q.get_device().get_info<sycl::info::device::name>().c_str(), "pat", "threads", "U", "GS", "ms", "GB/s");
  for (int pat : {0, 1, 2}) {
    for (size_t T : {256, 512, 1024, 2048, 4096, 8192, 16384, 32768}) {
      for (int U : {1, 2, 4, 8}) {
        const size_t GS = pat == 2 ? 16 : 1;
        if (chunks % T || (chunks / T) % U) continue;
        double s = 0;
        if (U == 1) s = run<1>(q, buf, out, chunks, T, pat, GS, 20);
        if (U == 2) s = run<2>(q, buf, out, chunks, T, pat, GS, 20);
        if (U == 4) s = run<4>(q, buf, out, chunks, T, pat, GS, 20);
        if (U == 8) s = run<8>(q, buf, out, chunks, T, pat, GS, 20);
        printf("%-4c %7zu %3d %4zu %9.3f %8.1f\n", "SIG"[pat], T, U, GS, s * 1e3, bytes / s / 1e9);
      }
    }
  }
}
