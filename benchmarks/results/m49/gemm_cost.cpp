// gemm_cost: stepwise cost decomposition of the 64-row s4 x a16 GEMM (gate+up 34816 x 5120) for the two register configurations,
//   256 GRF / 32 tokens per thread (G = 4, 4 threads per EU)   and   128 GRF / 16 tokens per thread (G = 2, 8 threads per EU).
// Stages (timing only, results are not meaningful):
//   ro    one thread per weight stream reads the stream (probe loop, 2 loads in flight); the other token-group threads exit
//   dup   every token-group thread reads the stream (duplicate weight requests)
//   loop  production loop structure (two register sets, tile t + 1 requested before the compute of tile t, 64-bit pointers), weights only
//   act   + hi / lo activation tile loads (xor-folded so they stay live)
//   full  + DPAS instead of the xor of the activations = the production loop
//   nodpas / noact variants: full without the weights loads... see main()
//   build: icpx -fsycl -O2 -std=c++20 gemm_cost.cpp -o gemm_cost
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <vector>
using namespace sycl;
using namespace sycl::ext::intel::esimd;
namespace xmx = sycl::ext::intel::esimd::xmx;
namespace sx = sycl::ext::oneapi::experimental;
using sycl::ext::intel::esimd::cache_hint;
using sycl::ext::intel::esimd::alignment;
using PT = xmx::dpas_argument_type;
enum Mode { RO, DUP, LOOP, ACT, FULL, ACT_NOW, DPAS_NOACT };
static const char *mname[] = {"ro", "dup", "loop (weights)", "+ activation loads", "+ DPAS (= production loop)", "activation loads only (no weights)", "weights + DPAS, no activation loads"};

