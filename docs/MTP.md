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

See PERFORMANCE.md (acceptance by draft position, draft length sweep, cost).
