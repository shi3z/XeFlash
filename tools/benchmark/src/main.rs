//! xf-bench: GEMM benchmark on the Arc Pro B60 with real Qwen3.8-27B matrix
//! shapes and synthetic high-entropy weights.
//!
//! Every case is first checked against a CPU reference (sampled rows, all
//! tokens), then timed. The time reported is the steady-state cost of one
//! GEMM when launches are queued back to back, which is how the engine runs
//! them; it covers weight read, operand supply, DPAS, scaling and the output
//! write.
//!
//! Run through scripts/b60run so the GPU lock is held.

use std::fmt::Write as _;
use std::time::Instant;

use xeflash_core::{Error, Result, Rng, WeightFormat, bf16_to_f32, f32_to_bf16};
use xeflash_quant::{pack_activations, pack_activations_bf16, pack_weights, pack_weights_bf16, split_a16};
use xeflash_runtime::{Device, DeviceBuf, Gemm};

#[derive(Clone, Copy)]
struct Shape {
    name: &'static str,
    rows: usize,
    cols: usize,
}

/// Real shapes of the model (rows = out features, cols = in features).
const SHAPES: &[Shape] = &[
    Shape { name: "mlp.gate/up", rows: 17408, cols: 5120 },
    Shape { name: "mlp.down", rows: 5120, cols: 17408 },
    Shape { name: "gdn.qkv", rows: 10240, cols: 5120 },
    // Row-stacked matrices of merged containers.
    Shape { name: "merged.qkvz", rows: 16384, cols: 5120 },
    Shape { name: "merged.attn_qkv", rows: 14336, cols: 5120 },
    Shape { name: "merged.gate_up", rows: 34816, cols: 5120 },
    // Output projections of the 27B model (GDN out and attention o): 64 per pass, the narrowest GEMMs.
    Shape { name: "out_proj", rows: 5120, cols: 6144 },
    // The output head (vocabulary x hidden).
    Shape { name: "lm_head", rows: 248320, cols: 5120 },
];

struct Case {
    shape: Shape,
    format: WeightFormat,
    tokens: usize,
    tpt: usize,
    segs: usize,
    a16: bool,
}

struct Outcome {
    ms: f64,
    ms_median: f64,
    max_rel_err: f64,
    exact: bool,
}

struct Weights {
    dev: DeviceBuf,
    /// Row-major values as f64-free integers (int formats) or bf16 bits.
    int: Vec<i8>,
    bf16: Vec<u16>,
    row_scale: Vec<f32>,
    row_scale_dev: DeviceBuf,
    /// Extra device copies of the packed weights (--cold): the timing loop cycles through them so that the weights come from DRAM, not L2.
    copies: Vec<DeviceBuf>,
}

fn make_weights(dev: &Device, shape: Shape, format: WeightFormat, cold: bool) -> Result<Weights> {
    let n = shape.rows * shape.cols;
    let mut rng = Rng::new(0xC0FFEE ^ (n as u64) ^ ((format as u64) << 40));
    let row_scale: Vec<f32> = (0..shape.rows).map(|_| 0.5 + 0.5 * rng.unit_f32().abs()).collect();
    let row_scale_dev = dev.upload(&row_scale)?;
    if format == WeightFormat::Bf16 {
        let bf16: Vec<u16> = (0..n).map(|_| f32_to_bf16(rng.unit_f32())).collect();
        let packed = pack_weights_bf16(shape.rows, shape.cols, &bf16)?;
        let nc = if cold { (160_000_000usize / (packed.len() * 4).max(1)).max(1) } else { 0 };
        let copies = (0..nc).map(|_| dev.upload(&packed)).collect::<Result<Vec<_>>>()?;
        Ok(Weights { dev: dev.upload(&packed)?, int: Vec::new(), bf16, row_scale, row_scale_dev, copies })
    } else {
        let (lo, hi) = format.int_range();
        let int: Vec<i8> = (0..n).map(|_| rng.range_i8(lo, hi)).collect();
        let packed = pack_weights(format, shape.rows, shape.cols, &int)?;
        let nc = if cold { (160_000_000usize / (packed.len() * std::mem::size_of_val(&packed[0])).max(1)).max(1) } else { 0 };
        let copies = (0..nc).map(|_| dev.upload(&packed)).collect::<Result<Vec<_>>>()?;
        Ok(Weights { dev: dev.upload(&packed)?, int, bf16: Vec::new(), row_scale, row_scale_dev, copies })
    }
}

