// xbd: experimental backend that drives YASAKANI's "bdraft2" drafter from
// another engine's hidden states.
//
// This file lives in the XeFlash tree and only INCLUDES the YASAKANI B60
// port's headers (read-only, from $YASAKANI_XE/src). No YASAKANI file is
// modified and libyskn is not used: yx::Draft is header-only and needs from
// the main engine only a queue, the allocator and the token embedding, so the
// yx::Engine is constructed with upto = 0 (no layer of the 10 GB main model is
// loaded).
//
// Data path: the caller passes the five tap states of the rows committed by
// its last main pass in host memory, laid out [tap][16 rows][5120] f32 (the
// drafter's own `cap` layout). One host-to-device copy per call; the two
// engines keep separate queues.
#include "draft.hpp"

#include <algorithm>
#include <cstring>
#include <string>

namespace {
thread_local std::string g_err;
struct Xbd {
  yx::Engine E;
  yx::Draft D;
  yx::SmpParams smp; // greedy (on = false)
  float *stage = nullptr; // staging copy of up to 4 tap blocks (64 rows), see xbd_ctx_dev_blocks
  Xbd(const char *main_path, const char *draft_path, int max_ctx) : E(main_path, 0, 16) {
    D.load(E, draft_path, max_ctx);
    stage = sycl::malloc_device<float>(size_t(4) * 5 * 16 * 5120, E.q);
  }
  ~Xbd() { if (stage) sycl::free(stage, E.q); }
};
template <typename F> int guard(F &&f) {
  try {
    f();
    return 0;
  } catch (const std::exception &e) {
    g_err = e.what();
    return 1;
  } catch (...) {
    g_err = "unknown exception";
    return 1;
  }
}
void put_taps(Xbd *x, const float *taps) {
  // Whole cap block: 5 taps x 16 rows x 5120 f32 = 1.6 MB.
  x->E.q.memcpy(x->D.cap, taps, size_t(5) * 16 * 5120 * sizeof(float)).wait_and_throw();
}
} // namespace

extern "C" {

const char *xbd_last_error(void) { return g_err.c_str(); }

int xbd_open(const char *main_yskn, const char *draft_yskn, int max_ctx, void **out) {
  *out = nullptr;
  return guard([&] { *out = new Xbd(main_yskn, draft_yskn, max_ctx); });
}

void xbd_close(void *h) { delete static_cast<Xbd *>(h); }

int xbd_reset(void *h) {
  return guard([&] { static_cast<Xbd *>(h)->D.reset(); });
}

// Append the K/V of n committed rows (ring positions pos0 .. pos0 + n - 1).
int xbd_ctx(void *h, const float *taps, int n, int pos0) {
  return guard([&] {
    auto *x = static_cast<Xbd *>(h);
    put_taps(x, taps);
    x->D.ctx(n, pos0);
    x->E.q.wait_and_throw();
  });
}

// Same as xbd_ctx, with the taps read from the other engine's device buffer (see xbd_step_dev): a device-to-device copy of the tap block and the ring
// update are queued on the drafter's queue and NOT waited for (the queue is in order: the next xbd_step / xbd_ctx_dev runs after them). The copy itself is
// waited for, because the other engine overwrites its tap block with its next pass. Returns 2 if dev_taps is not a device allocation of this context.
int xbd_ctx_dev(void *h, const float *dev_taps, int n, int pos0) {
  auto *x = static_cast<Xbd *>(h);
  try {
    if (sycl::get_pointer_type(dev_taps, x->E.q.get_context()) != sycl::usm::alloc::device) return 2;
  } catch (...) {
    return 2;
  }
  return guard([&] {
    x->E.q.memcpy(x->D.cap, dev_taps, size_t(5) * 16 * 5120 * sizeof(float)).wait();
    x->D.ctx(n, pos0);
  });
}

// Ring catch-up with n_total committed rows held in nblocks (<= 4) consecutive tap blocks of the other engine (block b = rows 16 b .. 16 b + 15, each [5][16][5120] f32, contiguous), ring positions pos0 ..:
// one device-to-device copy of all blocks into a staging buffer (waited for: the other engine overwrites its taps with its next pass), then, queued without waiting, per block a staging -> capture copy and the
// ring update. The queue is in order, so a later xbd_step runs after all of them. Returns 2 if dev_taps is not a device allocation of this context.
int xbd_ctx_dev_blocks(void *h, const float *dev_taps, int nblocks, int n_total, int pos0) {
  auto *x = static_cast<Xbd *>(h);
  try {
    if (sycl::get_pointer_type(dev_taps, x->E.q.get_context()) != sycl::usm::alloc::device) return 2;
  } catch (...) {
    return 2;
  }
  if (nblocks < 1 || nblocks > 4) return 1;
  return guard([&] {
    const size_t blk = size_t(5) * 16 * 5120;
    x->E.q.memcpy(x->stage, dev_taps, size_t(nblocks) * blk * sizeof(float)).wait();
    for (int b = 0; b < nblocks; b++) {
      x->E.q.memcpy(x->D.cap, x->stage + size_t(b) * blk, blk * sizeof(float));
      x->D.ctx(std::min(16, n_total - 16 * b), pos0 + 16 * b);
    }
  });
}

// Catch the ring up with n committed rows (n may be 0, then taps is ignored),
// then draft one block of R rows (8 or 16): frontier token `tok` at position
// p, R - 1 drafts for positions p + 1 .. p + R - 1 written to out.
int xbd_step(void *h, const float *taps, int n, int pos0, int R, int tok, int p, int *out) {
  return guard([&] {
    auto *x = static_cast<Xbd *>(h);
    if (n > 0) put_taps(x, taps);
    x->D.step(n, pos0, R, tok, p, x->smp, out);
  });
}

// Same as xbd_step, but the taps are read straight from the other engine's
// device buffer (same [tap][16][5120] layout). Valid only if that buffer
// belongs to this queue's SYCL context (both engines on the default platform
// context) and the other engine's queue has finished writing it; returns 2
// if the pointer is not a device allocation of this context.
int xbd_step_dev(void *h, const float *dev_taps, int n, int pos0, int R, int tok, int p, int *out) {
  auto *x = static_cast<Xbd *>(h);
  try {
    if (sycl::get_pointer_type(dev_taps, x->E.q.get_context()) != sycl::usm::alloc::device) return 2;
  } catch (...) {
    return 2;
  }
  return guard([&] {
    if (n > 0) x->E.q.memcpy(x->D.cap, dev_taps, size_t(5) * 16 * 5120 * sizeof(float));
    x->D.step(n, pos0, R, tok, p, x->smp, out);
  });
}

} // extern "C"
