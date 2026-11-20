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
    sketch: Option<Box<ffi::xf_sketch>>,
    allocs: Vec<Alloc>,
    ctx: usize,
    pos: usize,
    last_m: usize,
    capture: bool,
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
        if std::env::var_os("XF_TRACE_ALLOC").is_some() {
            eprintln!("alloc {:#018x} +{:#x} {category} {name}", ptr as usize, buf.len_bytes());
        }
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
        if m.format != WeightFormat::S4 && m.format != WeightFormat::S8 && m.format != WeightFormat::S2 && m.format != WeightFormat::S3 && m.format != WeightFormat::S3P {
            return Err(Error::Invalid(format!("{name}: unsupported matrix format")));
        }
        let w = self.dev.upload(m.tiles)?;
        let w = self.keep(category, name, w);
        let rs = self.upload_f32("matrix scales", name, &m.row_scale)?;
        let cs = self.upload_f32("matrix scales", name, &m.col_scale)?;
        let bias = match &m.bias {
            Some(b) => self.upload_f32("matrix scales", name, b)?,
            None => std::ptr::null(),
        };
        let cmax = m.col_scale.iter().fold(0f32, |a, v| a.max(v.abs()));
        Ok(ffi::xf_mat { w, rs, cs, bias, cmax, rows: m.rows as i32, cols: m.cols as i32, fmt: m.format as i32 })
    }
}

impl Engine {
    /// Put the whole text model on the device. `ctx` is the KV-cache capacity
    /// in tokens; all memory is allocated here, nothing later.
    pub fn load(dev: &Device, xfm: &Container, ctx: usize) -> Result<Engine> {
        Self::load_with_mtp(dev, xfm, None, ctx)
    }

    /// Like [`load`], but take the MTP block from another container (for
    /// comparing drafter weights on one trunk).
    pub fn load_with_mtp(dev: &Device, xfm: &Container, mtp_xfm: Option<&Container>, ctx: usize) -> Result<Engine> {
        if ctx == 0 || ctx % 64 != 0 {
            return Err(Error::Invalid("context capacity must be a positive multiple of 64".into()));
        }
        let mut ld = Loader { dev, xfm, bufs: Vec::new(), allocs: Vec::new() };
        let null_mat =
            ffi::xf_mat { w: std::ptr::null(), rs: std::ptr::null(), cs: std::ptr::null(), bias: std::ptr::null(), cmax: 0.0, rows: 0, cols: 0, fmt: 0 };
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
            if std::env::var_os("XF_TRACE_ALLOC").is_some() {
                eprintln!("alloc {:#018x} +{:#x} state layer {l}", state.ptr as usize, sbytes);
            }
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
        let trunk_xfm = xfm;
        let xfm = mtp_xfm.unwrap_or(trunk_xfm);
        ld.xfm = xfm;
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
        if std::env::var_os("XF_TRACE_ALLOC").is_some() {
            eprintln!("alloc {:#018x} +{:#x} workspace", ws.ptr as usize, ws_bytes);
        }
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
        let mut e = Engine { dev: dev.clone(), model, _layers: layers, bufs: ld.bufs, states, ws, mtp, sketch: None, allocs, ctx, pos: 0, last_m: 0, capture: false };
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
        let flags = if embed { ffi::XF_FWD_EMBED } else { 0 }
            | if head { ffi::XF_FWD_HEAD } else { 0 }
            | if self.capture { ffi::XF_FWD_CAPTURE } else { 0 };
        let prof = prof.map_or(std::ptr::null_mut(), |p| p.as_mut_ptr());
        check(unsafe {
            ffi::xf_forward(self.dev.ctx.0, &*self.model, self.last_m as i32, self.pos as i32, l0 as i32, l1 as i32, flags, prof)
        })
    }

    /// Whole pass: embedding, all layers, logits. Returns the greedy token
    /// and its logit for every input position.
    pub fn forward(&mut self, ids: &[u32], prof: Option<&mut [f64; 7]>) -> Result<Vec<(u32, f32)>> {
        self.set_tokens(ids)?;
        if std::env::var_os("XF_TRACE_LAYERS").is_some() {
            // Debug aid: one layer per submission with a wait, to locate a stuck kernel.
            self.run_layers(0, 0, true, false, None)?;
            self.dev.wait()?;
            for l in 0..LAYERS {
                eprint!("L{l} ");
                self.run_layers(l, l + 1, false, false, None)?;
                self.dev.wait()?;
            }
            eprint!("head ");
            self.run_layers(LAYERS, LAYERS, false, true, None)?;
            self.dev.wait()?;
            eprintln!("done");
            return self.argmax();
        }
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
    /// position `pos0 + i`. Returns the greedy draft token of the last row.
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
        // The draft head runs on the last row only.
        let io = self.read_io()?;
        Ok(vec![(io[32] as u32, f32::from_bits(io[48] as u32))])
    }

