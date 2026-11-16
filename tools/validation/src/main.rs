//! xf-validate: run converted matrices on the B60 and compare with the
//! original weights.
//!
//!   xf-validate gemm <checkpoint_dir> <model.xfm> <tensor substring> [more substrings]
//!
//! For every matching matrix and a Gaussian test vector `x` (one per token):
//!
//!   y_ref   = W x              original bf16 weights, f64 on the CPU
//!   y_q     = W^ x             reconstructed quantised weights, f64 on the CPU
//!   y_gpu                      XeFlash kernel: column scales folded into x,
//!                              x quantised to 8 or 16 bits, native DPAS
//!
//! `gpu vs q` isolates what the *arithmetic* costs (activation quantisation and
//! float rounding); `q vs ref` is what the *weight format* costs. They are
//! reported separately on purpose.

use rayon::prelude::*;
use xeflash_core::{Error, Result, Rng};
use xeflash_model::{Checkpoint, Container};
use xeflash_quant::{pack_activations, split_a16, unpack_weights};
use xeflash_runtime::{Device, Gemm};

fn rel(a: &[f64], b: &[f64]) -> f64 {
    let (mut d, mut n) = (0f64, 0f64);
    for (x, y) in a.iter().zip(b) {
        d += (x - y) * (x - y);
        n += y * y;
    }
    (d / n.max(1e-300)).sqrt()
}

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() < 4 || args[0] != "gemm" {
        return Err(Error::Invalid("usage: xf-validate gemm <checkpoint_dir> <model.xfm> <tensor substring>...".into()));
    }
    let ck = Checkpoint::open(std::path::Path::new(&args[1]))?;
    let xfm = Container::open(std::path::Path::new(&args[2]))?;
    let dev = Device::open()?;
    let tokens = 8usize;

    println!(
        "{:<58} {:>12} {:>10} {:>12} {:>12} {:>12}",
        "tensor", "shape", "q vs ref", "gpu8 vs q", "gpu16 vs q", "gpu16 vs ref"
    );
    let names: Vec<String> = xfm
        .names()
        .filter(|(n, k)| *k == "matrix" && args[3..].iter().any(|s| n.contains(s.as_str())))
        .map(|(n, _)| n.to_string())
        .collect();
    if names.is_empty() {
        return Err(Error::Invalid("no matrix in the container matches".into()));
    }
    for name in names {
        let m = xfm.matrix(&name)?;
        let (rows, cols) = (m.rows, m.cols);
        let w = ck.get(&name)?.to_f32()?;
        let q = unpack_weights(m.format, rows, cols, m.tiles)?;

        // Test activations: unit Gaussian, a different vector per token.
        let mut rng = Rng::new(0x5EED ^ rows as u64);
        let x: Vec<f32> = (0..tokens * cols).map(|_| (0..12).map(|_| rng.unit_f32()).sum::<f32>() * 0.5).collect();

        // CPU references.
        let mut y_ref = vec![0f64; tokens * rows];
        let mut y_q = vec![0f64; tokens * rows];
        for t in 0..tokens {
            let xt = &x[t * cols..(t + 1) * cols];
            let xc: Vec<f64> = xt.iter().zip(&m.col_scale).map(|(a, c)| *a as f64 * *c as f64).collect();
            let out: Vec<(f64, f64)> = (0..rows)
                .into_par_iter()
                .map(|i| {
                    let (wr, qr) = (&w[i * cols..(i + 1) * cols], &q[i * cols..(i + 1) * cols]);
                    let (mut a, mut b) = (0f64, 0f64);
                    for j in 0..cols {
                        a += wr[j] as f64 * xt[j] as f64;
                        b += (qr[j] as f64 + 0.5) * xc[j];
                    }
                    (a, b * m.row_scale[i] as f64)
                })
                .collect();
            for (i, (a, b)) in out.into_iter().enumerate() {
                y_ref[t * rows + i] = a;
                y_q[t * rows + i] = b;
            }
        }

        // GPU: fold column scales into x, quantise per token to `abits`.
        let w_dev = dev.upload(m.tiles)?;
        let rs_dev = dev.upload(&m.row_scale)?;
        let y_dev = dev.alloc(tokens * rows * 4)?;
        let mut gpu = Vec::new();
        for abits in [8u32, 16] {
            let qmax = ((1i32 << (abits - 1)) - 1) as f32;
            let mut xi = vec![0i16; tokens * cols];
            let mut ts = vec![0f32; tokens];
            let mut toff = vec![0f32; tokens];
            for t in 0..tokens {
                let xc: Vec<f32> = (0..cols).map(|j| x[t * cols + j] * m.col_scale[j]).collect();
                let amax = xc.iter().fold(0f32, |a, v| a.max(v.abs())).max(1e-30);
                let step = amax / qmax;
                let mut sum = 0i64;
                for j in 0..cols {
                    let v = (xc[j] / step).round().clamp(-qmax, qmax) as i16;
                    xi[t * cols + j] = v;
                    sum += v as i64;
                }
                ts[t] = step;
                toff[t] = 0.5 * sum as f32; // the +0.5 of the level grid
            }
            let ts_dev = dev.upload(&ts)?;
            let to_dev = dev.upload(&toff)?;
            let (x_dev, lo_dev) = if abits == 16 {
                let (hi, lo) = split_a16(&xi);
                (
                    dev.upload(&pack_activations(tokens, tokens, cols, &hi)?)?,
                    Some(dev.upload(&pack_activations(tokens, tokens, cols, &lo)?)?),
                )
            } else {
                let x8: Vec<i8> = xi.iter().map(|v| *v as i8).collect();
                (dev.upload(&pack_activations(tokens, tokens, cols, &x8)?)?, None)
            };
            dev.gemm(&Gemm {
                format: m.format,
                rows,
                cols,
                tokens,
                tokens_per_thread: 8,
                segs: 1,
                w: &w_dev,
                x: &x_dev,
                x_lo: lo_dev.as_ref(),
                row_scale: &rs_dev,
                token_scale: &ts_dev,
                y: &y_dev,
                y_part: None,
                token_offset: Some(&to_dev),
            })?;
            dev.wait()?;
            let mut y = vec![0f32; tokens * rows];
            y_dev.read(0, &mut y)?;
            gpu.push(y.iter().map(|v| *v as f64).collect::<Vec<f64>>());
        }
        println!(
            "{:<58} {:>12} {:>10.4} {:>12.2e} {:>12.2e} {:>12.4}",
            name.trim_start_matches("model.language_model."),
            format!("{rows}x{cols}"),
            rel(&y_q, &y_ref),
            rel(&gpu[0], &y_q),
            rel(&gpu[1], &y_q),
            rel(&gpu[1], &y_ref)
        );
    }
    Ok(())
}
