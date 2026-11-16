# Performance

Part A is the whole model on the B60 (Milestone 3). Part B is the earlier
GEMM-only study it was built on.

# Part A. Full model

Setup for every number in this part: Arc Pro B60 24 GB, driver
1.18.40196+15, oneAPI DPC++ 2026.2; model `Qwen/Qwen3.8-27B` revision
`1d4bf0f2`, container `qwen38-27b-s4-cal.xfm` (s4, calibrated, bias-corrected,
merged matrices, one matrix at s8); context capacity 8192; one job on the card
under `/tmp/b60.lock`; code at commit `d3796fc`. Raw outputs: `benchmarks/results/m3/`.

## A1. VRAM, measured

`xf-run mem` allocates everything and lists it; the last line is the driver's
own free-memory figure before and after.

| category | allocations | GiB |
|---|---|---|
| body matrices (merged) | 256 | 11.343 |
| lm_head | 1 | 0.592 |
| embedding table (bf16) | 1 | 2.368 |
| MTP block (4 matrices + `fc` in FP32) | 5 | 0.369 |
| matrix scales and biases | 779 | 0.039 |
| small tensors (norms, conv taps, gate projections) | 408 | 0.098 |
| KV cache, 16 layers, FP32, 8192 tokens | 16 | 1.000 |
| MTP KV cache | 1 | 0.063 |
| DeltaNet state and per-pass records | 48 | 0.217 |
| RoPE table | 2 | 0.002 |
| workspace | 1 | 0.076 |
| **total requested** | 1518 | **16.166** |
| driver: free before / after | | 22.484 / 6.284 (difference 16.200) |

The earlier "7.9 GiB" was never a measurement of residency. It was free VRAM
minus the container's file size, i.e. the expected headroom. Nothing is left
on the CPU: every matrix the engine uses is on the card. The file is 14.66 GiB;
residency is larger because of the cache, state and FP32 copies of `mtp.fc`
and the small tensors.

Context scaling: the FP32 KV cache costs 128 KiB per token (8 KiB per
attention layer), plus 8 KiB per token for the MTP cache.

| context | KV + MTP cache | total resident | fits in 22.3 GiB usable |
|---|---|---|---|
| 8 K | 1.06 GiB | 16.2 GiB | yes |
| 32 K | 4.25 GiB | 19.4 GiB | yes |
| 60 K | 7.97 GiB | 23.1 GiB | no |

The 32 K and 60 K rows are computed, not run. Long contexts need a 16-bit or
compressed KV cache; that is not implemented.

## A2. Correctness

Reference: the official transformers layer classes (`Qwen3_5DecoderLayer`),
one layer at a time on the CPU in FP32 (`tools/validation/ref_forward.py`).
Two weight sets: the original BF16 weights, and the engine's own quantised
weights reconstructed in floating point. The second isolates implementation
errors from quantisation.

**GPU against the same weights on the CPU** (30-token prompt, data-free
container, `cmp_gpu_vs_int4ref_explain.txt`):

| stage | max abs | RMS error | relative error | cosine |
|---|---|---|---|---|
| embedding | 0 | 0 | 0 | 1.000000 |
| layer 0 | 2.4e-3 | 6.8e-5 | 2.7e-4 | 1.000000 |
| layer 15 | 2.2e-2 | 3.5e-4 | 3.9e-4 | 1.000000 |
| layer 31 | 1.6e-2 | 7.6e-4 | 7.3e-4 | 1.000000 |
| layer 47 | 2.8e-2 | 2.0e-3 | 1.5e-3 | 0.999999 |
| layer 63 | 7.9e-1 | 2.5e-2 | 4.9e-3 | 0.999988 |
| logits | 2.4e-1 | 1.2e-2 | | KL 9.0e-5, top-1 30/30 |

Greedy tokens identical. The error grows smoothly with depth and has no jump
at any layer, so there is no layer-level bug; what remains is FP32 rounding,
the engine's `exp` and 16-bit activations.

