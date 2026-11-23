//! Part AI: oracle traces of the drafters and an offline simulator of speculative strategies.
//!
//!   xf-run trace <model.xfm> <ids.json>[,..] <n_new> --ctx N --bdraft main.yskn,draft.yskn --out DIR
//!       greedy decode, one row per pass; at every position the bdraft2 block drafts of 8 and 16 rows are recorded, with the real cost of a main pass of 8 .. 64 rows
//!   xf-run sim <trace>[,..] <policy>[,..]        policies: 0c | hy<min>/<blk> | hw<min>/<blk> | hv<min>/<blk> | ad[:key=val,..] | oracle
//!
//! The output of every strategy is the greedy output; what a proposal gets accepted is fully determined by the greedy text and the proposal, so the simulator replays the
//! recorded drafts and the real copy index and only needs a cost model for the pass time.
use super::*;
use crate::ctl::{self, Cand, Ctl, Params};
use crate::ext::{CopyIndex, Lookup};

pub struct Trace {
    pub name: String,
    pub prompt: Vec<u32>,
    pub tokens: Vec<u32>,
    pub d8: Vec<Vec<u32>>,
    pub d16: Vec<Vec<u32>>,
    pub cost: [f64; 5],
    pub t8: f64,
    pub t16: f64,
}

#[cfg(feature = "bdraft2")]
pub fn trace(dev: &Device, args: &[String]) -> Result<()> {
    use std::fmt::Write as _;
    let n_new: usize = args[3].parse().map_err(|_| Error::Invalid("bad token count".into()))?;
    let mut e = load_opts(dev, &args[1], opt_usize(args, "--ctx", 8192)?, args)?;
    let paths = opt(args, "--bdraft").ok_or_else(|| Error::Invalid("--bdraft main.yskn,draft.yskn".into()))?;
    let (m, d) = paths.split_once(',').ok_or_else(|| Error::Invalid("--bdraft main.yskn,draft.yskn".into()))?;
    let mut b = Bd::open(m, d, e.capacity())?;
    let dir = opt(args, "--out").unwrap_or_else(|| "trace".into());
    std::fs::create_dir_all(&dir).map_err(|e| Error::Invalid(e.to_string()))?;
    for path in args[2].split(',') {
        let prompt = read_ids(path)?;
        let name = Path::new(path).file_stem().and_then(|s| s.to_str()).unwrap_or(path).to_string();
        e.reset()?;
        e.set_capture(true);
        b.reset()?;
        let mut taps = vec![0f32; 5 * 16 * HIDDEN];
        let mut next = 0u32;
        let mut pend = (0usize, 0usize);
        let nchunks = prompt.len().div_ceil(16);
        for (ci, c) in prompt.chunks(16).enumerate() {
            let g = e.forward(c, None)?;
            e.commit(c.len())?;
            next = g.last().unwrap().0;
            e.read_taps(&mut taps)?;
            if ci + 1 < nchunks {
                b.ctx(&taps, c.len(), ci * 16)?;
            } else {
                pend = (c.len(), ci * 16);
            }
        }
        e.set_capture(false);
        let mut cost = Vec::new();
        for rows in [8usize, 16, 32, 48, 64] {
            let ids = vec![next; rows];
            e.forward(&ids, None)?;
            let t = Instant::now();
            for _ in 0..4 {
                e.forward(&ids, None)?;
            }
            cost.push(t.elapsed().as_secs_f64() / 4.0 * 1e3);
        }
        e.set_capture(true);
        let (mut toks, mut d8s, mut d16s) = (Vec::new(), Vec::new(), Vec::new());
        let (mut t8s, mut t16s) = (0f64, 0f64);
        for _ in 0..n_new {
            let pos = e.position();
            let t = Instant::now();
            let d16 = b.step(&taps, pend.0, pend.1, 16, next, pos)?;
            t16s += t.elapsed().as_secs_f64() * 1e3;
            let t = Instant::now();
            let d8 = b.step(&taps, 0, 0, 8, next, pos)?;
            t8s += t.elapsed().as_secs_f64() * 1e3;
            toks.push(next);
            d8s.push(d8);
            d16s.push(d16);
            let g = e.forward(&[next], None)?;
            e.commit(1)?;
            e.read_taps(&mut taps)?;
            pend = (1, pos);
            next = g[0].0;
        }
        toks.push(next);
        let mut s = String::new();
        let _ = writeln!(s, "name {name}");
        let _ = writeln!(s, "cost {}", cost.iter().map(|c| format!("{c:.3}")).collect::<Vec<_>>().join(" "));
        let _ = writeln!(s, "t8 {:.3} t16 {:.3}", t8s / n_new as f64, t16s / n_new as f64);
        let _ = writeln!(s, "prompt {} {}", prompt.len(), prompt.iter().map(|t| t.to_string()).collect::<Vec<_>>().join(" "));
        let _ = writeln!(s, "tokens {} {}", toks.len(), toks.iter().map(|t| t.to_string()).collect::<Vec<_>>().join(" "));
        for (j, (a, c)) in d8s.iter().zip(&d16s).enumerate() {
            let _ = writeln!(s, "d8 {j} {} {}", a.len(), a.iter().map(|t| t.to_string()).collect::<Vec<_>>().join(" "));
            let _ = writeln!(s, "d16 {j} {} {}", c.len(), c.iter().map(|t| t.to_string()).collect::<Vec<_>>().join(" "));
        }
        std::fs::write(format!("{dir}/{name}.trace"), s).map_err(|e| Error::Invalid(e.to_string()))?;
        eprintln!("{name}: traced {n_new} positions; main pass 8/16/32/48/64 rows {:?} ms; bdraft2 step 8 rows {:.2} ms, 16 rows (with 1 pending row) {:.2} ms", cost.iter().map(|c| (c * 100.0).round() / 100.0).collect::<Vec<_>>(), t8s / n_new as f64, t16s / n_new as f64);
    }
    Ok(())
}

