//! Online source controller for speculative decoding (Part AI): chooses, pass by pass, between verifying a copy candidate (prompt-lookup style, free to produce) and
//! the bdraft2 block (costs a drafter step), from what the run itself has observed: the accepted fraction of copy candidates by match-quality bucket, the accepted
//! drafts per bdraft2 pass, and the measured pass costs. It never looks at the prompt. Every choice only changes which tokens are verified, the output is the greedy output.

pub const NB: usize = 24;

#[derive(Clone, Debug)]
pub struct Cand {
    pub len: usize,    // candidate tokens available (<= 63)
    pub mlen: usize,   // backward match length of the chosen source (0 = sticky continuation)
    pub sticky: bool,
}

#[derive(Clone, Debug)]
pub struct Params {
    pub alpha: f64,       // EMA weight of a new observation
    pub prior: f64,       // weight (pseudo-observations) of the prior acceptance of a copy candidate of each match-quality bucket
    pub margin: f64,      // copy must beat bdraft2 by this factor
    pub explore: u32,     // passes without copy before a candidate of >= 8 tokens is verified anyway
    pub tcp: f64,         // host cost of a copy pass beyond the main pass (ms)
    pub q0: f64,          // added to the prior acceptance of every bucket (optimism)
    pub exit_after: u32,  // consecutive poor copy passes that end the copy mode
    pub floor: f64,       // expected accepted fraction assumed at least for a sticky continuation or a long (>= 16) match; 0 = off
    pub mix: bool,        // bimodal estimator (candidate right / wrong) instead of the geometric per-token one
    pub mode_on: bool,    // enable the copy mode (hysteresis)
    pub enter: f64,       // accepted fraction of a candidate of >= 8 tokens that switches the copy mode on
    pub qb: [f64; NB],    // per-bucket prior acceptance overrides (negative = use the built-in prior)
}

impl Default for Params {
    fn default() -> Self {
        Params { alpha: 0.3, prior: 4.0, margin: 1.0, explore: 100, tcp: 0.2, q0: 0.0, exit_after: 2, floor: 0.0, mix: false, mode_on: true, enter: 0.5, qb: [-1.0; NB] }
    }
}

pub struct Ctl {
    pub p: Params,
    s: [f64; NB], // copy candidates: accepted tokens (successes) per bucket, decayed
    r: [f64; NB], // copy candidates: rejections (a candidate that was not accepted to its end), decayed
    ebd8: f64,
    ebd16: f64,
    main: [f64; 5], // ms per pass for 8, 16, 32, 48, 64 rows
    pub dbd: f64,   // ms of one bdraft2 step (with its ring catch-up)
    since_copy: u32,
    mode: bool,    // copy mode: copying has been paying off, verify every candidate like the plain hybrid
    misses: u32,
}

fn class_of(rows: usize) -> usize {
    match rows {
        0..=8 => 0,
        9..=16 => 1,
        17..=32 => 2,
        33..=48 => 3,
        _ => 4,
    }
}