    /// Greedy token and logit of every row of the last pass. The argmax is
    /// finished on the device (ties go to the lowest token id); this reads
    /// 64 words.
    pub fn argmax(&self) -> Result<Vec<(u32, f32)>> {
        let io = self.read_io()?;
        Ok((0..self.last_m).map(|i| (io[32 + i] as u32, f32::from_bits(io[48 + i] as u32))).collect())
    }

    fn read_io(&self) -> Result<[i32; 64]> {
        let mut io = [0i32; 64];
        self.ws.read(self.ws_off(ffi::XF_WS_IDS), &mut io)?;
        Ok(io)
    }

    /// Hash of the committed model state: every DeltaNet state matrix and
    /// convolution history, and the KV rows of all committed positions.
    /// Two runs that committed the same tokens must give the same value,
    /// whatever pass sizes and draft lengths they used.
    pub fn state_hash(&self) -> Result<u64> {
        self.dev.wait()?;
        let mut h = 0xcbf29ce484222325u64;
        let mut eat = |v: &[u32]| {
            for x in v {
                h = (h ^ *x as u64).wrapping_mul(0x100000001b3);
            }
        };
        for (l, st) in self.states.iter().take(LAYERS).enumerate() {
            if l % 4 == 3 {
                let rows = self.pos * 4 * 256;
                if std::env::var("XF_KV").as_deref() == Ok("int8") {
                    // INT8 KV: K and V tiles as bytes, then the scales [kv head][position]
                    let n = self.ctx * 4 * 256;
                    let mut kb = vec![0u8; n];
                    let mut vb = vec![0u8; n];
                    st.read(0, &mut kb)?;
                    st.read(n, &mut vb)?;
                    let mut ks = vec![0u32; self.ctx * 4];
                    let mut vs = vec![0u32; self.ctx * 4];
                    st.read(2 * n, &mut ks)?;
                    st.read(2 * n + self.ctx * 16, &mut vs)?;
                    let mut kk = vec![0u32; rows];
                    let mut vv = vec![0u32; rows];
                    for p in 0..self.pos {
                        for kh in 0..4 {
                            for d in 0..256 {
                                kk[(p * 4 + kh) * 256 + d] = kb[((((p / 64 * 4 + kh) * 8 + (p % 64) / 8) * 16 + d / 16) * 8 + p % 8) * 16 + d % 16] as u32;
                                vv[(p * 4 + kh) * 256 + d] = vb[((((p / 64 * 4 + kh) * 4 + (p % 64) / 16) * 32 + d / 8) * 8 + d % 8) * 16 + p % 16] as u32;
                            }
                        }
                    }
                    eat(&kk);
                    eat(&vv);
                    let sc: Vec<u32> = (0..self.pos * 4).flat_map(|i| [ks[(i % 4) * self.ctx + i / 4], vs[(i % 4) * self.ctx + i / 4]]).collect();
                    eat(&sc);
                    continue;
                }
                let xmx = std::env::var("XF_KV").as_deref() == Ok("xmx");
                let kvm = match std::env::var("XF_KV").as_deref() {
                    Ok("bf16") | Ok("fp16") | Ok("xmx") => 2usize,
                    _ => 4,
                };
                let mut buf = vec![0u32; rows];
                if kvm == 2 {
                    // 16-bit KV (K^T layout): hash the stored 16-bit values, position-major
                    let mut all = vec![0u16; self.ctx * 4 * 256];
                    st.read(0, &mut all)?;
                    for p in 0..self.pos {
                        for kh in 0..4 {
                            for d in 0..256 {
                                buf[(p * 4 + kh) * 256 + d] = if xmx {
                                    // K tile layout: [block][kv head][key tile of 8][dim chunk of 16][8 keys][16 dims]
                                    all[((((p / 64 * 4 + kh) * 8 + (p % 64) / 8) * 16 + d / 16) * 8 + p % 8) * 16 + d % 16] as u32
                                } else {
                                    all[((p / 64 * 4 + kh) * 256 + d) * 64 + p % 64] as u32
                                };
                            }
                        }
                    }
                    eat(&buf);
                    let vb: Vec<u32> = if xmx {
                        let mut all = vec![0u16; self.ctx * 4 * 256];
                        st.read(self.ctx * 4 * 256 * 2, &mut all)?;
                        let mut o = vec![0u32; rows];
                        for p in 0..self.pos {
                            for kh in 0..4 {
                                for d in 0..256 {
                                    // V tile layout: [block][kv head][key chunk of 16][dim tile of 8][8 dims][16 keys]
                                    o[(p * 4 + kh) * 256 + d] =
                                        all[((((p / 64 * 4 + kh) * 4 + (p % 64) / 16) * 32 + d / 8) * 8 + d % 8) * 16 + p % 16] as u32;
                                }
                            }
                        }
                        o
                    } else {
                        let mut vb = vec![0u16; rows];
                        st.read(self.ctx * 4 * 256 * 2, &mut vb)?;
                        vb.iter().map(|&x| x as u32).collect()
                    };
                    eat(&vb);
                    continue;
                }
                if std::env::var("XF_ATTN_KT").map_or(true, |v| !v.starts_with('0')) && self.ctx % 64 == 0 {
                    // transposed K: [block of 64][kv head][dim][position]; hash in position-major order
                    let mut all = vec![0u32; self.ctx * 4 * 256];
                    st.read(0, &mut all)?;
                    for p in 0..self.pos {
                        for kh in 0..4 {
                            for d in 0..256 {
                                buf[(p * 4 + kh) * 256 + d] = all[((p / 64 * 4 + kh) * 256 + d) * 64 + p % 64];
                            }
                        }
                    }
                } else {
                    st.read(0, &mut buf)?; // K
                }
                eat(&buf);
                st.read(self.ctx * 4 * 256 * 4, &mut buf)?; // V
                eat(&buf);
            } else {
                let mut buf = vec![0u32; 48 * 128 * 128 + 3 * 10240]; // S, then the conv history
                st.read(0, &mut buf)?;
                eat(&buf);
            }
        }
        eat(&[self.pos as u32]);
        Ok(h)
    }

