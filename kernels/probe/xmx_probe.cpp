// xmx_probe: where does the time of a 4-bit weight GEMM go? Same thread layout as the production GEMM (one thread = 16 weight rows, all tiles of the
// column range, R tokens x G groups, U tiles per trip, two byte planes of 16-bit activations) and the same weight layout [row block][tile][256 B],
// weights cold (rotated over buffers larger than L2), in-order queue. Only the body of the tile loop differs. Does NOT touch the production kernels.
//   0 read the weight tiles only                           1 DPAS only, operands in registers, the GEMM's own chain structure (2*U*G chains)
//   2 DPAS only, 8 independent chains (peak structure)      3 operands from SLM (staged once) + DPAS
//   4 4-bit weights streamed from memory + DPAS (X in registers)     5 weights streamed + s4 -> s8 expansion, no DPAS
//   6 weights streamed + expansion + s8 DPAS                7 weights + both activation planes streamed + DPAS (the production loop without the double buffer)
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

ESIMD_INLINE simd<int32_t, 128> expand_s4_to_s8(simd<int32_t, 64> p) SYCL_ESIMD_FUNCTION {
  simd<int32_t, 128> out;
  auto words = p.template bit_cast_view<uint16_t>();
#pragma unroll
  for (int r = 0; r < 4; r++) {
#pragma unroll
    for (int half = 0; half < 2; half++) {
      simd<uint16_t, 16> w = words.template select<16, 2>(32 * r + half);
      simd<uint32_t, 16> v = convert<uint32_t>(w);
      simd<uint32_t, 16> e = (v & 0xFu) | ((v & 0xF0u) << 4) | ((v & 0xF00u) << 8) | ((v & 0xF000u) << 12);
      simd<int8_t, 64> b = e.template bit_cast_view<int8_t>();
      b = (b ^ int8_t(8)) - int8_t(8);
      out.template select<16, 1>(16 * (2 * r + half)) = b.template bit_cast_view<int32_t>();
    }
  }
  return out;
}

