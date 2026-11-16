//! Safe Rust front end of the XeFlash kernel library (`libxfk.so`).
//!
//! * [`Device`] owns the SYCL queue on the Arc Pro B60. It is cheap to clone.
//! * [`DeviceBuf`] is a RAII device-memory allocation; it keeps its `Device`
//!   alive and is freed (after the queue drains) when dropped.
//! * Kernel calls only *submit* work. [`Device::wait`] synchronises and is the
//!   place where asynchronous failures, including a lost device, surface.

mod ffi;

use std::ffi::CStr;
use std::sync::Arc;

use xeflash_core::{Error, Result, WeightFormat};

struct Ctx(*mut ffi::xf_ctx);
// The kernel library guards the queue internally (SYCL queues are thread-safe).
unsafe impl Send for Ctx {}
unsafe impl Sync for Ctx {}

impl Drop for Ctx {
    fn drop(&mut self) {
        unsafe { ffi::xf_ctx_destroy(self.0) }
    }
}

fn last_error() -> String {
    unsafe { CStr::from_ptr(ffi::xf_last_error()) }.to_string_lossy().into_owned()
}

fn check(status: i32) -> Result<()> {
    match status {
        ffi::XF_OK => Ok(()),
        ffi::XF_ERR_INVALID => Err(Error::Invalid(last_error())),
        ffi::XF_ERR_NO_DEVICE => Err(Error::NoDevice(last_error())),
        ffi::XF_ERR_OOM => Err(Error::OutOfMemory(last_error())),
        ffi::XF_ERR_DEVICE_LOST => Err(Error::DeviceLost(last_error())),
        _ => Err(Error::Runtime(last_error())),
    }
}

/// Static description of the GPU.
#[derive(Debug, Clone)]
pub struct DeviceInfo {
    pub name: String,
    pub driver: String,
    pub vram_total: u64,
    /// Zero when the driver does not report it (needs `ZES_ENABLE_SYSMAN=1`).
    pub vram_free: u64,
    pub max_alloc: u64,
    pub eu_count: u32,
    pub threads_per_eu: u32,
    pub slm_bytes: u32,
    pub clock_mhz: u32,
}

#[derive(Clone)]
pub struct Device {
    ctx: Arc<Ctx>,
}

impl Device {
    /// Open the first Intel Level Zero GPU. Never selects another vendor's card.
    pub fn open() -> Result<Self> {
        let mut raw = std::ptr::null_mut();
        check(unsafe { ffi::xf_ctx_create(&mut raw) })?;
        Ok(Device { ctx: Arc::new(Ctx(raw)) })
    }

    pub fn info(&self) -> Result<DeviceInfo> {
        let mut i = std::mem::MaybeUninit::<ffi::xf_devinfo>::zeroed();
        check(unsafe { ffi::xf_device_info(self.ctx.0, i.as_mut_ptr()) })?;
        let i = unsafe { i.assume_init() };
        let s = |b: &[std::ffi::c_char]| unsafe { CStr::from_ptr(b.as_ptr()) }.to_string_lossy().into_owned();
        Ok(DeviceInfo {
            name: s(&i.name),
            driver: s(&i.driver),
            vram_total: i.vram_total,
            vram_free: i.vram_free,
            max_alloc: i.max_alloc,
            eu_count: i.eu_count,
            threads_per_eu: i.threads_per_eu,
            slm_bytes: i.slm_bytes,
            clock_mhz: i.clock_mhz,
        })
    }

    /// Allocate `bytes` of device memory (contents undefined).
    pub fn alloc(&self, bytes: usize) -> Result<DeviceBuf> {
        if bytes == 0 {
            return Err(Error::Invalid("zero-sized device allocation".into()));
        }
        let ptr = unsafe { ffi::xf_alloc(self.ctx.0, bytes) };
        if ptr.is_null() {
            return Err(Error::OutOfMemory(last_error()));
        }
        Ok(DeviceBuf { dev: self.clone(), ptr, bytes })
    }

    /// Allocate and fill from host memory.
    pub fn upload<T: Pod>(&self, data: &[T]) -> Result<DeviceBuf> {
        let buf = self.alloc(std::mem::size_of_val(data))?;
        buf.write(0, data)?;
        Ok(buf)
    }

