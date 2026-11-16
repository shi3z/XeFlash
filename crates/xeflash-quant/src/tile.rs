//! XMX tile order.
//!
//! A matrix `W[rows][cols]` is cut into tiles of 16 rows x `TC` columns. A tile
//! is stored exactly as the DPAS "B" operand:
//!
//! ```text
//! tile = [register r][lane n] of 32-bit words
//! word(r, n) holds columns  tile*TC + r*E .. + E-1  of row  rowblk*16 + n
//! element j sits at bit offset j * bits          (E = 32 / bits)
//! ```
//!
//! | format | bits | E  | registers | TC | tile bytes |
//! |--------|------|----|-----------|----|------------|
//! | s4     | 4    | 8  | 4         | 32 | 256        |
//! | s2     | 2    | 16 | 2         | 32 | 128        |
//! | s8     | 8    | 4  | 8         | 32 | 512        |
//! | bf16   | 16   | 2  | 8         | 16 | 512        |
//!
//! Tiles are stored row-block major (`[rowblk][tile]`), so one GPU thread
//! streams one contiguous run of memory.

use xeflash_core::{Error, Result, WeightFormat};

fn check_shape(format: WeightFormat, rows: usize, cols: usize, len: usize) -> Result<()> {
    if rows % 16 != 0 || cols % format.tile_cols() != 0 {
        return Err(Error::Invalid(format!(
            "{rows}x{cols} is not a whole number of 16x{} tiles",
            format.tile_cols()
        )));
    }
    if len != rows * cols {
        return Err(Error::Invalid(format!("matrix has {len} elements, expected {}", rows * cols)));
    }
    Ok(())
}

fn storage_bits(format: WeightFormat) -> Result<usize> {
    match format {
        WeightFormat::S4 | WeightFormat::S4Exp8 => Ok(4),
        WeightFormat::S2 => Ok(2),
        WeightFormat::S8 => Ok(8),
        WeightFormat::Bf16 => Err(Error::Invalid("use pack_weights_bf16 for bf16".into())),
    }
}

/// Pack a row-major integer matrix into XMX tile order.
/// Values outside the format's range are an error (never silently wrapped).
pub fn pack_weights(format: WeightFormat, rows: usize, cols: usize, w: &[i8]) -> Result<Vec<u8>> {
    let bits = storage_bits(format)?;
    check_shape(format, rows, cols, w.len())?;
    let (lo, hi) = format.int_range();
    if let Some(v) = w.iter().find(|v| **v < lo || **v > hi) {
        return Err(Error::Invalid(format!("weight {v} outside {lo}..={hi} for {}", format.name())));
    }
    let e = 32 / bits; // elements per 32-bit word
    let tc = format.tile_cols();
    let regs = tc / e;
    let mask = (1u32 << bits) - 1;
    let tiles = cols / tc;
    let mut out = vec![0u8; rows / 16 * tiles * format.tile_bytes()];
    let mut words = out.chunks_exact_mut(4);
    for rb in 0..rows / 16 {
        for t in 0..tiles {
            for r in 0..regs {
                for n in 0..16 {
                    let base = (rb * 16 + n) * cols + t * tc + r * e;
                    let mut word = 0u32;
                    for (j, v) in w[base..base + e].iter().enumerate() {
                        word |= (*v as u32 & mask) << (j * bits);
                    }
                    words.next().unwrap().copy_from_slice(&word.to_le_bytes());
                }
            }
        }
    }
    Ok(out)
}

/// Inverse of [`pack_weights`].
pub fn unpack_weights(format: WeightFormat, rows: usize, cols: usize, packed: &[u8]) -> Result<Vec<i8>> {
    let bits = storage_bits(format)?;
    let e = 32 / bits;
    let tc = format.tile_cols();
    let regs = tc / e;
    let tiles = cols / tc;
    if rows % 16 != 0 || cols % tc != 0 || packed.len() != rows / 16 * tiles * format.tile_bytes() {
        return Err(Error::Invalid("packed buffer does not match the shape".into()));
    }
    let mut out = vec![0i8; rows * cols];
    let mut words = packed.chunks_exact(4);
    for rb in 0..rows / 16 {
        for t in 0..tiles {
            for r in 0..regs {
                for n in 0..16 {
                    let word = u32::from_le_bytes(words.next().unwrap().try_into().unwrap());
                    let base = (rb * 16 + n) * cols + t * tc + r * e;
                    for j in 0..e {
                        let raw = (word >> (j * bits)) << (32 - bits);
                        out[base + j] = ((raw as i32) >> (32 - bits)) as i8;
                    }
                }
            }
        }
    }
    Ok(out)
}

