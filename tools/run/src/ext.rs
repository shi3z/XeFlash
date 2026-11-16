//! Draft sources other than the official MTP block, for comparison on the same
//! XeFlash main model:
//!
//! * `Bdraft2`: YASAKANI's drafter through the experimental `libxbd` shim
//!   (feature `bdraft2`), fed with tap states captured from XeFlash.
//! * `Lookup`: host-only drafts in the manner of YASAKANI's D0 / D1
//!   (re-implemented from its description, not its code): D0 copies what
//!   followed the most recent earlier occurrence of the current n-gram
//!   (n = 8 .. 2); D1 follows tables of what the main model chose after the
//!   last one, two or three tokens.

use std::collections::HashMap;

/// D0 + D1 state over the committed token sequence.
#[derive(Default)]
pub struct Lookup {
    seq: Vec<u32>,
    /// For n = 2..=8: n-gram -> index of its last token (most recent occurrence).
    grams: Vec<HashMap<Vec<u32>, usize>>,
    t1: HashMap<u32, u32>,
    t2: HashMap<(u32, u32), u32>,
    t3: HashMap<(u32, u32, u32), u32>,
}

impl Lookup {
    pub fn new() -> Self {
        Lookup { grams: (0..9).map(|_| HashMap::new()).collect(), ..Default::default() }
    }

    /// Append a committed token and the main model's greedy choice after it.
    pub fn push(&mut self, tok: u32, next: u32) {
        self.seq.push(tok);
        let f = self.seq.len() - 1;
        for n in 2..=8usize {
            if f + 1 >= n {
                self.grams[n].insert(self.seq[f + 1 - n..=f].to_vec(), f);
            }
        }
        self.t1.insert(tok, next);
        if f >= 1 {
            self.t2.insert((self.seq[f - 1], tok), next);
        }
        if f >= 2 {
            self.t3.insert((self.seq[f - 2], self.seq[f - 1], tok), next);
        }
    }

    /// Up to `k` drafts for the positions after the frontier token `next`
    /// (which is not committed yet). Returns (drafts, tokens that came from D0).
    pub fn draft(&self, next: u32, k: usize) -> (Vec<u32>, usize) {
        let mut ctx: Vec<u32> = self.seq[self.seq.len().saturating_sub(8)..].to_vec();
        ctx.push(next);
        // D0: longest n-gram ending at the frontier that was seen before.
        let mut out = Vec::new();
        let mut n0 = 0;
        for n in (2..=8usize).rev() {
            if ctx.len() < n {
                continue;
            }
            if let Some(&p) = self.grams[n].get(&ctx[ctx.len() - n..]) {
                out.extend(self.seq[p + 1..self.seq.len().min(p + 1 + k)].iter().copied());
                n0 = n;
                break;
            }
        }
        // Short matches are unreliable: prefer the tables unless n >= 3.
        if n0 < 3 {
            let d1 = self.chain(&ctx, k);
            if !d1.is_empty() {
                return (d1, 0);
            }
        }
        let from_d0 = out.len();
        // Extend a D0 chain that ran into the end of the text with the tables.
        if out.len() < k {
            let mut c = ctx.clone();
            c.extend(&out);
            out.extend(self.chain(&c, k - out.len()));
        }
        (out, from_d0)
    }

    fn chain(&self, ctx: &[u32], k: usize) -> Vec<u32> {
        let mut c = ctx.to_vec();
        let mut out = Vec::new();
        while out.len() < k {
            let n = c.len();
            let hit = (n >= 3)
                .then(|| self.t3.get(&(c[n - 3], c[n - 2], c[n - 1])))
                .flatten()
                .or_else(|| (n >= 2).then(|| self.t2.get(&(c[n - 2], c[n - 1]))).flatten())
                .or_else(|| self.t1.get(&c[n - 1]));
            match hit {
                Some(&t) => {
                    out.push(t);
                    c.push(t);
                }
                None => break,
            }
        }
        out
    }
}