// FL bits: 1 = activation tiles always the same tile (L1-hot), 2 = weight tile always the same (L1-hot, no DRAM), 4 = activation loads as one 2D block load (G = 4 only)
template <int G, bool L, int M, int FL = 0>
static double run(queue &q, std::vector<int32_t *> &wbufs, const int32_t *X, const int32_t *XL, int32_t *out, size_t rowblks, size_t tiles) {
  constexpr int R = 8, TPT = R * G, XDW = 8 * TPT, WDW = 64;
  constexpr size_t mpad = 64, tq = mpad / TPT;
  constexpr size_t SEGS = (FL & 65536) ? 4 : (FL & 32768) ? 2 : 1;
  const size_t xstride = (FL & 1) ? 0 : mpad * 8, nthreads = rowblks * tq * SEGS;
  const size_t tps = tiles / SEGS;
  auto body = [=](size_t gid, const int32_t *W) SYCL_ESIMD_FUNCTION {
    const size_t tg = gid % tq;
    size_t rb = gid / tq, seg = 0;
    if constexpr (SEGS > 1) { seg = rb / rowblks; rb = rb % rowblks; }
    if constexpr (M == RO) { if (tg != 0) return; }
    const int32_t *wq = W + (SEGS > 1 ? (rb * SEGS + seg) : rb) * tps * WDW;
    if constexpr (M == RO || M == DUP) {
      simd<int32_t, 64> acc(0);
      for (size_t i = 0; i < tps; i += 2) {
        simd<int32_t, 64> a, b;
        a.copy_from(wq + i * 64);
        b.copy_from(wq + (i + 1) * 64);
        acc ^= a;
        acc ^= b;
      }
      acc.copy_to(out + gid * 64);
    } else {
      const size_t xoff = tg * TPT * 8;
      const size_t xs0 = SEGS > 1 ? seg * tps * xstride : 0;
      const int32_t *xq = X + xoff + xs0, *xlq = XL + xoff + xs0;
      simd<int32_t, 16 * R> acc[G], accl[G];
#pragma unroll
      for (int g = 0; g < G; g++) { acc[g] = 0; accl[g] = 0; }
      simd<int32_t, 64> fold(0);
      simd<int32_t, WDW> wa, wb;
      simd<int32_t, XDW> xa, xb, xla, xlb;
      constexpr bool LW = (M != ACT_NOW), LX = (M == ACT || M == FULL || M == ACT_NOW);
#define LDX(V, P) { if constexpr ((FL & 4) && G == 4) V = load_2d<int32_t, 16, 16, 1>(P, 63, 15, 63, 0, 0); else V.copy_from(P); }
#define LDW(V, P) { \
    if constexpr (FL & 16) V = block_load<int32_t, 64>(P, sx::properties{cache_hint_L1<cache_hint::uncached>, cache_hint_L2<cache_hint::cached>, alignment<256>}); \
    else if constexpr (FL & 32) V = block_load<int32_t, 64>(P, sx::properties{cache_hint_L1<cache_hint::streaming>, cache_hint_L2<cache_hint::cached>, alignment<256>}); \
    else if constexpr (FL & 64) V = block_load<int32_t, 64>(P, sx::properties{cache_hint_L1<cache_hint::uncached>, cache_hint_L2<cache_hint::uncached>, alignment<256>}); \
    else V.copy_from(P); }
#define PL(W_, X_, XL_)                                          \
  if constexpr ((FL & 8) && LX) { LDX(X_, xq); LDX(XL_, xlq); } \
  if constexpr (LW) LDW(W_, wq);                                 \
  if constexpr (!(FL & 2)) wq += WDW;                            \
  if constexpr (LX && !(FL & 8)) { LDX(X_, xq); LDX(XL_, xlq); } \
  xq += xstride; xlq += xstride;
#define PC(W_, X_, XL_)                                                                                  \
  {                                                                                                      \
    if constexpr (M == FULL || M == DPAS_NOACT) {                                                        \
      _Pragma("unroll") for (int g = 0; g < G; g++) {                                                    \
        simd<int32_t, 8 * R> a = X_.template select<8 * R, 1>(g * 8 * R);                                \
        acc[g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc[g], W_, a);     \
      }                                                                                                  \
      _Pragma("unroll") for (int g = 0; g < G; g++) {                                                    \
        simd<int32_t, 8 * R> a = XL_.template select<8 * R, 1>(g * 8 * R);                               \
        accl[g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(accl[g], W_, a);   \
      }                                                                                                  \
    } else {                                                                                             \
      if constexpr (LW) fold ^= W_;                                                                      \
      if constexpr (LX) {                                                                                \
        _Pragma("unroll") for (int k = 0; k < XDW / 64; k++) {                                           \
          fold ^= X_.template select<64, 1>(64 * k);                                                     \
          fold ^= XL_.template select<64, 1>(64 * k);                                                    \
        }                                                                                                \
      }                                                                                                  \
    }                                                                                                    \
  }
      if constexpr (M == DPAS_NOACT) { // activation registers stay as they are (zero-initialised): DPAS reads them
        xa = 1; xb = 2; xla = 3; xlb = 4;
      }
      PL(wa, xa, xla)
      for (size_t t = 0; t < tps; t += 2) {
        if constexpr (FL & 3840) { constexpr int BN = (FL & 256) ? 8 : (FL & 512) ? 16 : (FL & 1024) ? 4 : 32; if ((t % BN) == 0) barrier(); }
        PL(wb, xb, xlb)
        PC(wa, xa, xla)
        if (t + 2 < tps) { PL(wa, xa, xla) }
        PC(wb, xb, xlb)
      }
#pragma unroll
      for (int g = 0; g < G; g++) { fold ^= acc[g].template select<64, 1>(0); fold ^= accl[g].template select<64, 1>(0); }
      fold.copy_to(out + gid * 64);
    }
  };
  static int rep_idx = 0;
  auto one = [&](int r) {
    const int32_t *W = wbufs[r % wbufs.size()];
    const size_t w = (FL & 4096) ? 32 : (FL & 8192) ? 16 : (FL & 16384) ? 8 : 4;
    if constexpr (L) {
      sx::properties props{sycl::ext::intel::experimental::grf_size<256>};
      q.parallel_for(nd_range<1>(nthreads, w), props, [=](nd_item<1> it) SYCL_ESIMD_KERNEL { body(it.get_global_id(0), W); });
    } else {
      q.parallel_for(nd_range<1>(nthreads, w), [=](nd_item<1> it) SYCL_ESIMD_KERNEL { body(it.get_global_id(0), W); });
    }
  };
  for (int r = 0; r < 20; r++) one(r);
  q.wait();
  const int reps = 200;
  auto t0 = std::chrono::steady_clock::now();
  for (int r = 0; r < reps; r++) one(r);
  q.wait();
  (void)rep_idx;
  return std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count() / reps;
}
int main(int argc, char **argv) {
  queue q(gpu_selector_v, property::queue::in_order{});
  const size_t rows = 34816, cols = 5120, rowblks = rows / 16, tiles = cols / 32, bytes = rows * cols / 2;
  std::mt19937_64 rng(7);
  const size_t nbuf = (400u << 20) / bytes;
  std::vector<int32_t *> wbufs;
  std::vector<int32_t> h(bytes / 4);
  for (size_t b = 0; b < nbuf; b++) {
    for (auto &x : h) x = int32_t(rng());
    int32_t *p = malloc_device<int32_t>(bytes / 4, q);
    q.memcpy(p, h.data(), bytes).wait();
    wbufs.push_back(p);
  }
  const size_t xbytes = tiles * 64 * 8 * 4;
  std::vector<int32_t> hx(xbytes / 4);
  for (auto &x : hx) x = int32_t(rng());
  int32_t *X = malloc_device<int32_t>(xbytes / 4, q), *XL = malloc_device<int32_t>(xbytes / 4, q), *out = malloc_device<int32_t>(64 * 65536, q);
  q.memcpy(X, hx.data(), xbytes).wait();
  q.memcpy(XL, hx.data(), xbytes).wait();
  printf("gate+up 64 rows, weights %.1f MB, cold, back to back (us)\n%-40s %10s %10s\n", bytes / 1e6, "stage", "256 GRF/32tok", "128 GRF/16tok");
  auto row = [&](Mode m, double a, double b) { printf("%-40s %10.1f %10.1f\n", mname[m], a, b); fflush(stdout); };
#define ROWM(M) row(M, run<4, true, M>(q, wbufs, X, XL, out, rowblks, tiles), run<2, false, M>(q, wbufs, X, XL, out, rowblks, tiles))
  ROWM(RO); ROWM(DUP); ROWM(LOOP); ROWM(ACT); ROWM(FULL); ROWM(ACT_NOW); ROWM(DPAS_NOACT);
  printf("\nclassification of the activation cost (256 GRF / 32 tok; 128 GRF / 16 tok), us\n");
  auto r2 = [&](const char *n, double a, double b) { printf("%-60s %10.1f %10.1f\n", n, a, b); fflush(stdout); };
#define ROWF(N, M, F) r2(N, run<4, true, M, F>(q, wbufs, X, XL, out, rowblks, tiles), run<2, false, M, F>(q, wbufs, X, XL, out, rowblks, tiles))
  ROWF("full: activation tiles L1-hot (same tile every K step)", FULL, 1);
  ROWF("full: weight tile L1-hot (no DRAM stream)", FULL, 2);
  ROWF("full: both L1-hot (DPAS + L1 only)", FULL, 3);
  ROWF("activation loads only (no weights), L1-hot", ACT_NOW, 1);
  ROWF("full: activation as one 2D block load per plane (256 GRF only)", FULL, 4);
  ROWF("+ activation loads (xor), 2D block loads (256 GRF only)", ACT, 4);
  ROWF("full: activation loads issued before the weight load", FULL, 8);
  ROWF("full: weights L1-uncached (L2 cached)", FULL, 16);
  ROWF("full: weights L1-streaming (L2 cached)", FULL, 32);
  ROWF("full: K split in 2 segments (partial sums not written)", FULL, 32768);
  ROWF("full: K split in 4 segments", FULL, 65536);
  ROWF("full: WG 8, barrier every 8 tiles (K lockstep)", FULL, 16384 + 256);
  ROWF("full: WG 16, barrier every 8 tiles", FULL, 8192 + 256);
  ROWF("full: WG 32, barrier every 8 tiles", FULL, 4096 + 256);
  ROWF("full: WG 16, barrier every 16 tiles", FULL, 8192 + 512);
  ROWF("full: WG 16, barrier every 4 tiles", FULL, 8192 + 1024);
  ROWF("full: WG 16, no barrier (work-group size only)", FULL, 8192);
  ROWF("full: weights L1- and L2-uncached", FULL, 64);
}
