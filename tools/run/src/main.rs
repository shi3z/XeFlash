//! xf-run: load the resident model on the B60 and run it.
//!
//!   xf-run mem  <model.xfm> [--ctx N]
//!   xf-run dump <model.xfm> <ids.json> <out_dir> [--chunk 1|8|16] [--ctx N]
//!   xf-run mtp-tf <model.xfm> <ids.json> [--out pred.json]
//!   xf-run gen  <model.xfm> <ids.json>[,<ids2.json>..] <n_new> [--ctx N] [--mtp K[,K..]] [--profile]
//!               [--json results.json] [--out prefix]
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
        Some("mtp-tf") if args.len() >= 3 => mtp_teacher_forced(&dev, &args),
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

/// Teacher-forced MTP: feed the true tokens and trunk hidden states, record
/// what the MTP block predicts at every position (prediction of token t+1 at
/// MTP position t). Comparable with tools/validation/ref_mtp.py.
fn mtp_teacher_forced(dev: &Device, args: &[String]) -> Result<()> {
    let ids = read_ids(&args[2])?;
    let mut e = load(dev, &args[1], opt_usize(args, "--ctx", 8192)?)?;
    let mut pred = vec![e.mtp_pass(&ids[..1], 0, None, None)?[0].0];
    for (ci, c) in ids.chunks(16).enumerate() {
        let start = ci * 16;
        e.forward(c, None)?;
        e.commit(c.len())?;
        let rows = c.len().min(ids.len() - 1 - start);
        if rows > 0 {
            pred.extend(e.mtp_pass(&ids[start + 1..start + 1 + rows], start + 1, Some(0), None)?.iter().map(|p| p.0));
        }
    }
    let t = ids.len();
    let hit = (1..t - 1).filter(|i| pred[*i] == ids[i + 1]).count();
    println!("{pred:?}");
    if let Some(path) = opt(args, "--out") {
        std::fs::write(&path, format!("{pred:?}"))?;
    }
    eprintln!("MTP teacher-forced top-1 accuracy {hit}/{} = {:.1}%", t - 2, 100.0 * hit as f64 / (t - 2) as f64);
    Ok(())
}

struct RunStats {
    out: Vec<u32>,
    emitted: usize,
    prefill_s: f64,
    decode_s: f64,
    passes: usize,
    t_main: f64,
    t_mtp: f64,
    tried: Vec<usize>,
    accepted: Vec<usize>,
}