/// Pack a row-major bf16 matrix (raw bf16 bits) into XMX tile order.
pub fn pack_weights_bf16(rows: usize, cols: usize, w: &[u16]) -> Result<Vec<u8>> {
    let format = WeightFormat::Bf16;
    check_shape(format, rows, cols, w.len())?;
    let tiles = cols / 16;
    let mut out = vec![0u8; rows / 16 * tiles * format.tile_bytes()];
    let mut words = out.chunks_exact_mut(4);
    for rb in 0..rows / 16 {
        for t in 0..tiles {
            for r in 0..8 {
                for n in 0..16 {
                    let base = (rb * 16 + n) * cols + t * 16 + r * 2;
                    let word = w[base] as u32 | (w[base + 1] as u32) << 16;
                    words.next().unwrap().copy_from_slice(&word.to_le_bytes());
                }
            }
        }
    }
    Ok(out)
}

/// Pack 8-bit activations `x[m][cols]` as `[tile][m_pad][32]`: the DPAS "A"
/// operands of all tokens of one column tile are contiguous. Padding tokens
/// are zero.
pub fn pack_activations<T: Copy + Default>(m: usize, m_pad: usize, cols: usize, x: &[T]) -> Result<Vec<T>> {
    if cols % 32 != 0 || x.len() != m * cols || m_pad < m {
        return Err(Error::Invalid("bad activation shape".into()));
    }
    let tiles = cols / 32;
    let mut out = vec![T::default(); tiles * m_pad * 32];
    for t in 0..tiles {
        for i in 0..m {
            let dst = (t * m_pad + i) * 32;
            out[dst..dst + 32].copy_from_slice(&x[i * cols + t * 32..i * cols + t * 32 + 32]);
        }
    }
    Ok(out)
}

/// bf16 activations: tiles are 16 columns wide, `[tile][m_pad][16]`.
pub fn pack_activations_bf16(m: usize, m_pad: usize, cols: usize, x: &[u16]) -> Result<Vec<u16>> {
    if cols % 16 != 0 || x.len() != m * cols || m_pad < m {
        return Err(Error::Invalid("bad activation shape".into()));
    }
    let tiles = cols / 16;
    let mut out = vec![0u16; tiles * m_pad * 16];
    for t in 0..tiles {
        for i in 0..m {
            let dst = (t * m_pad + i) * 16;
            out[dst..dst + 16].copy_from_slice(&x[i * cols + t * 16..i * cols + t * 16 + 16]);
        }
    }
    Ok(out)
}

/// Split 16-bit activations into the signed high byte and unsigned low byte:
/// `x = 256 * hi + lo`. The kernel runs one DPAS per part on the same weights.
pub fn split_a16(x: &[i16]) -> (Vec<i8>, Vec<u8>) {
    (x.iter().map(|v| (v >> 8) as i8).collect(), x.iter().map(|v| *v as u8).collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    use xeflash_core::Rng;

    #[test]
    fn pack_roundtrip() {
        for f in [WeightFormat::S4, WeightFormat::S2, WeightFormat::S8] {
            let (rows, cols) = (32, 96);
            let (lo, hi) = f.int_range();
            let mut rng = Rng::new(7);
            let w: Vec<i8> = (0..rows * cols).map(|_| rng.range_i8(lo, hi)).collect();
            let p = pack_weights(f, rows, cols, &w).unwrap();
            assert_eq!(p.len(), rows * cols * f.bits() / 8);
            assert_eq!(unpack_weights(f, rows, cols, &p).unwrap(), w);
        }
    }

    #[test]
    fn s4_layout_matches_probe() {
        // Row 3, column 13 of tile 0: register 1 (cols 8..15), lane 3, nibble 5.
        let (rows, cols) = (16, 32);
        let mut w = vec![0i8; rows * cols];
        w[3 * cols + 13] = -3;
        let p = pack_weights(WeightFormat::S4, rows, cols, &w).unwrap();
        let word = u32::from_le_bytes(p[(16 + 3) * 4..(16 + 3) * 4 + 4].try_into().unwrap());
        assert_eq!(word, 0xD << 20);
        assert_eq!(p.iter().filter(|b| **b != 0).count(), 1);
    }

    #[test]
    fn out_of_range_is_rejected() {
        let w = vec![8i8; 16 * 32];
        assert!(pack_weights(WeightFormat::S4, 16, 32, &w).is_err());
    }

    #[test]
    fn a16_split() {
        let (hi, lo) = split_a16(&[-1, 255, 256, -32768, 32767]);
        for (i, x) in [-1i32, 255, 256, -32768, 32767].iter().enumerate() {
            assert_eq!(256 * hi[i] as i32 + lo[i] as i32, *x);
        }
    }
}
