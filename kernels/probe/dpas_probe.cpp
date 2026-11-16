// dpas_probe: empirically establish which DPAS operand precisions the B60 (Xe2)
// accepts through ESIMD, and the exact bit layout of each operand.
//
// For each (B precision, A precision) pair we run ONE dpas on the GPU with
// random operands and compare against a CPU model of the layout we assume:
//
//   Result[n] = C[n] + sum_{k<K} B[k][n] * A[k]          (RepeatCount = 1)
//
//   K = 8 * ops,  ops = 32 / max(bitsB, bitsA) capped at 8,  N = 16
//   B element (k, n): systolic stage d = k / ops, op j = k % ops.
//       It lives in "channel" (d, n); channels are laid out d-major, n-minor,
//       each channel ops*bitsB bits wide, element j at bit offset j*bitsB.
//   A element k: channel d = k / ops, each channel ops*bitsA bits wide,
//       element j at bit offset j*bitsA.
//
// If the assumed layout is wrong the probe prints a one-hot map instead.
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <random>
#include <vector>

using namespace sycl;
using namespace sycl::ext::intel::esimd;
namespace xmx = sycl::ext::intel::esimd::xmx;
using PT = xmx::dpas_argument_type;

static int64_t get_elem(const uint8_t *buf, size_t bitoff, int bits, bool sgn) {
  uint64_t v = 0;
  for (int b = 0; b < bits; b++) {
    size_t p = bitoff + b;
    v |= uint64_t((buf[p >> 3] >> (p & 7)) & 1) << b;
  }
  if (sgn && (v >> (bits - 1)))
    return int64_t(v) - (int64_t(1) << bits);
  return int64_t(v);
}

template <PT BP, PT AP, int BBITS, int ABITS> static bool run(queue &q, const char *name) {
  constexpr int MAXB = BBITS > ABITS ? BBITS : ABITS;
  constexpr int OPS = (32 / MAXB) > 8 ? 8 : (32 / MAXB);
  constexpr int K = 8 * OPS;
  constexpr int N = 16;
  constexpr int BDW = K * N * BBITS / 32; // dwords in B
  constexpr int ADW = K * ABITS / 32;     // dwords in A (repeat 1)

  uint8_t *bbuf = malloc_shared<uint8_t>(BDW * 4, q);
  uint8_t *abuf = malloc_shared<uint8_t>(ADW * 4, q);
  int32_t *out = malloc_shared<int32_t>(N, q);
  std::mt19937 rng(1234);
  for (int i = 0; i < BDW * 4; i++) bbuf[i] = rng();
  for (int i = 0; i < ADW * 4; i++) abuf[i] = rng();

  try {
    q.single_task([=]() SYCL_ESIMD_KERNEL {
       simd<int32_t, BDW> b;
       b.copy_from((const int32_t *)bbuf);
       simd<int32_t, ADW> a;
       a.copy_from((const int32_t *)abuf);
       simd<int32_t, N> c(1000);
       simd<int32_t, N> r = xmx::dpas<8, 1, int32_t, int32_t, int32_t, int32_t, BP, AP>(c, b, a);
       r.copy_to(out);
     }).wait_and_throw();
  } catch (const sycl::exception &e) {
    printf("%-10s  EXCEPTION: %s\n", name, e.what());
    return false;
  }

  bool ok = true;
  for (int n = 0; n < N; n++) {
    int64_t acc = 1000;
    for (int k = 0; k < K; k++) {
      int d = k / OPS, j = k % OPS;
      int64_t bv = get_elem(bbuf, size_t(d * N + n) * OPS * BBITS + j * BBITS, BBITS, true);
      int64_t av = get_elem(abuf, size_t(d) * OPS * ABITS + j * ABITS, ABITS, true);
      acc += bv * av;
    }
    if (int32_t(acc) != out[n]) ok = false;
  }
  printf("%-10s  K=%2d N=%d  B=%4d bytes  A=%3d bytes  MAC/dpas=%4d  layout %s\n", name, K, N,
         BDW * 4, ADW * 4, K * N, ok ? "OK" : "MISMATCH");
  free(bbuf, q);
  free(abuf, q);
  free(out, q);
  return ok;
}

int main() {
  queue q(gpu_selector_v);
  printf("device: %s\n", q.get_device().get_info<sycl::info::device::name>().c_str());
  printf("B = K x N operand (\"VNNI\" side), A = K operand; names are B x A\n");
  bool ok = true;
  ok &= run<PT::s8, PT::s8, 8, 8>(q, "s8 x s8");
  ok &= run<PT::s4, PT::s8, 4, 8>(q, "s4 x s8");
  ok &= run<PT::s8, PT::s4, 8, 4>(q, "s8 x s4");
  ok &= run<PT::s2, PT::s8, 2, 8>(q, "s2 x s8");
  ok &= run<PT::s8, PT::s2, 8, 2>(q, "s8 x s2");
  ok &= run<PT::s4, PT::s4, 4, 4>(q, "s4 x s4");
  ok &= run<PT::s2, PT::s2, 2, 2>(q, "s2 x s2");
  ok &= run<PT::s2, PT::s4, 2, 4>(q, "s2 x s4");
  ok &= run<PT::s4, PT::s2, 4, 2>(q, "s4 x s2");
  return ok ? 0 : 1;
}