/// Prefill `prompt`, then decode `n_new` tokens greedily with `k` MTP draft
/// tokens per cycle (0 = one token per trunk pass). `ignore_eos`-style: the
/// run always produces `n_new` tokens, like the benchmark it is compared with.
fn run_once(dev: &Device, e: &mut Engine, prompt: &[u32], n_new: usize, k: usize, pchunk: usize) -> Result<RunStats> {
    let trace = std::env::var_os("XF_TRACE").is_some();
    macro_rules! tr {
        ($($a:tt)*) => { if trace { eprintln!($($a)*); dev.wait()?; eprintln!("   ok"); } };
    }
    e.reset()?;
    let t0 = Instant::now();
    let mut next = 0u32;
    let mut d1 = 0u32; // MTP draft of the token after `next`
    let mut last_row = 0usize;
    if k > 0 {
        e.mtp_pass(&prompt[..1], 0, None, None)?; // MTP entry of the first token: zero hidden state
        tr!("mtp entry 0");
    }
    for (ci, c) in prompt.chunks(pchunk).enumerate() {
        next = e.forward(c, None)?.last().unwrap().0;
        tr!("prefill forward {}", c.len());
        e.commit(c.len())?;
        tr!("prefill commit");
        if k > 0 {
            let start = ci * pchunk;
            let ids: Vec<u32> = (0..c.len()).map(|i| *prompt.get(start + i + 1).unwrap_or(&next)).collect();
            d1 = e.mtp_pass(&ids, start + 1, Some(0), None)?.last().unwrap().0;
            last_row = c.len() - 1;
            tr!("prefill mtp rows {} at {}", c.len(), start + 1);
        }
    }
    dev.wait()?;
    let prefill_s = t0.elapsed().as_secs_f64();

    let mut out: Vec<u32> = Vec::with_capacity(n_new + 16);
    let (mut t_mtp, mut t_main) = (0f64, 0f64);
    let mut tried = vec![0usize; k + 1];
    let mut accepted = vec![0usize; k + 1];
    let mut passes = 0usize;
    let t1 = Instant::now();
    while out.len() < n_new {
        let pos = e.position();
        // Draft: `next` is certain (the trunk's own greedy choice); d1.. are MTP guesses.
        let tm = Instant::now();
        let mut drafts = vec![next];
        if k > 0 {
            drafts.push(d1);
            let mut src = last_row;
            for j in 2..=k {
                let d = e.mtp_pass(&[drafts[j - 1]], pos + j - 1, Some(src), None)?[0].0;
                tr!("draft {j} at {} src {src} -> {d}", pos + j - 1);
                drafts.push(d);
                src = 0;
            }
        }
        t_mtp += tm.elapsed().as_secs_f64();
        // Verify with the trunk and keep the agreeing prefix.
        let tv = Instant::now();
        tr!("verify {:?} at {pos}", drafts);
        let g = e.forward(&drafts, None)?;
        tr!("verified");
        let mut n = 1;
        while n < drafts.len() && g[n - 1].0 == drafts[n] {
            n += 1;
        }
        e.commit(n)?;
        tr!("commit {n}");
        t_main += tv.elapsed().as_secs_f64();
        for i in 1..drafts.len() {
            if i <= n {
                tried[i] += 1; // every earlier draft was accepted
            }
            if i < n {
                accepted[i] += 1;
            }
        }
        out.extend_from_slice(&drafts[..n]);
        next = g[n - 1].0;
        passes += 1;
        if k > 0 {
            // MTP cache entries for the committed tokens, from trunk hidden states;
            // the last row is also the first draft of the next cycle.
            let tm = Instant::now();
            let ids: Vec<u32> = (0..n).map(|i| if i + 1 < n { drafts[i + 1] } else { next }).collect();
            d1 = e.mtp_pass(&ids, pos + 1, Some(0), None)?.last().unwrap().0;
            last_row = n - 1;
            t_mtp += tm.elapsed().as_secs_f64();
        }
    }
    dev.wait()?;
    let decode_s = t1.elapsed().as_secs_f64();
    let emitted = out.len();
    out.truncate(n_new);
    Ok(RunStats { out, emitted, prefill_s, decode_s, passes, t_main, t_mtp, tried, accepted })
}

