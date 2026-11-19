// simd_int4: packed 4-bit weights multiply-accumulated directly on the vector ALUs (no XMX, no expansion to a matrix), against the DPAS kernel on the same bytes.
// Same weight layout as the GEMM ([row block][tile of 32 columns][64 dwords]; dword kg*16+n holds the nibbles k = 8kg .. 8kg+7 of row n, the layout the
// s4 DPAS operand has), same 16-bit activations, same int32 outputs (checked against a host reference). One thread = 16 rows (16 lanes) x all tiles.
//   SIMD: per tile 32 columns: nibble -> int32 (shift left, arithmetic shift right: 2 ops, shared by all tokens), then M multiply-adds with the token's activation as a scalar.
//   DPAS: the production loop (double buffer, two byte planes of the 16-bit activation), as probe mode 8 of xmx_probe.
#include <sycl/ext/intel/esimd.hpp>
#include <sycl/sycl.hpp>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <string>
#include <vector>
using namespace sycl;
using namespace sycl::ext::intel::esimd;
namespace xmx = sycl::ext::intel::esimd::xmx;
namespace es = sycl::ext::intel::esimd;
using PT = xmx::dpas_argument_type;

// X16: [tile][token][32] int16 (SIMD kernel); XH/XL: [tile][8*M dwords] byte planes (DPAS kernel, x[k] = hi*256 + lo)
template <int M, int MODE> // MODE 0 = SIMD (int32 mad), 1 = SIMD with int16 x int16 -> int32 mad, 2 = DPAS (double buffered)
static sycl::event launch(queue &q, const int32_t *W, const int16_t *X16, const int32_t *XH, const int32_t *XL, int32_t *out, size_t rowblks, size_t tiles) {
  return q.parallel_for(range<1>(rowblks), [=](id<1> id) SYCL_ESIMD_KERNEL {
    const size_t rb = id[0];
    const int32_t *wp = W + rb * tiles * 64;
    if constexpr (MODE == 2) {
      constexpr int U = 2, R = M < 8 ? M : 8, G = M / R;
      simd<int32_t, 16 * R> acc[U][G], accl[U][G];
#pragma unroll
      for (int u = 0; u < U; u++)
#pragma unroll
        for (int g = 0; g < G; g++) acc[u][g] = accl[u][g] = 0;
      simd<int32_t, 64> wa[U], wb[U];
      simd<int32_t, 8 * M> xa[U], xb[U], xla[U], xlb[U];
#pragma unroll
      for (int u = 0; u < U; u++) { wa[u].copy_from(wp + u * 64); xa[u].copy_from(XH + u * 8 * M); xla[u].copy_from(XL + u * 8 * M); }
      for (size_t t = 0; t < tiles; t += 2 * U) {
#pragma unroll
        for (int u = 0; u < U; u++) { wb[u].copy_from(wp + (t + U + u) * 64); xb[u].copy_from(XH + (t + U + u) * 8 * M); xlb[u].copy_from(XL + (t + U + u) * 8 * M); }
#pragma unroll
        for (int u = 0; u < U; u++)
#pragma unroll
          for (int g = 0; g < G; g++) {
            acc[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc[u][g], wa[u], simd<int32_t, 8 * R>(xa[u].template select<8 * R, 1>(g * 8 * R)));
            accl[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(accl[u][g], wa[u], simd<int32_t, 8 * R>(xla[u].template select<8 * R, 1>(g * 8 * R)));
          }
        if (t + 2 * U < tiles) {
#pragma unroll
          for (int u = 0; u < U; u++) { wa[u].copy_from(wp + (t + 2 * U + u) * 64); xa[u].copy_from(XH + (t + 2 * U + u) * 8 * M); xla[u].copy_from(XL + (t + 2 * U + u) * 8 * M); }
        }
#pragma unroll
        for (int u = 0; u < U; u++)
#pragma unroll
          for (int g = 0; g < G; g++) {
            acc[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc[u][g], wb[u], simd<int32_t, 8 * R>(xb[u].template select<8 * R, 1>(g * 8 * R)));
            accl[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(accl[u][g], wb[u], simd<int32_t, 8 * R>(xlb[u].template select<8 * R, 1>(g * 8 * R)));
          }
      }
#pragma unroll
      for (int g = 0; g < G; g++) {
        simd<int32_t, 16 * R> s = acc[0][g] * 256 + accl[0][g] + acc[1][g] * 256 + accl[1][g];
        s.copy_to(out + rb * 16 * M + g * 16 * R);
      }
    } else {
      simd<int32_t, 16> acc[M];
#pragma unroll
      for (int i = 0; i < M; i++) acc[i] = 0;
      simd<int32_t, 64> wa, wb;
      simd<int16_t, 32 * M> xa, xb;
      wa.copy_from(wp);
      xa.copy_from(X16);
      for (size_t t = 0; t < tiles; t += 2) {
        wb.copy_from(wp + (t + 1) * 64);
        xb.copy_from(X16 + (t + 1) * 32 * M);
#define STEP(WV, XV)                                                                                         \
  _Pragma("unroll") for (int kg = 0; kg < 4; kg++) {                                                         \
    simd<int32_t, 16> v = WV.template select<16, 1>(16 * kg);                                                \
    _Pragma("unroll") for (int p = 0; p < 8; p++) {                                                          \
      simd<int32_t, 16> wv = (v << (28 - 4 * p)) >> 28;                                                      \
      _Pragma("unroll") for (int tk = 0; tk < M; tk++) {                                                     \
        if constexpr (MODE == 0) acc[tk] += wv * int32_t(XV[tk * 32 + 8 * kg + p]);                          \
        else acc[tk] += simd<int16_t, 16>(wv) * int16_t(XV[tk * 32 + 8 * kg + p]);                                    \
      }                                                                                                      \
    }                                                                                                        \
  }
        STEP(wa, xa)
        if (t + 2 < tiles) { wa.copy_from(wp + (t + 2) * 64); xa.copy_from(X16 + (t + 2) * 32 * M); }
        STEP(wb, xb)
      }
#pragma unroll
      for (int tk = 0; tk < M; tk++) acc[tk].copy_to(out + (rb * M + tk) * 16);
    }
  });
}

template <int M>
static void bench(queue &q, const char *name, size_t N, size_t K, bool verify) {
  const size_t rowblks = N / 16, tiles = K / 32, bytes = N * K / 2;
  std::mt19937_64 rng(11);
  std::vector<int32_t> hw(bytes / 4);
  for (auto &x : hw) x = int32_t(rng());
  std::vector<int16_t> hx16(tiles * M * 32);
  for (auto &x : hx16) x = int16_t(rng());
  // DPAS activation planes: [tile][token][8 dwords] = 32 bytes per token; byte k of token = plane value of column k
  std::vector<int32_t> hh(tiles * 8 * M), hl(tiles * 8 * M);
  for (size_t t = 0; t < tiles; t++)
    for (int tk = 0; tk < M; tk++)
      for (int k = 0; k < 32; k++) {
        const int16_t v = hx16[(t * M + tk) * 32 + k];
        reinterpret_cast<int8_t *>(hh.data())[(t * M + tk) * 32 + k] = int8_t(v >> 8);
        reinterpret_cast<uint8_t *>(hl.data())[(t * M + tk) * 32 + k] = uint8_t(v & 0xFF);
      }
  const size_t nbuf = std::max<size_t>(2, (320u << 20) / bytes);
  std::vector<int32_t *> bufs;
  for (size_t b = 0; b < nbuf; b++) {
    int32_t *p = malloc_device<int32_t>(bytes / 4, q);
    if (b == 0) q.memcpy(p, hw.data(), bytes).wait();
    else { for (auto &x : hw) x = int32_t(rng()); q.memcpy(p, hw.data(), bytes).wait(); }
    bufs.push_back(p);
  }
  // buffer 0 holds the first random set: regenerate it for the check
  std::mt19937_64 rng0(11);
  for (auto &x : hw) x = int32_t(rng0());
  q.memcpy(bufs[0], hw.data(), bytes).wait();
  int16_t *X16 = malloc_device<int16_t>(hx16.size(), q);
  int32_t *XH = malloc_device<int32_t>(hh.size(), q), *XL = malloc_device<int32_t>(hl.size(), q), *out = malloc_device<int32_t>(rowblks * 16 * M, q);
  q.memcpy(X16, hx16.data(), hx16.size() * 2).wait();
  q.memcpy(XH, hh.data(), hh.size() * 4).wait();
  q.memcpy(XL, hl.data(), hl.size() * 4).wait();
  auto run = [&](auto &&fn, const char *lab, bool check) {
    fn(0);
    q.wait();
    if (check) {
      std::vector<int32_t> r(rowblks * 16 * M);
      q.memcpy(r.data(), out, r.size() * 4).wait();
      long bad = 0, tested = 0;
      for (size_t rb : {size_t(0), rowblks / 2, rowblks - 1})
        for (int tk = 0; tk < M; tk++)
          for (int n = 0; n < 16; n++) {
            int64_t ref = 0;
            for (size_t t = 0; t < tiles; t++)
              for (int kg = 0; kg < 4; kg++) {
                const uint32_t d = uint32_t(hw[(rb * tiles + t) * 64 + kg * 16 + n]);
                for (int p = 0; p < 8; p++) ref += int64_t(int32_t(int32_t(d << (28 - 4 * p)) >> 28)) * hx16[(t * M + tk) * 32 + 8 * kg + p];
              }
            // DPAS output layout: [token][n] per row block (same for the SIMD kernel)
            ++tested;
            if (int32_t(ref) != r[(rb * M + tk) * 16 + n]) ++bad;
          }
      printf("    check %-34s: %ld values, %ld wrong\n", lab, tested, bad);
    }
    for (int r = 0; r < 5; r++) fn(r);
    q.wait();
    const int reps = 100;
    auto t0 = std::chrono::steady_clock::now();
    for (int r = 0; r < reps; r++) fn(r);
    q.wait();
    const double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count() / reps;
    const double mac = double(N) * K * M; // logical multiply-adds
    printf("  %-44s %9.1f us %7.0f GB/s %8.2f TOPS (2MNK)\n", lab, us, bytes / us / 1e3, 2 * mac / us / 1e6);
  };
  printf("\n%s m=%d  N=%zu K=%zu  (%.1f MB 4-bit, %zu threads)\n", name, M, N, K, bytes / 1e6, rowblks);
  run([&](int r) { launch<M, 0>(q, bufs[r % nbuf], X16, XH, XL, out, rowblks, tiles); }, "SIMD packed int4, int32 mad", verify);
  run([&](int r) { launch<M, 1>(q, bufs[r % nbuf], X16, XH, XL, out, rowblks, tiles); }, "SIMD packed int4, int16 x int16 -> int32", verify);
  run([&](int r) { launch<M, 2>(q, bufs[r % nbuf], X16, XH, XL, out, rowblks, tiles); }, "DPAS s4 x s8 (two byte planes)", verify);
  for (auto p : bufs) free(p, q);
  free(X16, q); free(XH, q); free(XL, q); free(out, q);
}
int main(int argc, char **argv) {
  queue q(gpu_selector_v, property::queue::in_order{});
  printf("device %s\n", q.get_device().get_info<sycl::info::device::name>().c_str());
  const bool quick = argc > 1;
  bench<1>(q, "check shape", 256, 1024, true);
  bench<8>(q, "check shape", 256, 1024, true);
  if (quick) return 0;
  struct S { const char *n; size_t N, K; };
  for (const S &s : {S{"out projection", 5120, 6144}, S{"gate+up", 34816, 5120}, S{"GDN in-proj", 16384, 5120}}) {
    bench<1>(q, s.n, s.N, s.K, false);
    bench<8>(q, s.n, s.N, s.K, false);
    bench<16>(q, s.n, s.N, s.K, false);
  }
}
