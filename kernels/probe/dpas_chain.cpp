// dpas_chain: XMX rate against independent accumulator chains per thread and resident threads per EU (operands in registers, s4 x s8, repeat count 8).
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <chrono>
#include <cstdio>
using namespace sycl;
using namespace sycl::ext::intel::esimd;
namespace xmx = sycl::ext::intel::esimd::xmx;
using PT = xmx::dpas_argument_type;
template <int C>
static double run(queue &q, size_t T, int iters, int32_t *out) {
  auto go = [&] {
    q.parallel_for(range<1>(T), [=](id<1> id) SYCL_ESIMD_KERNEL {
      simd<int32_t, 64> b(int32_t(id[0]) | 0x01010101);
      simd<int32_t, 64> a(int32_t(id[0] * 3) | 0x01010101);
      simd<int32_t, 128> acc[C];
#pragma unroll
      for (int i = 0; i < C; i++) acc[i] = 0;
      for (int it = 0; it < iters; it++) {
#pragma unroll
        for (int i = 0; i < C; i++) acc[i] = xmx::dpas<8, 8, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc[i], b, a);
      }
      simd<int32_t, 128> s = acc[0];
#pragma unroll
      for (int i = 1; i < C; i++) s += acc[i];
      s.copy_to(out + id[0] * 128);
    });
  };
  go();
  q.wait();
  auto t0 = std::chrono::steady_clock::now();
  for (int r = 0; r < 5; r++) go();
  q.wait();
  return std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count() / 5;
}
int main() {
  queue q(gpu_selector_v, property::queue::in_order{});
  int32_t *out = malloc_device<int32_t>(16384 * 128, q);
  printf("s4 x s8 dpas.8x8, operands in registers: TOPS (peak 196.5) by independent chains per thread (columns) and threads per EU (rows)\n%-12s", "thr/EU");
  for (int c : {1, 2, 4, 8, 16}) printf("%8d", c);
  printf("\n");
  for (int tpe : {1, 2, 4, 8}) {
    const size_t T = size_t(160) * tpe;
    printf("%-12d", tpe);
    auto row = [&](auto cc, int iters) {
      constexpr int C = decltype(cc)::value;
      const double s = run<C>(q, T, iters, out);
      printf("%8.1f", T * double(C) * iters * 8192.0 / s / 1e12);
    };
    row(std::integral_constant<int, 1>{}, 160000);
    row(std::integral_constant<int, 2>{}, 80000);
    row(std::integral_constant<int, 4>{}, 40000);
    row(std::integral_constant<int, 8>{}, 20000);
    row(std::integral_constant<int, 16>{}, 10000);
    printf("\n");
  }
}