**Pass size.** Passes of 1, 8 and 16 tokens over the same sequence give
bit-identical final hidden states and logits (`cmp`, not a tolerance).

**Against the original BF16 weights** (held-out 160-token chat, position 0
excluded, `quality_chat0.txt`):

| weights | KL mean | KL median | KL p90 | top-1 agreement | next-token accuracy |
|---|---|---|---|---|---|
| original (reference) | 0 | 0 | 0 | 100 % | 66.5 % |
| s4 data-free | 0.280 | 0.085 | 0.410 | 83.7 % | 65.8 % |
| s4 calibrated + bias correction | 0.069 | 0.023 | 0.124 | 88.7 % | 69.0 % |

This is the difference caused by the weight format, not by the arithmetic.
It is one short text. YASAKANI's published figures (Speed: KL 0.030, 93.0 %
top-1; Quality: 0.012, 95.2 %) were measured on other text by its authors, so
the two are not a like-for-like comparison yet; on the face of it XeFlash s4
is still behind Speed in fidelity. No task-level evaluation (maths, code,
reasoning, Japanese, long context) has been run.

## A3. Decode without speculation

512 new tokens after each of the four `yasakani bench` prompts (24 to 30
prompt tokens, chat template, thinking off, greedy, no EOS stop).

| | tok/s | ms per token |
|---|---|---|
| XeFlash, all four prompts | 22.44 to 22.45 | 44.5 |
| YASAKANI on the B60, look-ahead off (its notes) | 18.1 to 18.6 | 55.8 |

History of the XeFlash figure: first working version 19.7 tok/s (50.8 ms);
fused norm and quantisation kernels 20.3 (49.3); merged matrices 22.4 (44.5).

Profile of one pass (`profile_passes.txt`). The profiled run waits after every
stage, which inflates it; the unprofiled time is the real one.

| tokens in pass | unprofiled | GEMM | quant | GDN | norm | attention | MLP act | profiled total |
|---|---|---|---|---|---|---|---|---|
| 1 | 42.4 ms | 37.3 | 3.2 | 4.4 | 1.6 | 1.4 | 1.0 | 48.9 |
| 8 | 50.3 ms | 43.3 | 3.6 | 5.3 | 1.6 | 1.5 | 1.5 | 56.8 |
| 16 | 58.6 ms | 47.6 | 3.7 | 8.1 | 1.7 | 1.6 | 2.2 | 64.9 |

(GEMM includes the lm_head. Profiled on fixed dummy tokens at position 0.)

Did the GEMM estimate of Part B hold? It predicted about 31 / 35 / 38 ms for
1 / 8 / 16 tokens from isolated kernels, without the head. In the engine the
profiled GEMM time is 37.3 / 43.3 / 47.6 ms including the head (about 1.6 ms)
and the profiling waits. Scaling by unprofiled / profiled time and removing
the head gives roughly 31 / 37 / 41 ms: the 1-token estimate held, the 8- and
16-token passes are 5 to 10 % above it. YASAKANI reports 43 ms of GEMM in an
8-row pass, but that is its own profile of a different pass, so the fair
statement is at the level of whole passes: 50.3 ms for an 8-token XeFlash
pass against 55.0 ms for an 8-row YASAKANI pass. That is a modest difference,
not a decisive one.

Prefill through 16-token passes runs at 186 to 249 tok/s on these short
prompts. No prefill-specific path exists yet, and 8K / 30K / 60K prefill and
decode have not been measured.

## A4. MTP speculative decoding

Official MTP block as drafter, `K` draft tokens per trunk pass, 512 tokens per
prompt (`decode_mtp_sweep.txt`, `decode_mtp_*.json`). Every run produced
exactly the tokens of the K = 0 run.

Tokens per second:

