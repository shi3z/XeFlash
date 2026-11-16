//! The resident model: every weight of the container on the device, recurrent
//! state, KV cache and one workspace, plus the pass / commit protocol.
//!
//! A pass (`forward`) runs up to 16 consecutive tokens starting at the
//! committed position and never changes committed state. `commit(n)` makes
//! the first `n` tokens of the last pass permanent. Decoding one token is
//! `forward(&[t])` + `commit(1)`; speculative verification is a longer pass
//! followed by a commit of the accepted prefix.

use std::ffi::c_void;

use xeflash_core::{Error, Result, WeightFormat, bf16_to_f32};
use xeflash_model::Container;

use crate::{Device, DeviceBuf, check, ffi};

pub const MAX_TOKENS: usize = 16;
pub const HIDDEN: usize = 5120;
pub const VOCAB: usize = 248320;
pub const LAYERS: usize = 64;
/// Timing categories reported by a profiled pass, in milliseconds.
pub const PROF_NAMES: [&str; 7] = ["norm", "quant", "gemm", "gdn", "attn", "mlp", "head"];

/// One device allocation, for the memory report.
pub struct Alloc {
    pub category: &'static str,
    pub name: String,
    pub bytes: usize,
}

pub struct Engine {
    dev: Device,
    model: Box<ffi::xf_model>,
    _layers: Box<[ffi::xf_layer]>,
    bufs: Vec<DeviceBuf>,
    states: Vec<DeviceBuf>,
    ws: DeviceBuf,
    mtp: Option<Box<ffi::xf_mtp>>,
    allocs: Vec<Alloc>,
    ctx: usize,
    pos: usize,
    last_m: usize,
}

// The raw pointers inside `model` point into buffers owned by the same struct.
unsafe impl Send for Engine {}

struct Loader<'a> {
    dev: &'a Device,
    xfm: &'a Container,
    bufs: Vec<DeviceBuf>,
    allocs: Vec<Alloc>,
}

impl Loader<'_> {
    fn keep(&mut self, category: &'static str, name: &str, buf: DeviceBuf) -> *mut c_void {
        let ptr = buf.ptr;
        self.allocs.push(Alloc { category, name: name.to_string(), bytes: buf.len_bytes() });
        self.bufs.push(buf);
        ptr
    }

    fn dense(&self, name: &str) -> Result<Vec<f32>> {
        let d = self.xfm.dense(name)?;
        if d.dtype != "bf16" {
            return Err(Error::Invalid(format!("{name}: expected bf16, found {}", d.dtype)));
        }
        Ok(d.bytes.chunks_exact(2).map(|b| bf16_to_f32(u16::from_le_bytes([b[0], b[1]]))).collect())
    }

    fn upload_f32(&mut self, category: &'static str, name: &str, v: &[f32]) -> Result<*const f32> {
        let buf = self.dev.upload(v)?;
        Ok(self.keep(category, name, buf).cast())
    }

    /// `1 + weight` of a zero-centred RMSNorm.
    fn gain(&mut self, name: &str) -> Result<*const f32> {
        let v: Vec<f32> = self.dense(name)?.iter().map(|w| 1.0 + w).collect();
        self.upload_f32("small tensors", name, &v)
    }

    fn matrix(&mut self, name: &str, category: &'static str) -> Result<ffi::xf_mat> {
        let m = self.xfm.matrix(name)?;
        if m.format != WeightFormat::S4 && m.format != WeightFormat::S8 && m.format != WeightFormat::S2 {
            return Err(Error::Invalid(format!("{name}: unsupported matrix format")));
        }
        let w = self.dev.upload(m.tiles)?;
        let w = self.keep(category, name, w);
        let rs = self.upload_f32("matrix scales", name, &m.row_scale)?;
        let cs = self.upload_f32("matrix scales", name, &m.col_scale)?;
        let cmax = m.col_scale.iter().fold(0f32, |a, v| a.max(v.abs()));
        Ok(ffi::xf_mat { w, rs, cs, cmax, rows: m.rows as i32, cols: m.cols as i32, fmt: m.format as i32 })
    }
}

