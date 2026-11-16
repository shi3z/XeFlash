/* xfk.h — C ABI between the Rust host (xeflash-runtime) and the SYCL/ESIMD
 * kernel library (libxfk.so).
 *
 * Rules of this boundary:
 *  - plain C types only; every function returns an xf_status (0 = ok) unless
 *    it returns a pointer (NULL = failure);
 *  - kernel entry points only SUBMIT work to the in-order queue; the host
 *    decides when to synchronise with xf_wait();
 *  - on failure, xf_last_error() returns a thread-local message.
 */
#ifndef XFK_H
#define XFK_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct xf_ctx xf_ctx;

typedef enum {
  XF_OK = 0,
  XF_ERR_INVALID = 1,     /* bad argument / unsupported kernel variant */
  XF_ERR_NO_DEVICE = 2,   /* no Intel GPU with the required features */
  XF_ERR_OOM = 3,         /* device allocation failed or would overcommit */
  XF_ERR_DEVICE_LOST = 4, /* the GPU was reset / hung while we were using it */
  XF_ERR_RUNTIME = 5      /* any other SYCL / driver error */
} xf_status;

typedef struct {
  char name[128];
  char driver[64];
  uint64_t vram_total;      /* bytes */
  uint64_t vram_free;       /* bytes; 0 when the driver does not report it */
  uint64_t max_alloc;       /* largest single USM allocation, bytes */
  uint32_t eu_count;        /* vector engines */
  uint32_t threads_per_eu;
  uint32_t slm_bytes;       /* shared local memory per work-group */
  uint32_t clock_mhz;
} xf_devinfo;

const char *xf_last_error(void);

int xf_ctx_create(xf_ctx **out);
void xf_ctx_destroy(xf_ctx *ctx);
int xf_device_info(xf_ctx *ctx, xf_devinfo *out);

/* Device USM, 4096-byte aligned. Refuses requests larger than the free VRAM
 * the driver reports (the xe driver would otherwise silently spill to system
 * memory and run two orders of magnitude slower). */
void *xf_alloc(xf_ctx *ctx, size_t bytes);
int xf_free(xf_ctx *ctx, void *ptr);
/* Synchronous host<->device copies. */
int xf_write(xf_ctx *ctx, void *dev_dst, const void *host_src, size_t bytes);
int xf_read(xf_ctx *ctx, void *host_dst, const void *dev_src, size_t bytes);
/* Wait for everything submitted so far; reports asynchronous errors. */
int xf_wait(xf_ctx *ctx);
/* Submit an empty kernel (launch-overhead measurement). */
int xf_noop(xf_ctx *ctx);

/* ---- GEMM -------------------------------------------------------------
 *
 * y[m][row] = rs[row] * ts[m] * (toff[m] + sum_col W[row][col] * x[m][col])
 *
 * Integer formats are exact: the sum is an int32 DPAS accumulation, so the
 * result does not depend on the kernel variant, the token batch size or the
 * number of column segments.
 *
 * Weights are stored in "XMX tile order": the matrix is cut into tiles of
 * 16 rows x TC columns (TC = 32 for integer weights, 16 for bf16) and every
 * tile is stored exactly as the DPAS B operand wants it, so the kernel block
 * loads a tile and feeds it to the systolic array with no reordering:
 *
 *   W_dev[rowblk][tile][reg r][lane n] : 32-bit word holding the columns
 *       tile*TC + r*E .. + E-1 of row rowblk*16 + n,
 *   E = 8 (s4), 16 (s2), 4 (s8), 2 (bf16) elements per 32-bit word,
 *   element j at bit offset j*bits.
 *
 * Activations are stored as x_dev[tile][m_pad][TC elements] (s8, or bf16),
 * i.e. the DPAS A operand of all tokens of one tile is contiguous.
 * m_pad is the token count rounded up to the kernel's tokens-per-thread.
 */
typedef enum {
  XF_W_S4 = 0,       /* packed signed 4-bit, native DPAS s4 x s8 */
  XF_W_S2 = 1,       /* packed signed 2-bit, native DPAS s2 x s8 */
  XF_W_S8 = 2,       /* signed 8-bit, DPAS s8 x s8 (uncompressed reference) */
  XF_W_BF16 = 3,     /* bfloat16 weights and activations (float reference) */
  XF_W_S4_EXP8 = 4,  /* packed s4 expanded to s8 in registers, then s8 x s8 */
  XF_W_S3 = 5        /* packed unsigned 3-bit codes spread to u4 in registers */
} xf_wfmt;