#[cfg(feature = "bdraft2")]
pub mod bdraft2 {
    use std::ffi::{CStr, CString, c_char, c_void};

    use xeflash_core::{Error, Result};

    #[link(name = "xbd")]
    unsafe extern "C" {
        fn xbd_last_error() -> *const c_char;
        fn xbd_open(main: *const c_char, draft: *const c_char, max_ctx: i32, out: *mut *mut c_void) -> i32;
        fn xbd_close(h: *mut c_void);
        fn xbd_reset(h: *mut c_void) -> i32;
        fn xbd_ctx(h: *mut c_void, taps: *const f32, n: i32, pos0: i32) -> i32;
        fn xbd_step(h: *mut c_void, taps: *const f32, n: i32, pos0: i32, r: i32, tok: i32, p: i32, out: *mut i32) -> i32;
        fn xbd_step_dev(h: *mut c_void, dev_taps: *const f32, n: i32, pos0: i32, r: i32, tok: i32, p: i32, out: *mut i32) -> i32;
    }

    fn check(st: i32) -> Result<()> {
        if st == 0 {
            Ok(())
        } else {
            Err(Error::Runtime(unsafe { CStr::from_ptr(xbd_last_error()) }.to_string_lossy().into_owned()))
        }
    }

    /// YASAKANI's bdraft2 drafter (weights and kernels of the YASAKANI B60
    /// port), driven by tap states supplied from host memory.
    pub struct Bdraft2(*mut c_void);

    impl Bdraft2 {
        pub fn open(main_yskn: &str, draft_yskn: &str, max_ctx: usize) -> Result<Self> {
            let (a, b) = (CString::new(main_yskn).unwrap(), CString::new(draft_yskn).unwrap());
            let mut h = std::ptr::null_mut();
            check(unsafe { xbd_open(a.as_ptr(), b.as_ptr(), max_ctx as i32, &mut h) })?;
            Ok(Bdraft2(h))
        }
        pub fn reset(&mut self) -> Result<()> {
            check(unsafe { xbd_reset(self.0) })
        }
        /// `taps` is `[5][16][5120]`; its first `n` rows per tap are ring rows `pos0..`.
        pub fn ctx(&mut self, taps: &[f32], n: usize, pos0: usize) -> Result<()> {
            check(unsafe { xbd_ctx(self.0, taps.as_ptr(), n as i32, pos0 as i32) })
        }
        /// Ring catch-up with `n` rows, then `r - 1` drafts after token `tok` at position `p`.
        pub fn step(&mut self, taps: &[f32], n: usize, pos0: usize, r: usize, tok: u32, p: usize) -> Result<Vec<u32>> {
            let mut out = vec![0i32; r];
            check(unsafe { xbd_step(self.0, taps.as_ptr(), n as i32, pos0 as i32, r as i32, tok as i32, p as i32, out.as_mut_ptr()) })?;
            Ok(out[..r - 1].iter().map(|t| *t as u32).collect())
        }
    }

    impl Bdraft2 {
        /// Like [`step`], reading the taps from the main engine's device
        /// buffer. `Ok(None)` if the two engines do not share a SYCL context
        /// (the caller then falls back to the host copy).
        pub fn step_dev(&mut self, dev_taps: *const f32, n: usize, pos0: usize, r: usize, tok: u32, p: usize) -> Result<Option<Vec<u32>>> {
            let mut out = vec![0i32; r];
            match unsafe { xbd_step_dev(self.0, dev_taps, n as i32, pos0 as i32, r as i32, tok as i32, p as i32, out.as_mut_ptr()) } {
                2 => Ok(None),
                st => {
                    check(st)?;
                    Ok(Some(out[..r - 1].iter().map(|t| *t as u32).collect()))
                }
            }
        }
    }

    impl Drop for Bdraft2 {
        fn drop(&mut self) {
            unsafe { xbd_close(self.0) }
        }
    }
}
