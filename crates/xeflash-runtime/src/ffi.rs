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

unsafe extern "C" {
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