impl Ctl {
    pub fn new(p: Params, main: [f64; 5], dbd: f64) -> Self {
        // Informed priors by match quality (pseudo-counts of weight `prior`): a sticky continuation or a long backward match is trusted at first, a 3-token match is not; the
        // first trials correct a wrong prior within a few passes.
        const Q0: [f64; NB] = [0.0, 0.3, 0.5, 0.8, 0.92, 0.95, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99, 0.0, 0.3, 0.5, 0.8, 0.92, 0.95, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99];
        const QM: [f64; NB] = [0.0, 0.05, 0.1, 0.15, 0.25, 0.6, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.0, 0.05, 0.1, 0.3, 0.4, 0.7, 0.92, 0.92, 0.92, 0.92, 0.92, 0.92];
        let base = if p.mix { QM } else { Q0 };
        let w = p.prior;
        let mut s = [0.0; NB];
        let mut r = [0.0; NB];
        for b in 0..NB {
            let q = (if p.qb[b] >= 0.0 { p.qb[b] } else { base[b] + p.q0 }).min(0.995);
            s[b] = q * w;
            r[b] = (1.0 - q) * w;
        }
        Ctl { s, r, ebd8: 3.5, ebd16: 4.5, main, dbd, since_copy: 0, mode: false, misses: 0, p }
    }
    fn bucket(c: &Cand) -> usize {
        let m = match c.mlen {
            0 => 0,
            1..=3 => 1,
            4..=5 => 2,
            6..=9 => 3,
            10..=19 => 4,
            _ => 5,
        };
        m + if c.sticky { 6 } else { 0 } + if c.len >= 32 { 12 } else { 0 }
    }
    fn q(&self, b: usize) -> f64 {
        // probability that a candidate of this bucket is 'right' (accepted nearly to its end): good / (good + bad), decayed
        self.s[b] / (self.s[b] + self.r[b]).max(1e-9)
    }
    /// Expected accepted tokens of a candidate of `n` tokens whose per-token acceptance is q (prefix model: q + q^2 + .. + q^n).
    fn exp_acc(&self, pi: f64, n: usize) -> f64 {
        if self.p.mix {
            // a right candidate is accepted to its end, a wrong one gives a short geometric run (per-token acceptance QBAD)
            const QBAD: f64 = 0.35;
            pi * n as f64 + (1.0 - pi) * QBAD * (1.0 - f64::powi(QBAD, n as i32)) / (1.0 - QBAD)
        } else if pi >= 0.9999 {
            n as f64
        } else {
            // geometric: pi is the per-token acceptance
            pi * (1.0 - pi.powi(n as i32)) / (1.0 - pi)
        }
    }
    pub fn main_ms(&self, rows: usize) -> f64 {
        self.main[class_of(rows)]
    }
    fn ebd(&self, rows: usize) -> f64 {
        if rows <= 8 { self.ebd8 } else { self.ebd16 }
    }
    /// `bd_rows` = rows the bdraft2 block would use (8 or 16). Returns the number of candidate tokens to verify, or None for the bdraft2 block.
    pub fn decide(&mut self, c: &Cand, bd_rows: usize) -> Option<usize> {
        if c.len < 4 {
            self.since_copy += 1;
            return None;
        }
        if self.mode && self.p.mode_on {
            self.since_copy = 0;
            return Some(c.len);
        }
        let v_bd = (1.0 + self.ebd(bd_rows)) / (self.main_ms(bd_rows) + self.dbd);
        let q = self.q(Self::bucket(c));
        let mut best: Option<(usize, f64)> = None;
        for &cls in &[16usize, 32, 64] {
            let n = c.len.min(cls - 1);
            if (cls == 32 && n < 16) || (cls == 64 && n < 32) {
                continue;
            }
            let mut e = self.exp_acc(q, n);
            if self.p.floor > 0.0 && (c.sticky || c.mlen >= 16) {
                e = e.max(self.p.floor * n as f64);
            }
            let v = (1.0 + e) / (self.main_ms(n + 1) + self.p.tcp);
            if best.map_or(true, |(_, bv)| v > bv) {
                best = Some((n, v));
            }
        }
        match best {
            Some((n, v)) if v > v_bd * self.p.margin => {
                self.since_copy = 0;
                Some(n)
            }
            _ => {
                self.since_copy += 1;
                if self.since_copy > self.p.explore && c.len >= 8 {
                    self.since_copy = 0;
                    Some(c.len.min(15))
                } else {
                    None
                }
            }
        }
    }
    pub fn observe_copy(&mut self, c: &Cand, verified: usize, accepted: usize) {
        let b = Self::bucket(c);
        let g = 1.0 - self.p.alpha; // decay
        if verified >= 8 {
            let frac = accepted as f64 / verified as f64;
            if frac >= self.p.enter {
                self.mode = true;
                self.misses = 0;
            } else {
                self.misses += 1;
                if self.misses >= self.p.exit_after {
                    self.mode = false;
                }
            }
        }
        if self.p.mix {
            let right = accepted as f64 >= 0.9 * verified as f64;
            self.s[b] = g * self.s[b] + if right { 1.0 } else { 0.0 };
            self.r[b] = g * self.r[b] + if right { 0.0 } else { 1.0 };
        } else {
            self.s[b] = g * self.s[b] + accepted as f64;
            self.r[b] = g * self.r[b] + if accepted < verified { 1.0 } else { 0.0 };
        }
    }
    pub fn observe_bd(&mut self, rows: usize, accepted: usize) {
        let a = self.p.alpha;
        if rows <= 8 {
            self.ebd8 = (1.0 - a) * self.ebd8 + a * accepted as f64;
        } else {
            self.ebd16 = (1.0 - a) * self.ebd16 + a * accepted as f64;
        }
    }
    /// Measured wall time of a pass of `rows` rows (verify + commit), EMA into the cost table.
    pub fn observe_main(&mut self, rows: usize, ms: f64) {
        let k = class_of(rows);
        self.main[k] = 0.8 * self.main[k] + 0.2 * ms;
    }
    pub fn observe_draft(&mut self, ms: f64) {
        self.dbd = 0.8 * self.dbd + 0.2 * ms;
    }
}
