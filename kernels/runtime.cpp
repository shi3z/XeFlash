// libxfk runtime: device discovery, USM allocation, copies, synchronisation.
#include <cstring>
#include <exception>

#include "ctx.hpp"

namespace {
thread_local std::string g_last_error;

uint64_t free_vram(const sycl::device &d) {
  // Needs ZES_ENABLE_SYSMAN=1 in the environment; otherwise the aspect is absent.
  if (d.has(sycl::aspect::ext_intel_free_memory))
    return d.get_info<sycl::ext::intel::info::device::free_memory>();
  return 0;
}
} // namespace

void xf_set_error(const std::string &msg) { g_last_error = msg; }

int xf_translate_exception(const char *where) {
  try {
    throw;
  } catch (const sycl::exception &e) {
    std::string what = e.what();
    g_last_error = std::string(where) + ": " + what;
    if (what.find("DEVICE_LOST") != std::string::npos) return XF_ERR_DEVICE_LOST;
    if (what.find("OUT_OF_DEVICE_MEMORY") != std::string::npos ||
        what.find("OUT_OF_HOST_MEMORY") != std::string::npos ||
        what.find("OUT_OF_RESOURCES") != std::string::npos)
      return XF_ERR_OOM;
    return XF_ERR_RUNTIME;
  } catch (const std::exception &e) {
    g_last_error = std::string(where) + ": " + e.what();
    return XF_ERR_RUNTIME;
  } catch (...) {
    g_last_error = std::string(where) + ": unknown exception";
    return XF_ERR_RUNTIME;
  }
}

extern "C" {

const char *xf_last_error(void) { return g_last_error.c_str(); }

int xf_ctx_create(xf_ctx **out) {
  if (!out) return XF_ERR_INVALID;
  *out = nullptr;
  return xf_guard("xf_ctx_create", [&]() -> int {
    // Intel GPUs only: XeFlash must never place work on another vendor's card.
    sycl::device chosen;
    bool found = false;
    for (const auto &d : sycl::device::get_devices(sycl::info::device_type::gpu)) {
      if (d.get_info<sycl::info::device::vendor_id>() != 0x8086) continue;
      if (d.get_backend() != sycl::backend::ext_oneapi_level_zero) continue;
      chosen = d;
      found = true;
      break;
    }
    if (!found) {
      xf_set_error("no Intel Level Zero GPU found (is the oneAPI runtime on LD_LIBRARY_PATH?)");
      return XF_ERR_NO_DEVICE;
    }
    auto async_handler = [](sycl::exception_list l) {
      for (auto &e : l) std::rethrow_exception(e);
    };
    *out = new xf_ctx(sycl::queue(chosen, async_handler, sycl::property::queue::in_order{}));
    return XF_OK;
  });
}

void xf_ctx_destroy(xf_ctx *ctx) {
  if (!ctx) return;
  try {
    ctx->q.wait();
  } catch (...) {
  }
  delete ctx;
}

int xf_device_info(xf_ctx *ctx, xf_devinfo *out) {
  if (!ctx || !out) return XF_ERR_INVALID;
  return xf_guard("xf_device_info", [&]() -> int {
    std::memset(out, 0, sizeof(*out));
    const sycl::device d = ctx->q.get_device();
    std::strncpy(out->name, d.get_info<sycl::info::device::name>().c_str(), sizeof(out->name) - 1);
    std::strncpy(out->driver, d.get_info<sycl::info::device::driver_version>().c_str(),
                 sizeof(out->driver) - 1);
    out->vram_total = d.get_info<sycl::info::device::global_mem_size>();
    out->vram_free = free_vram(d);
    out->max_alloc = d.get_info<sycl::info::device::max_mem_alloc_size>();
    if (d.has(sycl::aspect::ext_intel_gpu_eu_count))
      out->eu_count = d.get_info<sycl::ext::intel::info::device::gpu_eu_count>();
    if (d.has(sycl::aspect::ext_intel_gpu_hw_threads_per_eu))
      out->threads_per_eu = d.get_info<sycl::ext::intel::info::device::gpu_hw_threads_per_eu>();
    out->slm_bytes = (uint32_t)d.get_info<sycl::info::device::local_mem_size>();
    out->clock_mhz = d.get_info<sycl::info::device::max_clock_frequency>();
    return XF_OK;
  });
}

void *xf_alloc(xf_ctx *ctx, size_t bytes) {
  if (!ctx || bytes == 0) {
    xf_set_error("xf_alloc: invalid argument");
    return nullptr;
  }
  try {
    const sycl::device d = ctx->q.get_device();
    const uint64_t fr = free_vram(d);
    // Keep 256 MiB of headroom: overcommitting does not fail on this driver,
    // it migrates buffers to system memory.
    if (fr != 0 && bytes + (256ull << 20) > fr) {
      xf_set_error("xf_alloc: request of " + std::to_string(bytes) + " bytes exceeds free VRAM (" +
                   std::to_string(fr) + " bytes)");
      return nullptr;
    }
    void *p = sycl::aligned_alloc_device(4096, bytes, ctx->q);
    if (!p) xf_set_error("xf_alloc: device allocation of " + std::to_string(bytes) + " bytes failed");
    return p;
  } catch (...) {
    xf_translate_exception("xf_alloc");
    return nullptr;
  }
}

int xf_free(xf_ctx *ctx, void *ptr) {
  if (!ctx) return XF_ERR_INVALID;
  if (!ptr) return XF_OK;
  return xf_guard("xf_free", [&]() -> int {
    ctx->q.wait_and_throw();
    sycl::free(ptr, ctx->q);
    return XF_OK;
  });
}

int xf_write(xf_ctx *ctx, void *dev_dst, const void *host_src, size_t bytes) {
  if (!ctx || !dev_dst || !host_src) return XF_ERR_INVALID;
  return xf_guard("xf_write", [&]() -> int {
    ctx->q.memcpy(dev_dst, host_src, bytes).wait_and_throw();
    return XF_OK;
  });
}

int xf_read(xf_ctx *ctx, void *host_dst, const void *dev_src, size_t bytes) {
  if (!ctx || !host_dst || !dev_src) return XF_ERR_INVALID;
  return xf_guard("xf_read", [&]() -> int {
    ctx->q.memcpy(host_dst, dev_src, bytes).wait_and_throw();
    return XF_OK;
  });
}

int xf_wait(xf_ctx *ctx) {
  if (!ctx) return XF_ERR_INVALID;
  return xf_guard("xf_wait", [&]() -> int {
    ctx->q.wait_and_throw();
    return XF_OK;
  });
}

int xf_noop(xf_ctx *ctx) {
  if (!ctx) return XF_ERR_INVALID;
  return xf_guard("xf_noop", [&]() -> int {
    ctx->q.single_task([]() {});
    return XF_OK;
  });
}

} // extern "C"