pub fn load_trace(path: &str) -> Result<Trace> {
    let txt = std::fs::read_to_string(path).map_err(|e| Error::Invalid(format!("{path}: {e}")))?;
    let mut t = Trace { name: String::new(), prompt: vec![], tokens: vec![], d8: vec![], d16: vec![], cost: [0.0; 5], t8: 0.0, t16: 0.0 };
    for l in txt.lines() {
        let mut w = l.split_whitespace();
        match w.next() {
            Some("name") => t.name = w.next().unwrap_or("").to_string(),
            Some("cost") => {
                for (i, x) in w.enumerate().take(5) {
                    t.cost[i] = x.parse().unwrap_or(0.0);
                }
            }
            Some("t8") => {
                t.t8 = w.next().unwrap_or("0").parse().unwrap_or(0.0);
                w.next();
                t.t16 = w.next().unwrap_or("0").parse().unwrap_or(0.0);
            }
            Some("prompt") => t.prompt = w.skip(1).filter_map(|x| x.parse().ok()).collect(),
            Some("tokens") => t.tokens = w.skip(1).filter_map(|x| x.parse().ok()).collect(),
            Some(k @ ("d8" | "d16")) => {
                let v: Vec<u32> = w.skip(2).filter_map(|x| x.parse().ok()).collect();
                if k == "d8" { t.d8.push(v) } else { t.d16.push(v) }
            }
            _ => {}
        }
    }
    Ok(t)
}

fn acc_len(d: &[u32], toks: &[u32], j: usize) -> usize {
    let mut a = 0;
    while a < d.len() && j + 1 + a < toks.len() && d[a] == toks[j + 1 + a] {
        a += 1;
    }
    a
}

/// Cost model of the simulator (ms): fitted on the measured cycles of the real configurations (see Part AI).
#[derive(Clone)]
pub struct Cost {
    pub ov: f64, // per pass: commit, bookkeeping, launch
    pub cu: f64, // ring catch-up per 16-row block of the previous pass
    pub tcp: f64, // candidate search
}

impl Default for Cost {
    fn default() -> Self {
        Cost { ov: 0.65, cu: 0.45, tcp: 0.15 }
    }
}

fn main_ms(t: &Trace, rows: usize) -> f64 {
    t.cost[match rows { 0..=8 => 0, 9..=16 => 1, 17..=32 => 2, 33..=48 => 3, _ => 4 }]
}

pub struct SimOut {
    pub tok_s: f64,
    pub passes: usize,
    pub copy_passes: usize,
    pub tok_per_pass: f64,
    pub ms_per_pass: f64,
    pub main_ms: f64,
    pub draft_ms: f64,
    pub classes: [usize; 4],
}

