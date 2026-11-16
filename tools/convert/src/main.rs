//! xf-convert: inspect the original checkpoint and study / produce XeFlash
//! weight formats. CPU only; never touches the GPU.
//!
//!   xf-convert inspect <checkpoint_dir>
//!   xf-convert analyze <checkpoint_dir> [--layers 0,31,63] [--json out.json]
//!   xf-convert convert <checkpoint_dir> <out.xfm> [--bits 4|2|8] [--only substring]
//!   xf-convert verify  <checkpoint_dir> <model.xfm>

use std::collections::BTreeMap;
use std::fmt::Write as _;
use std::path::Path;
use std::time::Instant;

use xeflash_core::{Error, Result, WeightFormat};
use xeflash_model::{Checkpoint, Container, ContainerWriter, Dtype};
use xeflash_quant::{QuantSpec, pack_weights, quantize, unpack_weights};

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("inspect") if args.len() >= 2 => inspect(Path::new(&args[1])),
        Some("analyze") if args.len() >= 2 => analyze(Path::new(&args[1]), &args[2..]),
        Some("convert") if args.len() >= 3 => convert(Path::new(&args[1]), Path::new(&args[2]), &args[3..]),
        Some("verify") if args.len() >= 3 => verify(Path::new(&args[1]), Path::new(&args[2])),
        _ => Err(Error::Invalid(
            "usage: xf-convert inspect <dir> | analyze <dir> [--layers a,b,c] [--json out.json] | \
             convert <dir> <out.xfm> [--bits 4|2|8] [--only substring] | verify <dir> <model.xfm>"
                .into(),
        )),
    }
}

/// Replace layer / block indices by `N` so tensors group by role.
fn pattern(name: &str) -> String {
    name.split('.').map(|p| if p.chars().all(|c| c.is_ascii_digit()) { "N" } else { p }).collect::<Vec<_>>().join(".")
}

fn inspect(dir: &Path) -> Result<()> {
    let ck = Checkpoint::open(dir)?;
    // pattern -> (shape, dtype, count, params)
    let mut groups: BTreeMap<(String, Vec<usize>), (String, usize, usize)> = BTreeMap::new();
    let mut total = 0usize;
    for name in ck.names() {
        let t = ck.get(name)?;
        let e = groups.entry((pattern(name), t.shape.to_vec())).or_insert((format!("{:?}", t.dtype), 0, 0));
        e.1 += 1;
        e.2 += t.numel();
        total += t.numel();
    }
    println!("{:<62} {:>18} {:>6} {:>5} {:>16}", "tensor pattern", "shape", "dtype", "count", "params");
    for ((pat, shape), (dtype, count, params)) in &groups {
        let shape = shape.iter().map(|d| d.to_string()).collect::<Vec<_>>().join("x");
        println!("{pat:<62} {shape:>18} {dtype:>6} {count:>5} {params:>16}");
    }
    println!("total parameters: {total} ({:.3} B)", total as f64 / 1e9);
    Ok(())
}

