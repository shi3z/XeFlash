// nbarrier_probe: does the producer / consumer named barrier of ESIMD work on this GPU (Xe2, BMG)? One producer thread fills SLM stages (double buffered),
// seven consumer threads of the work-group read them. full[b]: producer arrived + consumers arrived -> consumers wait; empty[b]: consumers done reading -> producer waits.
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <cstdio>
#include <vector>
using namespace sycl;
using namespace sycl::ext::intel::esimd;
int main(int argc, char **argv) {
  queue q(gpu_selector_v, property::queue::in_order{});
  const int NST = 64, WGS = 8, NWG = 64;
  uint32_t *out = malloc_device<uint32_t>(size_t(NWG) * WGS * 16, q);
  q.memset(out, 0, size_t(NWG) * WGS * 16 * 4).wait();
  const int mode = argc > 1 ? atoi(argv[1]) : 0; // 0: named barriers, 1: plain barrier (reference)
  q.parallel_for(nd_range<1>(size_t(NWG) * WGS, WGS), [=](nd_item<1> it) SYCL_ESIMD_KERNEL {
    slm_init<2048>();
    const uint32_t lt = it.get_local_id(0), wg = it.get_group(0);
    simd<uint32_t, 16> acc(0u);
    if (mode == 1) {
      for (int s = 0; s < NST; s++) {
        const uint32_t b = s & 1;
        if (lt == 0) slm_block_store<uint32_t, 16>(b * 512 + 0, simd<uint32_t, 16>(uint32_t(s * 3 + wg), 1));
        barrier();
        if (lt != 0) acc += slm_block_load<uint32_t, 16>(b * 512);
        barrier();
      }
    } else if (mode >= 2) {
      // one stage only: which signal / wait combination completes?
      named_barrier_init<2>();
      if (lt == 0) {
        slm_block_store<uint32_t, 16>(0, simd<uint32_t, 16>(uint32_t(wg), 1));
        named_barrier_signal(1, 0x1, 1, WGS - 1);
        if (mode == 5) named_barrier_wait(1);
      } else {
        if (mode == 2 || mode == 5) named_barrier_signal(1, 0x2, 1, WGS - 1);
        named_barrier_wait(1);
        acc += slm_block_load<uint32_t, 16>(0);
      }
    } else {
      named_barrier_init<5>();
      constexpr uint8_t FULL0 = 1, EMPTY0 = 3;
      if (lt == 0) { // producer
        for (int s = 0; s < NST; s++) {
          const uint32_t b = s & 1;
          if (s >= 2) { named_barrier_signal(EMPTY0 + b, 0x2, WGS - 1, 1); named_barrier_wait(EMPTY0 + b); } // roles swapped: the 7 readers are the "producers" of the empty barrier, the writer its consumer
          slm_block_store<uint32_t, 16>(b * 512, simd<uint32_t, 16>(uint32_t(s * 3 + wg), 1));
          named_barrier_signal(FULL0 + b, 0x1, 1, WGS - 1);
        }
      } else {
        for (int s = 0; s < NST; s++) {
          const uint32_t b = s & 1;
          named_barrier_signal(FULL0 + b, 0x2, 1, WGS - 1);
          named_barrier_wait(FULL0 + b);
          acc += slm_block_load<uint32_t, 16>(b * 512);
          if (s + 2 < NST) named_barrier_signal(EMPTY0 + b, 0x1, WGS - 1, 1);
        }
      }
    }
    acc.copy_to(out + (size_t(wg) * WGS + lt) * 16);
  });
  q.wait();
  std::vector<uint32_t> h(size_t(NWG) * WGS * 16);
  q.memcpy(h.data(), out, h.size() * 4).wait();
  int bad = 0;
  for (int wg = 0; wg < NWG; wg++)
    for (int lt = 1; lt < WGS; lt++)
      for (int i = 0; i < 16; i++) {
        uint32_t ref = 0;
        if (mode >= 2) ref = uint32_t(wg) + i; else for (int s = 0; s < NST; s++) ref += uint32_t(s * 3 + wg) + i;
        if (h[(size_t(wg) * WGS + lt) * 16 + i] != ref) bad++;
      }
  printf("mode %d: %d mismatches of %d\n", mode, bad, NWG * (WGS - 1) * 16);
}