    /// Copy the residual stream after layers 5, 19, 33, 47 and 61 of every
    /// pass (hidden_states[l + 1] in transformers numbering) for an external
    /// drafter. Off by default.
    pub fn set_capture(&mut self, on: bool) {
        self.capture = on;
    }

    /// The captured states of the last pass, `[5 taps][16 rows][5120]`; rows
    /// beyond the pass size are stale.
    pub fn read_taps(&self, out: &mut [f32]) -> Result<()> {
        if out.len() != 5 * MAX_TOKENS * HIDDEN {
            return Err(Error::Invalid("tap buffer must hold 5 x 16 x 5120 values".into()));
        }
        self.ws.read(self.ws_off(ffi::XF_WS_CAP), out)
    }

    /// Device address of the tap block (`[5][16][5120]` f32), for a consumer
    /// that shares this engine's SYCL context. Only meaningful after
    /// [`Device::wait`] or a read-back, when the pass that wrote it is done.
    pub fn taps_device_ptr(&self) -> *const f32 {
        unsafe { self.ws.ptr.cast::<u8>().add(self.ws_off(ffi::XF_WS_CAP)).cast() }
    }

    pub fn has_sketch(&self) -> bool {
        self.sketch.is_some()
    }

    /// Attach a head sketch for MTP drafting (never used for trunk logits).
    /// `table` is `[vocab][rank_full]` int8 with one scale per row and `proj`
    /// is `[rank_full][5120]`; the first `rank` principal directions are used.
    /// `groups * 64` candidates are rescored exactly: the vocabulary is cut
    /// into `groups` parts and each id-mod-64 class of a part contributes its
    /// best token. `groups` must divide 3880 (e.g. 4, 8, 20, 40).
    pub fn set_sketch(&mut self, table: &[i8], scale: &[f32], proj: &[f32], rank: usize, groups: usize) -> Result<()> {
        let full = proj.len() / HIDDEN;
        if table.len() != VOCAB * full || scale.len() != VOCAB || proj.len() != full * HIDDEN || rank > full || rank % 128 != 0 || groups == 0 || groups > 64 || 3880 % groups != 0 {
            return Err(Error::Invalid("head sketch tensors have unexpected shapes, or bad rank / chunk size".into()));
        }
        let mut codes = vec![0i8; VOCAB * rank];
        for (dst, src) in codes.chunks_exact_mut(rank).zip(table.chunks_exact(full)) {
            dst.copy_from_slice(&src[..rank]);
        }
        let tiles = xeflash_quant::pack_weights(WeightFormat::S8, VOCAB, rank, &codes)?;
        let w = self.dev.upload(&tiles)?;
        let rs = self.dev.upload(scale)?;
        let cs = self.dev.upload(&vec![1f32; rank])?;
        let b = self.dev.upload(&proj[..rank * HIDDEN])?;
        for (name, buf) in [("table (s8)", &w), ("row scale", &rs), ("col scale", &cs), ("proj", &b)] {
            self.allocs.push(Alloc { category: "head sketch", name: name.into(), bytes: buf.len_bytes() });
        }
        self.sketch = Some(Box::new(ffi::xf_sketch {
            a: ffi::xf_mat { w: w.ptr, rs: rs.ptr.cast(), cs: cs.ptr.cast(), bias: std::ptr::null(), cmax: 1.0, rows: VOCAB as i32, cols: rank as i32, fmt: WeightFormat::S8 as i32 },
            b: b.ptr.cast(),
            rank: rank as i32,
            groups: groups as i32,
        }));
        self.bufs.extend([w, rs, cs, b]);
        Ok(())
    }