impl Engine {
    /// Put the whole text model on the device. `ctx` is the KV-cache capacity
    /// in tokens; all memory is allocated here, nothing later.
    pub fn load(dev: &Device, xfm: &Container, ctx: usize) -> Result<Engine> {
        if ctx == 0 || ctx % 64 != 0 {
            return Err(Error::Invalid("context capacity must be a positive multiple of 64".into()));
        }
        let mut ld = Loader { dev, xfm, bufs: Vec::new(), allocs: Vec::new() };
        let null_mat =
            ffi::xf_mat { w: std::ptr::null(), rs: std::ptr::null(), cs: std::ptr::null(), cmax: 0.0, rows: 0, cols: 0, fmt: 0 };
        let mut layers = Vec::with_capacity(LAYERS);
        let mut states = Vec::new();
        let mut state_allocs = Vec::new();
        for l in 0..LAYERS {
            let p = format!("model.language_model.layers.{l}.");
            let is_attn = l % 4 == 3;
            let mut m = [null_mat; 7];
            let mut aux = [std::ptr::null::<f32>(); 5];
            let mlp_at;
            let has = |n: &str| xfm.names().any(|(name, kind)| kind == "matrix" && name == n);
            if is_attn {
                // Merged containers stack q, k, v into one matrix (slot 0).
                let merged = format!("{p}self_attn.qkv_proj.weight");
                if has(&merged) {
                    m[0] = ld.matrix(&merged, "body matrices")?;
                } else {
                    for (i, n) in ["q_proj", "k_proj", "v_proj"].iter().enumerate() {
                        m[i] = ld.matrix(&format!("{p}self_attn.{n}.weight"), "body matrices")?;
                    }
                }
                m[3] = ld.matrix(&format!("{p}self_attn.o_proj.weight"), "body matrices")?;
                aux[0] = ld.gain(&format!("{p}self_attn.q_norm.weight"))?;
                aux[1] = ld.gain(&format!("{p}self_attn.k_norm.weight"))?;
                mlp_at = 4;
            } else {
                let merged = format!("{p}linear_attn.in_proj_qkvz.weight");
                if has(&merged) {
                    m[0] = ld.matrix(&merged, "body matrices")?;
                } else {
                    m[0] = ld.matrix(&format!("{p}linear_attn.in_proj_qkv.weight"), "body matrices")?;
                    m[1] = ld.matrix(&format!("{p}linear_attn.in_proj_z.weight"), "body matrices")?;
                }
                m[2] = ld.matrix(&format!("{p}linear_attn.out_proj.weight"), "body matrices")?;
                let mut ab = ld.dense(&format!("{p}linear_attn.in_proj_a.weight"))?;
                ab.extend(ld.dense(&format!("{p}linear_attn.in_proj_b.weight"))?);
                aux[0] = ld.upload_f32("small tensors", "in_proj_a+b", &ab)?;
                // [10240][1][4] -> tap-major [4][10240]
                let conv = ld.dense(&format!("{p}linear_attn.conv1d.weight"))?;
                let n = conv.len() / 4;
                let mut taps = vec![0f32; conv.len()];
                for c in 0..n {
                    for k in 0..4 {
                        taps[k * n + c] = conv[c * 4 + k];
                    }
                }
                aux[1] = ld.upload_f32("small tensors", "conv1d", &taps)?;
                let mut nega = vec![0f32; 64];
                for (o, a) in nega.iter_mut().zip(ld.dense(&format!("{p}linear_attn.A_log"))?) {
                    *o = -a.exp();
                }
                aux[2] = ld.upload_f32("small tensors", "A_log", &nega)?;
                let mut dtb = ld.dense(&format!("{p}linear_attn.dt_bias"))?;
                dtb.resize(64, 0.0);
                aux[3] = ld.upload_f32("small tensors", "dt_bias", &dtb)?;
                let gw = ld.dense(&format!("{p}linear_attn.norm.weight"))?;
                aux[4] = ld.upload_f32("small tensors", "linear_attn.norm", &gw)?;
                mlp_at = 3;
            }
            let gate_up = format!("{p}mlp.gate_up_proj.weight");
            if has(&gate_up) {
                m[mlp_at] = ld.matrix(&gate_up, "body matrices")?;
            } else {
                m[mlp_at] = ld.matrix(&format!("{p}mlp.gate_proj.weight"), "body matrices")?;
                m[mlp_at + 1] = ld.matrix(&format!("{p}mlp.up_proj.weight"), "body matrices")?;
            }
            m[mlp_at + 2] = ld.matrix(&format!("{p}mlp.down_proj.weight"), "body matrices")?;
            let kind = if is_attn { ffi::XF_LAYER_ATTN } else { ffi::XF_LAYER_GDN };
            let sbytes = unsafe { ffi::xf_state_bytes(kind, ctx as i32) };
            let state = dev.alloc(sbytes)?;
            state_allocs.push(Alloc {
                category: if is_attn { "KV cache" } else { "DeltaNet state" },
                name: format!("layer {l}"),
                bytes: sbytes,
            });
            layers.push(ffi::xf_layer {
                kind,
                reserved: 0,
                ln1: ld.gain(&format!("{p}input_layernorm.weight"))?,
                ln2: ld.gain(&format!("{p}post_attention_layernorm.weight"))?,
                m,
                aux,
                state: state.ptr,
            });
            states.push(state);
        }
        let fnorm = ld.gain("model.language_model.norm.weight")?;
        let head = ld.matrix("lm_head.weight", "lm_head")?;
        let emb = xfm.dense("model.language_model.embed_tokens.weight")?;
        if emb.dtype != "bf16" || emb.bytes.len() != VOCAB * HIDDEN * 2 {
            return Err(Error::Invalid("embedding table has an unexpected type or shape".into()));
        }
        let emb_buf = dev.upload(emb.bytes)?;
        let embed = ld.keep("embedding (bf16)", "embed_tokens", emb_buf).cast::<u16>().cast_const();

        // RoPE table: 32 frequencies, theta 1e7, rotary dim 64; angles in f32 like the reference.
        let inv_freq: Vec<f32> = (0..32).map(|i| (1.0 / 1e7f64.powf(2.0 * i as f64 / 64.0)) as f32).collect();
        let mut cos = vec![0f32; ctx * 32];
        let mut sin = vec![0f32; ctx * 32];
        for p in 0..ctx {
            for i in 0..32 {
                let a = (p as f32 * inv_freq[i]) as f64;
                cos[p * 32 + i] = a.cos() as f32;
                sin[p * 32 + i] = a.sin() as f32;
            }
        }
        let rope_cos = ld.upload_f32("RoPE table", "cos", &cos)?;
        let rope_sin = ld.upload_f32("RoPE table", "sin", &sin)?;

        // The official MTP block, if the container carries it in usable form
        // (mtp.fc must be dense: it does not survive low-bit quantisation).
        let mut mtp = None;
        if xfm.names().any(|(n, k)| n == "mtp.fc.weight" && k == "dense") {
            let p = "mtp.layers.0.";
            let mut m = [null_mat; 7];
            let has = |n: &str| xfm.names().any(|(name, kind)| kind == "matrix" && name == n);
            if has(&format!("{p}self_attn.qkv_proj.weight")) {
                m[0] = ld.matrix(&format!("{p}self_attn.qkv_proj.weight"), "MTP")?;
            } else {
                for (i, n) in ["q_proj", "k_proj", "v_proj"].iter().enumerate() {
                    m[i] = ld.matrix(&format!("{p}self_attn.{n}.weight"), "MTP")?;
                }
            }
            m[3] = ld.matrix(&format!("{p}self_attn.o_proj.weight"), "MTP")?;
            if has(&format!("{p}mlp.gate_up_proj.weight")) {
                m[4] = ld.matrix(&format!("{p}mlp.gate_up_proj.weight"), "MTP")?;
            } else {
                m[4] = ld.matrix(&format!("{p}mlp.gate_proj.weight"), "MTP")?;
                m[5] = ld.matrix(&format!("{p}mlp.up_proj.weight"), "MTP")?;
            }
            m[6] = ld.matrix(&format!("{p}mlp.down_proj.weight"), "MTP")?;
            let mut aux = [std::ptr::null::<f32>(); 5];
            aux[0] = ld.gain(&format!("{p}self_attn.q_norm.weight"))?;
            aux[1] = ld.gain(&format!("{p}self_attn.k_norm.weight"))?;
            let sbytes = unsafe { ffi::xf_state_bytes(ffi::XF_LAYER_ATTN, ctx as i32) };
            let state = dev.alloc(sbytes)?;
            state_allocs.push(Alloc { category: "MTP KV cache", name: "mtp".into(), bytes: sbytes });
            let layer = ffi::xf_layer {
                kind: ffi::XF_LAYER_ATTN,
                reserved: 0,
                ln1: ld.gain(&format!("{p}input_layernorm.weight"))?,
                ln2: ld.gain(&format!("{p}post_attention_layernorm.weight"))?,
                m,
                aux,
                state: state.ptr,
            };
            states.push(state);
            let fc = ld.dense("mtp.fc.weight")?;
            if fc.len() != HIDDEN * 2 * HIDDEN {
                return Err(Error::Invalid("mtp.fc has an unexpected shape".into()));
            }
            let fc = ld.upload_f32("MTP", "mtp.fc (f32)", &fc)?;
            mtp = Some(Box::new(ffi::xf_mtp {
                layer,
                fc,
                gain_e: ld.gain("mtp.pre_fc_norm_embedding.weight")?,
                gain_h: ld.gain("mtp.pre_fc_norm_hidden.weight")?,
                norm: ld.gain("mtp.norm.weight")?,
            }));
        }

        let ws_bytes = unsafe { ffi::xf_ws_bytes(ctx as i32) };
        let ws = dev.alloc(ws_bytes)?;
        let mut allocs = ld.allocs;
        allocs.extend(state_allocs);
        allocs.push(Alloc { category: "workspace", name: "workspace".into(), bytes: ws_bytes });

        let layers = layers.into_boxed_slice();
        let model = Box::new(ffi::xf_model {
            nlayers: LAYERS as i32,
            ctx: ctx as i32,
            layers: layers.as_ptr(),
            embed,
            fnorm,
            head,
            rope_cos,
            rope_sin,
            ws: ws.ptr,
        });
        let mut e = Engine { dev: dev.clone(), model, _layers: layers, bufs: ld.bufs, states, ws, mtp, allocs, ctx, pos: 0, last_m: 0 };
        e.reset()?;
        Ok(e)
    }