/// gen: `<ids.json>[,<ids2.json>...] <n_new> [--mtp K[,K2...]]`. Every prompt
/// is run with every draft length on one loaded model; outputs are compared
/// with the first draft length listed (use 0 first to check against plain
/// greedy decoding).
fn generate(dev: &Device, args: &[String]) -> Result<()> {
    let n_new: usize = args[3].parse().map_err(|_| Error::Invalid("bad token count".into()))?;
    let pchunk = opt_usize(args, "--prefill-chunk", 16)?;
    let ks: Vec<usize> = opt(args, "--mtp")
        .unwrap_or_else(|| "0".into())
        .split(',')
        .map(|v| v.parse().map_err(|_| Error::Invalid("bad --mtp list".into())))
        .collect::<Result<_>>()?;
    if ks.iter().any(|k| *k > 15) {
        return Err(Error::Invalid("--mtp must be at most 15 (a pass holds 16 tokens)".into()));
    }
    let mut e = load(dev, &args[1], opt_usize(args, "--ctx", 8192)?)?;
    if ks.iter().any(|k| *k > 0) && !e.has_mtp() {
        return Err(Error::Invalid("this container has no usable MTP block".into()));
    }
    let mut json = String::from("[\n");
    let mut all_equal = true;
    for (pi, path) in args[2].split(',').enumerate() {
        let prompt = read_ids(path)?;
        let name = Path::new(path).file_stem().and_then(|s| s.to_str()).unwrap_or(path).to_string();
        if pi == 0 {
            // Warm-up: compile every kernel variant.
            let trace = std::env::var_os("XF_TRACE").is_some();
            for m in [1usize, 2, 16] {
                if trace { eprintln!("warm-up forward {m}"); }
                e.forward(&prompt[..m.min(prompt.len())], None)?;
                if trace { dev.wait()?; eprintln!("warm-up commit"); }
                e.commit(0)?;
                if ks.iter().any(|k| *k > 0) {
                    if trace { dev.wait()?; eprintln!("warm-up mtp {m}"); }
                    e.mtp_pass(&prompt[..m.min(prompt.len())], 0, Some(0), None)?;
                }
                if trace { dev.wait()?; eprintln!("   ok"); }
            }
        }
        let mut base: Option<Vec<u32>> = None;
        for &k in &ks {
            let r = run_once(dev, &mut e, &prompt, n_new, k, pchunk)?;
            let same = base.as_ref().is_none_or(|b| *b == r.out);
            all_equal &= same;
            let tps = r.emitted as f64 / r.decode_s;
            let acc: Vec<String> =
                (1..=k).map(|i| format!("{:.0}%", 100.0 * r.accepted[i] as f64 / r.tried[i].max(1) as f64)).collect();
            eprintln!(
                "{name:<8} K={k:<2} {tps:>7.2} tok/s | {:.2} tok/pass | trunk {:>6.2} ms/pass, MTP {:>6.2} ms/pass | prefill {:.0} tok/s | accept [{}]{}",
                r.emitted as f64 / r.passes as f64,
                r.t_main / r.passes as f64 * 1e3,
                r.t_mtp / r.passes as f64 * 1e3,
                prompt.len() as f64 / r.prefill_s,
                acc.join(" "),
                if base.is_some() { if same { "  same tokens" } else { "  TOKENS DIFFER" } } else { "" }
            );
            let _ = std::fmt::Write::write_fmt(
                &mut json,
                format_args!(
                    "  {{\"prompt\":\"{name}\",\"prompt_tokens\":{},\"new_tokens\":{},\"mtp_k\":{k},\"tok_per_s\":{tps:.3},\"tokens_per_pass\":{:.4},\"trunk_ms_per_pass\":{:.3},\"mtp_ms_per_pass\":{:.3},\"prefill_tok_per_s\":{:.2},\"accepted\":{:?},\"tried\":{:?},\"same_as_first\":{same}}},\n",
                    prompt.len(),
                    r.emitted,
                    r.emitted as f64 / r.passes as f64,
                    r.t_main / r.passes as f64 * 1e3,
                    r.t_mtp / r.passes as f64 * 1e3,
                    prompt.len() as f64 / r.prefill_s,
                    &r.accepted[1..],
                    &r.tried[1..]
                ),
            );
            if base.is_none() {
                println!("{:?}", r.out);
                if let Some(out) = opt(args, "--out") {
                    std::fs::write(format!("{out}.{name}.json"), format!("{:?}", r.out))?;
                }
                base = Some(r.out);
            }
        }
    }
    eprintln!("outputs identical across draft lengths: {all_equal}");
    if let Some(path) = opt(args, "--json") {
        std::fs::write(&path, json.trim_end().trim_end_matches(',').to_string() + "\n]\n")?;
    }
    if args.iter().any(|a| a == "--profile") {
        // Separate profiled passes: they synchronise after every stage, so their sum is above the real pass time.
        for m in [1usize, 8, 16] {
            let mut prof = [0f64; 7];
            let reps = 6;
            let toks: Vec<u32> = (0..m as u32).map(|i| 1000 + i).collect();
            for _ in 0..reps {
                e.forward(&toks, Some(&mut prof))?;
                e.commit(0)?;
            }
            let total: f64 = prof.iter().sum();
            eprint!("profile ({m:>2} tokens/pass, sync per stage, ms):");
            for (n, v) in PROF_NAMES.iter().zip(prof) {
                eprint!(" {n} {:.2}", v / reps as f64);
            }
            eprintln!(" | total {:.2}", total / reps as f64);
            // The same pass unprofiled.
            let t = Instant::now();
            for _ in 0..reps {
                e.forward(&toks, None)?;
                e.commit(0)?;
            }
            eprintln!("          unprofiled: {:.2} ms/pass", t.elapsed().as_secs_f64() / reps as f64 * 1e3);
        }
    }
    Ok(())
}
