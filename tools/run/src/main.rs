//! xf-run: load the resident model on the B60 and run it.
//!
//!   xf-run mem  <model.xfm> [--ctx N]
//!   xf-run dump <model.xfm> <ids.json> <out_dir> [--chunk 1|8|16] [--ctx N]
//!   xf-run gen  <model.xfm> <ids.json> <n_new> [--ctx N] [--prefill-chunk 16] [--out ids.json]
//!
//! `ids.json` is a JSON array of token ids. Run through scripts/b60run.

use std::collections::BTreeMap;
use std::path::Path;
use std::time::Instant;

use xeflash_core::{Error, Result};
use xeflash_model::Container;
use xeflash_runtime::Device;
use xeflash_runtime::engine::{Engine, HIDDEN, LAYERS, PROF_NAMES, VOCAB};

const GIB: f64 = (1u64 << 30) as f64;

fn opt(args: &[String], key: &str) -> Option<String> {
    args.iter().position(|a| a == key).and_then(|i| args.get(i + 1)).cloned()
}

fn opt_usize(args: &[String], key: &str, default: usize) -> Result<usize> {
    opt(args, key).map_or(Ok(default), |v| v.parse().map_err(|_| Error::Invalid(format!("bad value for {key}"))))
}

fn read_ids(path: &str) -> Result<Vec<u32>> {
    let text = std::fs::read_to_string(path)?;
    text.trim()
        .trim_start_matches('[')
        .trim_end_matches(']')
        .split(',')
        .map(|s| s.trim().parse::<u32>().map_err(|_| Error::Invalid(format!("{path}: not a JSON array of token ids"))))
        .collect()
}

fn write_f32(path: &Path, data: &[f32]) -> Result<()> {
    let bytes: Vec<u8> = data.iter().flat_map(|v| v.to_le_bytes()).collect();
    Ok(std::fs::write(path, bytes)?)
}

fn load(dev: &Device, model: &str, ctx: usize) -> Result<Engine> {
    let before = dev.info()?.vram_free;
    let t = Instant::now();
    let xfm = Container::open(Path::new(model))?;
    let engine = Engine::load(dev, &xfm, ctx)?;
    dev.wait()?;
    let after = dev.info()?.vram_free;
    let mut by_cat: BTreeMap<&str, (usize, usize)> = BTreeMap::new();
    for a in engine.allocations() {
        let e = by_cat.entry(a.category).or_default();
        e.0 += a.bytes;
        e.1 += 1;
    }
    let total: usize = by_cat.values().map(|v| v.0).sum();
    eprintln!("loaded {model} in {:.1}s, context capacity {ctx} tokens", t.elapsed().as_secs_f64());
    eprintln!("{:<22} {:>6} {:>12}", "device allocations", "count", "GiB");
    for (cat, (bytes, count)) in &by_cat {
        eprintln!("  {:<20} {:>6} {:>12.4}", cat, count, *bytes as f64 / GIB);
    }
    eprintln!("  {:<20} {:>6} {:>12.4}", "TOTAL requested", engine.buffer_count(), total as f64 / GIB);
    eprintln!(
        "driver free VRAM: {:.4} GiB before, {:.4} GiB after, difference {:.4} GiB",
        before as f64 / GIB,
        after as f64 / GIB,
        (before as f64 - after as f64) / GIB
    );
    Ok(engine)
}

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let dev = Device::open()?;
    match args.first().map(String::as_str) {
        Some("mem") if args.len() >= 2 => {
            load(&dev, &args[1], opt_usize(&args, "--ctx", 8192)?)?;
            Ok(())
        }
        Some("dump") if args.len() >= 4 => dump(&dev, &args),
        Some("gen") if args.len() >= 4 => generate(&dev, &args),
        _ => Err(Error::Invalid("usage: xf-run mem|dump|gen ... (see the source header)".into())),
    }
}

