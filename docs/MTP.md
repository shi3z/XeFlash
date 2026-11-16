# The official MTP block

The checkpoint (`Qwen/Qwen3.8-27B`, revision `1d4bf0f2`) ships a multi-token
prediction module that Hugging Face transformers drops at load time
(`_keys_to_ignore_on_load_unexpected = [r"^mtp.*"]`). XeFlash uses it as the
drafter for speculative decoding.

## Tensors (all bf16)

| tensor | shape |
|---|---|
| `mtp.fc.weight` | 5120 x 10240 |
| `mtp.pre_fc_norm_embedding.weight`, `mtp.pre_fc_norm_hidden.weight`, `mtp.norm.weight` | 5120 |
| `mtp.layers.0.input_layernorm.weight`, `post_attention_layernorm.weight` | 5120 |
| `mtp.layers.0.self_attn.q_proj / k_proj / v_proj / o_proj` | 12288x5120 / 1024x5120 / 1024x5120 / 5120x6144 |
| `mtp.layers.0.self_attn.q_norm / k_norm` | 256 |
| `mtp.layers.0.mlp.gate_proj / up_proj / down_proj` | 17408x5120 (x2) / 5120x17408 |

About 0.425 G parameters. There is no MTP embedding and no MTP output matrix:
`config.json` has `mtp_num_hidden_layers: 1`, `mtp_use_dedicated_embeddings:
false`, and both are shared with the trunk.

## Graph

No implementation exists in transformers. The graph below is the one in
vLLM's `qwen3_5_mtp.py` (contributed by the Qwen team) and in llama.cpp's
`graph_mtp` (`src/models/qwen35.cpp`); the two agree. Both target
Qwen3.5 / 3.6; the Qwen3.8 tensor names and shapes match them exactly.

```
h_P      trunk output at position P AFTER the trunk's final norm
x_{P+1}  the token sampled from position P

e   = RMSNorm_e(embed_tokens[x_{P+1}])            zero-centred: x^ * (1 + w)
g   = RMSNorm_h(h_P)
z   = fc( cat[e, g] )                             embedding half first, no bias
z   = full-attention decoder layer(z)             q/k norm, RoPE, sigmoid output gate, SiLU MLP;
                                                  own KV cache over the whole sequence
y   = RMSNorm_mtp(z)
logits = lm_head(y)                               shared head -> draft of x_{P+2}
```

Recursion for more draft tokens: feed `y` (after `mtp.norm`) as the hidden
state of the next step together with the embedding of the token just drafted,
one position further on. The same single layer is used at every step.

Details where the two references differ:

* Position of the pair `(h_P, x_{P+1})`: vLLM uses P, llama.cpp P+1. RoPE is
  relative, so this is a constant offset. XeFlash uses P+1.
* First token: vLLM has no MTP entry for `x_0`; llama.cpp adds one with a zero
  hidden state. XeFlash follows llama.cpp.
* An unmerged mlx-lm pull request feeds the hidden state *before* the final
  norm. `tools/validation/ref_mtp.py --pre-norm` exists to test that reading.

## What it costs to store

`mtp.fc` cannot be quantised with a uniform grid (5.4 dB at 4 bits, 6.5 dB at
8 bits; every other matrix is above 17 dB). It is kept as is and run in FP32.
The attention and MLP matrices are ordinary and are stored like the trunk's.

## Implementation

* `xf_mtp_step` (`kernels/model/model.cpp`): one MTP pass over up to 16 rows.
  Row `i` pairs a hidden state left in the workspace by the previous pass with
  a token id; it reuses the trunk's attention layer code with the MTP's own KV
  cache, then `mtp.norm`, the shared `lm_head` and the argmax kernel.