    /// Block until everything submitted so far has finished.
    pub fn wait(&self) -> Result<()> {
        check(unsafe { ffi::xf_wait(self.ctx.0) })
    }

    /// Submit an empty kernel (for launch-overhead measurements).
    pub fn noop(&self) -> Result<()> {
        check(unsafe { ffi::xf_noop(self.ctx.0) })
    }

    /// Submit one GEMM. See [`Gemm`] for the data layout contract.
    pub fn gemm(&self, g: &Gemm<'_>) -> Result<()> {
        g.validate()?;
        let d = ffi::xf_gemm_desc {
            wfmt: g.format as i32,
            rows: g.rows as i32,
            cols: g.cols as i32,
            m: g.tokens as i32,
            tokens_per_thread: g.tokens_per_thread as i32,
            segs: g.segs as i32,
            a16: g.x_lo.is_some() as i32,
            reserved: 0,
            w: g.w.ptr,
            x: g.x.ptr,
            xlo: g.x_lo.map_or(std::ptr::null(), |b| b.ptr.cast_const()),
            rs: g.row_scale.ptr.cast(),
            ts: g.token_scale.ptr.cast(),
            y: g.y.ptr.cast(),
            ypart: g.y_part.map_or(std::ptr::null_mut(), |b| b.ptr),
            toff: g.token_offset.map_or(std::ptr::null(), |b| b.ptr.cast_const().cast()),
        };
        check(unsafe { ffi::xf_gemm(self.ctx.0, &d) })
    }
}

/// Plain-old-data element types that may be copied to and from the device.
///
/// # Safety
/// Implementors must have no padding and accept every bit pattern.
pub unsafe trait Pod: Copy + 'static {}
unsafe impl Pod for u8 {}
unsafe impl Pod for i8 {}
unsafe impl Pod for u16 {}
unsafe impl Pod for i16 {}
unsafe impl Pod for u32 {}
unsafe impl Pod for i32 {}
unsafe impl Pod for f32 {}

/// A device-memory allocation. Freed on drop, after pending kernels finish.
pub struct DeviceBuf {
    dev: Device,
    ptr: *mut std::ffi::c_void,
    bytes: usize,
}

// Device memory is only touched through the queue.
unsafe impl Send for DeviceBuf {}
unsafe impl Sync for DeviceBuf {}

impl DeviceBuf {
    pub fn len_bytes(&self) -> usize {
        self.bytes
    }

    /// Copy `data` into the buffer at `byte_offset` (synchronous).
    pub fn write<T: Pod>(&self, byte_offset: usize, data: &[T]) -> Result<()> {
        let n = std::mem::size_of_val(data);
        if byte_offset.checked_add(n).is_none_or(|end| end > self.bytes) {
            return Err(Error::Invalid(format!(
                "write of {n} bytes at offset {byte_offset} exceeds buffer of {} bytes",
                self.bytes
            )));
        }
        if n == 0 {
            return Ok(());
        }
        check(unsafe {
            ffi::xf_write(self.dev.ctx.0, self.ptr.cast::<u8>().add(byte_offset).cast(), data.as_ptr().cast(), n)
        })
    }

    /// Copy from the buffer at `byte_offset` into `out` (synchronous; waits for
    /// previously submitted kernels because the queue is in-order).
    pub fn read<T: Pod>(&self, byte_offset: usize, out: &mut [T]) -> Result<()> {
        let n = std::mem::size_of_val(out);
        if byte_offset.checked_add(n).is_none_or(|end| end > self.bytes) {
            return Err(Error::Invalid(format!(
                "read of {n} bytes at offset {byte_offset} exceeds buffer of {} bytes",
                self.bytes
            )));
        }
        if n == 0 {
            return Ok(());
        }
        check(unsafe {
            ffi::xf_read(self.dev.ctx.0, out.as_mut_ptr().cast(), self.ptr.cast::<u8>().add(byte_offset).cast(), n)
        })
    }
}