/// Teacher-forced run that saves the hidden state after the embedding and
/// after every layer, plus logits, for comparison with the reference.
fn dump(dev: &Device, args: &[String]) -> Result<()> {
    let ids = read_ids(&args[2])?;
    let out = Path::new(&args[3]);
    std::fs::create_dir_all(out)?;
    let chunk = opt_usize(args, "--chunk", 16)?;
    let mut e = load(dev, &args[1], opt_usize(args, "--ctx", 8192)?)?;
    let t = ids.len();
    let mut hidden = vec![vec![0f32; t * HIDDEN]; LAYERS + 1];
    let mut logits = vec![0f32; t * VOCAB];
    let mut greedy = Vec::new();
    for (ci, c) in ids.chunks(chunk).enumerate() {
        let at = ci * chunk * HIDDEN;
        e.set_tokens(c)?;
        e.run_layers(0, 0, true, false, None)?;
        hidden[0][at..at + c.len() * HIDDEN].copy_from_slice(&e.read_hidden()?);
        for l in 0..LAYERS {
            e.run_layers(l, l + 1, false, l + 1 == LAYERS, None)?;
            hidden[l + 1][at..at + c.len() * HIDDEN].copy_from_slice(&e.read_hidden()?);
        }
        let lo = ci * chunk * VOCAB;
        logits[lo..lo + c.len() * VOCAB].copy_from_slice(&e.read_logits()?);
        greedy.extend(e.argmax()?.iter().map(|g| g.0));
        e.commit(c.len())?;
    }
    for (l, h) in hidden.iter().enumerate() {
        write_f32(&out.join(format!("h{l:02}.bin")), h)?;
    }
    write_f32(&out.join("logits.bin"), &logits)?;
    std::fs::write(out.join("greedy.json"), format!("{greedy:?}"))?;
    eprintln!("dumped {t} tokens (chunks of {chunk}) to {}", out.display());
    Ok(())
}

fn generate(dev: &Device, args: &[String]) -> Result<()> {
    let prompt = read_ids(&args[2])?;
    let n_new: usize = args[3].parse().map_err(|_| Error::Invalid("bad token count".into()))?;
    let pchunk = opt_usize(args, "--prefill-chunk", 16)?;
    let mut e = load(dev, &args[1], opt_usize(args, "--ctx", 8192)?)?;

    // Warm-up: compile every kernel variant, then start from a clean state.
    for m in [1usize, 2, 16] {
        e.forward(&prompt[..m.min(prompt.len())], None)?;
        e.commit(0)?;
    }
    e.reset()?;

    let t0 = Instant::now();
    let mut next = 0u32;
    for c in prompt.chunks(pchunk) {
        next = e.forward(c, None)?.last().unwrap().0;
        e.commit(c.len())?;
    }
    dev.wait()?;
    let prefill = t0.elapsed().as_secs_f64();

    let mut out = Vec::with_capacity(n_new);
    let t1 = Instant::now();
    for _ in 0..n_new {
        out.push(next);
        next = e.forward(&[next], None)?[0].0;
        e.commit(1)?;
    }
    dev.wait()?;
    let decode = t1.elapsed().as_secs_f64();

    // A separate profiled token (synchronises after every stage, so it is slower).
    let mut prof = [0f64; 7];
    let reps = 8;
    for _ in 0..reps {
        next = e.forward(&[next], Some(&mut prof))?[0].0;
        e.commit(1)?;
    }
    println!("{out:?}");
    if let Some(path) = opt(args, "--out") {
        std::fs::write(&path, format!("{out:?}"))?;
    }
    eprintln!(
        "prefill: {} tokens in {:.3}s = {:.1} tok/s (chunks of {pchunk})",
        prompt.len(),
        prefill,
        prompt.len() as f64 / prefill
    );
    eprintln!(
        "decode : {} tokens in {:.3}s = {:.2} tok/s, {:.2} ms/token (no speculation)",
        n_new,
        decode,
        n_new as f64 / decode,
        decode / n_new as f64 * 1e3
    );
    let total: f64 = prof.iter().sum();
    eprint!("profile (1 token, sync per stage, ms):");
    for (n, v) in PROF_NAMES.iter().zip(prof) {
        eprint!(" {n} {:.2}", v / reps as f64);
    }
    eprintln!(" | total {:.2}", total / reps as f64);
    Ok(())
}
