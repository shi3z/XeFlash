//! Types shared by every XeFlash crate: errors, weight formats, small utilities.

use std::fmt;

/// Errors surfaced by XeFlash. GPU errors keep the status class reported by
/// the kernel library so callers can react to a lost device or to OOM.
#[derive(Debug)]
pub enum Error {
    Invalid(String),
    NoDevice(String),
    OutOfMemory(String),
    DeviceLost(String),
    Runtime(String),
    Io(std::io::Error),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::Invalid(m) => write!(f, "invalid argument: {m}"),
            Error::NoDevice(m) => write!(f, "no usable device: {m}"),
            Error::OutOfMemory(m) => write!(f, "out of device memory: {m}"),
            Error::DeviceLost(m) => write!(f, "device lost: {m}"),
            Error::Runtime(m) => write!(f, "GPU runtime error: {m}"),
            Error::Io(e) => write!(f, "I/O error: {e}"),
        }
    }
}

impl std::error::Error for Error {}

impl From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Self {
        Error::Io(e)
    }
}

pub type Result<T> = std::result::Result<T, Error>;

/// Weight storage formats understood by the GEMM kernels. The discriminants
/// are the `xf_wfmt` values of the C ABI.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[repr(i32)]
pub enum WeightFormat {
    /// Packed signed 4-bit, fed to DPAS as a native s4 operand.
    S4 = 0,
    /// Packed signed 2-bit, fed to DPAS as a native s2 operand.
    S2 = 1,
    /// Signed 8-bit (uncompressed integer reference).
    S8 = 2,
    /// bfloat16 weights and activations (floating-point reference).
    Bf16 = 3,
    /// Packed s4 storage, expanded to s8 in registers before DPAS.
    S4Exp8 = 4,
    /// Packed unsigned 3-bit codes, spread to u4 in registers before DPAS.
    /// Codes are offset binary (`u = q + 4`); the offset is a per-token scalar.
    S3 = 5,
}

impl WeightFormat {
    /// Columns covered by one 16-row tile.
    pub const fn tile_cols(self) -> usize {
        match self {
            WeightFormat::Bf16 => 16,
            _ => 32,
        }
    }
    /// Bytes one tile occupies in device memory.
    pub const fn tile_bytes(self) -> usize {
        match self {
            WeightFormat::S4 | WeightFormat::S4Exp8 => 256,
            WeightFormat::S2 => 128,
            WeightFormat::S3 => 192,
            WeightFormat::S8 | WeightFormat::Bf16 => 512,
        }
    }
    /// Stored bits per weight.
    pub const fn bits(self) -> usize {
        self.tile_bytes() * 8 / (16 * self.tile_cols())
    }
    /// Inclusive value range of an integer format.
    pub const fn int_range(self) -> (i8, i8) {
        match self {
            WeightFormat::S4 | WeightFormat::S4Exp8 => (-8, 7),
            WeightFormat::S2 => (-2, 1),
            WeightFormat::S3 => (0, 7),
            _ => (-128, 127),
        }
    }
    pub const fn name(self) -> &'static str {
        match self {
            WeightFormat::S4 => "s4",
            WeightFormat::S2 => "s2",
            WeightFormat::S8 => "s8",
            WeightFormat::Bf16 => "bf16",
            WeightFormat::S4Exp8 => "s4>s8",
            WeightFormat::S3 => "s3",
        }
    }
}

/// Small deterministic generator for tests and benchmarks (xoshiro256**).
/// Benchmarks must use high-entropy data: the B60 reads all-zero pages several
/// times faster than real weights.
pub struct Rng([u64; 4]);

impl Rng {
    pub fn new(seed: u64) -> Self {
        let mut z = seed.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut next = || {
            z = z.wrapping_add(0x9E37_79B9_7F4A_7C15);
            let mut x = z;
            x = (x ^ (x >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
            x = (x ^ (x >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
            x ^ (x >> 31)
        };
        Rng([next(), next(), next(), next()])
    }
    pub fn next_u64(&mut self) -> u64 {
        let s = &mut self.0;
        let r = s[1].wrapping_mul(5).rotate_left(7).wrapping_mul(9);
        let t = s[1] << 17;
        s[2] ^= s[0];
        s[3] ^= s[1];
        s[1] ^= s[2];
        s[0] ^= s[3];
        s[2] ^= t;
        s[3] = s[3].rotate_left(45);
        r
    }
    /// Uniform integer in `lo..=hi`.
    pub fn range_i8(&mut self, lo: i8, hi: i8) -> i8 {
        let span = (hi as i16 - lo as i16 + 1) as u64;
        (lo as i16 + (self.next_u64() >> 33).rem_euclid(span) as i16) as i8
    }
    /// Uniform float in [-1, 1).
    pub fn unit_f32(&mut self) -> f32 {
        ((self.next_u64() >> 40) as f32 / (1u64 << 23) as f32) - 1.0
    }
}

/// Round a float to bfloat16 (round to nearest even) and return its bits.
pub fn f32_to_bf16(v: f32) -> u16 {
    let b = v.to_bits();
    let lsb = (b >> 16) & 1;
    ((b.wrapping_add(0x7FFF + lsb)) >> 16) as u16
}

pub fn bf16_to_f32(b: u16) -> f32 {
    f32::from_bits((b as u32) << 16)
}
