//! xf-run: load the resident model on the B60 and run it.
//!
//!   xf-run mem  <model.xfm> [--ctx N]
//!   xf-run dump <model.xfm> <ids.json> <out_dir> [--chunk 1|8|16] [--ctx N]
//!   xf-run cmp  <model.xfm> <ids.json>[,..] <n_new> [--block 8|16|0=adaptive] [--sketch dir ..] [--bdraft main.yskn,draft.yskn]
//!               compare draft sources on the same main model: official MTP, bdraft2 (feature), D0/D1-style lookup
//!   xf-run collect <model.xfm> <dir of ids .json> <out_dir> <n_new> --bdraft main.yskn,draft.yskn [--skip-existing]
//!               teacher data for drafter training: tokens, the five tap states (f16) of every committed row,
//!               and what bdraft2 proposed / got accepted in the real speculative loop
//!   xf-run mtp-tf <model.xfm> <ids.json> [--out pred.json]
//!   xf-run gen  <model.xfm> <ids.json>[,<ids2.json>..] <n_new> [--ctx N] [--mtp K[,K..]] [--profile]
//!               [--sketch dir --rank 512 --groups 8] [--mtp-xfm other.xfm] [--host-chain]
//!               [--json results.json] [--out prefix]
//!
//! `ids.json` is a JSON array of token ids. Run through scripts/b60run.

mod ext;

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
    load_opts(dev, model, ctx, &[])
}