fn analyze(dir: &Path, rest: &[String]) -> Result<()> {
    let opt = |k: &str| rest.iter().position(|a| a == k).and_then(|i| rest.get(i + 1)).cloned();
    let layers: Vec<usize> = opt("--layers")
        .unwrap_or_else(|| "0,3,30,31,62,63".into())
        .split(',')
        .map(|s| s.parse().map_err(|_| Error::Invalid(format!("bad layer index {s}"))))
        .collect::<Result<_>>()?;
    let ck = Checkpoint::open(dir)?;
    let roles = [
        "mlp.gate_proj", "mlp.up_proj", "mlp.down_proj",
        "linear_attn.in_proj_qkv", "linear_attn.in_proj_z", "linear_attn.out_proj",
        "self_attn.q_proj", "self_attn.k_proj", "self_attn.v_proj", "self_attn.o_proj",
    ];
    // (label, bits, column scales)
    let variants = [("s8 r", 8, false), ("s4 r", 4, false), ("s4 r+c", 4, true), ("s3 r+c", 3, true), ("s2 r", 2, false), ("s2 r+c", 2, true)];
    print!("{:<46} {:>12}", "tensor", "shape");
    for (label, _, _) in variants {
        print!(" {label:>8}");
    }
    println!("   (SQNR dB; r = row scale, c = column scale)");
    let mut json = String::from("[\n");
    for layer in layers {
        for role in roles {
            let Some(name) = ck.names().find(|n| *n == format!("model.language_model.layers.{layer}.{role}.weight")).map(str::to_string) else {
                continue; // role not present in this layer type
            };
            let t = ck.get(&name)?;
            if t.shape.len() != 2 {
                return Err(Error::Invalid(format!("{name} is not a matrix")));
            }
            let (rows, cols) = (t.shape[0], t.shape[1]);
            let w = t.to_f32()?;
            let short = name.rsplit("layers.").next().unwrap_or(&name).trim_end_matches(".weight");
            print!("{:<46} {:>12}", format!("L{short}"), format!("{rows}x{cols}"));
            let t0 = Instant::now();
            let _ = write!(json, "  {{\"tensor\":\"{name}\",\"rows\":{rows},\"cols\":{cols}");
            for (label, bits, col_scale) in variants {
                let z = quantize(&w, rows, cols, QuantSpec { bits, col_scale, iters: 3 })?;
                print!(" {:>8.2}", z.sqnr_db());
                let _ = write!(json, ",\"{label}\":{:.3}", z.sqnr_db());
            }
            json.push_str("},\n");
            println!("   [{:.1}s]", t0.elapsed().as_secs_f64());
        }
    }
    if let Some(path) = opt("--json") {
        std::fs::write(&path, json.trim_end().trim_end_matches(',').to_string() + "\n]\n")?;
        println!("wrote {path}");
    }
    Ok(())
}

/// Which tensors become low-bit GEMM matrices. Everything else is copied
/// verbatim: norms, the DeltaNet gate vectors and conv taps are tiny, and the
/// embedding table is a lookup, not a GEMM.
fn is_gemm_matrix(name: &str, shape: &[usize]) -> bool {
    shape.len() == 2
        && shape[0] % 16 == 0
        && shape[1] % 32 == 0
        && shape[0] * shape[1] >= 1 << 20
        && !name.ends_with("embed_tokens.weight")
}

/// The vision tower is outside the scope of the text engine.
fn is_text_tensor(name: &str) -> bool {
    !name.starts_with("model.visual")
}

fn dtype_name(d: Dtype) -> Result<&'static str> {
    match d {
        Dtype::Bf16 => Ok("bf16"),
        Dtype::F16 => Ok("f16"),
        Dtype::F32 => Ok("f32"),
        Dtype::Other => Err(Error::Invalid("unsupported dtype in checkpoint".into())),
    }
}

/// Below this SQNR a matrix is not quantised but copied verbatim. Every body
/// matrix of the model is above 17.7 dB at 4 bits.
const FALLBACK_DB: f64 = 16.0;

