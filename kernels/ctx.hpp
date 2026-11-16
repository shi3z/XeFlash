// Internal to libxfk: the context object and error plumbing.
#pragma once
#include <sycl/sycl.hpp>

#include <string>

#include "include/xfk.h"

struct xf_ctx {
  sycl::queue q;
  explicit xf_ctx(sycl::queue queue) : q(std::move(queue)) {}
};

void xf_set_error(const std::string &msg);
// Translate the in-flight exception into a status + thread-local message.
int xf_translate_exception(const char *where);

// Run `fn`, mapping any exception to an xf_status.
template <typename F> int xf_guard(const char *where, F &&fn) {
  try {
    return fn();
  } catch (...) {
    return xf_translate_exception(where);
  }
}