| K | explain | code | story | proof | mean |
|---|---|---|---|---|---|
| 0 | 22.4 | 22.4 | 22.5 | 22.5 | 22.4 |
| 1 | 34.8 | 35.9 | 32.4 | 36.2 | 34.8 |
| 2 | 45.5 | 48.4 | 37.4 | 49.6 | 45.2 |
| 3 | 51.6 | 57.7 | 38.8 | 59.0 | 51.8 |
| 4 | 54.9 | 65.1 | 38.1 | 66.2 | 56.1 |
| 6 | 56.1 | 68.7 | 35.0 | 71.2 | **57.7** |
| 8 | 50.8 | 66.0 | 30.6 | 67.8 | 53.8 |
| 12 | 46.7 | 62.4 | 26.6 | 63.5 | 49.8 |
| YASAKANI on the B60 (its notes) | 66.5 | 118.1 | 41.8 | 118.7 | 86.3 |
| YASAKANI on the RTX 5060 Ti (its notes) | 121.7 | 197.1 | 71.2 | 189.8 | 144.9 |

Tokens committed per trunk pass, and time per cycle:

| K | explain | code | story | proof | trunk ms | MTP ms |
|---|---|---|---|---|---|---|
| 1 | 1.87 | 1.93 | 1.73 | 1.95 | 48.8 | 4.9 |
| 2 | 2.59 | 2.76 | 2.12 | 2.83 | 49.1 | 7.8 |
| 4 | 3.48 | 4.15 | 2.40 | 4.22 | 49.9 | 13.5 |
| 6 | 3.90 | 4.80 | 2.41 | 4.99 | 50.7 | 18.9 |
| 8 | 4.06 | 5.30 | 2.42 | 5.45 | 55.7 | 24.3 |
| 12 | 4.29 | 5.78 | 2.42 | 5.89 | 57.2 | 34.8 |

Acceptance of draft position `i` given that all earlier drafts were accepted
(K = 6): explain 89 / 76 / 73 / 74 / 73 / 67 %, code 89 / 92 / 85 / 86 / 77 /
78 %, story 71 / 57 / 44 / 47 / 22 / 25 %, proof 94 / 89 / 85 / 85 / 82 /
82 %.

Reading:

* The official MTP block is a usable drafter as shipped: first-draft
  acceptance of 71 to 97 % on the model's own output. Teacher-forced on a
  human-written chat it predicts 63.3 % (GPU, s4) / 64.6 % (CPU, BF16) of the
  next-next tokens; the GPU and CPU predictions agree at 141 of 160 positions.
* Best fixed draft length is 6: 57.7 tok/s, 2.6 times the non-speculative
  rate. Choosing K per prompt would give 58.7.
* **This does not reach YASAKANI on the B60 (86.3 tok/s): XeFlash is at 67 %
  of it**, and at 40 % of the RTX 5060 Ti figure. Milestone 4 is not met.
* Why: each draft costs about 2.7 ms (the shared lm_head alone is 1.27 G
  weights, about 1.6 ms, per draft), so six drafts cost 19 ms on top of a
  51 ms trunk pass, for 2.4 to 5.0 tokens. YASAKANI's cycle is 55 ms + 2.2 ms
  + 6.9 ms for 5.26 tokens. The deficit is in the drafter's cost and in
  acceptance on prose, not in the trunk pass.
* VRAM added by MTP: 0.43 GiB (0.369 weights including FP32 `fc`, 0.063 KV cache).

MTP at other precisions (BF16, s8) was not measured; only s4 for the layer
with `fc` in FP32. The `fc` matrix cannot be stored at 4 or 8 bits at all
(MTP.md).

## A5. What to do next, from these measurements

1. Drafter cost. A draft step should not run the full lm_head: a shortlist or
   a low-bit head would roughly halve the 2.7 ms. Draft tokens
   could also stay on the device instead of one read-back per step.
2. Stop drafting early. Acceptance falls with depth and differs by text;
   a confidence threshold on the MTP logit margin should replace a fixed K.
3. Trunk pass: 10 ms of a 42 ms pass is not GEMM. The DeltaNet gate
   projections (FP32, serial rows) and the remaining small kernels are the
   targets; the GEMM itself is at the memory bus.
4. Quality: activation-aware rounding with full covariance (GPTQ-like) on the
   same format, then the task suites, before any lower-bit experiment.