/// `--mtp-xfm <container>`: take the MTP block from another container.
/// `--sketch <dir with head_sketch.safetensors> [--rank 512] [--groups 8]`: head sketch for drafting.
fn load_opts(dev: &Device, model: &str, ctx: usize, args: &[String]) -> Result<Engine> {
    let before = dev.info()?.vram_free;
    let t = Instant::now();
    let xfm = Container::open(Path::new(model))?;
    let mtp_xfm = match opt(args, "--mtp-xfm") {
        Some(p) => Some(Container::open(Path::new(&p))?),
        None => None,
    };
    let mut engine = Engine::load_with_mtp(dev, &xfm, mtp_xfm.as_ref(), ctx)?;
    if let Some(dir) = opt(args, "--sketch") {
        let ck = xeflash_model::Checkpoint::open(Path::new(&dir))?;
        let table = ck.get("head.sketch.table")?;
        let table: &[i8] = unsafe { std::slice::from_raw_parts(table.bytes.as_ptr().cast(), table.bytes.len()) };
        let scale = ck.get("head.sketch.scale")?.to_f32()?;
        let proj = ck.get("head.sketch.proj")?.to_f32()?;
        engine.set_sketch(table, &scale, &proj, opt_usize(args, "--rank", 512)?, opt_usize(args, "--groups", 8)?)?;
    }
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
        Some("cmp") if args.len() >= 4 => compare(&dev, &args),
        Some("collect") if args.len() >= 5 => collect(&dev, &args),
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
    for t in 0..ids.len() - 1 {
        e.forward(&ids[t..t + 1], None)?;
        e.commit(1)?;
        pred.push(e.mtp_pass(&ids[t + 1..t + 2], t + 1, Some(0), None)?[0].0);
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

/// New tokens after which the committed state is hashed (see `RunStats::state`).
const STATE_AT: usize = 64;

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
    /// Hash of the committed state after exactly `n_new` generated tokens
    /// cannot be taken (a cycle may overshoot), so it is taken at the first
    /// commit boundary at or after 64 new tokens together with that length.
    state: (usize, u64),
}

/// Prefill `prompt`, then decode `n_new` tokens greedily with `k` MTP draft
/// tokens per cycle (0 = one token per trunk pass). `ignore_eos`-style: the
/// run always produces `n_new` tokens, like the benchmark it is compared with.
fn run_once(dev: &Device, e: &mut Engine, prompt: &[u32], n_new: usize, k: usize, pchunk: usize, host_chain: bool) -> Result<RunStats> {
    if k > 0 && !host_chain {
        return run_spec(dev, e, prompt, n_new, k, pchunk);
    }
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
    let mut state = (0usize, 0u64);
    let mut hash_s = 0f64;
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
        if state.0 == 0 && out.len() >= STATE_AT {
            {
                let th = Instant::now();
                state = (out.len(), e.state_hash()?);
                hash_s += th.elapsed().as_secs_f64(); // not part of the decode time
            }
        }
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
    let decode_s = t1.elapsed().as_secs_f64() - hash_s;
    let emitted = out.len();
    out.truncate(n_new);
    Ok(RunStats { out, emitted, prefill_s, decode_s, passes, t_main, t_mtp, tried, accepted, state })
}

/// Speculative decoding with the draft chain on the device: one submission
/// (MTP steps + trunk verify pass) and one read-back per cycle.
fn run_spec(dev: &Device, e: &mut Engine, prompt: &[u32], n_new: usize, k: usize, pchunk: usize) -> Result<RunStats> {
    e.reset()?;
    let t0 = Instant::now();
    e.mtp_pass(&prompt[..1], 0, None, None)?; // MTP entry of the first token: zero hidden state
    let mut next = 0u32;
    let mut fill: Vec<u32> = Vec::new();
    let nchunks = prompt.len().div_ceil(pchunk);
    for (ci, c) in prompt.chunks(pchunk).enumerate() {
        next = e.forward(c, None)?.last().unwrap().0;
        e.commit(c.len())?;
        let start = ci * pchunk;
        fill = (0..c.len()).map(|i| *prompt.get(start + i + 1).unwrap_or(&next)).collect();
        if ci + 1 < nchunks {
            e.spec_draft(&fill, next, 1, None)?; // MTP cache rows of this chunk; the draft is not used
        }
    }
    dev.wait()?;
    let prefill_s = t0.elapsed().as_secs_f64();

    let mut out: Vec<u32> = Vec::with_capacity(n_new + 16);
    let mut tried = vec![0usize; k + 1];
    let mut accepted = vec![0usize; k + 1];
    let mut passes = 0usize;
    let mut state = (0usize, 0u64);
    let mut hash_s = 0f64;
    let t1 = Instant::now();
    while out.len() < n_new {
        let (drafts, g) = e.spec_cycle(&fill, next, k)?;
        debug_assert_eq!(drafts[0], next);
        let mut n = 1;
        while n < drafts.len() && g[n - 1].0 == drafts[n] {
            n += 1;
        }
        e.commit(n)?;
        for i in 1..drafts.len() {
            if i <= n {
                tried[i] += 1;
            }
            if i < n {
                accepted[i] += 1;
            }
        }
        out.extend_from_slice(&drafts[..n]);
        if state.0 == 0 && out.len() >= STATE_AT {
            {
                let th = Instant::now();
                state = (out.len(), e.state_hash()?);
                hash_s += th.elapsed().as_secs_f64(); // not part of the decode time
            }
        }
        next = g[n - 1].0;
        fill = (0..n).map(|i| if i + 1 < n { drafts[i + 1] } else { next }).collect();
        passes += 1;
    }
    dev.wait()?;
    let decode_s = t1.elapsed().as_secs_f64() - hash_s;
    let emitted = out.len();
    out.truncate(n_new);
    // The cycle is one submission, so trunk and MTP time are not separable here; see --profile.
    Ok(RunStats { out, emitted, prefill_s, decode_s, passes, t_main: decode_s, t_mtp: 0.0, tried, accepted, state })
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
    let mut e = load_opts(dev, &args[1], opt_usize(args, "--ctx", 8192)?, args)?;
    let host_chain = args.iter().any(|a| a == "--host-chain");
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
        let mut base_states: std::collections::HashMap<usize, u64> = std::collections::HashMap::new();
        for &k in &ks {
            let r = run_once(dev, &mut e, &prompt, n_new, k, pchunk, host_chain)?;
            if k == 0 && base.is_none() {
                // Reference states at every length a speculative run could stop at.
                e.reset()?;
                let mut nx = 0u32;
                for c in prompt.chunks(pchunk) {
                    nx = e.forward(c, None)?.last().unwrap().0;
                    e.commit(c.len())?;
                }
                for len in 1..=STATE_AT + 16 {
                    nx = e.forward(&[nx], None)?[0].0;
                    e.commit(1)?;
                    if len >= STATE_AT {
                        base_states.insert(len, e.state_hash()?);
                    }
                }
            }
            let state_ok = base_states.get(&r.state.0).map(|h| *h == r.state.1);
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
                match (base.is_some(), same, state_ok) {
                    (false, _, _) => "".to_string(),
                    (true, true, Some(true)) => format!("  same tokens, same state at +{}", r.state.0),
                    (true, true, None) => "  same tokens (state not compared)".to_string(),
                    (true, true, Some(false)) => "  same tokens, STATE DIFFERS".to_string(),
                    (true, false, _) => "  TOKENS DIFFER".to_string(),
                }
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
        // XF_ATTN_SWEEP="HG:TG:GP;HG:TG:GP;..." profiles the attention stage for each configuration at this position.
        if let Ok(sw) = std::env::var("XF_ATTN_SWEEP") {
            for cfg in sw.split(';') {
                let v: Vec<&str> = cfg.split(':').collect();
                unsafe {
                    std::env::set_var("XF_ATTN_HG", v[0]);
                    std::env::set_var("XF_ATTN_TG", v[1]);
                    std::env::set_var("XF_ATTN_GP", v[2]);
                    match v.get(3) {
                        Some(x) if *x != "0" => std::env::set_var("XF_ATTN_SLM", x),
                        _ => std::env::remove_var("XF_ATTN_SLM"),
                    }
                    if let Some(c) = v.get(4) {
                        std::env::set_var("XF_ATTN_SLMC", c);
                    }
                }
                eprint!("sweep pos {} cfg {cfg}:", e.position());
                for m in [1usize, 8, 16] {
                    let mut prof = [0f64; 7];
                    let toks: Vec<u32> = (0..m as u32).map(|i| 1000 + i).collect();
                    e.forward(&toks, None)?;
                    for _ in 0..6 {
                        e.forward(&toks, Some(&mut prof))?;
                        e.commit(0)?;
                    }
                    eprint!(" m{m} attn {:.2}", prof[4] / 6.0);
                }
                eprintln!();
            }
        }
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
        if e.has_mtp() {
            // One MTP draft step (1 row): categories as above; "norm" holds embedding,
            // the two pre-fc norms and fc; "head" holds mtp.norm quantisation, lm_head and argmax.
            let mut prof = [0f64; 7];
            let reps = 20;
            for _ in 0..reps {
                e.mtp_pass(&[1000], 5, Some(0), Some(&mut prof))?;
            }
            let total: f64 = prof.iter().sum();
            eprint!("profile (MTP step, 1 row, sync per stage, ms):");
            for (n, v) in PROF_NAMES.iter().zip(prof) {
                eprint!(" {n} {:.3}", v / reps as f64);
            }
            eprintln!(" | total {:.3}", total / reps as f64);
            let t = Instant::now();
            for _ in 0..reps {
                e.mtp_pass(&[1000], 5, Some(0), None)?;
            }
            eprintln!("          unprofiled (includes argmax read-back): {:.3} ms/step", t.elapsed().as_secs_f64() / reps as f64 * 1e3);
            // At the current (deep) position: draft chain, trunk pass and whole cycle, unprofiled, no commit.
            {
                let fill = [1000u32; 4];
                let reps = 10;
                for (label, k) in [("cycle K=6, 4 fill rows", 6usize), ("cycle K=7, 4 fill rows", 7)] {
                    e.spec_draft(&fill, 1000, k, None)?;
                    dev.wait()?;
                    let t = Instant::now();
                    for _ in 0..reps {
                        e.spec_draft(&fill, 1000, k, None)?;
                    }
                    dev.wait()?;
                    let d = t.elapsed().as_secs_f64() / reps as f64 * 1e3;
                    let toks: Vec<u32> = (0..=k as u32).map(|i| 1000 + i).collect();
                    let t = Instant::now();
                    for _ in 0..reps {
                        e.forward(&toks, None)?;
                    }
                    let f = t.elapsed().as_secs_f64() / reps as f64 * 1e3;
                    let t = Instant::now();
                    for _ in 0..reps {
                        e.spec_cycle(&fill, 1000, k)?;
                    }
                    let c = t.elapsed().as_secs_f64() / reps as f64 * 1e3;
                    eprintln!("deep position {}: {label}: draft chain {d:.2} ms, trunk pass {f:.2} ms, whole cycle {c:.2} ms", e.position());
                }
            }
            // The device-side chain: 1 fill row + 6 drafts, per-stage and unprofiled.
            let toks = [1000u32];
            e.reset()?;
            e.forward(&toks, None)?;
            e.commit(1)?;
            for kk in [1usize, 7] {
                let mut prof = [0f64; 7];
                for _ in 0..reps {
                    e.spec_draft(&toks, 1000, kk, Some(&mut prof))?;
                }
                dev.wait()?;
                let total: f64 = prof.iter().sum();
                eprint!("profile (device chain, 1 fill row, {kk} drafts{}, ms):", if e.has_sketch() { ", sketch head" } else { ", full head" });
                for (n, v) in PROF_NAMES.iter().zip(prof) {
                    eprint!(" {n} {:.3}", v / reps as f64);
                }
                eprintln!(" | total {:.3}", total / reps as f64);
                let t = Instant::now();
                for _ in 0..reps {
                    e.spec_draft(&toks, 1000, kk, None)?;
                }
                dev.wait()?;
                eprintln!("          unprofiled: {:.3} ms per chain", t.elapsed().as_secs_f64() / reps as f64 * 1e3);
            }
        }
    }
    Ok(())
}

#[cfg(feature = "bdraft2")]
type Bd = ext::bdraft2::Bdraft2;
#[cfg(not(feature = "bdraft2"))]
struct Bd;
#[cfg(not(feature = "bdraft2"))]
impl Bd {
    fn reset(&mut self) -> Result<()> { Ok(()) }
    fn ctx(&mut self, _: &[f32], _: usize, _: usize) -> Result<()> { Ok(()) }
    fn step(&mut self, _: &[f32], _: usize, _: usize, _: usize, _: u32, _: usize) -> Result<Vec<u32>> { Ok(Vec::new()) }
    fn step_dev(&mut self, _: *const f32, _: usize, _: usize, _: usize, _: u32, _: usize) -> Result<Option<Vec<u32>>> { Ok(None) }
}

/// Speculative decoding with a host-driven draft source: `bd = Some` uses the
/// bdraft2 backend fed with captured tap states, `None` the D0/D1-style lookup.
/// Verify block is `k + 1` rows. Returns the stats plus seconds spent moving taps.
/// `block` = 8 or 16 rows per verify pass, or 0 for the adaptive rule (see `Adapt`).
fn run_ext(dev: &Device, e: &mut Engine, prompt: &[u32], n_new: usize, block: usize, bd: Option<&mut Bd>) -> Result<(RunStats, f64)> {
    run_ext_mode(dev, e, prompt, n_new, block, bd, false)
}

/// `cost` = adaptive rule with the 16/8 cycle-cost ratio measured on this machine, at the current context length
/// (probe of real 8- and 16-row passes before decoding), instead of the fixed 1.16 of the short-context port notes.
fn run_ext_mode(dev: &Device, e: &mut Engine, prompt: &[u32], n_new: usize, block: usize, mut bd: Option<&mut Bd>, cost: bool) -> Result<(RunStats, f64)> {
    let k = if block == 0 { 15 } else { block - 1 };
    let mut adapt = Adapt::new();
    let mut zero_copy = bd.is_some();
    let mut n16 = 0usize;
    e.reset()?;
    e.set_capture(bd.is_some());
    if let Some(b) = bd.as_deref_mut() {
        b.reset()?;
    }
    let mut lk = ext::Lookup::new();
    let mut taps = vec![0f32; 5 * 16 * HIDDEN];
    let t0 = Instant::now();
    let mut next = 0u32;
    let mut pend = (0usize, 0usize); // rows of the last committed pass not yet in the drafter's ring
    let nchunks = prompt.len().div_ceil(16);
    for (ci, c) in prompt.chunks(16).enumerate() {
        let g = e.forward(c, None)?;
        e.commit(c.len())?;
        for (t, gi) in c.iter().zip(&g) {
            lk.push(*t, gi.0);
        }
        next = g.last().unwrap().0;
        if let Some(b) = bd.as_deref_mut() {
            e.read_taps(&mut taps)?;
            if ci + 1 < nchunks {
                b.ctx(&taps, c.len(), ci * 16)?;
            } else {
                pend = (c.len(), ci * 16);
            }
        }
    }
    dev.wait()?;
    let prefill_s = t0.elapsed().as_secs_f64();
    if block == 0 && cost {
        // Probe: real passes at the current position (no commit, taps capture off so the pending taps stay intact).
        e.set_capture(false);
        let time = |e: &mut Engine, rows: usize| -> Result<f64> {
            let ids = vec![next; rows];
            e.forward(&ids, None)?;
            let t = Instant::now();
            for _ in 0..4 {
                e.forward(&ids, None)?;
            }
            Ok(t.elapsed().as_secs_f64() / 4.0 * 1e3)
        };
        let (t8, t16) = (time(e, 8)?, time(e, 16)?);
        let d = if bd.is_some() { 6.5 } else { 0.5 }; // drafter ms per cycle (bdraft2: measured 6.3)
        adapt.c16 = (t16 + d) / (t8 + d);
        e.set_capture(bd.is_some());
        eprintln!("          cost probe at position {}: 8 rows {t8:.1} ms, 16 rows {t16:.1} ms -> c16 = {:.3}", e.position(), adapt.c16);
    }

    let mut out: Vec<u32> = Vec::with_capacity(n_new + 16);
    let (mut t_draft, mut t_main, mut t_taps) = (0f64, 0f64, 0f64);
    let mut tried = vec![0usize; k + 1];
    let mut accepted = vec![0usize; k + 1];
    let mut passes = 0usize;
    let mut state = (0usize, 0u64);
    let mut hash_s = 0f64;
    let t1 = Instant::now();
    while out.len() < n_new {
        let pos = e.position();
        if zero_copy {
            dev.wait()?; // the commit of the last pass and its tap writes are done
        }
        let td = Instant::now();
        let mut ids = vec![next];
        let rows = match block {
            0 if adapt.use16() => 16,
            0 => 8,
            b => b,
        };
        n16 += (rows == 16) as usize;
        match bd.as_deref_mut() {
            Some(b) => {
                // Taps straight from the main engine's device buffer when both
                // engines share a SYCL context; through host memory otherwise.
                let mut d = None;
                if zero_copy {
                    d = b.step_dev(e.taps_device_ptr(), pend.0, pend.1, rows, next, pos)?;
                    zero_copy = d.is_some();
                }
                if d.is_none() {
                    if pend.0 > 0 {
                        e.read_taps(&mut taps)?;
                    }
                    d = Some(b.step(&taps, pend.0, pend.1, rows, next, pos)?);
                }
                ids.extend(d.unwrap());
            }
            None => ids.extend(lk.draft(next, rows - 1).0),
        }
        t_draft += td.elapsed().as_secs_f64();
        let tv = Instant::now();
        let g = e.forward(&ids, None)?;
        let mut n = 1;
        while n < ids.len() && g[n - 1].0 == ids[n] {
            n += 1;
        }
        e.commit(n)?;
        t_main += tv.elapsed().as_secs_f64();
        adapt.update(rows, n - 1);
        for i in 1..ids.len() {
            if i <= n {
                tried[i] += 1;
            }
            if i < n {
                accepted[i] += 1;
            }
        }
        for i in 0..n {
            lk.push(ids[i], g[i].0);
        }
        out.extend_from_slice(&ids[..n]);
        if state.0 == 0 && out.len() >= STATE_AT {
            {
                let th = Instant::now();
                state = (out.len(), e.state_hash()?);
                hash_s += th.elapsed().as_secs_f64(); // not part of the decode time
            }
        }
        next = g[n - 1].0;
        passes += 1;
        if bd.is_some() {
            pend = (n, pos);
        }
    }
    dev.wait()?;
    let decode_s = t1.elapsed().as_secs_f64() - hash_s;
    let emitted = out.len();
    out.truncate(n_new);
    e.set_capture(false);
    if block == 0 {
        eprintln!("          adaptive block: {n16} of {passes} passes used 16 rows; taps {}", if zero_copy { "device-to-device" } else { "through host" });
    } else if bd.is_some() {
        eprintln!("          taps {}", if zero_copy { "device-to-device" } else { "through host" });
    }
    t_taps += 0.0;
    Ok((RunStats { out, emitted, prefill_s, decode_s, passes, t_main, t_mtp: t_draft, tried, accepted, state }, t_taps))
}

/// YASAKANI's rule for choosing between 8 and 16 verify rows (from its port
/// notes): go to 16 when the tokens a 16-row pass is expected to add beyond
/// the first 7 outweigh its extra cost. `c16` is the cost of a 16-row cycle
/// relative to an 8-row one; measured here as 71 ms / 61.5 ms.
struct Adapt {
    g16: f64,
    extra: f64,
    t8: f64,
    /// Cost of a 16-row cycle relative to an 8-row one (draft + verify + commit).
    c16: f64,
}

impl Adapt {
    const C16: f64 = 1.16;
    fn new() -> Self {
        Adapt { g16: 0.0, extra: 3.0, t8: 4.0, c16: Self::C16 }
    }
    fn use16(&self) -> bool {
        self.g16 > (self.c16 - 1.0) * self.t8
    }
    /// `a` = drafts accepted in a pass of `rows` rows.
    fn update(&mut self, rows: usize, a: usize) {
        self.t8 = 0.85 * self.t8 + 0.15 * (a.min(7) + 1) as f64;
        let gobs = if rows == 16 {
            if a >= 7 {
                self.extra = 0.8 * self.extra + 0.2 * (a - 7) as f64;
            }
            a.saturating_sub(7) as f64
        } else if a >= 7 {
            self.extra
        } else {
            0.0
        };
        self.g16 = 0.85 * self.g16 + 0.15 * gobs;
    }
}

/// cmp: the same main model, prompts and verify block, three draft sources.
fn compare(dev: &Device, args: &[String]) -> Result<()> {
    let n_new: usize = args[3].parse().map_err(|_| Error::Invalid("bad token count".into()))?;
    let block = opt_usize(args, "--block", 8)?;
    if block != 8 && block != 16 && block != 0 {
        return Err(Error::Invalid("--block must be 8, 16 or 0 (adaptive, external drafters only)".into()));
    }
    let k = if block == 0 { 7 } else { block - 1 }; // MTP has no adaptive rule: 7 drafts
    let mut e = load_opts(dev, &args[1], opt_usize(args, "--ctx", 8192)?, args)?;
    #[allow(unused_mut)]
    let mut bd: Option<Bd> = None;
    #[cfg(feature = "bdraft2")]
    if let Some(paths) = opt(args, "--bdraft") {
        let (m, d) = paths.split_once(',').ok_or_else(|| Error::Invalid("--bdraft main.yskn,draft.yskn".into()))?;
        let before = dev.info()?.vram_free;
        bd = Some(Bd::open(m, d, e.capacity())?);
        let after = dev.info()?.vram_free;
        eprintln!("bdraft2 backend loaded: +{:.3} GiB device memory (driver)", (before as f64 - after as f64) / GIB);
    }
    let mut json = String::from("[\n");
    for (pi, path) in args[2].split(',').enumerate() {
        let prompt = read_ids(path)?;
        let name = Path::new(path).file_stem().and_then(|s| s.to_str()).unwrap_or(path).to_string();
        if pi == 0 {
            for m in [1usize, 2, 16] {
                e.forward(&prompt[..m.min(prompt.len())], None)?;
                e.commit(0)?;
            }
        }
        // Reference: plain greedy, plus state hashes at every length a speculative run may stop at.
        let base = run_once(dev, &mut e, &prompt, n_new, 0, 16, true)?;
        let mut base_states = std::collections::HashMap::new();
        e.reset()?;
        let mut nx = 0u32;
        for c in prompt.chunks(16) {
            nx = e.forward(c, None)?.last().unwrap().0;
            e.commit(c.len())?;
        }
        for len in 1..=STATE_AT + 16 {
            nx = e.forward(&[nx], None)?[0].0;
            e.commit(1)?;
            if len >= STATE_AT {
                base_states.insert(len, e.state_hash()?);
            }
        }
        eprintln!("{name:<9} none      {:>7.2} tok/s | 1.00 tok/pass | main {:>6.2} ms/pass", base.emitted as f64 / base.decode_s, base.t_main / base.passes as f64 * 1e3);
        let mut report = |label: &str, r: &RunStats, taps_s: f64, split: bool| {
            let tps = r.emitted as f64 / r.decode_s;
            let cyc = r.decode_s / r.passes as f64 * 1e3;
            let same = r.out == base.out;
            let st = base_states.get(&r.state.0).map(|h| *h == r.state.1);
            let acc: Vec<String> = (1..r.tried.len()).map(|i| format!("{:.0}", 100.0 * r.accepted[i] as f64 / r.tried[i].max(1) as f64)).collect();
            let parts = if split {
                format!("main {:>6.2}, draft {:>6.2} (of which taps {:.2}) ms/pass", r.t_main / r.passes as f64 * 1e3, (r.t_mtp + taps_s) / r.passes as f64 * 1e3, taps_s / r.passes as f64 * 1e3)
            } else {
                "one submission per cycle".to_string()
            };
            eprintln!(
                "{name:<9} {label:<9} {tps:>7.2} tok/s | {:.2} tok/pass | cycle {cyc:>6.2} ms | {parts} | accept% [{}] | {}",
                r.emitted as f64 / r.passes as f64,
                acc.join(" "),
                match (same, st) {
                    (true, Some(true)) => "same tokens, same state",
                    (true, None) => "same tokens (state not compared)",
                    (true, Some(false)) => "same tokens, STATE DIFFERS",
                    (false, _) => "TOKENS DIFFER",
                }
            );
            let _ = std::fmt::Write::write_fmt(
                &mut json,
                format_args!(
                    "  {{\"prompt\":\"{name}\",\"drafter\":\"{label}\",\"block\":{block},\"tok_per_s\":{tps:.3},\"tokens_per_pass\":{:.4},\"cycle_ms\":{cyc:.3},\"main_ms\":{:.3},\"draft_ms\":{:.3},\"taps_ms\":{:.3},\"same_tokens\":{same},\"same_state\":{}}},\n",
                    r.emitted as f64 / r.passes as f64,
                    if split { r.t_main / r.passes as f64 * 1e3 } else { -1.0 },
                    if split { (r.t_mtp + taps_s) / r.passes as f64 * 1e3 } else { -1.0 },
                    taps_s / r.passes as f64 * 1e3,
                    st.unwrap_or(false)
                ),
            );
        };
        let only_bd = args.iter().any(|a| a == "--only-bd");
        if e.has_mtp() && !only_bd {
            let r = run_spec(dev, &mut e, &prompt, n_new, k, 16)?;
            report("mtp", &r, 0.0, false);
        }
        if let Some(b) = bd.as_mut() {
            // `--configs 8,16,0,0c`: verify block per run; `0` = adaptive with the fixed port-notes cost ratio,
            // `0c` = adaptive with the measured cost ratio. Default: the single `--block`.
            let cfgs: Vec<String> = match opt(args, "--configs") {
                Some(c) => c.split(',').map(|x| x.to_string()).collect(),
                None => vec![block.to_string()],
            };
            for cfg in cfgs {
                let (blk, cost) = match cfg.as_str() {
                    "0c" => (0usize, true),
                    c => (c.parse::<usize>().map_err(|_| Error::Invalid("bad --configs".into()))?, false),
                };
                let (r, taps_s) = run_ext_mode(dev, &mut e, &prompt, n_new, blk, Some(b), cost)?;
                let label = match (blk, cost) {
                    (0, true) => "bd2:adapt-cost".to_string(),
                    (0, false) => "bd2:adapt-old".to_string(),
                    (n, _) => format!("bd2:fixed{n}"),
                };
                report(&label, &r, taps_s, true);
            }
        }
        if !only_bd {
            let (r, _) = run_ext(dev, &mut e, &prompt, n_new, block, None)?;
            report("d0d1", &r, 0.0, true);
        }
    }
    if let Some(path) = opt(args, "--json") {
        std::fs::write(&path, json.trim_end().trim_end_matches(',').to_string() + "\n]\n")?;
    }
    Ok(())
}

/// IEEE half from f32, round to nearest even (taps are stored as f16).
fn f32_to_f16(v: f32) -> u16 {
    let x = v.to_bits();
    let sign = ((x >> 16) & 0x8000) as u16;
    let exp = ((x >> 23) & 0xff) as i32;
    let man = x & 0x7f_ffff;
    if exp == 0xff {
        return sign | 0x7c00 | if man != 0 { 0x200 } else { 0 };
    }
    let e = exp - 127 + 15;
    if e >= 31 {
        return sign | 0x7c00;
    }
    if e <= 0 {
        if e < -10 {
            return sign;
        }
        let m = (man | 0x80_0000) >> (1 - e);
        let half = (m >> 13) as u16;
        let rem = m & 0x1fff;
        return sign | (half + ((rem > 0x1000 || (rem == 0x1000 && half & 1 == 1)) as u16));
    }
    let half = sign | ((e as u16) << 10) | (man >> 13) as u16;
    let rem = man & 0x1fff;
    half + ((rem > 0x1000 || (rem == 0x1000 && half & 1 == 1)) as u16)
}

/// collect: run every prompt with the bdraft2 drafter (adaptive block) and save,
/// per sequence, `<name>.tok` (u32 token ids: prompt then generated),
/// `<name>.taps` (f16, [tokens][5][5120]: residual stream after layers
/// 5/19/33/47/61 for every committed token) and `<name>.json` (prompt length
/// and one record per speculative cycle: position, block rows, drafts, accepted).
/// The main model's greedy choice after token t is token t + 1 of the file.
fn collect(dev: &Device, args: &[String]) -> Result<()> {
    let n_new: usize = args[4].parse().map_err(|_| Error::Invalid("bad token count".into()))?;
    let out = Path::new(&args[3]);
    std::fs::create_dir_all(out)?;
    let mut files: Vec<_> = std::fs::read_dir(&args[2])?
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().is_some_and(|x| x == "json"))
        .collect();
    files.sort();
    let skip = args.iter().any(|a| a == "--skip-existing");
    let budget = opt_usize(args, "--seconds", 240)? as f64; // stop starting new sequences after this long
    let mut e = load_opts(dev, &args[1], opt_usize(args, "--ctx", 8192)?, args)?;
    #[allow(unused_mut)]
    let mut bd: Option<Bd> = None;
    #[cfg(feature = "bdraft2")]
    if let Some(paths) = opt(args, "--bdraft") {
        let (m, d) = paths.split_once(',').ok_or_else(|| Error::Invalid("--bdraft main.yskn,draft.yskn".into()))?;
        bd = Some(Bd::open(m, d, e.capacity())?);
    }
    let Some(mut bd) = bd else {
        return Err(Error::Invalid("collect needs --bdraft and the bdraft2 feature".into()));
    };
    e.set_capture(true);
    let started = Instant::now();
    let (mut done, mut toks) = (0usize, 0usize);
    let mut taps = vec![0f32; 5 * 16 * HIDDEN];
    for path in &files {
        let name = path.file_stem().and_then(|s| s.to_str()).unwrap_or("seq").to_string();
        if skip && out.join(format!("{name}.json")).exists() {
            continue;
        }
        if started.elapsed().as_secs_f64() > budget {
            break;
        }
        let prompt = read_ids(path.to_str().unwrap())?;
        if prompt.len() + n_new + 16 > e.capacity() {
            continue;
        }
        e.reset()?;
        bd.reset()?;
        let mut seq: Vec<u32> = Vec::new();
        let mut f16: Vec<u16> = Vec::new();
        let mut save_rows = |taps: &[f32], n: usize, f16: &mut Vec<u16>| {
            for r in 0..n {
                for t in 0..5 {
                    let at = (t * 16 + r) * HIDDEN;
                    f16.extend(taps[at..at + HIDDEN].iter().map(|v| f32_to_f16(*v)));
                }
            }
        };
        let mut next = 0u32;
        let mut pend = (0usize, 0usize);
        let nchunks = prompt.len().div_ceil(16);
        for (ci, c) in prompt.chunks(16).enumerate() {
            next = e.forward(c, None)?.last().unwrap().0;
            e.commit(c.len())?;
            e.read_taps(&mut taps)?;
            save_rows(&taps, c.len(), &mut f16);
            seq.extend_from_slice(c);
            if ci + 1 < nchunks {
                bd.ctx(&taps, c.len(), ci * 16)?;
            } else {
                pend = (c.len(), ci * 16);
            }
        }
        let mut adapt = Adapt::new();
        let mut cycles = String::new();
        let mut generated = 0usize;
        while generated < n_new {
            let pos = e.position();
            let rows = if adapt.use16() { 16 } else { 8 };
            let drafts = bd.step(&taps, pend.0, pend.1, rows, next, pos)?;
            let mut ids = vec![next];
            ids.extend(&drafts);
            let g = e.forward(&ids, None)?;
            let mut n = 1;
            while n < ids.len() && g[n - 1].0 == ids[n] {
                n += 1;
            }
            e.commit(n)?;
            adapt.update(rows, n - 1);
            e.read_taps(&mut taps)?;
            save_rows(&taps, n, &mut f16);
            seq.extend_from_slice(&ids[..n]);
            let sep = if cycles.is_empty() { "" } else { "," };
            cycles.push_str(&format!("{sep}{{\"pos\":{pos},\"rows\":{rows},\"drafts\":{:?},\"accepted\":{}}}", drafts, n - 1));
            generated += n;
            next = g[n - 1].0;
            pend = (n, pos);
        }
        let tok_bytes: Vec<u8> = seq.iter().flat_map(|t| t.to_le_bytes()).collect();
        let tap_bytes: Vec<u8> = f16.iter().flat_map(|t| t.to_le_bytes()).collect();
        std::fs::write(out.join(format!("{name}.tok")), tok_bytes)?;
        std::fs::write(out.join(format!("{name}.taps")), tap_bytes)?;
        std::fs::write(
            out.join(format!("{name}.json")),
            format!("{{\"name\":\"{name}\",\"prompt_tokens\":{},\"tokens\":{},\"next_after_last\":{next},\"cycles\":[{cycles}]}}\n", prompt.len(), seq.len()),
        )?;
        done += 1;
        toks += seq.len();
    }
    eprintln!("collected {done} sequences, {toks} tokens in {:.0}s", started.elapsed().as_secs_f64());
    Ok(())
}