* `Engine::mtp_pass` (`crates/xeflash-runtime/src/engine.rs`).
* Decode loop (`xf-run gen --mtp K`), with committed position `P` and `next`
  the trunk's own greedy token for position `P`:
  1. Drafts `d_1..d_K`: `d_1` comes from the MTP row that paired `h_{P-1}` with
     `next`; each further draft is one single-row MTP pass.
  2. One trunk pass over `[next, d_1, .., d_K]`. Trunk output `i` is the true
     greedy successor of input `i`; the agreeing prefix (at least `next`) is
     committed. Recurrent state and KV rows of rejected rows are never
     committed, so there is nothing to roll back.
  3. One MTP pass over the committed rows with the trunk's real hidden states.
     It rewrites the MTP cache entries the drafts had filled speculatively and
     its last row is `d_1` of the next cycle.

Because trunk passes of 1, 8 and 16 tokens are bit-identical (integer GEMMs,
per-token float kernels), the tokens produced with any `K` are the tokens of
plain greedy decoding. This is checked, not assumed: see EXPERIMENTS.md.

## Results

**Is the graph right?** Teacher-forced on a held-out 160-token chat with the
original weights on the CPU (`tools/validation/ref_mtp.py`), fraction of
positions where the MTP block predicts the token after next:

| reading of the graph | accuracy |
|---|---|
| embedding first, hidden after the final norm (vLLM, llama.cpp) | 64.6 % |
| embedding first, hidden before the final norm (mlx-lm PR) | 62.7 % |
| hidden first | 0.0 % |

The engine (s4 trunk and MTP layer, FP32 `fc`) scores 63.3 % on the same text
and makes the same prediction as the CPU reference at 141 of 160 positions.

**Speculative decoding** (four benchmark prompts, 512 tokens each, greedy;
PERFORMANCE.md A4 has the full tables):

| draft length K | mean tok/s | tokens per trunk pass | MTP ms per cycle |
|---|---|---|---|
| 0 | 22.4 | 1.00 | 0 |
| 1 | 34.8 | 1.73 to 1.95 | 4.9 |
| 2 | 45.2 | 2.12 to 2.83 | 7.8 |
| 4 | 56.1 | 2.40 to 4.22 | 13.5 |
| 6 | 57.7 | 2.41 to 4.99 | 18.9 |
| 8 | 53.8 | 2.42 to 5.45 | 24.3 |
| 12 | 49.8 | 2.42 to 5.89 | 34.8 |

* First-draft acceptance is 71 to 97 % on the model's own output; it decays
  with depth, quickly on prose (story: 71, 57, 44, 47, 22, 25 %) and slowly on
  code and proofs (about 80 % at depth 6).
* Output is identical to non-speculative greedy decoding for every K and
  every prompt (checked token by token in each run).
* Each extra draft costs about 2.7 ms, most of it the shared lm_head. That
  cost, not acceptance, is what makes K above 6 a loss.
* No commit or rollback time is visible: rejected rows are simply not
  committed.

Not measured: MTP in BF16 or s8, calibrated MTP weights, a confidence-based
stop, combination with other draft sources.

## Update: sketch head and device-side chain

The drafter's lm_head is no longer the full matrix. Per draft step:

```
z      = proj (512 x 5120, FP32) . y              y = mtp.norm output
score  = table (248320 x 512, s8, per-row scale) . z      ordinary GEMM, 16-bit activations
cand   = in each of 40 parts of the vocabulary, the best token of every id-mod-64 class (2560)
token  = argmax over the candidates' 16-row blocks of the real lm_head (exact integer logits)
```

The token id is written on the device into the next step's input slot and
into the verify pass's id list; the host submits the whole chain and the
trunk pass together and reads back once per cycle (`xf_spec_draft`,
`Engine::spec_cycle`). The trunk's own logits always use the full head.

Measured (PERFORMANCE.md Part C): draft step 2.52 -> 1.67 ms; mean of the four
benchmark prompts 57.7 -> 61.8 tok/s at K = 6; outputs and committed state
identical to non-speculative decoding. The two fine-tuned weight sets from
`/data/xeflash-drafter` load through the normal converter and show no
measurable difference from the official weights on these prompts.

The MTP KV cache keeps every committed row (the handover's warning against
"newest N only" does not arise). It is FP32, 8 KiB per token.
