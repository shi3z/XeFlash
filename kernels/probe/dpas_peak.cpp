// dpas_peak: XMX throughput with every operand in registers (no memory traffic in the loop), for the operand types of the GEMM kernels.
//   threads T, 8 independent accumulators per thread, dpas repeat count 8 (8 rows x N=16), N dpas per thread.
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <chrono>
#include <cstdio>
using namespace sycl;
using namespace sycl::ext::intel::esimd;
namespace xmx = sycl::ext::intel::esimd::xmx;
using PT = xmx::dpas_argument_type;

// ACC = float for 16-bit float types, int32 for integer types; B = weights operand dwords (16 n x K), A = 8 rows x K
template <typename ACC, PT BP, PT AP, int BDW, int ADW>
static double run(queue &q, size_t T, int iters, int32_t *out) {
  auto go = [&] {
    q.parallel_for(range<1>(T), [=](id<1> id) SYCL_ESIMD_KERNEL {
      simd<int32_t, BDW> b(int32_t(id[0]) | 0x01010101);
      simd<int32_t, 8 * ADW / 8 * 8 / 8 * 1> dummy(0);
      simd<int32_t, 8 * ADW> a(int32_t(id[0] * 3) | 0x01010101);
      simd<ACC, 128> acc[8];
#pragma unroll
      for (int i = 0; i < 8; i++) acc[i] = ACC(0);
      for (int it = 0; it < iters; it++) {
#pragma unroll
        for (int i = 0; i < 8; i++) acc[i] = xmx::dpas<8, 8, ACC, ACC, int32_t, int32_t, BP, AP>(acc[i], b, a);
      }
      simd<ACC, 128> s = acc[0];
#pragma unroll
      for (int i = 1; i < 8; i++) s += acc[i];
      simd<int32_t, 128> r = s.template bit_cast_view<int32_t>();
      r.copy_to(out + id[0] * 128);
    });
  };
  go();
  q.wait();
  auto t0 = std::chrono::steady_clock::now();
  const int reps = 5;
  for (int r = 0; r < reps; r++) go();
  q.wait();
  return std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count() / reps;
}
int main() {
  queue q(gpu_selector_v, property::queue::in_order{});
  const size_t Tmax = 8192;
  int32_t *out = malloc_device<int32_t>(Tmax * 128, q);
  const int iters = 20000;
  printf("device %s; dpas.8x8 with register operands, 8 independent accumulators per thread, %d x 8 dpas per thread\n", q.get_device().get_info<sycl::info::device::name>().c_str(), iters);
  printf("%-22s %7s %10s %12s\n", "operands (B x A)", "threads", "TOPS", "ops/dpas");
  struct R { const char *n; double ops; };
  for (size_t T : {640, 1280, 2560, 5120}) {
    double ops_hf = 8.0 * 16 * 16 * 2, ops_i8 = 8.0 * 16 * 32 * 2;
    double s;
    s = run<float, PT::fp16, PT::fp16, 128, 8>(q, T, iters, out);   printf("%-22s %7zu %10.1f %12.0f\n", "fp16 x fp16 -> f32", T, T * 8.0 * iters * ops_hf / s / 1e12, ops_hf);
    s = run<float, PT::bf16, PT::bf16, 128, 8>(q, T, iters, out);   printf("%-22s %7zu %10.1f %12.0f\n", "bf16 x bf16 -> f32", T, T * 8.0 * iters * ops_hf / s / 1e12, ops_hf);
    s = run<int32_t, PT::s8, PT::s8, 128, 8>(q, T, iters, out);     printf("%-22s %7zu %10.1f %12.0f\n", "s8 x s8 -> s32", T, T * 8.0 * iters * ops_i8 / s / 1e12, ops_i8);
    s = run<int32_t, PT::s4, PT::s8, 64, 8>(q, T, iters, out);      printf("%-22s %7zu %10.1f %12.0f\n", "s4 x s8 -> s32 (GEMM)", T, T * 8.0 * iters * ops_i8 / s / 1e12, ops_i8);
    s = run<int32_t, PT::u4, PT::s8, 64, 8>(q, T, iters, out);      printf("%-22s %7zu %10.1f %12.0f\n", "u4 x s8 -> s32 (s3)", T, T * 8.0 * iters * ops_i8 / s / 1e12, ops_i8);
  }
}