typedef struct {
  int32_t wfmt;          /* xf_wfmt */
  int32_t rows;          /* multiple of 16 */
  int32_t cols;          /* multiple of TC * unroll (all model shapes are) */
  int32_t m;             /* tokens (activation rows) actually used */
  int32_t tokens_per_thread; /* 1, 8, 16 or 32: selects the kernel variant */
  int32_t segs;          /* column segments per row block (>=1); >1 needs ypart */
  int32_t a16;           /* 1: 16-bit activations as s8 hi (x) + u8 lo (xlo) */
  int32_t reserved;
  const void *w;         /* device: tile-ordered weights */
  const void *x;         /* device: activations (hi part when a16) */
  const void *xlo;       /* device: u8 low part, or NULL */
  const float *rs;       /* device: rows floats */
  const float *ts;       /* device: m_pad floats */
  float *y;              /* device: m_pad * rows floats, [m][row] */
  void *ypart;           /* device scratch when segs > 1, or NULL:
                            segs * (a16 ? 2 : 1) * m_pad * rows 4-byte words */
  const float *toff;     /* device: m_pad floats added to the integer sum
                            before scaling (integer formats), or NULL */
} xf_gemm_desc;

int xf_gemm(xf_ctx *ctx, const xf_gemm_desc *d);

/* ---- Model pass (kernels/model/model.cpp) ------------------------------ */

/* A quantised matrix resident on the device. */
typedef struct {
  const void *w;    /* tile-ordered codes */
  const float *rs;  /* rows */
  const float *cs;  /* cols */
  float cmax;       /* max |cs| */
  int32_t rows, cols, fmt;
} xf_mat;

enum { XF_LAYER_GDN = 0, XF_LAYER_ATTN = 1 };

/* Matrices:  GDN  m = {in_proj_qkv, in_proj_z, out_proj, gate, up, down}
 *            ATTN m = {q_proj, k_proj, v_proj, o_proj, gate, up, down}
 * Aux (f32): GDN  aux = {ab [96][5120] (a rows then b rows), conv taps [4][10240],
 *                        -exp(A_log) [64], dt_bias [64], norm weight [128]}
 *            ATTN aux = {1 + q_norm [256], 1 + k_norm [256]}
 * ln1 / ln2 hold 1 + weight of input_layernorm / post_attention_layernorm.
 * state: block of xf_state_bytes(kind, ctx) bytes owned by the host. */
typedef struct {
  int32_t kind, reserved;
  const float *ln1, *ln2;
  xf_mat m[7];
  const float *aux[5];
  void *state;
} xf_layer;

typedef struct {
  int32_t nlayers, ctx;
  const xf_layer *layers;
  const uint16_t *embed; /* bf16 [vocab][5120] */
  const float *fnorm;    /* 1 + final norm weight */
  xf_mat head;           /* lm_head */
  const float *rope_cos, *rope_sin; /* [ctx][32] */
  void *ws;              /* xf_ws_bytes(ctx) bytes */
} xf_model;

enum { XF_FWD_EMBED = 1, XF_FWD_HEAD = 2 };
enum { XF_WS_IDS = 0, XF_WS_H, XF_WS_XN, XF_WS_LOGITS, XF_WS_AMAX_V, XF_WS_AMAX_I, XF_WS_MTP_H };
enum { XF_MAX_TOKENS = 16, XF_PROF_COUNT = 7, XF_AMAX_PER_TOKEN = 97 * 64 };

size_t xf_ws_bytes(int ctx);
size_t xf_state_bytes(int kind, int ctx);
size_t xf_ws_offset(int which, int ctx);

/* Submit layers [l0, l1) for m tokens at positions pos0.. . Token ids must be
 * in the workspace (XF_WS_IDS) when XF_FWD_EMBED is set. Committed recurrent
 * state is not modified. If prof is non-NULL (XF_PROF_COUNT doubles) the call
 * synchronises after every stage and adds milliseconds per category:
 * norm, quant, gemm, gdn, attn, mlp, head. */
int xf_forward(xf_ctx *ctx, const xf_model *md, int m, int pos0, int l0, int l1, int flags, double *prof);
/* Make the first n tokens of the last pass part of the recurrent state. */
int xf_commit(xf_ctx *ctx, const xf_model *md, int n);
/* Queued device-to-device copy / zero fill. */
int xf_copy(xf_ctx *ctx, void *dst, const void *src, size_t bytes);
int xf_zero(xf_ctx *ctx, void *dst, size_t bytes);

#ifdef __cplusplus
}
#endif
#endif