5. s3 was not tried in the model; Part B says it only helps at one token per
   pass with the current kernel.

# Part B. GEMM study (before the model existed)

Everything in sections 1 to 5 is measured on the Arc Pro B60. Section 6 is a
projection and is labelled as such. There is no end-to-end tokens-per-second
number yet: the model is not implemented beyond its GEMMs.

Setup: Arc Pro B60 24 GB, driver 1.18.40196+15, oneAPI DPC++ 2026.2, 128-GRF
mode, in-order queue, one job on the card (`/tmp/b60.lock`), idle host.
Raw data: `benchmarks/results/gemm_v2.{txt,json}`.

## 1. What is timed

`xf-bench` times one GEMM of a real matrix shape, launches queued back to
back, after checking the result against a CPU reference. The time covers the
whole kernel: weight read, operand supply (any unpacking), DPAS, int-to-float
conversion with row/token scales and offset, output write. Weights are
uniformly random codes; the card reads compressible data several times faster,
so zero-filled buffers would flatter every number.

* `Gw/s`: weights processed per second (rows x cols / time).
* `GB/s`: weight bytes read per second. The YASAKANI hardware study measured
  about 435 GB/s for incompressible data on this card; the s2 kernel exceeds
  that on one shape (616 GB/s), so it is a reference point, not a hard ceiling.
* `TOPS`: 2 x rows x cols x tokens / time (doubled with 16-bit activations).

All integer results are bit-exact against the CPU for every variant.

## 2. Decode: one token

| format | bits | gate/up 17408x5120 | down 5120x17408 | qkv 10240x5120 |
|---|---|---|---|---|
| bf16 | 16 | 0.4218 ms, 211 Gw/s | 0.4210 ms (4 seg) | 0.2498 ms |
| s8 | 8 | 0.2170 ms, 411 Gw/s | 0.2172 ms | 0.1324 ms |
| s4 expanded to s8 | 4 | 0.1260 ms, 708 Gw/s | 0.1201 ms (4 seg) | 0.0838 ms |
| **s4 native** | 4 | **0.1132 ms, 787 Gw/s** | 0.1155 ms, 772 Gw/s | 0.0606 ms, 865 Gw/s |
| s4 native, 16-bit act. | 4 | 0.1148 ms, 777 Gw/s | 0.1157 ms | 0.0608 ms |
| s3 (spread to u4) | 3 | 0.0978 ms, 912 Gw/s | 0.0965 ms (4 seg), 924 Gw/s | 0.0482 ms, 1087 Gw/s |
| s3, 16-bit act. | 3 | 0.0995 ms, 896 Gw/s | 0.0977 ms (4 seg) | 0.0506 ms |
| **s2 native** | 2 | **0.0457 ms, 1952 Gw/s** | 0.0527 ms (4 seg), 1692 Gw/s | 0.0213 ms, 2462 Gw/s |

(bf16, s8 and s4-expanded rows are from `gemm_v1`; they did not change.)

Bus use at one token: s4 386 to 432 GB/s, s3 342 to 408 GB/s, s2 423 to
616 GB/s. s4 and s2 run at the memory bus; s3 gives up to about 20 % of it to
the in-register spread.

## 3. Small batches (speculative verification)

Time per GEMM in ms, best segment setting, 16-bit activations unless noted.

| format | matrix | 1 token | 8 tokens | 16 tokens |
|---|---|---|---|---|
| s4 | gate/up | 0.1148 | 0.1198 | 0.1265 |
| s4 | down | 0.1157 | 0.1397 (4 seg) | 0.1610 (4 seg) |
| s4 | qkv | 0.0608 | 0.0751 | 0.0839 |
| s3 | gate/up | 0.0995 | 0.1332 | 0.1414 |
| s3 | down | 0.0977 (4 seg) | 0.1268 (4 seg) | 0.1569 (4 seg) |
| s3 | qkv | 0.0506 | 0.0722 | 0.0975 |
| s3, 8-bit act. | gate/up | 0.0978 | 0.1034 | 0.1198 |
| s2, 8-bit act. | gate/up | 0.0457 | 0.0529 | 0.0715 |