pub fn simulate(t: &Trace, policy: &str, c: &Cost) -> SimOut {
    let n = t.tokens.len() - 1;
    let toks = &t.tokens;
    let mut cp = CopyIndex::new(3);
    let mut lkp = Lookup::new();
    for (i, p) in t.prompt.iter().enumerate() {
        cp.push(*p);
        lkp.push(*p, if i + 1 < t.prompt.len() { t.prompt[i + 1] } else { toks[0] });
    }
    let (mut j, mut passes, mut ncopy) = (0usize, 0usize, 0usize);
    let mut classes = [0usize; 4];
    let (mut ms, mut ms_main, mut ms_draft) = (0f64, 0f64, 0f64);
    let mut ptr: Option<usize> = None;
    let mut pend_rows = t.prompt.len().min(16).max(1);
    let (mut adapt_g16, mut adapt_extra, mut adapt_t8) = (0f64, 3.0f64, 4.0f64);
    let c16 = ((t.cost[1] + 6.5) / (t.cost[0] + 6.5)).max(1.0);
    let (hy, maxrows, blk, kind) = {
        let (head, rest) = policy.split_once('/').unwrap_or((policy, "8"));
        match head.get(..2) {
            Some("hy") => (head[2..].parse().unwrap_or(4usize), 16usize, rest.parse().unwrap_or(8usize), 'h'),
            Some("hw") => (head[2..].parse().unwrap_or(4usize), 32, rest.parse().unwrap_or(16), 'h'),
            Some("hv") => (head[2..].parse().unwrap_or(4usize), 64, rest.parse().unwrap_or(16), 'h'),
            Some("ad") => (4, 64, 0, 'a'),
            Some("ar") => (0, 16, 0, 'r'),
            Some("bd") => (0, 16, head[2..].parse().unwrap_or(8usize), 'b'),
            Some("lk") => (0, 16, head[2..].parse().unwrap_or(8usize), 'l'),
            _ if policy.starts_with("oracle") => (4, 64, 0, 'o'),
            _ => (0, 16, 0, 'b'),
        }
    };
    let mut ctl = {
        let mut p = Params::default();
        if let Some((_, kv)) = policy.split_once(':') {
            for item in kv.split(|ch| ch == ',' || ch == '_') {
                if let Some((k, v)) = item.split_once('=') {
                    let v: f64 = v.parse().unwrap_or(0.0);
                    match k { "alpha" => p.alpha = v, "prior" => p.prior = v, "margin" => p.margin = v, "explore" => p.explore = v as u32, "tcp" => p.tcp = v, "q0" => p.q0 = v, "mode" => p.mode_on = v > 0.0, "mix" => p.mix = v > 0.0, "exit" => p.exit_after = v as u32, "floor" => p.floor = v, "enter" => p.enter = v, k if k.starts_with('b') && k[1..].parse::<usize>().map_or(false, |i| i < ctl::NB) => p.qb[k[1..].parse::<usize>().unwrap()] = v, _ => {} }
                }
            }
        }
        Ctl::new(p, t.cost, t.t16)
    };
    let use16 = |g16: f64, t8: f64| g16 > (c16 - 1.0) * t8;
    let ag_n: usize = policy.split_once(':').and_then(|(_, kv)| kv.split(|ch| ch == ',' || ch == '_').find_map(|i| i.strip_prefix("agn=").and_then(|v| v.parse().ok()))).unwrap_or(63);
    let ag_th: usize = policy.split_once(':').and_then(|(_, kv)| kv.split(|ch| ch == ',' || ch == '_').find_map(|i| i.strip_prefix("ag=").and_then(|v| v.parse().ok()))).unwrap_or(0);
    let (mut r_ema, mut r_last, mut r_prev) = (4.0f64, 0usize, 0usize);
    let (r_mode, r_th, r_alpha) = {
        let mut m = String::from("ema"); let (mut th, mut al) = (6.0f64, 0.3f64);
        if let Some((_, kv)) = policy.split_once(':') { for item in kv.split(',') { if let Some((k, v)) = item.split_once('=') { match k { "mode" => m = v.to_string(), "th" => th = v.parse().unwrap_or(6.0), "alpha" => al = v.parse().unwrap_or(0.3), _ => {} } } } }
        (m, th, al)
    };
    while j < n {
        let next = toks[j];
        let nbk = pend_rows.div_ceil(16);
        // candidate
        let (cand, src, mlen, sticky) = if kind != 'b' {
            let (mut cnd, src, mlen, sticky) = cp.propose_ex(next, maxrows - 1, ptr);
            cnd.truncate(if cnd.len() >= 32 && maxrows >= 64 { 63 } else if cnd.len() >= 16 && maxrows >= 32 { 31 } else { 15 });
            (cnd, src, mlen, sticky)
        } else {
            (Vec::new(), 0, 0, false)
        };
        let mut bd_rows = if kind == 'r' {
            let want16 = match r_mode.as_str() { "full" => r_last >= 7, "last" => r_last as f64 >= r_th, "two" => r_last.max(r_prev) as f64 >= r_th, _ => r_ema >= r_th };
            if want16 { 16 } else { 8 }
        } else if kind == 'a' || kind == 'o' || blk == 0 { if use16(adapt_g16, adapt_t8) { 16 } else { 8 } } else { blk };
        // choose
        let mut copy_n: Option<usize> = None;
        let mut oracle_lk: Option<usize> = None;
        let mut agree_used = false;
        match kind {
            'h' => {
                if !cand.is_empty() && cand.len() >= hy {
                    copy_n = Some(cand.len());
                }
            }
            'a' => {
                let cd = Cand { len: cand.len(), mlen, sticky };
                copy_n = ctl.decide(&cd, bd_rows);
                if copy_n.is_none() && ag_th > 0 && cand.len() >= 4 {
                    // second opinion: the drafter's block (which a non-copy pass would run anyway) against the copy candidate
                    let d = if bd_rows == 16 { &t.d16[j] } else { &t.d8[j] };
                    let mut l = 0;
                    while l < d.len() && l < cand.len() && d[l] == cand[l] { l += 1; }
                    if l >= ag_th { copy_n = Some(cand.len().min(ag_n)); agree_used = true; }
                }
            }
            'o' => {
                let allow_lk = !policy.contains(":bd") && !policy.contains(":cp");
                let allow_cp = !policy.contains(":bd") && !policy.contains(":lk");
                // oracle: best value per ms over the bdraft2 blocks and the copy candidates of every row class (non-causal)
                let mut best = (0usize, 0f64, usize::MAX);
                for (i, (d, r)) in [(&t.d8[j], 8usize), (&t.d16[j], 16)].iter().enumerate() {
                    let a = acc_len(d, toks, j);
                    let v = (1.0 + a as f64) / (main_ms(t, *r) + if *r == 8 { t.t8 } else { t.t16 } + c.cu * (nbk.saturating_sub(1)) as f64 + c.ov);
                    if v > best.1 { best = (i, v, usize::MAX); }
                }
                for r in [8usize, 16] {
                    if !allow_lk { break; }
                    let dl = lkp.draft(next, r - 1).0;
                    let a = acc_len(&dl, toks, j);
                    let v = (1.0 + a as f64) / (main_ms(t, r) + c.ov);
                    if v > best.1 { best = (7 + r, v, usize::MAX); }
                }
                for &cls in &[16usize, 32, 64] {
                    let k = cand.len().min(cls - 1);
                    if k < 4 || !allow_cp { continue; }
                    let a = acc_len(&cand[..k], toks, j);
                    let v = (1.0 + a as f64) / (main_ms(t, k + 1) + c.tcp + c.cu * nbk as f64 + c.ov);
                    if v > best.1 { best = (9, v, k); }
                }
                if best.2 != usize::MAX { copy_n = Some(best.2); } else { copy_n = None; }
                oracle_lk = if best.0 >= 15 { Some(best.0 - 7) } else { None };
                if best.0 == 0 { bd_rows = 8; } else if best.0 == 1 { bd_rows = 16; }
            }
            _ => {}
        }
        let (emitted, rows_run);
        let lk_rows = if kind == 'l' { Some(blk) } else { oracle_lk };
        if let Some(r) = lk_rows {
            let dl = lkp.draft(next, r - 1).0;
            let a = acc_len(&dl, toks, j);
            emitted = a + 1;
            rows_run = r;
            let mm = main_ms(t, r);
            ms += mm + c.ov;
            ms_main += mm;
            ptr = None;
        } else if let Some(k) = copy_n {
            let k = k.min(cand.len());
            let a = acc_len(&cand[..k], toks, j);
            emitted = a + 1;
            rows_run = k + 1;
            let mm = main_ms(t, rows_run);
            let mut dd = c.tcp + c.cu * nbk as f64;
            if agree_used { dd += if bd_rows == 16 { t.t16 } else { t.t8 }; }
            ms += mm + dd + c.ov;
            ms_main += mm;
            ms_draft += dd;
            ncopy += 1;
            classes[match rows_run { 0..=16 => 1, 17..=32 => 2, _ => 3 }] += 1;
            if kind == 'a' {
                ctl.observe_copy(&Cand { len: cand.len(), mlen, sticky }, k, a);
                ctl.observe_main(rows_run, mm);
            }
            ptr = Some(src + emitted);
        } else {
            let (d, r) = if bd_rows == 16 { (&t.d16[j], 16usize) } else { (&t.d8[j], 8) };
            let a = acc_len(d, toks, j);
            emitted = a + 1;
            rows_run = r;
            let mm = main_ms(t, r);
            let dd = (if r == 8 { t.t8 } else { t.t16 }) + c.cu * nbk.saturating_sub(1) as f64;
            ms += mm + dd + c.ov;
            ms_main += mm;
            ms_draft += dd;
            ptr = None;
            classes[0] += 1;
            if kind == 'a' || kind == 'o' || blk == 0 || kind == 'b' || kind == 'h' {
                // YASAKANI's 8 / 16 rule is updated by every drafter pass
                adapt_t8 = 0.85 * adapt_t8 + 0.15 * (a.min(7) + 1) as f64;
                let gobs = if r == 16 { if a >= 7 { adapt_extra = 0.8 * adapt_extra + 0.2 * (a - 7) as f64; } a.saturating_sub(7) as f64 } else if a >= 7 { adapt_extra } else { 0.0 };
                adapt_g16 = 0.85 * adapt_g16 + 0.15 * gobs;
            }
            r_prev = r_last; r_last = a; r_ema = (1.0 - r_alpha) * r_ema + r_alpha * a as f64;
            if kind == 'a' {
                ctl.observe_bd(r, a);
                ctl.observe_main(r, mm);
                ctl.observe_draft(dd);
            }
        }
        let emitted = emitted.min(n - j);
        if std::env::var("SIMD").is_ok() && (kind == 'a' || kind == 'h') {
            eprintln!("  j {:>5} {} rows {:>3} emitted {:>3} cand len {:>3} mlen {:>3} sticky {}", j, if copy_n.is_some() { "copy" } else { "bd  " }, rows_run, emitted, cand.len(), mlen, sticky);
        }
        for i in 0..emitted {
            cp.push(toks[j + i]);
            lkp.push(toks[j + i], toks[j + i + 1]);
        }
        j += emitted;
        pend_rows = emitted;
        passes += 1;
        let _ = rows_run;
    }
    SimOut { tok_s: n as f64 / ms * 1e3, passes, copy_passes: ncopy, tok_per_pass: n as f64 / passes as f64, ms_per_pass: ms / passes as f64, main_ms: ms_main / passes as f64, draft_ms: ms_draft / passes as f64, classes }
}

