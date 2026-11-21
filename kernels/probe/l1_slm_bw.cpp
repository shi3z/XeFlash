// l1_slm_bw: load bandwidth of the L1 (global loads that hit a small resident buffer) against SLM block loads, same 512-byte loads as the GEMM's activation tiles.
// Each thread issues N loads of 512 B per iteration (independent), accumulates with XOR; threads per work-group WG, SLM filled once.
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <chrono>
#include <cstdio>
#include <vector>
using namespace sycl;
using namespace sycl::ext::intel::esimd;
template <bool SLM, int N>
static void launch(queue &q, const int32_t *buf, int32_t *out, size_t threads, size_t wg, int iters) {
  q.parallel_for(nd_range<1>(threads, wg), [=](nd_item<1> it) SYCL_ESIMD_KERNEL {
    slm_init<32768>();
    const size_t t = it.get_global_id(0);
    if constexpr (SLM) {
      const int lt = int(it.get_local_id(0));
      for (int i = lt; i < 8192 / 128; i += int(it.get_local_range(0))) {
        simd<int32_t, 128> v;
        v.copy_from(buf + i * 128);
        slm_block_store<int32_t, 128>(uint32_t(i * 512), v);
      }
      barrier();
    }
    simd<int32_t, 128> acc(0);
    for (int i = 0; i < iters; i++) {
#pragma unroll
      for (int u = 0; u < N; u++) {
        simd<int32_t, 128> v;
        const uint32_t off = uint32_t(((i * N + u + t) & 63) * 512);
        if constexpr (SLM) v = slm_block_load<int32_t, 128>(off);
        else v.copy_from(buf + (off / 4));
        acc ^= v;
      }
    }
    acc.copy_to(out + t * 128);
  });
}
int main() {
  queue q(gpu_selector_v, property::queue::in_order{});
  int32_t *buf = malloc_device<int32_t>(8192 * 4, q);
  std::vector<int32_t> h(8192 * 4, 1);
  q.memcpy(buf, h.data(), h.size() * 4).wait();
  int32_t *out = malloc_device<int32_t>(128 * 65536, q);
  printf("threads wg | L1 TB/s (N=4) | SLM TB/s (N=4)\n");
  for (size_t threads : {1280, 2560, 5120}) {
    for (size_t wg : {4, 8}) {
      double r[2];
      for (int s = 0; s < 2; s++) {
        const int iters = 20000;
        auto one = [&] { if (s) launch<true, 4>(q, buf, out, threads, wg, iters); else launch<false, 4>(q, buf, out, threads, wg, iters); };
        for (int k = 0; k < 3; k++) one();
        q.wait();
        auto t0 = std::chrono::steady_clock::now();
        for (int k = 0; k < 5; k++) one();
        q.wait();
        double sec = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count() / 5;
        r[s] = double(threads) * iters * 4 * 512 / sec / 1e12;
      }
      printf("%6zu %2zu | %6.2f | %6.2f\n", threads, wg, r[0], r[1]);
    }
  }
}