fn run_case(dev: &Device, w: &Weights, c: &Case, min_time: f64) -> Result<Outcome> {
    let Shape { rows, cols, .. } = c.shape;
    let m = c.tokens;
    let mpad = m.div_ceil(c.tpt) * c.tpt;
    let mut rng = Rng::new(42 + m as u64);

    let token_scale: Vec<f32> = (0..mpad).map(|_| 0.75 + 0.25 * rng.unit_f32().abs()).collect();
    let ts_dev = dev.upload(&token_scale)?;
    let is_int = c.format != WeightFormat::Bf16;
    let token_offset: Vec<f32> = (0..mpad).map(|_| if is_int { (rng.next_u64() >> 44) as f32 * 0.5 - 250000.0 } else { 0.0 }).collect();
    let to_dev = if is_int { Some(dev.upload(&token_offset)?) } else { None };
    let y_dev = dev.alloc(mpad * rows * 4)?;
    let planes = 1 + c.a16 as usize;
    let ypart_dev = if c.segs > 1 { Some(dev.alloc(c.segs * planes * mpad * rows * 4)?) } else { None };

    // Activations and the CPU-side copies used by the reference.
    let mut x_i16: Vec<i16> = Vec::new();
    let mut x_bf: Vec<u16> = Vec::new();
    let (x_dev, xlo_dev) = if c.format == WeightFormat::Bf16 {
        x_bf = (0..m * cols).map(|_| f32_to_bf16(rng.unit_f32())).collect();
        (dev.upload(&pack_activations_bf16(m, mpad, cols, &x_bf)?)?, None)
    } else if c.a16 {
        x_i16 = (0..m * cols).map(|_| (rng.next_u64() >> 48) as i16).collect();
        let (hi, lo) = split_a16(&x_i16);
        (
            dev.upload(&pack_activations(m, mpad, cols, &hi)?)?,
            Some(dev.upload(&pack_activations(m, mpad, cols, &lo)?)?),
        )
    } else {
        x_i16 = (0..m * cols).map(|_| rng.range_i8(-127, 127) as i16).collect();
        let x8: Vec<i8> = x_i16.iter().map(|v| *v as i8).collect();
        (dev.upload(&pack_activations(m, mpad, cols, &x8)?)?, None)
    };

    let gemm = Gemm {
        format: c.format,
        rows,
        cols,
        tokens: m,
        tokens_per_thread: c.tpt,
        segs: c.segs,
        w: &w.dev,
        x: &x_dev,
        x_lo: xlo_dev.as_ref(),
        row_scale: &w.row_scale_dev,
        token_scale: &ts_dev,
        y: &y_dev,
        y_part: ypart_dev.as_ref(),
        token_offset: to_dev.as_ref(),
    };

    // ---- correctness (also serves as JIT warm-up) ----
    dev.gemm(&gemm)?;
    dev.wait()?;
    let mut y = vec![0f32; mpad * rows];
    y_dev.read(0, &mut y)?;
    let mut max_rel = 0f64;
    let mut exact = true;
    let row_step = 251;
    for i in 0..m {
        for row in (0..rows).step_by(row_step) {
            let got = y[i * rows + row];
            let want: f32;
            let tol_ref: f64;
            if c.format == WeightFormat::Bf16 {
                let mut acc = 0f64;
                let mut mag = 0f64;
                for col in 0..cols {
                    let p = bf16_to_f32(w.bf16[row * cols + col]) as f64 * bf16_to_f32(x_bf[i * cols + col]) as f64;
                    acc += p;
                    mag += p.abs();
                }
                want = (acc * w.row_scale[row] as f64 * token_scale[i] as f64) as f32;
                tol_ref = mag * w.row_scale[row] as f64 * token_scale[i] as f64;
            } else if c.a16 {
                // The kernel accumulates the two byte planes separately.
                let (mut hi, mut lo) = (0i32, 0i32);
                for col in 0..cols {
                    let wv = w.int[row * cols + col] as i32;
                    let xv = x_i16[i * cols + col] as i32;
                    hi = hi.wrapping_add(wv * (xv >> 8));
                    lo = lo.wrapping_add(wv * (xv & 0xFF));
                }
                let f = hi as f32 * 256.0 + lo as f32 + token_offset[i];
                want = f * w.row_scale[row] * token_scale[i];
                tol_ref = want.abs() as f64;
            } else {
                let mut acc = 0i32;
                for col in 0..cols {
                    acc = acc.wrapping_add(w.int[row * cols + col] as i32 * x_i16[i * cols + col] as i32);
                }
                want = (acc as f32 + token_offset[i]) * w.row_scale[row] * token_scale[i];
                tol_ref = want.abs() as f64;
            }
            if got.to_bits() != want.to_bits() {
                exact = false;
            }
            let rel = (got as f64 - want as f64).abs() / tol_ref.max(1e-30);
            max_rel = max_rel.max(rel);
        }
    }

    // ---- timing ----
    let srcs: Vec<&DeviceBuf> = if w.copies.is_empty() { vec![&w.dev] } else { w.copies.iter().collect() };
    let mut rot: Vec<Gemm> = Vec::new();
    for wb in srcs {
        rot.push(Gemm {
            format: c.format,
            rows,
            cols,
            tokens: m,
            tokens_per_thread: c.tpt,
            segs: c.segs,
            w: wb,
            x: &x_dev,
            x_lo: xlo_dev.as_ref(),
            row_scale: &w.row_scale_dev,
            token_scale: &ts_dev,
            y: &y_dev,
            y_part: ypart_dev.as_ref(),
            token_offset: to_dev.as_ref(),
        });
    }
    let t0 = Instant::now();
    dev.gemm(&rot[0])?;
    dev.wait()?;
    let one = t0.elapsed().as_secs_f64();
    let reps = ((min_time / one.max(1e-6)).ceil() as usize).clamp(3, 2000);
    let mut samples = Vec::new();
    for _ in 0..5 {
        let t = Instant::now();
        for i in 0..reps {
            dev.gemm(&rot[i % rot.len()])?;
        }
        dev.wait()?;
        samples.push(t.elapsed().as_secs_f64() / reps as f64 * 1e3);
    }
    samples.sort_by(|a, b| a.partial_cmp(b).unwrap());
    Ok(Outcome { ms: samples[0], ms_median: samples[2], max_rel_err: max_rel, exact })
}

