// dpas_map: one-hot mapping of the DPAS B operand when its precision is below
// 8 bits. For every bit-field position p (in units of BBITS) of the B operand
// we set that field to +1, set all A elements to distinct primes, and record
// which output lane changes and by how much -> (n, k) for that field.
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <cstdint>
#include <cstdio>
#include <cstring>
using namespace sycl;
using namespace sycl::ext::intel::esimd;
namespace xmx = sycl::ext::intel::esimd::xmx;
using PT = xmx::dpas_argument_type;

template <PT BP, int BBITS, int BDW> static void map(queue &q, const char *name) {
  constexpr int N = 16, ADW = 8;
  uint8_t *bbuf = malloc_shared<uint8_t>(BDW * 4, q);
  int8_t *abuf = malloc_shared<int8_t>(32, q);
  int32_t *out = malloc_shared<int32_t>(N, q);
  for (int k = 0; k < 32; k++) abuf[k] = int8_t(k + 1); // value k+1 identifies k
  printf("== %s, B operand passed as %d dwords\n", name, BDW);
  int fields = BDW * 32 / BBITS;
  int printed = 0;
  for (int p = 0; p < fields; p++) {
    memset(bbuf, 0, BDW * 4);
    bbuf[(p * BBITS) >> 3] = uint8_t(1u << ((p * BBITS) & 7));
    q.single_task([=]() SYCL_ESIMD_KERNEL {
       simd<int32_t, BDW> b;
       b.copy_from((const int32_t *)bbuf);
       simd<int32_t, ADW> a;
       a.copy_from((const int32_t *)abuf);
       simd<int32_t, N> c(0);
       simd<int32_t, N> r = xmx::dpas<8, 1, int32_t, int32_t, int32_t, int32_t, BP, PT::s8>(c, b, a);
       r.copy_to(out);
     }).wait_and_throw();
    int hit = -1, cnt = 0;
    for (int n = 0; n < N; n++)
      if (out[n]) { hit = n; cnt++; }
    // print a compact sample: first 40 fields, then every 61st
    if (p < 40 || p % 61 == 0 || cnt != 1) {
      if (cnt == 1) printf("  field %4d (byte %3d bit %d) -> n=%2d k=%2d\n", p, (p*BBITS)>>3, (p*BBITS)&7, hit, out[hit] - 1);
      else printf("  field %4d (byte %3d bit %d) -> %d lanes hit\n", p, (p*BBITS)>>3, (p*BBITS)&7, cnt);
      if (++printed > 70) break;
    }
  }
}
int main() {
  queue q(gpu_selector_v);
  map<PT::s4, 4, 64>(q, "s4 x s8");
  map<PT::s2, 2, 32>(q, "s2 x s8");
  return 0;
}
