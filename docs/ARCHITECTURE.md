# XeFlash architecture

XeFlash is an inference engine for Qwen3.8-27B on a single Intel Arc Pro B60
(Xe2 / Battlemage, 24 GB). The host is Rust; GPU kernels are C++20 SYCL/ESIMD.

The design starts from one hardware fact and works outwards.

## 1. The fact: DPAS takes 4-bit and 2-bit operands directly

The Xe2 systolic array instruction (`dpas`, exposed as
`sycl::ext::intel::esimd::xmx::dpas`) accepts `s4/u4` and `s2/u2` operand
precisions in addition to `s8/u8` and `bf16`. `kernels/probe/dpas_probe.cpp`
runs every combination on the B60 and `kernels/probe/dpas_map.cpp` maps the
bit layout with one-hot operands. Result for the weight ("B") operand:

| precision | 16 rows x 32 columns occupy | layout of one 32-bit word (register `r`, lane `n`) |
|---|---|---|
| s8 | 512 B = 8 GRF | columns `4r..4r+3` of row `n`, one byte each |
| s4 | 256 B = 4 GRF | columns `8r..8r+7` of row `n`, one nibble each |
| s2 | 128 B = 2 GRF | columns `16r..16r+15` of row `n`, two bits each |

No bits are wasted and nothing has to be expanded: a block load of packed
4-bit weights *is* a DPAS operand. One `dpas` is 512 multiply-accumulates
(16 rows x 32 columns) per token, and the repeat count processes up to 8
tokens against the same weight registers.

There is no 3-bit operand precision. A 3-bit format would need an unpack to
s4 in registers.

## 2. Weight format: XMX tile order

A matrix `W[rows][cols]` is stored as `[row block of 16][tile of 32 columns]`,
each tile exactly in the layout above. This is fixed at conversion time
(`xeflash-quant::tile`), so at run time a GPU thread does, per tile:

```
block load W tile (256 B, s4)  ->  dpas(acc, W, x chunk)  ->  next tile
```

No gather, no table, no shared local memory, no reordering. One thread owns
16 output rows and streams one contiguous run of memory.

Quantisation is chosen so that everything except the 4-bit codes is free at
run time (see QUANTIZATION.md):

```
W[i][j] ~= r[i] * (q[i][j] + 0.5) * c[j]
```

`r` is applied when the int32 accumulator is converted to float, `c` is folded
into the activation vector before it is quantised, and the `+0.5` is one
scalar per token.

## 3. Activations

DPAS needs integer activations. They are stored as `[tile][token][32 bytes]`
so that the "A" operands of all tokens of a tile are contiguous. 16-bit
activations are two byte planes (`x = 256*hi + lo`, `s8` and `u8`), i.e. a
second `dpas` on weight registers that are already loaded. Decode is bound by
weight bandwidth, so this costs under 1 % (measured) and removes activation
quantisation as a quality concern.

## 4. Kernel variants

Decode and prefill are different problems and use different instantiations of
one template (`kernels/gemm/gemm.cpp`):

| use | tokens/thread | DPAS repeat | bound by |
|---|---|---|---|
| decode | 1 | 1, 4 tiles per loop trip with independent accumulators | memory bandwidth |
| verify (speculative) | 8 or 16 | 8 | memory bandwidth |
| prefill | 32 | 8, 4 groups | XMX throughput, weights reused from cache |

Matrices with few rows (e.g. `down_proj`, 5120 x 17408 = 320 row blocks) can
be split into column segments so that enough threads are resident to fill the
memory bus; partial sums are combined by a small second kernel.

## 5. Host / kernel boundary

```
Rust (xeflash-runtime)  --C ABI (kernels/include/xfk.h)-->  libxfk.so (SYCL/ESIMD)
```

* `Device` owns the in-order queue; `DeviceBuf` is a RAII device allocation.
* Kernel entry points only submit; `Device::wait()` synchronises and is where
  asynchronous errors (including `DEVICE_LOST`) surface as typed errors.
* `xf_alloc` refuses requests above the free VRAM the driver reports: the xe
  driver does not fail an overcommit, it migrates buffers to system memory.
