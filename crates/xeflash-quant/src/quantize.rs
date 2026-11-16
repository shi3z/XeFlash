//! Scalar low-bit quantisation shaped by what the Xe2 GEMM gets for free.
//!
//! ```text
//! W[i][j]  ~=  r[i] * (q[i][j] + 0.5) * c[j]        q in [-2^(b-1), 2^(b-1) - 1]
//! ```
//!
//! * `q` is what the kernel streams into DPAS (native s4 / s2 operand).
//! * `r` (per output row) is applied when the int32 accumulator is converted
//!   to float, which the kernel does anyway.
//! * `c` (per input column) is multiplied into the activation vector before it
//!   is quantised for DPAS, so it costs nothing per weight.
//! * The `+0.5` makes the level grid symmetric (16 levels for 4 bits instead
//!   of 15 usable ones, 4 instead of 3 for 2 bits). At run time it is one
//!   scalar per token: `0.5 * sum_j c[j] x[j]`, shared by every row.
//!
//! This is data-free (weight-space error only). Activation-aware refinement is
//! a separate step once calibration statistics exist.

use rayon::prelude::*;
use xeflash_core::{Error, Result};

#[derive(Debug, Clone, Copy)]
pub struct QuantSpec {
    /// Bits per weight: 2, 3, 4 or 8.
    pub bits: u32,
    /// Fit a per-column scale in addition to the per-row scale.
    pub col_scale: bool,
    /// Alternating refinement rounds (>= 1).
    pub iters: usize,
}

pub struct Quantized {
    pub rows: usize,
    pub cols: usize,
    pub bits: u32,
    /// Row-major codes.
    pub q: Vec<i8>,
    pub row_scale: Vec<f32>,
    pub col_scale: Vec<f32>,
    /// Sum of squared reconstruction errors and of squared weights.
    pub sq_err: f64,
    pub sq_norm: f64,
}

impl Quantized {
    /// Relative Frobenius error `|W - W^| / |W|`.
    pub fn rel_err(&self) -> f64 {
        (self.sq_err / self.sq_norm.max(1e-300)).sqrt()
    }
    /// Signal-to-quantisation-noise ratio in dB.
    pub fn sqnr_db(&self) -> f64 {
        10.0 * (self.sq_norm.max(1e-300) / self.sq_err.max(1e-300)).log10()
    }
    pub fn reconstruct(&self, i: usize, j: usize) -> f32 {
        self.row_scale[i] * (self.q[i * self.cols + j] as f32 + 0.5) * self.col_scale[j]
    }
}

/// Step sizes tried per row, as multiples of the row's RMS. Centred on the
/// MSE-optimal uniform step for a Gaussian source; real rows are heavier
/// tailed, so the grid extends further up than down.
fn step_grid(bits: u32) -> Vec<f32> {
    let opt = match bits {
        2 => 0.996,
        3 => 0.586,
        4 => 0.335,
        _ => 0.031,
    };
    (0..14).map(|k| opt * (0.70 + 0.08 * k as f32)).collect()
}

/// Quantise one row given column scales. Returns (row scale, squared error).
fn quantize_row(w: &[f32], c: &[f32], lo: f32, hi: f32, grid: &[f32], q: &mut [i8]) -> (f32, f64) {
    let n = w.len();
    let mut v = vec![0f32; n];
    let mut ss = 0f64;
    for j in 0..n {
        v[j] = w[j] / c[j];
        ss += (v[j] as f64) * (v[j] as f64);
    }
    let rms = (ss / n as f64).sqrt() as f32;
    if rms == 0.0 {
        q.fill(0);
        // All-zero row: scale 0 reproduces it exactly.
        return (0.0, 0.0);
    }
    let mut best = (f64::INFINITY, 0f32, 0f32); // (error, step, fitted scale)
    for &t in grid {
        let inv = 1.0 / (rms * t);
        // Weighted least squares for the scale: minimise sum c^2 (v - r l)^2.
        let (mut num, mut den, mut sww) = (0f64, 0f64, 0f64);
        for j in 0..n {
            let l = (v[j] * inv).floor().clamp(lo, hi) + 0.5;
            let cl = c[j] * l;
            num += (w[j] as f64) * (cl as f64);
            den += (cl as f64) * (cl as f64);
            sww += (w[j] as f64) * (w[j] as f64);
        }
        let err = sww - num * num / den;
        if err < best.0 {
            best = (err, rms * t, (num / den) as f32);
        }
    }
    let inv = 1.0 / best.1;
    for j in 0..n {
        q[j] = (v[j] * inv).floor().clamp(lo, hi) as i8;
    }
    (best.2, best.0.max(0.0))
}