impl Drop for DeviceBuf {
    fn drop(&mut self) {
        // xf_free drains the queue first, so no kernel can still be using the
        // memory. A failure here means the device is already gone.
        let status = unsafe { ffi::xf_free(self.dev.ctx.0, self.ptr) };
        if status != ffi::XF_OK {
            eprintln!("xeflash: freeing device memory failed: {}", last_error());
        }
    }
}

/// `y[m][row] = row_scale[row] * token_scale[m] * (token_offset[m] + sum_col W[row][col] * x[m][col])`
///
/// Buffers must be in the layouts produced by `xeflash-quant`:
/// * `w`: XMX tile order, `rows/16 * cols/tile_cols` tiles of `tile_bytes`;
/// * `x`: `[tile][m_pad][32 bytes]` (s8, or 16 bf16 values);
/// * `x_lo`: optional unsigned low byte of 16-bit activations, same layout;
/// * `y`: `[m_pad][rows]` f32; `y_part`: `[segs][m_pad][rows]` when `segs > 1`.
///
/// `m_pad` is `tokens` rounded up to `tokens_per_thread`.
pub struct Gemm<'a> {
    pub format: WeightFormat,
    pub rows: usize,
    pub cols: usize,
    pub tokens: usize,
    /// 1 (decode), 8 or 16 (verify), 32 (prefill).
    pub tokens_per_thread: usize,
    /// Column segments per 16-row block; more segments means more, shorter threads.
    pub segs: usize,
    pub w: &'a DeviceBuf,
    pub x: &'a DeviceBuf,
    pub x_lo: Option<&'a DeviceBuf>,
    pub row_scale: &'a DeviceBuf,
    pub token_scale: &'a DeviceBuf,
    pub y: &'a DeviceBuf,
    /// Scratch for `segs > 1`: `segs * planes * m_pad * rows` 4-byte words,
    /// `planes` = 2 with 16-bit activations.
    pub y_part: Option<&'a DeviceBuf>,
    /// Per-token value added to the integer sum before scaling (`m_pad` f32).
    /// Carries the `+0.5` of the half-offset level grid.
    pub token_offset: Option<&'a DeviceBuf>,
}

impl Gemm<'_> {
    pub fn tokens_padded(&self) -> usize {
        self.tokens.div_ceil(self.tokens_per_thread) * self.tokens_per_thread
    }

    fn validate(&self) -> Result<()> {
        let bad = |m: String| Err(Error::Invalid(m));
        if !matches!(self.tokens_per_thread, 1 | 8 | 16 | 32) {
            return bad("tokens_per_thread must be 1, 8, 16 or 32".into());
        }
        if self.rows == 0 || self.rows % 16 != 0 || self.cols == 0 || self.tokens == 0 || self.segs == 0 {
            return bad(format!("bad GEMM shape {}x{} tokens {}", self.rows, self.cols, self.tokens));
        }
        let tc = self.format.tile_cols();
        if self.cols % tc != 0 {
            return bad(format!("cols {} not a multiple of the tile width {tc}", self.cols));
        }
        let tiles = self.cols / tc;
        let mpad = self.tokens_padded();
        let need = |name: &str, buf: &DeviceBuf, bytes: usize| {
            if buf.bytes < bytes {
                Err(Error::Invalid(format!("{name} buffer has {} bytes, kernel needs {bytes}", buf.bytes)))
            } else {
                Ok(())
            }
        };
        need("w", self.w, self.rows / 16 * tiles * self.format.tile_bytes())?;
        need("x", self.x, tiles * mpad * 32)?;
        if let Some(lo) = self.x_lo {
            need("x_lo", lo, tiles * mpad * 32)?;
        }
        need("row_scale", self.row_scale, self.rows * 4)?;
        need("token_scale", self.token_scale, mpad * 4)?;
        need("y", self.y, mpad * self.rows * 4)?;
        if let Some(off) = self.token_offset {
            if self.format == WeightFormat::Bf16 {
                return bad("token_offset is only defined for integer formats".into());
            }
            need("token_offset", off, mpad * 4)?;
        }
        match (self.segs, self.y_part) {
            (1, _) => {}
            (s, Some(p)) => need("y_part", p, s * (1 + self.x_lo.is_some() as usize) * mpad * self.rows * 4)?,
            (_, None) => return bad("segs > 1 requires y_part".into()),
        }
        Ok(())
    }
}