* s4: 8 tokens cost 4 to 24 % more than 1, 16 tokens 10 to 39 % more.
* s3 loses its advantage over s4 at 8 and 16 tokens with 16-bit activations.
  The s3 kernel spends ALU time on the spread and then runs two 8-token DPAS
  per tile; it is no longer bandwidth bound. This kernel is untuned.
* 16-bit activations for s2 were not benchmarked.

## 4. Large batches (prefill)

| format | matrix | 64 tokens | 256 tokens | TOPS at 256 |
|---|---|---|---|---|
| bf16 | gate/up | 0.804 ms | 3.200 ms | 14.3 |
| s8 | gate/up | 0.430 ms | 1.564 ms | 29.2 |
| s4 | gate/up | 0.243 ms | 0.902 ms | 50.6 |
| s4 | down | 0.234 ms | 0.585 ms | 78.1 |
| s4 | qkv | 0.095 ms | 0.412 ms | 65.1 |
| s3 | gate/up | 0.278 ms | 1.050 ms | 43.5 |
| s2 | gate/up | 0.165 ms | 0.609 ms | 74.9 |
| s2 | qkv | 0.066 ms | 0.357 ms | 75.2 (101.8 at 64) |

The prefill instantiation (32 tokens per thread, weights re-read from cache by
each token group) reaches 44 to 102 TOPS against a 196 TOPS peak. It exists to
show the format works for batches; it has not been optimised. Narrower
operands help here as well (fewer registers per tile, more tiles in cache).

## 5. ISA, registers, memory

`benchmarks/results/isa_s4_v1.md`, from IGC dumps:

| kernel | static inst. | GRF | DPAS in loop | loads per tile | gather | SLM | spill | barrier |
|---|---|---|---|---|---|---|---|---|
| s4 decode (R1 U4) | 344 | 128 | `dpas.8x1 s4 x b` | 1 x 256 B + 1 x 32 B | none | none | 0 | 0 |
| s4 + 16-bit act. | 418 | 128 | + `dpas.8x1 s4 x ub` | + 1 x 32 B | none | none | 0 | 0 |
| s4 verify (R8 U2) | 495 | 128 | `dpas.8x8 s4 x b` | 1 x 256 B + 1 x 256 B | none | none | 0 | 0 |
| s4 prefill (R8 G4) | 1299 | 128 | 4 x `dpas.8x8` | 1 x 256 B + 4 x 256 B | none | none | 0 | 0 |
| s3 decode (first version) | 597 | 128 | `dpas.8x1 u4 x b` | 128 B + 64 B + 32 B | none | none | 0 | 0 |

No kernel uses shared local memory, a gather or a barrier, and none spills.
Thread counts: 1088 for 17408 rows, 640 for 10240 rows, 320 x segments for
5120 rows.

VRAM: the benchmark holds one matrix at a time (44.6 MB for 17408 x 5120 at
s4). The converted model is 14.56 GiB on disk: 409 s4 matrices (26.02 G
weights, 13.0 GB), the bf16 embedding table (2.54 GB) and small tensors. On
an idle card 22.48 GiB are free, so the model fits fully resident with about
7.9 GiB left for state, KV cache and buffers. (That file still holds `mtp.fc`
at s4, where it reconstructs at 5.4 dB; the converter now keeps such matrices
in bf16. All 408 other matrices are between 17.8 and 19.3 dB.)

Launch overhead: 2.3 us per queued kernel, 7.7 us with a wait.

## 6. Is the INT4 format better than YASAKANI's trellis format?

### Measured, kernel against kernel

YASAKANI figures are from its own notes (`xe/PORT_NOTES.md`,
`arch/REPORT.md`), measured on this card; they were not re-run here.