* Only an Intel Level Zero GPU is ever selected.
* Every GPU run goes through `scripts/b60run`, which takes `/tmp/b60.lock`.

The host does not call kernels one by one. Rust builds an `xf_model` once (a
table of device pointers: matrices, small tensors, state blocks, one
workspace) and a pass is a single FFI call, `xf_forward`, which submits every
kernel of the pass (several hundred) to the queue. The host synchronises once
per pass, when it reads the argmax partials back.

## 6. The model (`kernels/model/model.cpp`, `xeflash-runtime::engine`)

Structure, taken from `config.json` and the transformers reference
(`modeling_qwen3_5.py`), not from the model name: 64 layers, hidden 5120;
layer `l` is gated full attention when `l % 4 == 3` (16 layers) and Gated
DeltaNet otherwise (48 layers); every layer ends with a SiLU-gated MLP
(17408). Norms are zero-centred RMSNorms (`x^ * (1 + w)`).

Everything is resident: all matrices, the bf16 embedding table, the head,
DeltaNet states, the KV cache and the workspace are allocated at load and
nothing is allocated afterwards. `xf-run mem` prints every allocation
category and the driver's own before/after figure.

### Pass and commit

A pass processes up to 16 consecutive tokens starting at the committed
position. It never changes committed state:

* DeltaNet: the pass reads the committed state `S`, walks its tokens with the
  state in registers, and records per token the normalised key, the delta and
  the decay. `xf_commit(n)` replays the first `n` rank-1 updates into `S` and
  shifts the convolution history.
* Attention: K/V rows are written at their absolute positions, beyond the
  committed length; committing just moves the length.

So decoding is `forward([t])`, `commit(1)`; speculative verification is a
longer pass followed by a commit of the accepted prefix, and rejection needs
no rollback at all. Snapshot/restore of a conversation is a copy of the state
blocks.

### Kernels of one layer

| step | kernel | threads | notes |
|---|---|---|---|
| residual add + RMSNorm | `k_addnorm` | 40 per token, one work-group | sum of squares through SLM, one barrier |
| activation quantisation | `k_quant` | <= 64 per token, one work-group | 16-bit, two byte planes in tile order; offset sum through SLM |
| GEMM | `xf_gemm` (section 4) | 16 rows each | exact int32 |
| DeltaNet gates | `k_gemv_f32`, `k_gdn_gate` | per row / per token | `in_proj_a/b` stay FP32 |
| causal conv + SiLU | `k_conv` | 64 channels each | 3-row history |
| q/k normalisation | `k_gdn_qk` | per key head | |
| delta rule | `k_gdn_core` | one per (value head, value column) = 6144 | 128 state values in 8 registers across the tokens of the pass |
| gated output norm | `k_gdn_post` | per value head | |
| attention q / kv | `k_attn_q`, `k_attn_kv` | per head | head RMSNorm, RoPE from a table |
| attention scores | `k_attn_part` | per (token, head, 64 keys) | running-max softmax per block |
| attention combine | `k_attn_comb` | per (token, head) | merges blocks, sigmoid gate |
| MLP activation | `k_mlp_act` | 64 columns each | |

This is the correctness-first set: FP32 everywhere outside the GEMMs, one
kernel per step. Attention is deliberately unfused and FP32 over an FP32 KV
cache; it is the baseline that later variants must beat.

Matrices that consume the same vector (`qkv`+`z`, `q`+`k`+`v`, `gate`+`up`)
can be stacked row-wise by the converter (`--merge`), which turns two or three
quantisation + GEMM launches into one.

### Numerical contract

* GEMMs are exact integer arithmetic on 16-bit activations, so a row's result
  does not depend on how many tokens share the pass.
* Every float kernel works per token.
* Consequence, verified: passes of 1, 8 and 16 tokens produce bit-identical
  logits and states.

## 7. Status

Implemented and verified on the B60: the full forward pass, greedy decoding,
prefill in 16-token passes, the official MTP block and MTP speculative
decoding, calibrated conversion. Not implemented: sampling other than greedy,
a Rust tokenizer (token ids come from the official Python tokenizer), the
OpenAI-compatible API, long-context attention kernels (DPAS, compressed KV).
See PERFORMANCE.md for numbers and EXPERIMENTS.md for the record.