fn launch_overhead(dev: &Device) -> Result<(f64, f64)> {
    for _ in 0..100 {
        dev.noop()?;
    }
    dev.wait()?;
    let n = 2000;
    let t = Instant::now();
    for _ in 0..n {
        dev.noop()?;
    }
    dev.wait()?;
    let queued = t.elapsed().as_secs_f64() / n as f64 * 1e6;
    let t = Instant::now();
    for _ in 0..n {
        dev.noop()?;
        dev.wait()?;
    }
    let waited = t.elapsed().as_secs_f64() / n as f64 * 1e6;
    Ok((queued, waited))
}

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let quick = args.iter().any(|a| a == "--quick");
    let json_path = args.iter().position(|a| a == "--json").and_then(|i| args.get(i + 1)).cloned();
    let only_shape = args.iter().position(|a| a == "--shape").and_then(|i| args.get(i + 1)).cloned();
    let only_fmt = args.iter().position(|a| a == "--format").and_then(|i| args.get(i + 1)).cloned();
    if let Some(bad) = args.iter().find(|a| a.starts_with("--") && !["--quick", "--json", "--shape", "--format", "--segs", "--tokens", "--cold"].contains(&a.as_str())) {
        return Err(Error::Invalid(format!("unknown option {bad}")));
    }

    let dev = Device::open()?;
    let info = dev.info()?;
    println!("device   : {} (driver {})", info.name, info.driver);
    println!(
        "memory   : {:.2} GiB total, {:.2} GiB free, max single allocation {:.2} GiB",
        info.vram_total as f64 / (1u64 << 30) as f64,
        info.vram_free as f64 / (1u64 << 30) as f64,
        info.max_alloc as f64 / (1u64 << 30) as f64
    );
    println!(
        "threads  : {} EU x {} = {}   SLM {} KiB   {} MHz",
        info.eu_count,
        info.threads_per_eu,
        info.eu_count * info.threads_per_eu,
        info.slm_bytes / 1024,
        info.clock_mhz
    );
    let (queued, waited) = launch_overhead(&dev)?;
    println!("launch   : {queued:.2} us queued, {waited:.2} us with a wait per launch\n");

    // --segs 1,2,4,8 : column segments to try (default 1 and, for narrow matrices, 4); --tokens 1,8,16 : token counts
    let cold = args.iter().any(|a| a == "--cold"); // rotate over weight copies > L2 so that DRAM bandwidth is measured
    let seg_list: Option<Vec<usize>> = args.iter().position(|a| a == "--segs").and_then(|i| args.get(i + 1)).map(|v| v.split(',').filter_map(|x| x.parse().ok()).collect());
    let tok_list: Option<Vec<usize>> = args.iter().position(|a| a == "--tokens").and_then(|i| args.get(i + 1)).map(|v| v.split(',').filter_map(|x| x.parse().ok()).collect());
    let formats =
        [WeightFormat::Bf16, WeightFormat::S8, WeightFormat::S4Exp8, WeightFormat::S4, WeightFormat::S3, WeightFormat::S2];
    let token_counts_vec: Vec<usize> = tok_list.clone().unwrap_or_else(|| if quick { vec![1, 8, 64] } else { vec![1, 8, 16, 64, 256] });
    let token_counts: &[usize] = &token_counts_vec;
    let min_time = if quick { 0.1 } else { 0.4 };

    println!(
        "{:<12} {:>12} {:>6} {:>4} {:>4} {:>4} {:>9} {:>9} {:>8} {:>8} {:>8}  {}",
        "matrix", "shape", "fmt", "tok", "tpt", "seg", "ms", "ms(med)", "Gw/s", "GB/s", "TOPS", "check"
    );
    let mut json = String::from("[\n");
    for shape in SHAPES {
        if only_shape.as_ref().is_some_and(|s| !shape.name.contains(s.as_str())) {
            continue;
        }
        for format in formats {
            if only_fmt.as_ref().is_some_and(|s| format.name() != s) {
                continue;
            }
            let w = make_weights(&dev, *shape, format, cold)?;
            for &tokens in token_counts {
                let tpt = match tokens {
                    1 => 1,
                    2..=8 => 8,
                    9..=16 => 16,
                    _ => 32,
                };
                let mut variants = vec![(1usize, false)];
                if tokens <= 16 && shape.rows < 8192 {
                    variants.push((4, false)); // few row blocks: add column workers
                }
                if matches!(format, WeightFormat::S4 | WeightFormat::S3 | WeightFormat::S8 | WeightFormat::S4Exp8) && tokens <= 16 {
                    variants.push((1, true)); // 16-bit activations
                    if shape.rows < 8192 {
                        variants.push((4, true));
                    }
                }
                if let Some(sl) = &seg_list {
                    variants.clear();
                    for &sg in sl {
                        variants.push((sg, false));
                        if matches!(format, WeightFormat::S4 | WeightFormat::S3 | WeightFormat::S8 | WeightFormat::S4Exp8) && tokens <= 16 {
                            variants.push((sg, true));
                        }
                    }
                }
                let tcol = if format == WeightFormat::Bf16 { 16 } else { 32 };
                let unroll = match tpt { 1 => 4, 8 => 2, _ => 1 };
                for (segs, a16) in variants {
                    if shape.cols % (tcol * unroll * segs) != 0 {
                        continue; // this segment count does not divide the columns
                    }
                    let case = Case { shape: *shape, format, tokens, tpt, segs, a16 };
                    let o = run_case(&dev, &w, &case, min_time)?;
                    let weights = (shape.rows * shape.cols) as f64;
                    let secs = o.ms * 1e-3;
                    let gw = weights / secs / 1e9;
                    let gb = weights * format.bits() as f64 / 8.0 / secs / 1e9;
                    let tops = 2.0 * weights * tokens as f64 * if a16 { 2.0 } else { 1.0 } / secs / 1e12;
                    let fmt_name = if a16 { format!("{}+a16", format.name()) } else { format.name().to_string() };
                    let check = if o.exact { "exact".to_string() } else { format!("rel {:.1e}", o.max_rel_err) };
                    println!(
                        "{:<12} {:>12} {:>6} {:>4} {:>4} {:>4} {:>9.4} {:>9.4} {:>8.1} {:>8.1} {:>8.2}  {}",
                        shape.name,
                        format!("{}x{}", shape.rows, shape.cols),
                        fmt_name,
                        tokens,
                        tpt,
                        segs,
                        o.ms,
                        o.ms_median,
                        gw,
                        gb,
                        tops,
                        check
                    );
                    let _ = writeln!(
                        json,
                        "  {{\"matrix\":\"{}\",\"rows\":{},\"cols\":{},\"format\":\"{}\",\"a16\":{},\"tokens\":{},\"tokens_per_thread\":{},\"segs\":{},\"ms\":{:.6},\"ms_median\":{:.6},\"gw_per_s\":{:.2},\"gb_per_s\":{:.2},\"tops\":{:.3},\"exact\":{},\"max_rel_err\":{:.3e}}},",
                        shape.name, shape.rows, shape.cols, format.name(), a16, tokens, tpt, segs, o.ms, o.ms_median, gw, gb, tops, o.exact, o.max_rel_err
                    );
                }
            }
        }
    }
    if let Some(path) = json_path {
        let body = json.trim_end().trim_end_matches(',').to_string() + "\n]\n";
        std::fs::write(&path, body)?;
        println!("\nwrote {path}");
    }
    Ok(())
}