    pub fn clear_sketch(&mut self) {
        self.sketch = None; // buffers stay allocated until the engine is dropped
    }

    /// The draft phase alone: rewrite the MTP cache rows of the `fill.len()`
    /// tokens committed by the last pass (`fill[i]` = token following row i)
    /// and produce `k` drafts on the device. Used on its own during prefill.
    pub fn spec_draft(&mut self, fill: &[u32], next: u32, k: usize, prof: Option<&mut [f64; 7]>) -> Result<()> {
        let mtp = self.mtp.as_ref().ok_or_else(|| Error::Invalid("this container has no usable MTP block".into()))?;
        let n = fill.len();
        if n == 0 || n > MAX_TOKENS || k == 0 || k >= MAX_TOKENS || n > self.pos {
            return Err(Error::Invalid("bad speculative draft shape".into()));
        }
        let mut io = [0i32; 32];
        for (d, t) in io.iter_mut().zip(fill) {
            *d = *t as i32;
        }
        io[16] = next as i32;
        self.ws.write(self.ws_off(ffi::XF_WS_IDS), &io)?;
        let sk = self.sketch.as_ref().map_or(std::ptr::null(), |s| &**s as *const ffi::xf_sketch);
        let prof = prof.map_or(std::ptr::null_mut(), |p| p.as_mut_ptr());
        check(unsafe {
            ffi::xf_spec_draft(self.dev.ctx.0, &*self.model, &**mtp, sk, n as i32, (self.pos - n + 1) as i32, k as i32, prof)
        })
    }

    /// One speculative cycle with a single host synchronisation: the draft
    /// phase ([`spec_draft`]) and the trunk pass over `[next, d1..dk]` are
    /// submitted together; then the drafts and the trunk's greedy tokens are
    /// read back. The caller compares them and commits the agreeing prefix.
    pub fn spec_cycle(&mut self, fill: &[u32], next: u32, k: usize) -> Result<(Vec<u32>, Vec<(u32, f32)>)> {
        if self.pos + k + 1 > self.ctx {
            return Err(Error::Invalid(format!("context capacity {} exceeded", self.ctx)));
        }
        self.spec_draft(fill, next, k, None)?;
        self.last_m = k + 1;
        let flags = ffi::XF_FWD_EMBED | ffi::XF_FWD_HEAD | ffi::XF_FWD_IDS_SLOT1;
        check(unsafe {
            ffi::xf_forward(self.dev.ctx.0, &*self.model, (k + 1) as i32, self.pos as i32, 0, LAYERS as i32, flags, std::ptr::null_mut())
        })?;
        let io = self.read_io()?;
        let drafts = (0..=k).map(|j| io[16 + j] as u32).collect();
        let greedy = (0..=k).map(|i| (io[32 + i] as u32, f32::from_bits(io[48 + i] as u32))).collect();
        Ok((drafts, greedy))
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