/// Quantise a row-major `rows x cols` matrix.
pub fn quantize(w: &[f32], rows: usize, cols: usize, spec: QuantSpec) -> Result<Quantized> {
    if !matches!(spec.bits, 2 | 3 | 4 | 8) || spec.iters == 0 {
        return Err(Error::Invalid("bits must be 2, 3, 4 or 8 and iters >= 1".into()));
    }
    if w.len() != rows * cols || rows == 0 || cols == 0 {
        return Err(Error::Invalid("matrix size does not match its shape".into()));
    }
    if w.iter().any(|v| !v.is_finite()) {
        return Err(Error::Invalid("matrix contains non-finite values".into()));
    }
    let lo = -((1i32 << (spec.bits - 1)) as f32);
    let hi = ((1i32 << (spec.bits - 1)) - 1) as f32;
    let grid = step_grid(spec.bits);

    // Column scales start at the column RMS, normalised to geometric mean 1.
    let mut c = vec![1f32; cols];
    if spec.col_scale {
        let ss = w
            .par_chunks(cols)
            .fold(|| vec![0f64; cols], |mut a, row| {
                for (s, v) in a.iter_mut().zip(row) {
                    *s += (*v as f64) * (*v as f64);
                }
                a
            })
            .reduce(|| vec![0f64; cols], |mut a, b| {
                for (x, y) in a.iter_mut().zip(&b) {
                    *x += y;
                }
                a
            });
        for (cj, s) in c.iter_mut().zip(&ss) {
            *cj = if *s > 0.0 { (s / rows as f64).sqrt() as f32 } else { 1.0 };
        }
        normalize(&mut c);
    }

    let mut q = vec![0i8; rows * cols];
    let mut r = vec![0f32; rows];
    let mut sq_err = 0f64;
    let rounds = if spec.col_scale { spec.iters } else { 1 };
    for round in 0..rounds {
        let errs: Vec<(f32, f64)> = w
            .par_chunks(cols)
            .zip(q.par_chunks_mut(cols))
            .map(|(wr, qr)| quantize_row(wr, &c, lo, hi, &grid, qr))
            .collect();
        sq_err = errs.iter().map(|e| e.1).sum();
        for (ri, e) in r.iter_mut().zip(&errs) {
            *ri = e.0;
        }
        if round + 1 == rounds {
            break;
        }
        // Least-squares column scales for the current codes and row scales:
        // c[j] = sum_i w[i][j] p[i][j] / sum_i p[i][j]^2,  p = r[i] (q + 0.5).
        let (num, den) = w
            .par_chunks(cols)
            .zip(q.par_chunks(cols))
            .zip(r.par_iter())
            .fold(
                || (vec![0f64; cols], vec![0f64; cols]),
                |(mut num, mut den), ((wr, qr), ri)| {
                    for j in 0..cols {
                        let p = (*ri * (qr[j] as f32 + 0.5)) as f64;
                        num[j] += wr[j] as f64 * p;
                        den[j] += p * p;
                    }
                    (num, den)
                },
            )
            .reduce(
                || (vec![0f64; cols], vec![0f64; cols]),
                |(mut n1, mut d1), (n2, d2)| {
                    for j in 0..cols {
                        n1[j] += n2[j];
                        d1[j] += d2[j];
                    }
                    (n1, d1)
                },
            );
        for j in 0..cols {
            if den[j] > 0.0 && num[j] > 0.0 {
                c[j] = (num[j] / den[j]) as f32;
            }
        }
    }
    let sq_norm: f64 = w.par_iter().map(|v| (*v as f64) * (*v as f64)).sum();
    Ok(Quantized { rows, cols, bits: spec.bits, q, row_scale: r, col_scale: c, sq_err, sq_norm })
}

/// Scale `c` so its geometric mean is 1 (keeps row scales in a sane range).
fn normalize(c: &mut [f32]) {
    let mean_log = c.iter().map(|v| (*v as f64).ln()).sum::<f64>() / c.len() as f64;
    let k = (-mean_log).exp() as f32;
    for v in c.iter_mut() {
        *v *= k;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use xeflash_core::Rng;

    fn gaussian(rng: &mut Rng) -> f32 {
        (0..12).map(|_| rng.unit_f32()).sum::<f32>() * 0.5
    }

    #[test]
    fn gaussian_sqnr_is_near_theory() {
        let (rows, cols) = (64, 2048);
        let mut rng = Rng::new(3);
        let w: Vec<f32> = (0..rows * cols).map(|_| gaussian(&mut rng)).collect();
        // Theory for an optimal uniform quantiser on a Gaussian: 9.3 / 14.3 / 19.4 dB.
        for (bits, want) in [(2, 9.3), (3, 14.3), (4, 19.4)] {
            let z = quantize(&w, rows, cols, QuantSpec { bits, col_scale: false, iters: 1 }).unwrap();
            assert!((z.sqnr_db() - want).abs() < 0.5, "{bits} bits: {} dB", z.sqnr_db());
        }
    }

    #[test]
    fn reported_error_matches_reconstruction() {
        let (rows, cols) = (32, 256);
        let mut rng = Rng::new(9);
        let w: Vec<f32> =
            (0..rows * cols).map(|i| gaussian(&mut rng) * (1.0 + (i % cols) as f32 / 64.0)).collect();
        let z = quantize(&w, rows, cols, QuantSpec { bits: 4, col_scale: true, iters: 3 }).unwrap();
        let mut err = 0f64;
        for i in 0..rows {
            for j in 0..cols {
                let d = (w[i * cols + j] - z.reconstruct(i, j)) as f64;
                err += d * d;
            }
        }
        assert!((err - z.sq_err).abs() <= 1e-3 * err.max(1e-12), "{err} vs {}", z.sq_err);
        // Columns have very different magnitudes here, so column scales must help.
        let plain = quantize(&w, rows, cols, QuantSpec { bits: 4, col_scale: false, iters: 1 }).unwrap();
        assert!(z.sq_err < plain.sq_err);
    }
}