fn convert(dir: &Path, out: &Path, rest: &[String]) -> Result<()> {
    let opt = |k: &str| rest.iter().position(|a| a == k).and_then(|i| rest.get(i + 1)).cloned();
    let bits: u32 = opt("--bits").map_or(Ok(4), |b| b.parse().map_err(|_| Error::Invalid("bad --bits".into())))?;
    let format = match bits {
        4 => WeightFormat::S4,
        2 => WeightFormat::S2,
        8 => WeightFormat::S8,
        _ => return Err(Error::Invalid("--bits must be 4, 2 or 8 (formats DPAS consumes directly)".into())),
    };
    let only = opt("--only");
    let ck = Checkpoint::open(dir)?;
    let meta = serde_json::json!({
        "source": dir.display().to_string(),
        "quantizer": "row+column scale, half-offset grid, 3 rounds, data-free",
        "default_bits": bits,
    });
    let mut writer = ContainerWriter::create(out, meta, 1 << 20)?;
    let names: Vec<String> = ck
        .names()
        .filter(|n| is_text_tensor(n) && only.as_ref().is_none_or(|o| n.contains(o.as_str())))
        .map(str::to_string)
        .collect();
    let t_all = Instant::now();
    let (mut n_mat, mut n_dense, mut weights, mut sum_db, mut min_db) = (0usize, 0usize, 0usize, 0f64, f64::INFINITY);
    for (i, name) in names.iter().enumerate() {
        let t = ck.get(name)?;
        if is_gemm_matrix(name, t.shape) {
            let (rows, cols) = (t.shape[0], t.shape[1]);
            let t0 = Instant::now();
            let w = t.to_f32()?;
            let z = quantize(&w, rows, cols, QuantSpec { bits, col_scale: true, iters: 3 })?;
            // A matrix that is far from Gaussian (mtp.fc: 5.4 dB at 4 bits and
            // still 6.5 dB at 8) cannot be carried by a uniform grid. Such
            // matrices are rare and small; keep the original data and let the
            // engine run them through the bf16 kernel.
            if z.sqnr_db() < FALLBACK_DB {
                writer.add_dense(name, dtype_name(t.dtype)?, t.shape, t.bytes)?;
                n_dense += 1;
                println!("[{:>4}/{}] {:<62} kept dense: {:.2} dB at {bits} bits", i + 1, names.len(), name, z.sqnr_db());
                continue;
            }
            let tiles = pack_weights(format, rows, cols, &z.q)?;
            writer.add_matrix(name, format, rows, cols, &tiles, &z.row_scale, &z.col_scale, z.sqnr_db())?;
            n_mat += 1;
            weights += rows * cols;
            sum_db += z.sqnr_db();
            min_db = min_db.min(z.sqnr_db());
            println!(
                "[{:>4}/{}] {:<62} {:>12} {} {:>6.2} dB  {:.1}s",
                i + 1,
                names.len(),
                name,
                format!("{rows}x{cols}"),
                format.name(),
                z.sqnr_db(),
                t0.elapsed().as_secs_f64()
            );
        } else {
            writer.add_dense(name, dtype_name(t.dtype)?, t.shape, t.bytes)?;
            n_dense += 1;
        }
    }
    let bytes = writer.finish()?;
    println!(
        "wrote {}: {:.3} GiB, {n_mat} matrices ({:.3} B weights, mean {:.2} dB, min {:.2} dB), {n_dense} dense tensors, {:.0}s",
        out.display(),
        bytes as f64 / (1u64 << 30) as f64,
        weights as f64 / 1e9,
        sum_db / n_mat.max(1) as f64,
        min_db,
        t_all.elapsed().as_secs_f64()
    );
    Ok(())
}

/// Re-read a container and check it against the checkpoint it came from:
/// dense tensors must be byte-identical, and every matrix must reconstruct
/// with the SQNR the converter recorded.
fn verify(dir: &Path, model: &Path) -> Result<()> {
    let ck = Checkpoint::open(dir)?;
    let xfm = Container::open(model)?;
    let entries: Vec<(String, String)> = xfm.names().map(|(n, k)| (n.to_string(), k.to_string())).collect();
    let (mut bad, mut n_mat, mut sum_db, mut min_db) = (0usize, 0usize, 0f64, f64::INFINITY);
    for (name, kind) in &entries {
        let t = ck.get(name)?;
        if kind == "dense" {
            if xfm.dense(name)?.bytes != t.bytes {
                println!("MISMATCH dense {name}");
                bad += 1;
            }
            continue;
        }
        let m = xfm.matrix(name)?;
        if t.shape != [m.rows, m.cols] {
            println!("MISMATCH shape {name}");
            bad += 1;
            continue;
        }
        let w = t.to_f32()?;
        let q = unpack_weights(m.format, m.rows, m.cols, m.tiles)?;
        let (mut err, mut norm) = (0f64, 0f64);
        for i in 0..m.rows {
            let r = m.row_scale[i];
            let (wr, qr) = (&w[i * m.cols..(i + 1) * m.cols], &q[i * m.cols..(i + 1) * m.cols]);
            for j in 0..m.cols {
                let d = (wr[j] - r * (qr[j] as f32 + 0.5) * m.col_scale[j]) as f64;
                err += d * d;
                norm += (wr[j] as f64) * (wr[j] as f64);
            }
        }
        let db = 10.0 * (norm / err.max(1e-300)).log10();
        n_mat += 1;
        sum_db += db;
        min_db = min_db.min(db);
        if (db - m.sqnr_db).abs() > 0.02 {
            println!("MISMATCH {name}: reconstructs at {db:.3} dB, header says {:.3} dB", m.sqnr_db);
            bad += 1;
        }
    }
    println!(
        "{} tensors checked: {n_mat} matrices (mean {:.2} dB, min {:.2} dB), {} dense; {bad} mismatches",
        entries.len(),
        sum_db / n_mat.max(1) as f64,
        min_db,
        entries.len() - n_mat
    );
    if bad != 0 {
        return Err(Error::Invalid(format!("{bad} tensors failed verification")));
    }
    Ok(())
}