pub fn sim(args: &[String]) -> Result<()> {
    let traces: Vec<Trace> = args[1].split(',').map(load_trace).collect::<Result<_>>()?;
    let pols: Vec<&str> = args[2].split(',').collect();
    let cost = Cost { ov: opt(args, "--ov").and_then(|v| v.parse().ok()).unwrap_or(0.65), cu: opt(args, "--cu").and_then(|v| v.parse().ok()).unwrap_or(0.45), tcp: opt(args, "--tcp").and_then(|v| v.parse().ok()).unwrap_or(0.15) };
    println!("{:<16}{}", "task", pols.iter().map(|p| format!("{p:>16}")).collect::<String>());
    let mut sums = vec![0f64; pols.len()];
    for t in &traces {
        let outs: Vec<SimOut> = pols.iter().map(|p| simulate(t, p, &cost)).collect();
        println!("{:<16}{}", t.name, outs.iter().map(|o| format!("{:>8.1} ({:>4.1}%)", o.tok_s, 100.0 * o.copy_passes as f64 / o.passes as f64)).collect::<String>());
        if std::env::var("SIMV").is_ok() {
            println!("{:<16}{}", "  tok/pass|ms", outs.iter().map(|o| format!("{:>8.2}|{:>6.1}", o.tok_per_pass, o.ms_per_pass)).collect::<String>());
            println!("{:<16}{}", "  bd/c16/c32/c64", outs.iter().map(|o| format!("{:>3}/{:>3}/{:>3}/{:>3} ", o.classes[0], o.classes[1], o.classes[2], o.classes[3])).collect::<String>());
        }
        for (s, o) in sums.iter_mut().zip(&outs) {
            *s += o.tok_s;
        }
    }
    println!("{:<16}{}", "mean", sums.iter().map(|s| format!("{:>16.1}", s / traces.len() as f64)).collect::<String>());
    Ok(())
}