    pub fn allocations(&self) -> &[Alloc] {
        &self.allocs
    }
    pub fn buffer_count(&self) -> usize {
        self.bufs.len() + self.states.len() + 1
    }
    pub fn position(&self) -> usize {
        self.pos
    }
    pub fn capacity(&self) -> usize {
        self.ctx
    }

    /// Clear recurrent state and the KV cache; position 0.
    pub fn reset(&mut self) -> Result<()> {
        for s in &self.states {
            check(unsafe { ffi::xf_zero(self.dev.ctx.0, s.ptr, s.len_bytes()) })?;
        }
        check(unsafe { ffi::xf_zero(self.dev.ctx.0, self.ws.ptr, self.ws.len_bytes()) })?;
        self.dev.wait()?;
        self.pos = 0;
        self.last_m = 0;
        Ok(())
    }

    fn ws_off(&self, which: i32) -> usize {
        unsafe { ffi::xf_ws_offset(which, self.ctx as i32) }
    }

    /// Put token ids into the workspace for the next pass.
    pub fn set_tokens(&mut self, ids: &[u32]) -> Result<()> {
        if ids.is_empty() || ids.len() > MAX_TOKENS {
            return Err(Error::Invalid(format!("a pass takes 1..={MAX_TOKENS} tokens, got {}", ids.len())));
        }
        if let Some(bad) = ids.iter().find(|t| **t as usize >= VOCAB) {
            return Err(Error::Invalid(format!("token id {bad} is outside the vocabulary")));
        }
        if self.pos + ids.len() > self.ctx {
            return Err(Error::Invalid(format!("context capacity {} exceeded", self.ctx)));
        }
        let v: Vec<i32> = ids.iter().map(|t| *t as i32).collect();
        self.ws.write(self.ws_off(ffi::XF_WS_IDS), &v)?;
        self.last_m = ids.len();
        Ok(())
    }