| | YASAKANI trellis, 3 bpw | XeFlash s4 | XeFlash s3 | XeFlash s2 |
|---|---|---|---|---|
| gate + up pair, 1 token | 0.291 ms | 0.226 ms | 0.196 ms | 0.091 ms |
| kernel rate | 736 to 808 Gw/s | 772 to 865 | 912 to 1087 | 1692 to 2462 |
| rate inside the engine | 530 to 630 Gw/s | not built | not built | not built |
| share of the bus | 53 to 63 % | 89 to 99 % | 79 to 94 % | 97 % and above |
| what limits it | 3.0 to 3.5e11 table lookups/s | memory bus | bus + ALU | memory bus |
| SLM | 16 KiB table per work-group | none | none | none |
| weight error, layer 3 | 0.175 to 0.191 | 0.108 to 0.117 | about 0.20 | about 0.35 |

So, for the first question this project had to answer:

* **Yes, a regular low-bit format feeds XMX without a gather, and at the same
  or higher speed.** Native s4 moves 33 % more bytes per weight than the
  trellis code and is still 0 to 29 % faster per weight in the kernel, because
  the trellis kernel is held to 53 to 63 % of the bus by its lookups.
* At that speed s4 carries about 4 dB less weight error than YASAKANI Speed
  (QUANTIZATION.md), which is headroom for quality or for fewer bits.
* The margin is modest, not a multiple. Both kernels are near the memory bus
  for their byte counts. From here, decode GEMM time is set by bytes per
  weight, not by kernel engineering.

### Projected, not measured: a full pass

Summing measured kernel times over the 400 body matrices (25.6 G weights;
`in_proj_z`, `out_proj` and the attention projections, 18 % of the weights,
are scaled from the measured shapes by weight count):

| configuration | body GEMM per pass |
|---|---|
| YASAKANI on B60, measured in its engine, 8 rows | 43 ms (its stated floor: about 40) |
| XeFlash s4, 16-bit act., 1 token | about 31 ms |
| XeFlash s4, 16-bit act., 8 tokens | about 35 ms |
| XeFlash s4, 16-bit act., 16 tokens | about 38 ms |
| XeFlash s3, 16-bit act., 1 token | about 26 ms |
| XeFlash s3, 8-bit act., 8 tokens | about 28 ms |
| XeFlash s2, 8-bit act., 1 token | about 13 ms |

These are sums of isolated kernel timings. YASAKANI's own kernel is also
faster in isolation than in its engine, and XeFlash will see some of the same
loss, so the s4 advantage over 43 ms is an upper estimate until a full pass
runs.

What that means for the targets, using YASAKANI's measured non-GEMM costs on
this card as a stand-in (12 ms of other kernels, 2.2 ms head, 6.9 ms drafter,
5.26 tokens per pass):

* Replacing only the GEMM with s4 gives a pass of roughly 56 ms against 64 ms,
  i.e. on the order of 95 to 100 tok/s. That would pass the 86 tok/s of
  YASAKANI on the B60 (Milestone 4) with little margin.
* 145 tok/s at 5.26 tokens per pass needs a whole pass in about 36 ms. s4
  cannot do that on GEMM bytes alone. It needs some combination of: fewer
  bytes per weight at equal quality (s3 with a tuned kernel, or s2/s4 mixes
  that survive on text), less non-GEMM time than YASAKANI's 12 ms, a cheaper
  drafter, or more accepted tokens per pass.
* The checkpoint contains an MTP block (`mtp.*`: one attention layer, one MLP
  and a 10240 -> 5120 projection, 0.43 G parameters) that YASAKANI does not
  use. Whether it drafts better than YASAKANI's 5-layer drafter is unknown and
  is the first thing to measure for speculative decoding.

None of the tok/s figures above is a result. 150 tok/s remains a research
target whose feasibility is not established.

## 7. Next measurements

1. Full pass on the B60 (Milestone 3): real in-engine GEMM time, non-GEMM
   kernels, correctness against the reference implementation.
2. Text-level quality of s4 and s3 against BF16 and both YASAKANI files.
3. s3 kernel tuning (single 192-byte load, 8-token path) and a prefill kernel
   that keeps XMX busy.