template <int R, int G, int U, int MODE>
static sycl::event launch(queue &q, const int32_t *W, const int32_t *X, const int32_t *XL, int32_t *out, size_t rowblks, size_t tiles, size_t xstride_rt = 0, size_t wstride_rt = 0) {
  constexpr int WDW = 64, XDW = 8 * R * G;
  constexpr size_t WG = 8; // threads per work-group for the SLM mode
  auto body = [=](size_t rb, size_t slm_base) SYCL_ESIMD_FUNCTION {
    const int32_t *wp = W + rb * tiles * WDW;
    simd<int32_t, 16 * R> acc[U][G], accl[U][G];
#pragma unroll
    for (int u = 0; u < U; u++)
#pragma unroll
      for (int g = 0; g < G; g++) acc[u][g] = accl[u][g] = 0;
    simd<int32_t, 16> fold(0);
    simd<int32_t, XDW> xr, xlr;
    xr.copy_from(X + rb % 64 * XDW);
    xlr.copy_from(XL + rb % 64 * XDW);
    simd<int32_t, WDW> wr;
    wr.copy_from(wp);
    if constexpr (MODE == 3) {
      // stage U tiles of weights and activations in this thread's SLM slice (global -> SLM once), then read them back every trip
#pragma unroll
      for (int u = 0; u < U; u++) {
        simd<int32_t, WDW> w;
        w.copy_from(wp + u * WDW);
        es::slm_block_store<int32_t, WDW>(uint32_t(slm_base + u * (WDW + 2 * XDW) * 4), w);
        es::slm_block_store<int32_t, XDW>(uint32_t(slm_base + (u * (WDW + 2 * XDW) + WDW) * 4), xr);
        es::slm_block_store<int32_t, XDW>(uint32_t(slm_base + (u * (WDW + 2 * XDW) + WDW + XDW) * 4), xlr);
      }
    }
    if constexpr (MODE == 8 || MODE == 9 || MODE == 10 || MODE == 11) {
      const size_t WS = MODE == 11 ? wstride_rt : size_t(WDW), XS = MODE == 11 ? xstride_rt : size_t(XDW);
      simd<int32_t, WDW> wa[U], wb[U];
      simd<int32_t, XDW> xa[U], xb[U], xla[U], xlb[U];
#pragma unroll
      for (int u = 0; u < U; u++) {
        wa[u].copy_from(wp + u * WS);
        xa[u].copy_from(X + u * XS);
        xla[u].copy_from(XL + u * XS);
      }
      for (size_t t = 0; t < tiles; t += 2 * U) {
#pragma unroll
        for (int u = 0; u < U; u++) {
          wb[u].copy_from(wp + (t + U + u) * WS);
          xb[u].copy_from(X + (t + U + u) * XS);
          xlb[u].copy_from(XL + (t + U + u) * XS);
        }
#pragma unroll
        for (int u = 0; u < U; u++)
#pragma unroll
          for (int g = 0; g < G; g++) {
            acc[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc[u][g], wa[u], simd<int32_t, 8 * R>(xa[u].template select<8 * R, 1>(g * 8 * R)));
            accl[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(accl[u][g], wa[u], simd<int32_t, 8 * R>(xla[u].template select<8 * R, 1>(g * 8 * R)));
          }
        if (t + 2 * U < tiles) {
#pragma unroll
          for (int u = 0; u < U; u++) {
            wa[u].copy_from(wp + (t + 2 * U + u) * WS);
            xa[u].copy_from(X + (t + 2 * U + u) * XS);
            xla[u].copy_from(XL + (t + 2 * U + u) * XS);
          }
        }
#pragma unroll
        for (int u = 0; u < U; u++)
#pragma unroll
          for (int g = 0; g < G; g++) {
            acc[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc[u][g], wb[u], simd<int32_t, 8 * R>(xb[u].template select<8 * R, 1>(g * 8 * R)));
            accl[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(accl[u][g], wb[u], simd<int32_t, 8 * R>(xlb[u].template select<8 * R, 1>(g * 8 * R)));
          }
      }
    } else if constexpr (MODE == 2) {
      simd<int32_t, 16 * R> c[8];
#pragma unroll
      for (int i = 0; i < 8; i++) c[i] = 0;
      for (size_t t = 0; t < tiles; t += 4) {
#pragma unroll
        for (int k = 0; k < 4 * 2 * G; k++) {
          const int g = (k / 2) % G;
          simd<int32_t, 8 * R> a = ((k & 1) ? xlr : xr).template select<8 * R, 1>(g * 8 * R);
          c[k % 8] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(c[k % 8], wr, a);
        }
      }
#pragma unroll
      for (int i = 0; i < 8; i++) acc[0][0] += c[i];
    } else {
      for (size_t t = 0; t < tiles; t += U) {
#pragma unroll
        for (int u = 0; u < U; u++) {
          simd<int32_t, WDW> w = wr;
          simd<int32_t, XDW> xv = xr, xl = xlr;
          if constexpr (MODE == 0 || MODE >= 4) w.copy_from(wp + (t + u) * WDW);
          if constexpr (MODE == 7) {
            xv.copy_from(X + (t + u) * XDW);   // production: [tile][token group][8 dwords per token], every thread walks the same tiles
            xl.copy_from(XL + (t + u) * XDW);
          }
          if constexpr (MODE == 3) {
            w = es::slm_block_load<int32_t, WDW>(uint32_t(slm_base + u * (WDW + 2 * XDW) * 4));
            xv = es::slm_block_load<int32_t, XDW>(uint32_t(slm_base + (u * (WDW + 2 * XDW) + WDW) * 4));
            xl = es::slm_block_load<int32_t, XDW>(uint32_t(slm_base + (u * (WDW + 2 * XDW) + WDW + XDW) * 4));
          }
          if constexpr (MODE == 0) {
#pragma unroll
            for (int i = 0; i < WDW; i += 16) fold ^= w.template select<16, 1>(i);
          } else if constexpr (MODE == 5) {
            simd<int32_t, 128> w8 = expand_s4_to_s8(w);
#pragma unroll
            for (int i = 0; i < 128; i += 16) fold ^= w8.template select<16, 1>(i);
          } else if constexpr (MODE == 6) {
            simd<int32_t, 128> w8 = expand_s4_to_s8(w);
#pragma unroll
            for (int g = 0; g < G; g++) {
              acc[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s8, PT::s8>(acc[u][g], w8, simd<int32_t, 8 * R>(xv.template select<8 * R, 1>(g * 8 * R)));
              accl[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s8, PT::u8>(accl[u][g], w8, simd<int32_t, 8 * R>(xl.template select<8 * R, 1>(g * 8 * R)));
            }
          } else {
#pragma unroll
            for (int g = 0; g < G; g++) {
              acc[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::s8>(acc[u][g], w, simd<int32_t, 8 * R>(xv.template select<8 * R, 1>(g * 8 * R)));
              accl[u][g] = xmx::dpas<8, R, int32_t, int32_t, int32_t, int32_t, PT::s4, PT::u8>(accl[u][g], w, simd<int32_t, 8 * R>(xl.template select<8 * R, 1>(g * 8 * R)));
            }
          }
        }
      }
    }
    if constexpr (MODE == 9 || MODE == 10 || MODE == 11) {
      // production epilogue: sum the U partial accumulators, convert to float, scale by row / token scale, write [token][row]
      simd<float, 16> rsv(0.01f);
      simd<float, 16> rbv(0.0f);
#pragma unroll
      for (int g = 0; g < G; g++) {
        simd<int32_t, 16 * R> sa = acc[0][g], sl = accl[0][g];
#pragma unroll
        for (int u = 1; u < U; u++) { sa += acc[u][g]; sl += accl[u][g]; }
#pragma unroll
        for (int m = 0; m < R; m++) {
          simd<int32_t, 16> si = sa.template select<16, 1>(16 * m), li = sl.template select<16, 1>(16 * m);
          simd<float, 16> f = convert<float>(si);
          f = f * 256.0f + convert<float>(li);
          f = f + 0.5f;
          f = f * rsv * 0.02f + rbv;
          f.copy_to(reinterpret_cast<float *>(out) + size_t(g * R + m) * (rowblks * 16) + rb * 16);
        }
      }
    } else {
      simd<int32_t, 16 * R> s = acc[0][0];
#pragma unroll
      for (int u = 0; u < U; u++)
#pragma unroll
        for (int g = 0; g < G; g++) s += acc[u][g] ^ accl[u][g];
      s.template select<16, 1>(0) ^= fold;
      s.copy_to(out + rb * 16 * R);
    }
  };
  if constexpr (MODE == 3) {
    return q.parallel_for(nd_range<1>(rowblks, WG), [=](nd_item<1> it) SYCL_ESIMD_KERNEL {
      es::slm_init<WG * U * (WDW + 2 * XDW) * 4>();
      body(it.get_global_id(0), it.get_local_id(0) * U * (WDW + 2 * XDW) * 4);
    });
  }
  if constexpr (MODE == 10 || MODE == 11) {
    return q.parallel_for(range<1>(rowblks * 1 * 1), [=](id<1> id) SYCL_ESIMD_KERNEL {
      const size_t idx = id[0], rb = idx % rowblks, tg = (idx / rowblks) % 1, seg = idx / (rowblks * 1);
      body(rb + tg + seg, 0);
    });
  }
  return q.parallel_for(range<1>(rowblks), [=](id<1> id) SYCL_ESIMD_KERNEL { body(id[0], 0); });
}

template <int R, int G, int U>
static void run_cfg(queue &q, const char *label, size_t N, size_t K, int m) {
  const size_t rowblks = N / 16, tiles = K / 32, bytes = N * K / 2;
  const size_t nbuf = std::getenv("PROBE_NBUF") ? std::atoi(std::getenv("PROBE_NBUF")) : std::max<size_t>(2, (320u << 20) / bytes);
  std::mt19937_64 rng(5);
  std::vector<int32_t> h(bytes / 4);
  std::vector<int32_t *> bufs;
  for (size_t b = 0; b < nbuf; b++) {
    for (auto &x : h) x = int32_t(rng());
    static const size_t align = std::getenv("PROBE_ALIGN") ? std::atoll(std::getenv("PROBE_ALIGN")) : 0; // 0 = malloc_device
    int32_t *p = align ? static_cast<int32_t *>(aligned_alloc_device(align, bytes, q)) : malloc_device<int32_t>(bytes / 4, q);
    q.memcpy(p, h.data(), bytes).wait();
    bufs.push_back(p);
  }
  const size_t XDW_RT = size_t(8 * R * G);
  const size_t xn = size_t(8 * R * G) * 1024;
  const size_t outn = std::max<size_t>(rowblks * 16 * R * 2, size_t(R * G) * rowblks * 16);
  std::vector<int32_t> hx(xn);
  for (auto &x : hx) x = int32_t(rng());
  int32_t *X = malloc_device<int32_t>(xn, q), *XL = malloc_device<int32_t>(xn, q), *out = malloc_device<int32_t>(std::max<size_t>(rowblks * 16 * R * 2, size_t(R * G) * rowblks * 16), q);
  q.memcpy(X, hx.data(), xn * 4).wait();
  q.memcpy(XL, hx.data(), xn * 4).wait();
  const char *names[] = {"0 read weights only", "1 DPAS only (GEMM chain structure)", "2 DPAS only (8 chains)", "3 SLM operands + DPAS",
                         "4 weights streamed + DPAS (X in regs)", "5 weights + s4->s8 expansion, no DPAS", "6 weights + expansion + s8 DPAS", "7 weights + X planes streamed + DPAS", "8 = 7 with the next tiles requested first", "9 = 8 with the production epilogue", "10 = 9 with 64-bit index arithmetic", "11 = 10 with run-time strides"};
  const double dpas_per_thread = double(tiles) * 2 * G;                       // two byte planes
  const double ops_per_dpas = double(R) * 16 * 32 * 2;
  const double ops = dpas_per_thread * rowblks * ops_per_dpas;
  printf("\n%s  N=%zu K=%zu (%.1f MB 4-bit), tokens/thread %d x %d groups, U=%d: %zu threads, %.0f dpas per thread, %.2f GOP issued (1 dpas = %.0f ops)\n", label, N, K, bytes / 1e6, R, G, U, rowblks,
         dpas_per_thread, ops / 1e9, ops_per_dpas);
  printf("  %-42s %9s %9s %9s %12s\n", "mode", "us", "GB/s", "TOPS", "% of 196.5");
  auto timeit = [&](auto &&fn, int mode) {
    for (int r = 0; r < 10; r++) fn(r);
    q.wait();
    static const int reps = std::getenv("PROBE_REPS") ? std::atoi(std::getenv("PROBE_REPS")) : 200;
    auto t0 = std::chrono::steady_clock::now();
    for (int r = 0; r < reps; r++) fn(r);
    q.wait();
    const double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - t0).count() / reps;
    printf("  %-42s %9.1f %9.0f %9.1f %11.1f%%\n", names[mode], us, bytes / us / 1e3, ops / us / 1e6, 100 * ops / us / 1e6 / 196.5);
  };
#define MODE_RUN(M) timeit([&](int r) { launch<R, G, U, M>(q, bufs[r % nbuf], X, XL, out, rowblks, tiles, size_t(XDW_RT) + size_t(std::getenv("PROBE_NEVER") ? 1 : 0), size_t(64)); }, M);
  MODE_RUN(0) MODE_RUN(1) MODE_RUN(2) MODE_RUN(3) MODE_RUN(4) MODE_RUN(5) MODE_RUN(6) MODE_RUN(7) MODE_RUN(8) MODE_RUN(9) MODE_RUN(10) MODE_RUN(11)
#undef MODE_RUN
  for (auto p : bufs) free(p, q);
  free(X, q);
  free(XL, q);
  free(out, q);
}

int main() {
  queue q(gpu_selector_v, property::queue::in_order{});
  if (std::getenv("PROBE_ONLY")) { run_cfg<8, 1, 2>(q, "gate+up m=8", 34816, 5120, 8); return 0; }
  struct S { const char *n; size_t N, K; };
  const S shapes[] = {{"out projection", 5120, 6144}, {"down", 5120, 17408}, {"gate+up", 34816, 5120}, {"GDN in-proj", 16384, 5120}, {"attention qkv", 14336, 5120}, {"lm_head", 248320, 5120}};
  printf("device %s, in-order queue, cold weights\n", q.get_device().get_info<sycl::info::device::name>().c_str());
  for (const S &s : shapes) {
    run_cfg<1, 1, 2>(q, (std::string(s.n) + " m=1").c_str(), s.N, s.K, 1);
    run_cfg<8, 1, 2>(q, (std::string(s.n) + " m=8").c_str(), s.N, s.K, 8);
    run_cfg<8, 2, 1>(q, (std::string(s.n) + " m=16").c_str(), s.N, s.K, 16);
  }
}