    /// Submit layers `l0..l1` for the tokens set by [`set_tokens`]. `embed`
    /// runs the embedding lookup first, `head` the final norm, lm_head and
    /// argmax partials. With `prof` the pass synchronises per stage.
    pub fn run_layers(&mut self, l0: usize, l1: usize, embed: bool, head: bool, prof: Option<&mut [f64; 7]>) -> Result<()> {
        let flags = if embed { ffi::XF_FWD_EMBED } else { 0 } | if head { ffi::XF_FWD_HEAD } else { 0 };
        let prof = prof.map_or(std::ptr::null_mut(), |p| p.as_mut_ptr());
        check(unsafe {
            ffi::xf_forward(self.dev.ctx.0, &*self.model, self.last_m as i32, self.pos as i32, l0 as i32, l1 as i32, flags, prof)
        })
    }

    /// Whole pass: embedding, all layers, logits. Returns the greedy token
    /// and its logit for every input position.
    pub fn forward(&mut self, ids: &[u32], prof: Option<&mut [f64; 7]>) -> Result<Vec<(u32, f32)>> {
        self.set_tokens(ids)?;
        self.run_layers(0, LAYERS, true, true, prof)?;
        self.argmax()
    }

    /// Make the first `n` tokens of the last pass part of the context.
    pub fn commit(&mut self, n: usize) -> Result<()> {
        if n > self.last_m {
            return Err(Error::Invalid(format!("cannot commit {n} tokens of a {}-token pass", self.last_m)));
        }
        check(unsafe { ffi::xf_commit(self.dev.ctx.0, &*self.model, n as i32) })?;
        self.pos += n;
        self.last_m = 0;
        Ok(())
    }

