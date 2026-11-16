//! Raw declarations of `kernels/include/xfk.h`. Keep the two in sync by hand:
//! the ABI is small on purpose.
#![allow(non_camel_case_types)]

use std::ffi::{c_char, c_void};

#[repr(C)]
pub struct xf_ctx {
    _private: [u8; 0],
}

pub const XF_OK: i32 = 0;
pub const XF_ERR_INVALID: i32 = 1;
pub const XF_ERR_NO_DEVICE: i32 = 2;
pub const XF_ERR_OOM: i32 = 3;
pub const XF_ERR_DEVICE_LOST: i32 = 4;

#[repr(C)]
pub struct xf_devinfo {
    pub name: [c_char; 128],
    pub driver: [c_char; 64],
    pub vram_total: u64,
    pub vram_free: u64,
    pub max_alloc: u64,
    pub eu_count: u32,
    pub threads_per_eu: u32,
    pub slm_bytes: u32,
    pub clock_mhz: u32,
}

#[repr(C)]
pub struct xf_gemm_desc {
    pub wfmt: i32,
    pub rows: i32,
    pub cols: i32,
    pub m: i32,
    pub tokens_per_thread: i32,
    pub segs: i32,
    pub a16: i32,
    pub reserved: i32,
    pub w: *const c_void,
    pub x: *const c_void,
    pub xlo: *const c_void,
    pub rs: *const f32,
    pub ts: *const f32,
    pub y: *mut f32,
    pub ypart: *mut c_void,
    pub toff: *const f32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct xf_mat {
    pub w: *const c_void,
    pub rs: *const f32,
    pub cs: *const f32,
    pub cmax: f32,
    pub rows: i32,
    pub cols: i32,
    pub fmt: i32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct xf_layer {
    pub kind: i32,
    pub reserved: i32,
    pub ln1: *const f32,
    pub ln2: *const f32,
    pub m: [xf_mat; 7],
    pub aux: [*const f32; 5],
    pub state: *mut c_void,
}

#[repr(C)]
pub struct xf_model {
    pub nlayers: i32,
    pub ctx: i32,
    pub layers: *const xf_layer,
    pub embed: *const u16,
    pub fnorm: *const f32,
    pub head: xf_mat,
    pub rope_cos: *const f32,
    pub rope_sin: *const f32,
    pub ws: *mut c_void,
}

#[repr(C)]
pub struct xf_mtp {
    pub layer: xf_layer,
    pub fc: *const f32,
    pub gain_e: *const f32,
    pub gain_h: *const f32,
    pub norm: *const f32,
}

pub const XF_LAYER_GDN: i32 = 0;
pub const XF_LAYER_ATTN: i32 = 1;
pub const XF_FWD_EMBED: i32 = 1;
pub const XF_FWD_HEAD: i32 = 2;
pub const XF_WS_IDS: i32 = 0;
pub const XF_WS_H: i32 = 1;
pub const XF_WS_LOGITS: i32 = 3;
pub const XF_WS_AMAX_V: i32 = 4;
pub const XF_WS_AMAX_I: i32 = 5;

unsafe extern "C" {
    pub fn xf_ws_bytes(ctx: i32) -> usize;
    pub fn xf_state_bytes(kind: i32, ctx: i32) -> usize;
    pub fn xf_ws_offset(which: i32, ctx: i32) -> usize;
    pub fn xf_forward(ctx: *mut xf_ctx, md: *const xf_model, m: i32, pos0: i32, l0: i32, l1: i32, flags: i32, prof: *mut f64) -> i32;
    pub fn xf_mtp_step(ctx: *mut xf_ctx, md: *const xf_model, mtp: *const xf_mtp, m: i32, pos0: i32, src_row: i32, prof: *mut f64) -> i32;
    pub fn xf_commit(ctx: *mut xf_ctx, md: *const xf_model, n: i32) -> i32;
    pub fn xf_copy(ctx: *mut xf_ctx, dst: *mut c_void, src: *const c_void, bytes: usize) -> i32;
    pub fn xf_zero(ctx: *mut xf_ctx, dst: *mut c_void, bytes: usize) -> i32;
    pub fn xf_last_error() -> *const c_char;
    pub fn xf_ctx_create(out: *mut *mut xf_ctx) -> i32;
    pub fn xf_ctx_destroy(ctx: *mut xf_ctx);
    pub fn xf_device_info(ctx: *mut xf_ctx, out: *mut xf_devinfo) -> i32;
    pub fn xf_alloc(ctx: *mut xf_ctx, bytes: usize) -> *mut c_void;
    pub fn xf_free(ctx: *mut xf_ctx, ptr: *mut c_void) -> i32;
    pub fn xf_write(ctx: *mut xf_ctx, dev_dst: *mut c_void, host_src: *const c_void, bytes: usize) -> i32;
    pub fn xf_read(ctx: *mut xf_ctx, host_dst: *mut c_void, dev_src: *const c_void, bytes: usize) -> i32;
    pub fn xf_wait(ctx: *mut xf_ctx) -> i32;
    pub fn xf_noop(ctx: *mut xf_ctx) -> i32;
    pub fn xf_gemm(ctx: *mut xf_ctx, d: *const xf_gemm_desc) -> i32;
}