    pub fn has_mtp(&self) -> bool {
        self.mtp.is_some()
    }

    /// One pass of the MTP block over `ids.len()` rows. Row `i` pairs the
    /// final-norm hidden state `src_row + i` left in the workspace by the
    /// previous pass (`None` = zero hidden state) with token `ids[i]`, at MTP
    /// position `pos0 + i`. Returns the greedy draft token of every row.
    pub fn mtp_pass(&mut self, ids: &[u32], pos0: usize, src_row: Option<usize>, prof: Option<&mut [f64; 7]>) -> Result<Vec<(u32, f32)>> {
        let mtp = self.mtp.as_ref().ok_or_else(|| Error::Invalid("this container has no usable MTP block".into()))?;
        if ids.is_empty() || ids.len() > MAX_TOKENS || pos0 + ids.len() > self.ctx {
            return Err(Error::Invalid("bad MTP pass shape".into()));
        }
        let v: Vec<i32> = ids.iter().map(|t| *t as i32).collect();
        self.ws.write(self.ws_off(ffi::XF_WS_IDS), &v)?;
        let prof = prof.map_or(std::ptr::null_mut(), |p| p.as_mut_ptr());
        check(unsafe {
            ffi::xf_mtp_step(self.dev.ctx.0, &*self.model, &**mtp, ids.len() as i32, pos0 as i32, src_row.map_or(-1, |r| r as i32), prof)
        })?;
        let keep = self.last_m;
        self.last_m = ids.len();
        let out = self.argmax();
        self.last_m = keep;
        out
    }

    /// Finish the argmax on the host (ties go to the lowest token id).
    pub fn argmax(&self) -> Result<Vec<(u32, f32)>> {
        const PER: usize = 97 * 64;
        let m = self.last_m;
        let mut v = vec![0f32; m * PER];
        let mut i = vec![0i32; m * PER];
        self.ws.read(self.ws_off(ffi::XF_WS_AMAX_V), &mut v)?;
        self.ws.read(self.ws_off(ffi::XF_WS_AMAX_I), &mut i)?;
        Ok((0..m)
            .map(|t| {
                let mut best = (0u32, f32::NEG_INFINITY);
                for k in t * PER..(t + 1) * PER {
                    if v[k] > best.1 || (v[k] == best.1 && (i[k] as u32) < best.0) {
                        best = (i[k] as u32, v[k]);
                    }
                }
                best
            })
            .collect())
    }

    /// Hidden states of the last pass, `[m][5120]` (after whatever layers ran).
    pub fn read_hidden(&self) -> Result<Vec<f32>> {
        let mut h = vec![0f32; self.last_m * HIDDEN];
        self.ws.read(self.ws_off(ffi::XF_WS_H), &mut h)?;
        Ok(h)
    }

    /// Logits of the last pass, `[m][248320]`.
    pub fn read_logits(&self) -> Result<Vec<f32>> {
        let mut l = vec![0f32; self.last_m * VOCAB];
        self.ws.read(self.ws_off(ffi::XF_WS_LOGITS), &mut l)?;
        Ok(l)
    }
}
