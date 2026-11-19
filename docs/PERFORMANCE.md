# Performance

Part A is the whole model on the B60 (Milestone 3). Part C is the official-MTP
drafting speed-up. Part D compares draft sources and holds the current best
numbers (86.6 tok/s with the bdraft2 backend). Part B is the earlier GEMM-only
study.

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

# Part C. Cheaper drafts (MTP head sketch, device-side chain)

Same card, model, container and prompts as Part A; code at the commit that
adds this section. Raw outputs: `benchmarks/results/m4/`. 512 new tokens per
prompt, greedy, context capacity 8192 unless stated. "Cycle" is the wall time
of one speculative cycle (drafts + trunk verify + commit + host), measured as
decode time / cycles.

## C1. Where a draft step's time went (before)

One MTP step, 1 row, host-driven (`baseline_sweep.txt`): 2.52 ms unprofiled.
Per stage, with a wait after each: embedding + pre-fc norms + `fc` 0.45 ms,
activation quantisation 0.06, MTP layer GEMMs 0.55, attention 0.04, MLP
activation 0.02, **shared lm_head + argmax 1.53**. The lm_head was 58 % of a
draft step. (The 6.2 ms per step of the RTX 5060 Ti PyTorch measurement does
not apply here; on the B60 the exact head is 1.5 ms.)

## C2. Changes, each measured on its own

| change | explain, K = 6 | cycle | tokens/pass |
|---|---|---|---|
| baseline: host reads every draft token back | 56.1 tok/s | 69.6 ms | 3.90 |
| draft chain on the device (ids, argmax, next embedding stay on the GPU; one submission and one read-back per cycle) | 56.1 to 56.7 | 68.8 to 69.5 | 3.90 |
| + head sketch, one candidate per 512 consecutive tokens (485 candidates) | 54.8 | 62.2 | 3.41 |
| + head sketch, candidates per id-mod-64 class, 512 candidates | 58.9 | 63.3 | 3.73 |
| same, 1280 candidates | 59.9 | 63.2 | 3.79 |
| **same, 2560 candidates (adopted)** | **59.6 to 60.3** | 63.8 to 64.5 | 3.84 |

* Removing the per-token host round trip is worth under 1 ms per cycle. The
  round trips were not the cost; the head was.
* The sketch is the artefact exported by the drafter project
  (`head_sketch.safetensors`: projection 512 x 5120 FP32, table 248320 x 512
  int8 with one scale per row, basis fitted to MTP output states). XeFlash
  stores the table as an s8 matrix in tile order and scores it with the
  ordinary GEMM kernel on 16-bit activations; candidates are then rescored
  with the real lm_head rows (same integer arithmetic as the full head), so a
  draft equals the full-head draft whenever its row block is a candidate.
* How candidates are chosen matters more than how many. One candidate per
  contiguous id range lost 8 points of first-draft acceptance (89 % -> 81 %):
  neighbouring ids are often near-duplicate tokens that eliminate each other.
  Taking, in each of `groups` parts of the vocabulary, the best token of every
  id-mod-64 class fixes most of it (87 % with 2560 candidates). It is still
  below the full head by 1 to 2 points; the 99.7 % recall reported for exact
  top-512 selection on the 5060 Ti is not reproduced by this selection rule.
* No fallback to the full head is implemented. A margin computed inside the
  candidate set cannot detect a missed candidate, and a miss only costs an
  accepted token, never correctness.

Sketch variants, K = 6 (`sketch_variants.txt`):

| rank | candidates | explain tok/s (tok/pass) | code tok/s (tok/pass) |
|---|---|---|---|
| 256 | 512 | 59.7 (3.79) | 70.0 (4.47) |
| 256 | 2560 | 59.3 (3.79) | 72.6 (4.67) |
| 512 | 256 | 57.9 (3.76) | 72.0 (4.72) |
| 512 | 512 | 58.9 (3.73) | - |
| 512 | 1280 | 59.9 (3.79) | - |
| 512 | 2560 | 59.6 to 60.3 (3.84) | 73.8 (4.80) |
| full head | - | 56.1 (3.90) | 68.6 (4.80) |

Rank 1024 does not exist in the exported file and was not built.

Draft step after the change (`m4_runs.txt`, section D): 1.67 ms unprofiled
(was 2.52). Per stage: embedding + norms + `fc` 0.42, quantisation 0.10, MTP
layer GEMMs 0.55, sketch + selection + rescoring + pick 0.70. A 7-draft chain
is 11.6 ms. The sketch adds 0.13 GiB (16.30 GiB resident in total).

## C3. Draft length sweep with the adopted configuration

Tokens per second (tokens committed per trunk pass):

| K | explain | code | story | proof | mean of these four | japanese |
|---|---|---|---|---|---|---|
| 0 | 22.4 | 22.4 | 22.4 | 22.4 | 22.4 | 22.4 |
| 2 | 46.6 (2.58) | 49.5 (2.74) | 38.5 (2.12) | 50.5 (2.80) | 46.3 | 37.4 (2.06) |
| 4 | 56.8 (3.41) | 68.5 (4.15) | 40.2 (2.39) | 68.7 (4.15) | 58.5 | 39.0 (2.31) |
| 6 | 59.6 (3.84) | 73.8 (4.80) | 37.7 (2.40) | 75.9 (4.94) | **61.8** | 38.8 (2.46) |
| 7 | 58.4 (3.90) | 74.7 (5.04) | 36.6 (2.41) | 76.4 (5.16) | 61.5 | 37.6 (2.48) |
| 8 | 54.4 (3.96) | 71.9 (5.30) | 33.5 (2.41) | 72.4 (5.34) | 58.0 | 34.4 (2.48) |
| 12 | 51.0 (4.15) | 70.1 (5.78) | 30.0 (2.41) | 69.9 (5.75) | 55.2 | 30.8 (2.48) |
| Part A (full head, host chain), best K | 56.1 | 68.9 | 38.8 | 72.6 | 57.7 at K = 6 | 37.0 |
| YASAKANI on the B60 (its notes) | 66.5 | 118.1 | 41.8 | 118.7 | 86.3 | - |

Cycle time grows from 55 ms (K = 2) to 65 ms (K = 6) and 82 ms (K = 12); the
jump between K = 7 and K = 8 (67.5 -> 73.7 ms) is the trunk pass switching
from the 8-token to the 16-token kernels.

Result against the goals:

* K = 2 baseline of 45.5 tok/s: passed (61.8 mean at K = 6; 46.3 at K = 2).
* **YASAKANI on the B60 (86 tok/s): not reached. XeFlash is at 61.8, 72 % of
  it** (was 67 %). Per prompt it is behind on all four.
* 145 tok/s: not reached.

Why, in numbers: at K = 6 a cycle is about 50 ms of trunk pass, 11 to 12 ms of
drafting and 2 ms of host, commit and read-back. Even a drafter that cost
nothing would give 3.84 / 4.80 / 2.40 / 4.94 tokens per 50.3 ms, i.e. 76 / 95
/ 48 / 98 tok/s, a mean of 79. The remaining gap to 86 is therefore in the
trunk pass and in acceptance on prose (story, Japanese: 2.4 tokens per pass),
not in the drafter any more.

## C4. Correctness

Every speculative run above produced exactly the tokens of the K = 0 run. In
addition the committed state is compared: a hash over all 48 DeltaNet state
matrices and convolution histories, the KV rows of every committed position
of the 16 attention layers, and the position, taken at the first commit
boundary at or after 64 new tokens, against a non-speculative run stopped at
the same length. All runs: same tokens, same state (K = 2 to 12, host chain
and device chain, full head and sketch, three MTP weight sets, 8K context).

EOS handling and prefix reuse are not implemented in the tool (runs ignore
EOS, like the benchmark they mirror), so they are not covered.

## C5. Official against fine-tuned MTP weights

The two exported variants convert with the existing converter from their
`checkpoint_overlay` directories (15 `mtp.*` tensors, same names, shapes and
dtype as the official ones; `mtp.fc` kept in bf16, the four matrices data-free
s4 at 18.4 to 18.8 dB, identical figures for all three sets). Same trunk,
sketch head, 512 tokens (`m4_runs.txt`, section C):

| MTP weights | K | japanese | explain | code | proof | mean |
|---|---|---|---|---|---|---|
| official | 6 | 38.8 | 59.6 | 73.8 | 75.9 | 62.0 |
| fc only (`f_fc_fq4`) | 6 | 38.9 | 56.8 | 75.2 | 76.6 | 61.9 |
| all (`c_all_lr2e-6_long`) | 6 | 38.2 | 58.6 | 75.2 | 77.4 | 62.3 |
| official | 7 | 37.6 | 58.4 | 74.6 | 76.4 | 61.8 |
| fc only | 7 | 37.6 | 56.8 | 78.3 | 75.7 | 62.1 |
| all | 7 | 37.4 | 57.8 | 76.1 | 77.2 | 62.1 |

Differences of -0.2 to +0.5 % on four prompts, with opposite signs per prompt:
no measurable gain here. The official weights stay the default. (Four prompts
cannot resolve the +1 % the drafter project measured on 112 sequences; this
says only that nothing larger shows up on the B60.)

## C6. 8K context

8024-token prompt (a technical document plus "summarize"), capacity 16384,
128 new tokens (`m4_runs.txt`, section E). Resident memory 17.41 GiB
requested, 17.44 GiB by the driver.

| | tok/s | cycle | tokens/pass |
|---|---|---|---|
| prefill (16-token passes) | 159 to 173 | | |
| K = 0 | 18.2 | 55.0 ms | 1.00 |
| K = 6, sketch | 33.7 | 118.6 ms | 4.00 |

Same tokens and state as K = 0. A 7-row trunk pass plus drafts takes 119 ms
at this depth against 65 ms at short context: the FP32, unfused attention
baseline (and the MTP's own attention over 8K rows) dominates. Long-context
attention is the largest single item for long prompts and has not been
optimised.

## C7. Main pass, remaining cost (analysis, no change made)

Profile with a wait per stage, ms (`m4_runs.txt`, section D):

| rows | unprofiled | body GEMM | lm_head | quant | GDN | norm | attention | MLP act |
|---|---|---|---|---|---|---|---|---|
| 1 | 42.7 | 35.6 | 1.5 | 3.1 | 4.4 | 1.6 | 1.7 | 0.9 |
| 8 | 50.3 | 41.4 | 1.8 | 3.5 | 5.3 | 1.6 | 1.8 | 1.4 |
| 16 | 58.5 | 45.7 | 1.9 | 3.6 | 8.1 | 1.6 | 1.8 | 2.1 |

* Weight bytes per pass: 11.34 GiB of body matrices plus 0.59 GiB head =
  12.8 GB. At the 1-row unprofiled time, and taking GEMM as about 78 % of the
  pass as in the profile, that is roughly 380 GB/s through the GEMMs: close to
  what the isolated kernels reach (386 to 432 GB/s). The body GEMM is at the
  memory bus; it gets faster only with fewer bytes.
* Precision mix: 255 of 256 body matrices are s4, one is s8
  (`layers.60.linear_attn.out_proj`), none is 16-bit. Weights are loaded once
  per pass; nothing is read twice.
* Not GEMM: about 10 ms at 1 row (quantisation 3.1, DeltaNet 4.4, norms 1.6,
  attention 1.7, activation 0.9 as profiled, which overstates them). This is
  the part kernel work can still remove.
* Rows cost: 8 rows add 7.6 ms over 1 row, 16 rows another 8.2 ms; most of it
  is in the GEMMs (XMX time of the 8-token DPAS, activation loads), the rest
  in the DeltaNet state kernel, which walks tokens serially.
* XMX utilisation in decode is low: about 20 TOPS at 8 rows (both activation
  planes counted) against a 196 TOPS peak. Compute is free, bytes are not.
* Kernel fusion inside the MTP step (item 6 of the plan) was not done: after
  the sketch, the step is 0.42 ms embedding + norms + `fc`, 0.55 ms layer
  GEMMs and 0.70 ms head, all dominated by memory traffic rather than by
  launches, so fusing the small kernels would move little.

Nothing in the trunk was changed in this round.

# Part D. Draft sources compared: official MTP, bdraft2, lookup

Same card, main model (`qwen38-27b-s4-cal.xfm`), prompts and settings as
Part C; 512 new tokens, greedy. Three draft sources on the same XeFlash main
model and the same verify block: the official MTP block (device chain, sketch
head), YASAKANI's bdraft2 through the experimental backend (BDRAFT2.md), and a
host-only D0/D1-style lookup. Raw outputs: `benchmarks/results/m5/`.
Every run: same tokens and same committed state as non-speculative decoding.

## D1. Fixed 8-row verify block (7 drafts)

Tokens per second (tokens committed per pass):

| prompt | none | official MTP | bdraft2 | lookup only |
|---|---|---|---|---|
| explain | 22.4 | 58.4 (3.90) | 74.6 (4.44) | 23.9 (1.18) |
| code | 22.4 | 74.7 (5.04) | 104.0 (6.24) | 30.9 (1.53) |
| story | 22.4 | 36.6 (2.41) | 42.0 (2.47) | 22.1 (1.07) |
| proof | 22.4 | 76.4 (5.16) | 99.3 (5.95) | 27.7 (1.38) |
| japanese | 22.4 | 37.6 (2.48) | 34.1 (2.00) | 24.4 (1.19) |
| mean of the first four | 22.4 | 61.5 | 80.0 | 26.1 |

Time per cycle, ms:

| | main verify | drafter | cycle |
|---|---|---|---|
| official MTP, 7 drafts | about 51 | about 14 (not separable: one submission) | 65.9 to 67.5 |
| bdraft2, taps through host | 51.1 | 9.6 to 10.5, of which 2.1 to 2.6 moving taps | 61.1 to 62.3 |
| bdraft2, taps device-to-device | 51.1 | 5.75 to 5.79 | 58.8 to 60.0 |
| lookup only | 48.3 to 49.5 | under 0.01 | 48.5 to 49.8 |

## D2. 16-row block and the adaptive rule (bdraft2)

| prompt | 8 rows | 16 rows (taps through host) | adaptive 8/16 | passes at 16 rows |
|---|---|---|---|---|
| explain | 74.6 | 70.9 | 75.2 | 5 of 114 |
| code | 104.0 | 115.0 | 115.1 | 52 of 66 |
| story | 42.0 | 35.3 | 42.0 | 0 of 207 |
| proof | 99.3 | 114.0 | 114.0 | 41 of 69 |
| japanese | 34.1 | 28.7 | 34.0 | 3 of 257 |
| **mean of the first four** | 80.0 | 79.0 | **86.6** | |
| YASAKANI on the B60 (its notes) | | | 86.3 (66.5 / 118.1 / 41.8 / 118.7) | |
| official MTP, best fixed K (Part C) | | | 61.8 | |

With 16 rows the official MTP is slower than with 8 (46.3 / 63.8 / 27.2 / 65.7
tok/s): its 15 chained steps cost about 30 ms and late drafts are rarely
accepted. bdraft2 drafts 15 tokens for the same 5.8 to 6.3 ms as 7.

## D3. Reading

* **bdraft2 is the faster drafter on this main model**: 86.6 against 61.8
  tok/s on the four benchmark prompts. It accepts more (2.5 to 7.8 tokens per
  pass against 2.4 to 5.2 for the MTP's best setting per prompt) and costs less per cycle (6 ms against 11 to 14 ms)
  because one block yields all drafts.
* It did not need retraining for XeFlash's INT4 main model: first-draft
  acceptance is 84 to 97 % on English, code and proofs.
* On the Japanese prompt it is worse than the official MTP (34 against 38
  tok/s; first-draft acceptance 47 % against 64 %). One prompt; not
  investigated.
* **Against YASAKANI on the same card: 86.6 against 86.3 tok/s, i.e. level.**
  That is not a win: the YASAKANI figure is from its notes and was not re-run,
  the difference is far inside run-to-run and prompt variation, and the two
  engines run different quantisations of the main model. Per prompt XeFlash is
  ahead on explain (75.2 / 66.5), level on story, slightly behind on code and
  proof (115 / 118, 114 / 119). YASAKANI's figure includes its D0/D1 sources
  and their controller, which this comparison does not use.
* Lookup alone gives 1.07 to 1.53 tokens per pass on these prompts. It is
  nearly free, so it is the obvious thing to combine with a model drafter, but
  alone it is not a drafter for fresh text.
* 145 tok/s is not in reach of this configuration: at 86.6 tok/s a cycle is
  58 to 68 ms, of which 51 to 58 ms is the main pass.

## D4. Memory

| | GiB (driver) |
|---|---|
| XeFlash main + official MTP + sketch, 8192-token cache | 16.33 |
| + bdraft2 backend (46 matrices, rings, 1.41 GB head, its copy of the embedding) | +2.80 |
| total with both drafters loaded | 19.13 |

Both fit; with bdraft2 only, the official MTP block and sketch (0.56 GiB)
would not be needed.

## D5. Recommendation

Use bdraft2 with the adaptive block as the drafter where its files are
available; keep the official MTP path (self-contained, no external code or
weights) as the fallback and for Japanese-like text until that gap is
understood. The backend stays an optional cargo feature: it compiles against
the YASAKANI source tree, so making it the default is a packaging and
ownership decision as much as a technical one (BDRAFT2.md, section 6).

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

# Part E. Long-context attention (K^T layout, shared K/V tiles)

All numbers: Qwen3.8-27B s4 calibrated container, B60, greedy, same prompts, same drafter weights, decode time
excludes load, prefill, warm-up and the state hash. Raw data: `benchmarks/results/m6/`.

## E1. Why the old attention was slow

`k_attn_part` ran one thread per (token, query head, 64-key block) and re-read the FP32 K/V rows for every token and
every head (the 6 query heads of a KV head did not share loads). At 8,040 tokens: 1 row 6.9 ms, 8 rows 38.7 ms,
16 rows 75.7 ms of the pass (time grew with the number of rows). Per-stage times are measured with a synchronisation
after each stage (their sum exceeds the real pass); unsynchronised pass times are listed separately.

## E2. New kernel (`k_attn_part3<HG,TG>`, `kernels/model/model.cpp`)

* K cache is stored transposed per block: `[block of 64 keys][kv head][dim][key]`. The 64 keys of a block are the
  SIMD lanes, so a score needs no horizontal reduction; one K^T vector load feeds `TG tokens x HG heads` FMAs
  (query element = scalar broadcast). V stays `[key][kv head][dim]`.
* One thread = (kv head, group of HG query heads, 64-key block, group of TG tokens when `gper = 1`). It forms the 64
  scores of every (token, head) of its group, a vectorised softmax (masked lanes = causal mask), then the weighted V
  sum. Partial results use the same `pm/pd/pv` format, so `k_attn_comb` is unchanged.
* FP32 throughout. Per-token arithmetic does not depend on HG, TG or the number of rows, so passes of 1, 8 and 16
  rows are bit-identical (checked: hidden state of 8 layers, logits and greedy tokens over 3,200 positions).
* Switch: `XF_ATTN_KT=0` selects the old kernels and row-major K layout. `XF_ATTN_HG/TG/GP` force a configuration;
  `XF_ATTN_LOG=1` prints the configuration chosen per pass size; `XF_ATTN_SWEEP="HG:TG:GP;..."` with
  `xf-run gen --profile` sweeps configurations at the current position without reloading.
* Layout note: the K layout is fixed when the cache is written, so it cannot be switched by context length at run
  time. Instead the configuration (HG, TG) is chosen per pass by context length and row count.

## E3. Configuration sweep (attention stage, ms, rows 1 / 8 / 16)

`benchmarks/results/m6/attn_sweep.txt`, `attn_kt_8k*.txt`, `l30k_prof.log`, `l48k_prof.log`.

| context | old kernel | best new (HG:TG:GP) |
|---|---|---|
| 336 | 1.65 / 1.85 / 2.95 | 1:2:1 2.66 / 2.74 / 2.80 |
| 1,104 | 1.71 / 4.06 / 6.45 | 1:2:1 2.66, 2:2:1 2.89, 3:2:1 3.00 |
| 2,128 | 1.95 / 7.79 / 13.59 | 3:2:1 2.87 / 3.19, 6:2:1 4.05 (16) |
| 4,176 | 3.60 / 16.78 / 31.55 | 3:2:1 3.12; 3:4:1 4.42 (8); 6:2:1 8.58 (16) |
| 8,104 | 6.91 / 38.63 / 75.78 | 3:2:1 4.23; 3:4:1 9.05 (8), 17.53 (16) |
| 30,104 | 37.6 / 386.6 / 824.5 | 6:2:1 14.96; 3:4:1 44.2 (8), 90.3 (16) |
| 48,580 | not measured | 6:2:1 24.8; 3:4:1 86.6 (8), 176.5 (16) |

HG = query heads per thread (6 = the whole GQA group), TG = tokens per thread, GP = 1: token groups are spread over
threads. Larger HG/TG reuse more loads but leave fewer threads; with TG = 8 registers spill (3:8 is 2x slower), and
HG=6 with TG=4 loses. The automatic choice (used unless `XF_ATTN_*` is set):
1 row: HG 1 below 1,536 tokens, 3 below 12,800, else 6 (TG 2); 2 to 8 rows: HG 3, TG 2 below 3,072 tokens else 4;
9 to 16 rows: HG 3 / TG 2 below 1,536, HG 6 / TG 2 up to 3,072, then HG 3 / TG 4.

At short context the new kernel is slower than the old one (about 0.9 ms of a 57 ms pass at 336 tokens, 1.6 %): the
work is too small to fill the GPU and per-launch latency dominates. It overtakes the old kernel at about 1,000
tokens.

## E4. Main pass at 8K (position 8,040, unsynchronised pass time)

| rows | old attention | new attention |
|---|---|---|
| 1 | 48.1 ms | 45.3 ms |
| 8 | 87.4 ms | 58.3 ms |
| 16 | 132.5 ms | 74.3 ms |

Stage times with per-stage synchronisation, 8 rows: GEMM 41.8, attention 9.2 (was 38.7), GDN 5.3, norm 1.6, quant 3.5,
MLP act 1.4, head 1.8.

## E5. Why the first end-to-end number moved less than the kernel (measurement error, fixed)

The first `gen` runs reported 116 -> 106 ms per K=6 cycle although the in-process cycle measured 99.9 -> 74.2 ms.
The `state_hash` check (reads and hashes the whole KV, about 1 GB on the host) sat inside the timed decode loop;
with the transposed K it also needs a re-ordering loop, so it cost more on the new path. It is now excluded from
decode time (the check itself still runs). After the fix: K=6 with the MTP drafter at 8K, 103.4 -> 77.3 ms per
cycle, 37.6 -> 50.3 tok/s. Production uses the new kernel: `XF_ATTN_LOG=1` shows
`k_attn_part3<HG=3,TG=4>` for 8 rows at 8K.

## E6. bdraft2 end to end

Adaptive 8/16 verify block, sketch MTP head, 512 new tokens for the short prompts and 256 for the 8K prompt,
state check at +68 tokens against non-speculative decoding. "adapt-old" is the rule of D2 (fixed cost ratio 1.16);
"adapt-cost" measures real 8- and 16-row passes at the start of the run and uses their ratio.

8K (long8000, 8,024-token prompt):

| configuration | tok/s | tokens/pass | cycle ms | main | drafter | 16-row cycles |
|---|---|---|---|---|---|---|
| old attention, fixed 8 | 36.75 | 3.53 | 95.96 | 88.08 | 6.14 | 0 |
| old attention, fixed 16 | 25.46 | 3.62 | 142.38 | 133.29 | 7.33 | all |
| old attention, adapt-old | 35.16 | 3.53 | 100.31 | 92.36 | 6.22 | few |
| new attention, fixed 8 | 53.02 | 3.53 | 66.52 | 58.64 | 6.15 | 0 |
| new attention, fixed 16 | 43.25 | 3.62 | 83.82 | 74.73 | 7.34 | all |
| new attention, adapt-old | 51.79 | 3.53 | 68.11 | 60.14 | 6.22 | 7 of 74 |
| new attention, adapt-cost | 53.07 | 3.53 | 66.46 | 58.62 | 6.10 | 0 of 74 |

All rows: same tokens as plain greedy, same committed state. Measured 8/16-row pass cost ratio at this length 1.248
(old rule assumes 1.16), so 16 rows are not worth it for this prompt (about 3.5 tokens per pass; the 16-row block
adds 0.09). An earlier run of the same comparison (192 tokens) gave 36.0 -> 53.0 tok/s.

Short prompts (new attention vs old attention, same adaptive rule; tok/s):

| prompt | old attn adapt-old | new fixed 8 | new fixed 16 | new adapt-old | new adapt-cost |
|---|---|---|---|---|---|
| explain | 76.40 | 74.47 | 72.94 | 75.29 | 74.70 |
| code | 117.74 | 102.02 | 117.43 | 114.02 | 114.64 |
| story | 42.30 | 41.45 | 36.07 | 41.46 | 41.46 |
| proof | 116.54 | 99.71 | 116.40 | 115.71 | 116.82 |
| japanese | 34.23 | 33.79 | 29.39 | 33.74 | 33.70 |
| mean of 4 (explain..proof) | 88.2 | 79.4 | 85.7 | 86.6 | 86.9 |
| mean of 5 | 77.4 | 70.3 | 74.4 | 76.0 | 76.3 |

The new attention costs about 1.5 % at short context (the old attention run was taken on another day in one
process; the two are not interleaved, so a difference of 1 % is within run-to-run variation). The measured-ratio
rule equals the old rule to within noise at short context (ratio 1.14, close to the 1.16 constant) and is better
at 8K and beyond, where the ratio rises to 1.25 (8K) and 1.55 (30K); fixed 16 loses about 13 % on story and Japanese,
and fixed 8 loses 10 to 15 % on code and proof, so the adaptive rule stays. No category is worse than fixed 8
by more than noise.

## E7. 30K and the memory limit

FP32 KV costs 128 KiB per token (16 layers) plus 8 KiB for the MTP layer; the pass workspace grows with context.

| context capacity | main + MTP + sketch | + bdraft2 | fits in 22.48 GiB free |
|---|---|---|---|
| 8,448 | 16.37 GiB | 19.17 GiB | yes |
| 30,720 | 19.39 GiB | 22.20 GiB | yes (0.28 GiB left) |
| 49,152 | 21.73 GiB | 24.5 GiB | without bdraft2 only |
| 61,440 | needs more than 22.5 GiB | | no, `xf_alloc` refuses the 363 MB pass workspace |

So 60K is not reachable with the FP32 KV cache on a 24 GB card, with or without bdraft2; 16-bit KV would be needed
(not implemented, and not an exact change). The largest measured context is 48,580 tokens without bdraft2.

30K (long30000, 30,024-token prompt of non-repeating text, bdraft2, 192 new tokens):

| | new attention | old attention |
|---|---|---|
| fixed 8: tok/s / tokens per pass | 31.53 / 3.18 | not run end to end (see below) |
| adapt-cost (measured ratio 1.548: never 16 rows) | 31.54 | |
| cycle / main / drafter | 100.86 / 92.99 / 6.15 ms | |
| 8-row pass, unsynchronised | 96.2 ms | 437.4 ms |
| 16-row pass | 147.2 ms | 885.5 ms |
| 1-row pass | 82.4 ms | 78.7 ms |
| K=0 decode | 16.1 tok/s | 12.6 tok/s |
| prefill | 162 tok/s | 47 tok/s |

An end-to-end old-attention run at 30K would hold the shared GPU lock for about 40 minutes (prefill with the old
kernel is 47 tok/s and the comparison prefills the prompt several times), so the old side is given at pass level
only. At 30K the old attention costs 387 ms per 8-row pass (the K/V of 16 layers no longer stay in cache);
the new one 44 ms.

48.5K, no bdraft2, 16 new tokens: K=0 12.56 tok/s (79.6 ms per token); passes 128.5 / 148.9 / 253.2 ms for 1 / 8 / 16 rows,
attention 87 / 100 / 196 ms in the last (sweep) configuration, best 3:4:1 86.6 ms (8 rows) and 6:2:1 24.8 ms (1 row).

## E8. Numerical agreement with the old kernel

`benchmarks/results/m6/numeric_check.txt`, `numeric_kl.txt`. Teacher-forced run of 3,200 tokens in chunks of 8:

* The new kernel is not bit-identical to the old one (different summation order and a block-wise softmax). Hidden
  state relative RMS difference: 1e-4 after layer 7, 7e-4 after layer 31, 3.7e-3 at the final hidden state;
  KL(old || new) of the next-token distribution: mean 5.2e-5, median 2.1e-6, max 3.9e-2 (the fidelity gap of the
  quantised model to the original is KL 0.069).
* The greedy token differs at 9 of 3,200 positions; in 8 of them the top-two logit gap is at most 0.015; the
  other (position 2,890) has a gap of 0.116 in the old kernel and 0.015 in the new one. Generated sequences of up to 512 tokens were
  identical to the old kernel in the 8K runs above; this is not guaranteed for every sequence.
* Within the new kernel, chunks of 1, 8 and 16 tokens are bit-identical in all 65 layer outputs and in logits,
  and speculative decoding reproduces plain greedy decoding (tokens and committed state, hash over DeltaNet
  state, convolution history and every committed KV row, compared at +68 tokens) in every run above.
  Commit and rejection are unchanged (a pass never writes committed state).

Not tested in this round: prefix reuse, EOS handling (no stop-token logic in `xf-run`), rollback across a
switch between 8 and 16 rows beyond the state hash comparison above (the hash is taken after runs that mix
both block sizes: 6 of 53 passes used 16 rows in the 8K run of E6's first comparison, 7 of 74 in adapt-old).

## E9. Where the time goes now (8 rows, unsynchronised pass)

| context | pass | GEMM | attention | GDN | other |
|---|---|---|---|---|---|
| 8K | 58.3 ms | 41.8 (72 %) | 9.2 (16 %) | 5.3 | 7.9 |
| 30K | 96.2 | 41.3 (43 %) | 44 (46 %) | 5.3 | 9 |
| 48.5K | 148.9 | 41.3 (28 %) | 86.6 (58 %) | 5.3 | 9 |

* At 8K the Main GEMMs dominate again; the drafter adds 6 ms per cycle.
* From 30K on attention dominates and grows faster than linearly (8K 9.2 ms, 30K 44 ms, 48.5K 87 ms: the K/V of
  one layer no longer fits the L2). The kernel is bound by reading K/V: one pass reads 128 KiB per token once per
  query-head group (2 with HG=3) and once per token group (2 for 8 rows), i.e. about four times the minimum
  (30K: 3.9 GB minimum, 15.7 GB read, 44 ms is about 360 GB/s).
* Candidates, in the order the measurements suggest (none implemented in this round): a work-group of the
  head-group x token-group threads of one block that loads each K/V tile once into SLM (cuts the traffic about
  4x); 16-bit KV (halves the bytes and the memory, changes results, needs a quality evaluation); more key splits
  for the 1-row case at long context; Page-Sparse attention (approximate, evaluated separately); then the Main
  GEMMs (42 ms of the 8-row pass at any context).


## Part F: SLM attention and 16-bit KV (see ATTENTION_OPTIMIZATION.md, KV_MEMORY.md)
- SLM work-group attention is the default for >= 2 rows: bit-identical to the previous kernel (3,200 tokens, chunks 8 and 16), 30K 8-row attention 44 -> 29 ms,
  16-row 90 -> 55 ms, 48K 8-row 87 -> 46 ms. bdraft2: 8K 53.07 -> 53.39 tok/s, 30K 31.5 -> 38.5, short-prompt mean 69.9 -> 72.0.
- `XF_KV=bf16|fp16`: KV halves; 60K fits with bdraft2 (22.40 of 22.48 GiB), 40.4 tok/s (64 tokens). Not bit-identical to FP32 KV:
  KL 4.0e-5 (BF16) / 3.1e-5 (FP16), 10 / 8 greedy flips in 3,200 tokens (nearly all with FP32 margin < 0.02).
- Not yet measured: 16-bit KV quality on retrieval/multi-needle/Japanese/code/math, prefix reuse and EOS at 60K, 48K with bdraft2.
- Next bottleneck at long context: the attention kernel is now FMA-issue bound (~3.3 TFLOP/s); next step would be DPAS-based attention (16-bit operands).

## Part G. XMX (DPAS) attention with a shared QK^T, and the Code study (XeFlash + bdraft2)

### G1. What was built
`XF_KV=xmx` (experimental; FP32 KV stays the default): K, V and Q in FP16, QK^T and PV on the XMX units (`dpas.8x8`, hf x hf -> f32), softmax in registers.
Layouts (K: DPAS A tiles [8 keys x 16 dims]; V^T: A tiles [8 dims x 16 keys]; Q^T: B tiles, pre-scaled by 1/16) are in ATTENTION_OPTIMIZATION.md.
Default kernel `k_attn_xmx3<XB=8>`: a work-group of 8 threads per (kv head, group of 16 (token, head) rows, segment of 8 blocks); the QK^T of each 32-key
sub-block is split over the 8 threads (4 key tiles x 2 halves of the dims), exchanged through 8 KiB of SLM (one barrier per sub-block); then every thread runs the online
softmax in registers and PV for its 32 V dims. One partial per segment is written and `k_attn_comb2` merges them. ISA check: no spill, 128 GRF, 1 barrier.
Steps measured on the way: block-partial buffers with a gather combine (combine alone 16-18 ms at 30K), a two-stage combine, the fused kernel with DQ=4 (spills, 114 sends)
against DQ=8 (no spill), and QK^T = 55-70% of the fused kernel's time at 30K (skip tests, `benchmarks/results/m8/fus_30k_skip*.log`).

Attention stage, ms for 16 layers (profile with per-stage sync), rows 1 / 8 / 16:
| context | part3 (FP32 KV) | SLM kernel (FP32 KV, 8 / 16 rows) | XMX shared XB8 |
|---|---|---|---|
| 1K | 3.7 / 3.8 / 3.8 | 1.6 / 2.6 | 1.3 / 1.5 / 1.6 |
| 8K | 4.7 / 9.0 / 17.5 | 8.7 / 15.9 | 2.2 / 3.5 / 4.7 |
| 30K | 18.5 / 44.2 / 90.4 | 29.2 / 54.8 | 7.5 / 10.5 / 14.8 |
| 48K | 36.9 / 86.6 / 176 | 46.3 / 87.2 | 12.5 / 16.8 / 23.7 |

Numerics (1,600 teacher-forced tokens, `benchmarks/results/m8/shared_numerics_1600.txt`): bit-identical for pass sizes 1 / 8 / 16 (exact speculative verification holds);
against FP32 KV: KL 1.7e-5 mean, 6 of 1,600 greedy flips (FP16 KV alone: KL 1.3e-5, 6 flips). Not lossless; the FP32 path remains available.

### G2. Long contexts, bdraft2 adaptive, same model and settings (tok/s; tokens and committed state equal to plain greedy in every run)
| context | FP32 KV, SLM kernels | FP16 KV, SLM kernels | XMX shared |
|---|---:|---:|---:|
| 8K (long-document summary prompt) | 53.4 | - | 58.3 (fixed 8), 57.5 (adaptive-cost) |
| 30K | 38.5 | 38.9 | 48.6 |
| 48K | does not fit with bdraft2 | 32.0 | 43.5 |
| 60K (64 tokens only) | does not fit | 40.4 (BF16 KV) | 51.6 |
60K fits in 22.4 of 22.48 GiB with the MTP head still loaded; with XF_KV=xmx the 378 MB block-partial buffer is no longer allocated.

### G3. Code: same prompt and conditions as the earlier 115.1 tok/s (code.json, 512 tokens, short context)
| backend | fixed 8 | fixed 16 | adaptive (old rule) | adaptive (measured cost) |
|---|---:|---:|---:|---:|
| FP32 KV, SLM kernels | 105.0 | 120.0 | 116.7 | 116.0 |
| XMX shared | 106.5 | 120.5 | 118.8 | 118.1 |
The earlier 115.1 (D2 above, 8-row pass 51.0 ms) is reproduced by the adaptive rule (116.7 / 116.0). Fixed 16 rows is faster than fixed 8 (+13 to +15%) and slightly faster
than either adaptive rule: the 16-row pass costs 1.16x an 8-row pass but adds 32% more tokens per pass (6.1 -> 8.1).

### G4. Code tasks (new prompts, hidden-test graded)
Mean tok/s over the tasks of each scenario (768 new tokens; 8K and 30K have the repository's own sources in front, then the same tasks):
| scenario | backend | fixed 8 | fixed 16 | adaptive (old rule) | adaptive (measured cost) |
|---|---|---:|---:|---:|---:|
| short, 7 code tasks (768 tok), mean | FP32 KV, SLM kernels | 98.4 | 111.5 | 110.9 | 111.0 |
| short, 7 code tasks (768 tok), mean | XMX shared, FP16 KV | 99.1 | 112.6 | 111.8 | 112.1 |
| 8K code context, 3 tasks, mean | FP32 KV, SLM kernels | 74.0 | 74.1 | 76.4 | 76.4 |
| 8K code context, 3 tasks, mean | XMX shared, FP16 KV | 83.3 | 88.4 | 89.7 | 89.6 |
| 30K code context, 2 tasks, mean | FP32 KV, SLM kernels | 56.2 | 50.5 | - | 56.2 |
| 30K code context, 2 tasks, mean | XMX shared, FP16 KV | 71.2 | 75.0 | - | 76.5 |

Per task, short context, XMX shared:

### C_code_xmx

| prompt | config | tok/s | tok/pass | 1st-draft accept | 16-row passes | main ms | draft ms | new tokens | exact |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| py_merge | fixed 8 | 102.1 | 5.93 | 91% | 0/130 (0%) | 50.3 | 5.8 | 768 | tokens+state |
| py_merge | fixed 16 | 107.9 | 7.25 | 86% | 107/107 (100%) | 58.5 | 6.6 | 768 | tokens+state |
| py_merge | adaptive (old rule) | 109.8 | 7.07 | 89% | 76/109 (70%) | 56.0 | 6.3 | 768 | tokens+state |
| py_merge | adaptive (measured cost) | 109.3 | 7.07 | 89% | 79/109 (72%) | 56.3 | 6.4 | 768 | tokens+state |
| py_csv | fixed 8 | 93.2 | 5.41 | 89% | 0/142 (0%) | 50.3 | 5.8 | 768 | tokens+state |
| py_csv | fixed 16 | 96.9 | 6.51 | 86% | 118/118 (100%) | 58.5 | 6.6 | 768 | tokens+state |
| py_csv | adaptive (old rule) | 97.4 | 6.24 | 86% | 82/123 (67%) | 55.8 | 6.3 | 768 | tokens+state |
| py_csv | adaptive (measured cost) | 96.5 | 6.19 | 86% | 84/124 (68%) | 55.9 | 6.3 | 768 | tokens+state |
| py_lru | fixed 8 | 114.0 | 6.64 | 94% | 0/116 (0%) | 50.3 | 5.8 | 768 | tokens+state |
| py_lru | fixed 16 | 130.6 | 8.80 | 91% | 88/88 (100%) | 58.5 | 6.6 | 768 | tokens+state |
| py_lru | adaptive (old rule) | 131.0 | 8.70 | 92% | 79/89 (89%) | 57.6 | 6.5 | 768 | tokens+state |
| py_lru | adaptive (measured cost) | 131.9 | 8.80 | 92% | 81/88 (92%) | 57.9 | 6.5 | 768 | tokens+state |
| rs_balanced | fixed 8 | 54.6 | 3.16 | 66% | 0/243 (0%) | 50.4 | 5.8 | 768 | tokens+state |
| rs_balanced | fixed 16 | 55.7 | 3.73 | 70% | 206/206 (100%) | 58.6 | 6.6 | 768 | tokens+state |
| rs_balanced | adaptive (old rule) | 55.1 | 3.31 | 64% | 56/232 (24%) | 52.4 | 6.0 | 768 | tokens+state |
| rs_balanced | adaptive (measured cost) | 55.1 | 3.32 | 64% | 63/231 (27%) | 52.6 | 6.0 | 768 | tokens+state |
| rs_merge | fixed 8 | 105.9 | 6.15 | 93% | 0/125 (0%) | 50.3 | 5.8 | 768 | tokens+state |
| rs_merge | fixed 16 | 117.9 | 7.93 | 91% | 97/97 (100%) | 58.5 | 6.6 | 768 | tokens+state |
| rs_merge | adaptive (old rule) | 118.9 | 7.69 | 90% | 72/100 (72%) | 56.2 | 6.4 | 768 | tokens+state |
| rs_merge | adaptive (measured cost) | 118.4 | 7.69 | 90% | 75/100 (75%) | 56.4 | 6.4 | 768 | tokens+state |
| cpp_fib | fixed 8 | 108.4 | 6.30 | 94% | 0/123 (0%) | 50.3 | 5.8 | 768 | tokens+state |
| cpp_fib | fixed 16 | 132.3 | 8.91 | 92% | 87/87 (100%) | 58.5 | 6.6 | 768 | tokens+state |
| cpp_fib | adaptive (old rule) | 128.4 | 8.42 | 93% | 75/92 (82%) | 57.0 | 6.4 | 768 | tokens+state |
| cpp_fib | adaptive (measured cost) | 131.5 | 8.71 | 92% | 78/89 (88%) | 57.5 | 6.5 | 768 | tokens+state |
| cpp_merge | fixed 8 | 115.5 | 6.71 | 98% | 0/115 (0%) | 50.3 | 5.8 | 768 | tokens+state |
| cpp_merge | fixed 16 | 146.9 | 9.90 | 97% | 78/78 (100%) | 58.5 | 6.6 | 768 | tokens+state |
| cpp_merge | adaptive (old rule) | 142.4 | 9.41 | 98% | 71/82 (87%) | 57.4 | 6.5 | 768 | tokens+state |
| cpp_merge | adaptive (measured cost) | 141.9 | 9.41 | 98% | 73/82 (89%) | 57.6 | 6.5 | 768 | tokens+state |

Per task, 8K context:

### D_8k_xmx

| prompt | config | tok/s | tok/pass | 1st-draft accept | 16-row passes | main ms | draft ms | new tokens | exact |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| codectx8k_py_csv | fixed 8 | 78.1 | 4.77 | 82% | 0/162 (0%) | 53.1 | 6.1 | 768 | tokens+state |
| codectx8k_py_csv | fixed 16 | 79.7 | 5.73 | 79% | 135/135 (100%) | 62.6 | 7.4 | 768 | tokens+state |
| codectx8k_py_csv | adaptive (old rule) | 81.4 | 5.37 | 80% | 65/144 (45%) | 57.4 | 6.7 | 768 | tokens+state |
| codectx8k_py_csv | adaptive (measured cost) | 81.4 | 5.37 | 80% | 65/144 (45%) | 57.4 | 6.7 | 768 | tokens+state |
| codectx8k_rs_balanced | fixed 8 | 73.6 | 4.49 | 78% | 0/171 (0%) | 53.1 | 6.1 | 768 | tokens+state |
| codectx8k_rs_balanced | fixed 16 | 74.2 | 5.33 | 75% | 144/144 (100%) | 62.6 | 7.4 | 768 | tokens+state |
| codectx8k_rs_balanced | adaptive (old rule) | 78.4 | 5.26 | 75% | 81/146 (55%) | 58.4 | 6.8 | 768 | tokens+state |
| codectx8k_rs_balanced | adaptive (measured cost) | 78.0 | 5.22 | 76% | 81/147 (55%) | 58.3 | 6.8 | 768 | tokens+state |
| codectx8k_cpp_fib | fixed 8 | 98.4 | 6.02 | 92% | 0/128 (0%) | 53.1 | 6.1 | 768 | tokens+state |
| codectx8k_cpp_fib | fixed 16 | 111.3 | 8.03 | 94% | 96/96 (100%) | 62.6 | 7.4 | 768 | tokens+state |
| codectx8k_cpp_fib | adaptive (old rule) | 109.4 | 7.71 | 93% | 85/100 (85%) | 61.1 | 7.2 | 768 | tokens+state |
| codectx8k_cpp_fib | adaptive (measured cost) | 109.4 | 7.71 | 93% | 85/100 (85%) | 61.1 | 7.2 | 768 | tokens+state |

### D_8k_fp32

| prompt | config | tok/s | tok/pass | 1st-draft accept | 16-row passes | main ms | draft ms | new tokens | exact |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| codectx8k_py_csv | fixed 8 | 65.0 | 4.31 | 80% | 0/178 (0%) | 58.5 | 6.1 | 768 | tokens+state |
| codectx8k_py_csv | fixed 16 | 62.8 | 5.22 | 79% | 147/147 (100%) | 73.9 | 7.3 | 768 | tokens+state |
| codectx8k_py_csv | adaptive (old rule) | 65.4 | 4.80 | 78% | 67/160 (42%) | 64.9 | 6.6 | 768 | tokens+state |
| codectx8k_py_csv | adaptive (measured cost) | 65.6 | 4.52 | 79% | 25/170 (15%) | 60.8 | 6.3 | 768 | tokens+state |
| codectx8k_rs_balanced | fixed 8 | 67.2 | 4.47 | 78% | 0/172 (0%) | 58.5 | 6.1 | 768 | tokens+state |
| codectx8k_rs_balanced | fixed 16 | 64.1 | 5.33 | 75% | 144/144 (100%) | 73.9 | 7.4 | 768 | tokens+state |
| codectx8k_rs_balanced | adaptive (old rule) | 69.4 | 5.26 | 75% | 81/146 (55%) | 67.1 | 6.8 | 768 | tokens+state |
| codectx8k_rs_balanced | adaptive (measured cost) | 68.4 | 4.68 | 79% | 20/164 (12%) | 60.3 | 6.3 | 768 | tokens+state |
| codectx8k_cpp_fib | fixed 8 | 89.8 | 5.98 | 91% | 0/129 (0%) | 58.4 | 6.1 | 768 | tokens+state |
| codectx8k_cpp_fib | fixed 16 | 95.4 | 7.95 | 93% | 97/97 (100%) | 73.7 | 7.4 | 768 | tokens+state |
| codectx8k_cpp_fib | adaptive (old rule) | 94.4 | 7.63 | 92% | 86/101 (85%) | 71.5 | 7.2 | 768 | tokens+state |
| codectx8k_cpp_fib | adaptive (measured cost) | 95.0 | 7.14 | 92% | 55/108 (51%) | 66.3 | 6.7 | 768 | tokens+state |

Per task, 30K context:

### E_30k_xmx

| prompt | config | tok/s | tok/pass | 1st-draft accept | 16-row passes | main ms | draft ms | new tokens | exact |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| codectx30k_py_csv | fixed 8 | 72.8 | 4.96 | 81% | 0/155 (0%) | 60.1 | 6.1 | 768 | tokens+state |
| codectx30k_py_csv | fixed 16 | 76.9 | 6.30 | 78% | 122/122 (100%) | 72.6 | 7.4 | 768 | tokens+state |
| codectx30k_py_csv | adaptive (measured cost) | 79.1 | 6.15 | 78% | 87/125 (70%) | 68.8 | 7.0 | 768 | tokens+state |
| codectx30k_rs_balanced | fixed 8 | 69.6 | 4.74 | 81% | 0/162 (0%) | 60.1 | 6.1 | 768 | tokens+state |
| codectx30k_rs_balanced | fixed 16 | 73.2 | 6.00 | 77% | 128/128 (100%) | 72.6 | 7.4 | 768 | tokens+state |
| codectx30k_rs_balanced | adaptive (measured cost) | 73.9 | 5.73 | 78% | 91/134 (68%) | 68.6 | 7.0 | 768 | tokens+state |

### E_30k_fp32

| prompt | config | tok/s | tok/pass | 1st-draft accept | 16-row passes | main ms | draft ms | new tokens | exact |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| codectx30k_py_csv | fixed 8 | 57.1 | 4.93 | 80% | 0/156 (0%) | 78.3 | 6.1 | 768 | tokens+state |
| codectx30k_py_csv | fixed 16 | 51.3 | 6.25 | 78% | 123/123 (100%) | 112.4 | 7.4 | 768 | tokens+state |
| codectx30k_py_csv | adaptive (measured cost) | 57.1 | 4.93 | 80% | 0/156 (0%) | 78.3 | 6.1 | 768 | tokens+state |
| codectx30k_rs_balanced | fixed 8 | 55.3 | 4.77 | 82% | 0/161 (0%) | 78.3 | 6.1 | 768 | tokens+state |
| codectx30k_rs_balanced | fixed 16 | 49.7 | 6.05 | 79% | 127/127 (100%) | 112.4 | 7.4 | 768 | tokens+state |
| codectx30k_rs_balanced | adaptive (measured cost) | 55.3 | 4.77 | 82% | 0/161 (0%) | 78.3 | 6.1 | 768 | tokens+state |


16-row selection of the measured-cost adaptive rule over all passes: short code tasks 65%, 8K 59%, 30K 69% (FP32 kernels: short 65%, 8K 23%, 30K 0%).

### G5. Is fixed 16 better than fixed 8 for code?
Yes, on every task and context measured with the XMX attention: short +2% (rs_balanced, first-draft acceptance 66%) to +27% (cpp_merge, 98%); 8K +1% to +13%; 30K +5%.
With the FP32-KV kernels it is not always so: at 30K the 16-row pass costs 1.43x (112 vs 78 ms) and for rs_balanced fixed 16 loses to fixed 8 (49.7 vs 55.3 tok/s).
The XMX attention makes the 16-row pass cheaper (cost ratio 1.21 at 30K, 1.18 at 8K, 1.16 short), which is why 16 rows pays more.
The adaptive rule (`Adapt`: expected extra accepted tokens `g16` against `(c16-1) * t8`) starts at g16 = 0 and decays by 0.85 on every pass with fewer than 7 accepted drafts, so it uses 8 rows at the start and
after a miss. On the highest-acceptance tasks it stays 1 to 3.5% below always-16 (cpp_merge 141.9 vs 146.9), and it is better than both fixed settings where acceptance is mixed (py_csv and rs_balanced at 8K and 30K).
Checked from the source and from the 16-row counts; the rule was not changed.

### G6. Overall comparison, short context, 512 tokens (tok/s)
| prompt | backend | fixed 8 | fixed 16 | adaptive (old) | adaptive (cost) | tok/pass @8 / @16 | 1st-draft accept | 16-row passes (adaptive-cost) |
|---|---|---:|---:|---:|---:|---|---:|---:|
| explain | FP32 KV (SLM kernels) | 76.6 | 74.5 | 77.4 | 76.9 | 4.44 / 5.00 | 84% | 9% |
| explain | XMX shared (FP16 KV) | 76.8 | 74.9 | 77.6 | 77.0 | 4.44 / 5.00 | 84% | 10% |
| code | FP32 KV (SLM kernels) | 105.0 | 120.0 | 116.7 | 116.0 | 6.10 / 8.08 | 90% | 81% |
| code | XMX shared (FP16 KV) | 106.5 | 120.5 | 118.8 | 118.1 | 6.17 / 8.08 | 90% | 82% |
| story | FP32 KV (SLM kernels) | 42.7 | 36.9 | 42.7 | 42.7 | 2.46 / 2.46 | 68% | 0% |
| story | XMX shared (FP16 KV) | 43.0 | 37.0 | 43.0 | 43.0 | 2.47 / 2.46 | 68% | 0% |
| proof | FP32 KV (SLM kernels) | 102.5 | 118.9 | 118.5 | 119.6 | 5.95 / 8.00 | 97% | 63% |
| proof | XMX shared (FP16 KV) | 102.8 | 119.4 | 119.0 | 120.1 | 5.95 / 8.00 | 97% | 63% |
| japanese | FP32 KV (SLM kernels) | 34.8 | 30.0 | 34.7 | 34.7 | 2.00 / 2.00 | 47% | 2% |
| japanese | XMX shared (FP16 KV) | 34.8 | 30.3 | 34.8 | 34.8 | 2.00 / 2.01 | 48% | 2% |
| mean of explain/code/story/proof | FP32 KV | 81.7 | 87.6 | 88.8 | 88.8 | | | |
| mean of explain/code/story/proof | XMX shared | 82.2 | 88.0 | 89.6 | 89.5 | | | |

### G7. Correctness of the generated code
Hidden tests run in a bubblewrap sandbox (no network, read-only system, tmpfs work dir, CPU / memory / process limits); `tools/code_eval/`. The engine's greedy output is the same for every verify setting (decoding is exact).
| run | task | FP32-KV engine | XMX engine |
|---|---|---|---|
| short | cpp_fib | compile_error (block cut off) | compile_error (block cut off) |
| short | cpp_merge | compile_error (block cut off) | compile_error (block cut off) |
| short | py_csv | fail | fail |
| short | py_lru | pass (block cut off) | pass (block cut off) |
| short | py_merge | fail | fail |
| short | rs_balanced | compile_error | compile_error |
| short | rs_merge | pass | pass |
| 8K | codectx8k_cpp_fib | compile_error (block cut off) | compile_error (block cut off) |
| 8K | codectx8k_py_csv | fail | fail |
| 8K | codectx8k_rs_balanced | compile_error | compile_error |
| 30K | codectx30k_py_csv | fail | fail |
| 30K | codectx30k_rs_balanced | compile_error | compile_error |

passed / graded: short fp32: 2/7; short xmx: 2/7; 8K fp32: 0/3; 8K xmx: 0/3; 30K fp32: 0/2; 30K xmx: 0/2

### G8. Caveats
- Pass rates are low. Part of the failures are answers cut off at 768 tokens inside the code block (short cpp_fib and cpp_merge, 8K cpp_fib: marked above), which cannot compile.
  The failures I inspected in the log (short py_csv, py_merge, rs_balanced) are small syntax slips (`=` for `==`, a `]` closed with `)`, an unclosed `'{`); I did not inspect the 8K and 30K failures one by one.
  The results are the same with FP32 KV and with the XMX attention (11 of the 12 greedy sequences are token-identical between the two), so the failures do not come from this attention work.
  At the failing `'{'` position of rs_balanced the engine puts 9% on the closing quote and 24% on a newline (teacher-forced `xf-run dump`). Whether the BF16 model behaves differently was not measured
  (27B BF16 does not fit in the 56 GB of free host RAM). This is a model-quality question (INT4), not an attention one.
- At most 768 tokens were generated; some answers are cut off inside a code block (marked above).
- Greedy decoding only; one run per condition; the 48K and 60K figures use 128 and 64 generated tokens.
- The adaptive rule was not changed or tuned; its 16-row selection rates are reported as measured.


## Part H. XeFlash on the B60 against YASAKANI on the RTX 5060 Ti (same Qwen3.8-27B prompts, greedy, same generation lengths)

### H1. Method
- Both engines receive the **same token ids** (`benchmarks/prompts/*.json`), greedy decoding, the same number of new tokens per prompt (512 for `code`, 768 for the code tasks, 256 for the long summary prompts), one run each.
- B60: XeFlash with `XF_KV=xmx` (shared XMX attention, FP16 KV), bdraft2 attached, results of Parts G (`benchmarks/results/m8`, `m9`) and the 60K run with 256 tokens (`m11/b60_60k_256`).
- 5060 Ti: YASAKANI (its tuned build, speed model, look-ahead with bdraft2 = its default `on`, `off` = plain decoding), driven by `tools/compare5060/run_yasakani.py` (reads the YASAKANI tree, writes nothing into it), `scripts/y5060_suite.sh`, results in `m11/y_*.json`.
  The engine capacity was set per context group (2,048 / 10,240 / 32,768 / 65,536 tokens).
- tok/s: YASAKANI's own definition, (generated - 1) / generation time without prefill; XeFlash: emitted tokens / decode time without prefill, state hash and logging. Verify, drafter and passes as each engine counts them.
- VRAM: B60 = driver-reported allocation after loading (XeFlash buffers + bdraft2), 5060 Ti = peak `nvidia-smi` memory.used sampled every 0.2 s (includes the CUDA context).

### H2. Results (tok/s; the last columns are B60 / 5060 Ti)

#### 1. Code, 512 tokens

| prompt | new tokens | B60 fixed 8 | B60 fixed 16 | B60 adaptive | **5060 Ti** | 5060 / B60 adaptive | tok/pass B60 / 5060 | main verify ms B60 / 5060 | drafter ms B60 / 5060 | VRAM GiB B60 / 5060 |
|---|---:|---:|---:|---:|---:|---:|---|---|---|---|
| code | 512 | 106.5 | 120.6 | 118.0 | **201.6** | 1.71x | 7.72 / 7.30 | 56.9 / 36.0 | 6.4 / 0.17 | 18.1 (ctx 1024) / 13.8 |

#### 1b. Code tasks, short, 768 tokens

| prompt | new tokens | B60 fixed 8 | B60 fixed 16 | B60 adaptive | **5060 Ti** | 5060 / B60 adaptive | tok/pass B60 / 5060 | main verify ms B60 / 5060 | drafter ms B60 / 5060 | VRAM GiB B60 / 5060 |
|---|---:|---:|---:|---:|---:|---:|---|---|---|---|
| py_merge | 768 | 102.1 | 107.9 | 109.3 | **218.8** | 2.00x | 7.07 / 8.08 | 56.3 / 36.8 | 6.4 / 0.07 | 18.1 (ctx 1024) / 13.8 |
| py_csv | 768 | 93.2 | 96.9 | 96.5 | **198.4** | 2.06x | 6.19 / 7.59 | 55.9 / 38.2 | 6.3 / 0.02 | 18.1 (ctx 1024) / 13.8 |
| py_lru | 768 | 114.0 | 130.6 | 131.9 | **213.0** | 1.61x | 8.80 / 7.45 | 57.9 / 34.9 | 6.5 / 0.01 | 18.1 (ctx 1024) / 13.8 |
| rs_balanced | 768 | 54.6 | 55.7 | 55.1 | **167.6** | 3.04x | 3.32 / 6.34 | 52.6 / 37.8 | 6.0 / 0.01 | 18.1 (ctx 1024) / 13.8 |
| rs_merge | 768 | 105.9 | 117.9 | 118.4 | **216.2** | 1.83x | 7.69 / 8.72 | 56.4 / 40.3 | 6.4 / 0.01 | 18.1 (ctx 1024) / 13.8 |
| cpp_fib | 768 | 108.4 | 132.3 | 131.5 | **210.7** | 1.60x | 8.71 / 7.59 | 57.5 / 36.0 | 6.5 / 0.01 | 18.1 (ctx 1024) / 13.8 |
| cpp_merge | 768 | 115.5 | 146.9 | 141.9 | **248.0** | 1.75x | 9.41 / 9.24 | 57.6 / 37.2 | 6.5 / 0.02 | 18.1 (ctx 1024) / 13.8 |

#### 2. Long context, summary prompt, 256 tokens

| prompt | new tokens | B60 fixed 8 | B60 fixed 16 | B60 adaptive | **5060 Ti** | 5060 / B60 adaptive | tok/pass B60 / 5060 | main verify ms B60 / 5060 | drafter ms B60 / 5060 | VRAM GiB B60 / 5060 |
|---|---:|---:|---:|---:|---:|---:|---|---|---|---|
| long8000 | 256 | 58.3 | 51.0 | 57.5 | **94.7** | 1.65x | 3.53 / 3.31 | 53.4 / 34.8 | 6.2 / 0.04 | 18.6 (ctx 8448) / 14.0 |
| long30000 | 256 | 48.7 | 43.6 | 48.6 | **84.5** | 1.74x | 3.31 / 3.19 | 60.2 / 37.4 | 6.2 / 0.04 | 20.1 (ctx 30720) / 14.4 |
| long60000 | 256 | 39.8 | 31.8 | 39.8 | **77.4** | 1.94x | 3.08 / 3.27 | 69.6 / 41.5 | 6.1 / 0.02 | 22.1 (ctx 61440) / 15.1 |

#### 2b. Code with real source in front, 768 tokens

| prompt | new tokens | B60 fixed 8 | B60 fixed 16 | B60 adaptive | **5060 Ti** | 5060 / B60 adaptive | tok/pass B60 / 5060 | main verify ms B60 / 5060 | drafter ms B60 / 5060 | VRAM GiB B60 / 5060 |
|---|---:|---:|---:|---:|---:|---:|---|---|---|---|
| codectx8k_py_csv | 768 | 78.1 | 79.7 | 81.4 | **171.8** | 2.11x | 5.37 / 6.21 | 57.4 / 36.0 | 6.7 / 0.08 | 18.6 (ctx 8960) / 14.0 |
| codectx8k_rs_balanced | 768 | 73.6 | 74.2 | 78.0 | **158.2** | 2.03x | 5.22 / 6.10 | 58.3 / 38.4 | 6.8 / 0.05 | 18.6 (ctx 8960) / 14.0 |
| codectx8k_cpp_fib | 768 | 98.4 | 111.3 | 109.4 | **192.4** | 1.76x | 7.71 / 7.75 | 61.1 / 40.2 | 7.2 / 0.02 | 18.6 (ctx 8960) / 14.0 |
| codectx30k_py_csv | 768 | 72.8 | 76.9 | 79.1 | **152.7** | 1.93x | 6.15 / 6.00 | 68.8 / 39.0 | 7.0 / 0.06 | 20.1 (ctx 31040) / 14.4 |
| codectx30k_rs_balanced | 768 | 69.6 | 73.2 | 73.9 | **130.7** | 1.77x | 5.73 / 5.11 | 68.6 / 38.9 | 7.0 / 0.03 | 20.1 (ctx 31040) / 14.4 |

#### YASAKANI reference rows (same runs): look-ahead off = plain decoding

| prompt | on tok/s | off tok/s | prefill tok/s | rows histogram (on) |
|---|---:|---:|---:|---|
| code | 201.6 | 38.3 | 223 | {'1': 1, '5': 1, '8': 43, '16': 25} |
| long8000 | 94.7 | 37.2 | 790 | {'2': 1, '3': 1, '4': 1, '5': 1, '8': 69, '16': 4} |
| long30000 | 84.5 | 34.6 | 720 | {'1': 1, '2': 1, '3': 1, '4': 1, '6': 1, '8': 75} |
| long60000 | 77.4 | 31.7 | 644 | {'5': 1, '8': 77} |


### H3. What this shows
- **Code, 512 tokens: 201.6 tok/s on the 5060 Ti against 120.6 (fixed 16) / 118.0 (adaptive) on the B60**, i.e. 1.67x to 1.71x. With YASAKANI plain decoding (look-ahead off) at 38.3 tok/s against 22.7 for XeFlash K=0.
- Time per pass is the main difference: one verify pass (5060 Ti) 36.0 ms against 56.9 ms (B60, adaptive; main verify only), plus 6.4 ms of drafter on the B60 (YASAKANI reports 0.17 ms: its drafter work is counted inside the verify pass / overlapped, so the drafter columns are not comparable, compare `ms/pass` = 36.2 against 63.3).
  Tokens per pass are similar for code.json (7.7 against 7.3) but differ by task: rs_balanced 3.3 (B60) against 6.3 (5060 Ti).
- **Long context** (summary prompt, 256 tokens): 8K 94.7 against 57.5 (1.65x), 30K 84.5 against 48.6 (1.74x), **60K 77.4 tok/s on the 5060 Ti against 39.8 on the B60 (1.94x)**.
  YASAKANI's 5060 Ti loses little with context (94.7 -> 77.4, -18%) because its KV is INT8 and its verify pass grows from 34.8 to 41.5 ms; the B60 loses 31% (58.3 -> 39.8 with fixed 8 rows), its pass grows from 53 to 70 ms.
- Memory at 60K: B60 22.1 of ~22.5 usable GiB (FP16 KV 3.75 GiB, bdraft2 included), 5060 Ti 15.1 of 16 GiB peak.
- The two engines produce **different text** from the same prompt (the greedy sequences diverge after 15 to 51 tokens, e.g. code.json after 24): different weight quantisation (XeFlash INT4 s4 container vs YASAKANI speed model),
  and different KV formats (FP16 vs INT8 rows). Acceptance and tokens per pass therefore differ per prompt, and the numbers compare engines on the same prompt and length, not on the same generated text.
- Not measured: the same drafter state on both sides (each uses its own bdraft2 integration), repeated runs / variance, prefill speed of XeFlash for the long prompts at the same settings (YASAKANI prefill 644 to 790 tok/s is in the json).


## Part I. Where the Main verification pass goes (B60 against the RTX 5060 Ti), and the GEMM

Profiles: `XF_PROF_DETAIL=1 xf-run gen ... --profile` (every kernel followed by a synchronisation; the sum is larger than the real pass, both are given) and, for YASAKANI,
`YSKN_PROF=1` with `use_graph=0` (`scripts/y5060_prof.sh`). Parsers: `tools/profile/`. Raw logs and tables: `benchmarks/results/m12/`.
Same prompts on both sides (`long8000`, `long30000`, `long60000`, `code`), 8-row verify pass.

### I1. B60, 8-row pass, ms per pass (XMX attention, FP16 KV; FP32-KV numbers in `b60_tables_*_none.md`)
| part | 1K | 8K | 30K |
|---|---:|---:|---:|
| GEMM (all projections + head) | 43.5 | 43.3 | 43.6 |
| activation quantisation (257 launches) | 3.6 | 3.6 | 3.7 |
| GDN kernels (core 2.9, gemv a/b 2.1, conv, post, qk-norm, gate) | 7.3 | 7.3 | 7.3 |
| attention (q-prep, kv-store, main, combine) | ~2.0 (FP32 KV) | 4.0 | 11.8 |
| RMSNorm + residual (129 launches) | 1.6 | 1.6 | 1.6 |
| MLP activation | 1.5 | 1.5 | 1.5 |
| **sum of synchronised kernels** | 59.6 | 61.4 | 68.9 |
| **real pass time (no per-kernel sync)** | **50.5** | **52.1** | **59.5** |
The per-kernel synchronisation adds 9 to 10 ms; the real pass is the second number. Not measured separately: the host side of a pass (launch queue, read-back of the argmax).

### I2. RTX 5060 Ti (YASAKANI), 8-row pass, ms per pass (blocking per-kernel times, drafter kernels included)
| part | 8K | 30K | 60K |
|---|---:|---:|---:|
| GEMM (`lnord_kernel`: 256 layer GEMMs 24.9 ms, the others and the head ~4.5) | 29.3 | 29.4 | 29.4 |
| attention (reads 4-bit packed KV) | 2.4 | 5.3 | 9.3 |
| GDN | 2.8 | 2.8 | 2.8 |
| norm / residual (129 launches) | 1.15 | 1.14 | 1.13 |
| MLP activation | 1.08 | 1.08 | 1.09 |
| head argmax | 0.54 | 0.54 | 0.53 |
| drafter / sampler kernels | 1.6 | 1.7 | 1.7 |
| **total** | **38.9** | **42.1** | **46.0** |
(reported unsynchronised verify time in the earlier tables: 34.8 / 37.4 / 41.5 ms.) About 850 launches per pass against about 1,500 on the B60.

### I3. What explains the 15 ms gap in the pass (8K; B60 52.1 real / 61.4 synchronised, 5060 Ti 38.9 synchronised)
| | B60 | 5060 Ti | difference |
|---|---:|---:|---:|
| GEMM | 43.3 | 29.3 | +14.0 |
| GDN | 7.3 | 2.8 | +4.5 |
| activation quantisation + norm + MLP activation | 6.7 | 2.2 | +4.5 |
| attention | 4.0 | 2.4 | +1.6 |
- GEMM: the B60 streams 12.8 GB of weights per pass (4-bit codes + scales, head included) at 296-361 GB/s (65 to 80% of the 456 GB/s peak, which YASAKANI's own report puts at 381-448 GB/s sustained on this card);
  YASAKANI streams about 10.9 GB at 393 GB/s (88% of 448). More bytes (+17%) and a lower fraction of the bandwidth both contribute.
- The 5060 Ti fuses the activation quantisation into other kernels; XeFlash runs it as 257 separate launches per pass.
- Attention at long context: YASAKANI's KV is 4-bit packed (`atxpk4` kernels), XeFlash reads 16-bit.

### I4. GEMM on the B60: is the XMX the limit? (xf-bench --cold: weights rotated through 160 MB of copies so that they come from DRAM; `benchmarks/results/m12/gemm_*.txt`)
- Per shape at 8 rows, in-model time against the cold benchmark: gate+up 259 / 248 us, down 151 / 142, GDN in-proj 129 / 115, out projections 117 / 93 (best segment count), attention qkv 119 / 104 us. The in-model numbers are the benchmark's.
- With the DPAS and the activation loads switched off (diagnostic, results wrong) the kernel takes the same time as the full kernel (gate+up 244-248 us against 248 us): **the GEMM is limited by streaming the weights, not by XMX work or the activation loads**;
  row count barely changes it (gate+up 242 / 259 / 279 us for 1 / 8 / 16 rows).
- Unroll 1 / 2 / 4 tiles, L1-uncached or streaming loads, prefetch of tiles ahead: no effect (within 2%). Tile-major weight order: slower for wide matrices (gate+up 248 -> 396 us), faster for the narrowest one (out projection 116 -> 94 us); not adopted.
- Narrow matrices (5120 rows = 320 row blocks) reach only 134-255 GB/s: too few threads for the memory system; splitting the columns (segments) adds threads but also partial sums and a combine kernel.
  **Adopted**: the out projections (5120 x 6144) use 2 column segments for <= 8 rows and 1 for 16 rows instead of 4 (the 4 was a rule of thumb). Results are bit-identical (integer partial sums; checked on 1,600 tokens, pass sizes 8 and 16);
  8-row pass 49.92 -> 48.66 ms, 16-row pass 58.25 -> 56.15 ms (1K context, XMX; 1-row pass unchanged).
- Ideal streaming time for 12.8 GB at the sustained 415 GB/s is about 31 ms; the GEMMs take 43.5 ms now (40 ms with the best segment counts). The remaining 9 to 12 ms would need a different weight stream (fewer bytes, or a layout that reaches the 435 GB/s of a plain read),
  not more XMX work. The weight format (uniform 4-bit plus scales) already is 17% larger than YASAKANI's mixed format.


## Part J. INT8 KV (`XF_KV=int8`) and overlap of drafter and Main

### J1. INT8 KV, measured (same model, prompts and build; FP16 KV = `XF_KV=xmx`)
Scheme: one scale per (position, kv head) for K and one for V (max|x| / 127, round to nearest), the same DPAS tile layouts as the FP16 version; the kernel converts the INT8 tiles to FP16 for the DPAS,
multiplies the rows of S^T by the key's scale and the rows of P by the value's scale before the PV product (the softmax denominator uses the unscaled weights). Shared XMX kernel only; the FP32 and FP16 paths are untouched.

Quality (3,200 teacher-forced tokens, `benchmarks/results/m12/int8_quality_3200.txt`), against the FP32-KV engine:
| KV | KL mean | KL max | max abs logit diff | greedy flips | flips with fp32 margin >= 0.02 |
|---|---:|---:|---:|---:|---:|
| FP16 (XMX) | 4.9e-5 | 6.6e-2 | 1.8 | 11 / 3200 | 0 |
| INT8 | **7.0e-4** | 0.38 | 7.9 | **31 / 3200** | 14 |
Pass sizes 1 / 8 / 16 give bit-identical logits with INT8 as well (exact speculative verification holds). The INT8 error is 14x the FP16 one in KL and about three times the greedy flips, 14 of them at positions where the FP32 top-2 margin was >= 0.02,
i.e. not only near-ties. Per-position, per-head scales are the simplest scheme; per-channel or per-group scales were not tried.

Attention stage, ms for 16 layers, rows 1 / 8 / 16 (`i8_sweep_*.log`): 1K 2.25 / 2.40 / 2.44 (FP16: 1.31 / 1.48 / 1.59); 8K 2.58 / 4.86 / 6.85 (2.16 / 3.49 / 4.73); 30K 6.97 / 13.6 / 21.4 (7.46 / 10.5 / 14.8).
The kernel is not limited by DRAM traffic, so halving the bytes does not pay for the conversion and the scale multiplications.

bdraft2, same build (`benchmarks/results/m12/i8e_*.json`), tok/s:
| case | FP16 KV | INT8 KV |
|---|---:|---:|
| code.json, 512 tokens: fixed 8 / fixed 16 / adaptive | 109.1 / 124.6 / 123.0 | 109.1 / 125.4 / 123.7 |
| 30K summary, 256 tokens: fixed 8 / fixed 16 | 49.8 / 44.8 | 49.0 / 40.4 |
| 60K summary, 256 tokens: fixed 8 | 40.5 (main pass 68.2 ms) | 38.3 (73.5 ms) |
VRAM at 60K with bdraft2: KV 3.75 -> 1.90 GiB, total allocation 22.13 -> 20.17 GiB. Tokens and committed state equal plain greedy in every run.
**Decision**: INT8 KV is a memory option (about 2 GiB at 60K), not a speed option: equal speed at short context, 2 to 10% slower at 30K and 60K, and clearly less accurate. It stays experimental; FP32 remains the default and FP16 (XMX) the fast long-context choice.
(Note: the code.json numbers of Part G (120.5 for fixed 16) predate the out-projection segment change of Part I; the same-build FP16 figure is 124.6.)

### J2. Can the drafter and the Main pass overlap? (analysis from the measurements above; no overlapped run was built)
Dependencies of a cycle: the drafter needs the committed tokens and the tap states of the accepted rows, which exist only after the Main pass, its head and the accept decision; the next Main pass needs the draft tokens. The chain
Main(n) -> accept -> drafter(n+1) -> Main(n+1) is strictly serial for the same stream of tokens: the drafter (6.1 to 7.4 ms, 10 to 12% of a cycle) cannot hide behind the verify pass of the same cycle.
What could be overlapped, with the time available (8-row pass at 8K, per pass):
- Inside a Main layer: the GDN `gemv-ab` kernel (2.1 ms per pass, needs only the normed input) is independent of the in-projection GEMM (6.2 ms); the 257 activation-quantisation launches (3.6 ms) and norms (1.6 ms) are on the critical path of their GEMMs.
  Upper bound for overlapping the independent GDN kernels with the GEMMs: about 2 to 3 ms per pass (4 to 6%), needs a second queue with explicit events and may be absorbed by the memory-bound GEMMs themselves.
- Narrow GEMMs (the 64 out-projections, 93 us, 7.5 ms per pass in total) use 320 to 640 threads and leave the GPU partly idle, but the kernel following each of them depends on its output; nothing independent is queued next to them.
- Drafter against the tail of the Main pass: the lm_head GEMM (1.8 ms) and the argmax (0.05 ms) are followed by the accept decision; the drafter's row-wise work on the taps (KV-ring update for the 8 rows) could be computed for all rows and committed for the accepted ones, hiding at most the time of the head, about 1.8 ms (3%).
- Speculating one cycle ahead (start drafting from the assumption that all drafts are accepted): with acceptance of the first draft around 90% on code, all 7 drafts are accepted in roughly half of the cycles, so about half of the 6 ms would be saved on those cycles and wasted GPU time (slowing the verify pass that runs beside it) on the others.
  Not attempted; the expected gain is below 5% before the contention cost.
YASAKANI's drafter takes 1.6 ms inside its 38.9 ms pass (5060 Ti); the 6.2 ms of XeFlash's drafter is the larger target, but a profile of the bdraft2 backend itself (`experimental/bdraft2`) at kernel level has not been made, so its split into scoring, block forward and selection is unknown.

### J3. Summary of the priority list
1. B60 Main pass profiled per kernel (Part I1): GEMM 43.5 of 59.6 ms synchronised (52 ms real).
2. The 5060 Ti pass profiled per kernel (Part I2): GEMM 29.3 of 38.9 ms; non-GEMM kernels 9.6 ms against 16 ms.
3. GEMM: streaming-bound at 65 to 80% of the bandwidth, not XMX-bound; segment count change adopted (bit-identical, -1.3 / -2.1 ms); layout, cache hints, prefetch, unroll: no gain.
4. INT8 KV: implemented, exact across pass sizes, 14x the KL of FP16, not faster (J1).
5. Overlap: analysed (J2); no large safe gain found without a drafter profile.


## Part K. 4-bit GEMM read efficiency (priority 1), controlled experiments

### K1. What the memory system gives (`kernels/probe/bw_probe.cpp`, `bw_small.cpp`, `bw_shapes.cpp`; random data, 512 MiB / cold)
- Streaming reads with one contiguous stream per thread (the layout of the weights: `[row block][tile][256 B]`) reach 390 to 440 GB/s from 1,024 threads up, whatever the number of loads in flight per thread (U = 1 to 8):
  the hardware prefetches the sequential streams. 16-group interleaving without sequential streams does not (56 GB/s at U = 1). Constant or arithmetic-progression data reads at 600 to 2,000 GB/s (memory compression): all probes use random bytes.
- A 16 MiB read (the size of an out projection) takes 39 us on an out-of-order queue and **54.8 us on the in-order queue the engine uses** (the tail of one kernel is not hidden by the next); big matrices 402 to 415 GB/s:
  floor per pass for the 5 shapes of the model at 8 rows 30.7 ms (pure reads, in order) against about 38 ms for the GEMMs before this work (head excluded). (An earlier estimate of 13 ms of slack used the out-of-order probe and was too large; the slack is about 7 ms, 19%.)
- The GEMM uses the same layout and thread layout as the probe (rows / 16 streams, 256 B tiles), so layout and number of threads are not what limits it: tile-major order is slower (gate+up 248 -> 396 us), L1/L2 hints and prefetch do nothing.

### K2. A-H on one shape: 5120 x 6144, 8 tokens, s4 weights with 16-bit activations (`XF_GEMM_EXP=A..H`, same range of threads, same tile loop and epilogue in every mode; cold weights; main kernel only, us)
| experiment | what it isolates | segs 1 | segs 2 | segs 4 |
|---|---|---:|---:|---:|
| A read the weight tiles only | weight load | 66.1 | 73.2 | 93.6 |
| B read + s4 -> s8 expansion, no DPAS | dequantisation (this does not exist in the real s4 kernel: the DPAS takes the packed s4 directly) | 114.7 | 95.4 | 100.0 |
| C weights resident in registers + DPAS, activations from memory | XMX work and activation loads | 40.8 | 26.8 | 24.0 |
| D read + DPAS (the production loop) | the real kernel | 98.4 | 79.0 | 97.7 |
| E = D with the next tiles requested before the DPAS (double buffer) | overlap of load and compute | **65.9** | **71.0** | 95.9 |
| F = D without activation loads | | 67.5 | 74.5 | 95.2 |
| G = D without DPAS (reads W and X) | | 74.2 | 72.7 | 94.2 |
| H DPAS only, weights and activations in registers | pure XMX | 24.3 | 18.7 | 21.0 |
Same experiment on gate+up (34816 x 5120, segs 1): A 237, B 263, C 72, D 245, E 242, F 238, G 240, H 62 us.
- The XMX work is small (H 19 to 24 us for the narrow matrix, 62 us for gate+up; C with the activation loads 27 to 72 us), and expanding s4 to s8 in registers costs 20 to 50 us on top of the read (B against A): the native s4 DPAS is the right design, a format that needs expansion would be slower.
- D is slower than A + (small) because the next tile's loads are issued only after the current DPAS: with the double buffer (E) the narrow matrix goes from 98.4 to 65.9 us (segs 1) and equals the read-only kernel (A, 66.1); on gate+up the gain is 1%, because there the reads are already continuous.
- Reading alone (A) in this kernel is 66 to 73 us against the 54.8 us in-order floor of the probe for the same bytes: about 20% remain in the kernel structure (epilogue, tail), not in the weight stream.

### K3. Adopted (bit-identical results, checked on 1,600 tokens at pass sizes 1 / 8 / 16 and in `xf-bench`)
- Software-pipelined integer loop for the 8-token and 16-token GEMM kernels (default; `XF_GEMM_PIPE=0` restores the previous loop). Cold GEMM, us per call, best segments: out projection m=8 92.1 -> 65.9 (segs 1), m=16 102.8 -> 77.5; down (5120 x 17408) m=8 143.7 -> 131.4 (segs 2), m=16 163.3 -> 160.0;
  gate+up, qkvz, attention qkv within 2%; m = 1 unchanged.
- Segment counts: rows < 8192 and m > 1: 1 segment for 5120 x 6144 and 2 for 5120 x 17408 (the combine kernel disappears for the out projections).
- Pass time at 1K context, XMX, no per-kernel synchronisation: 8 rows 48.65 -> 46.72 ms, 16 rows 56.15 -> 53.88 ms, 1 row 42.31 -> 42.09 ms (from the start of Part I: 49.92 -> 46.72 and 58.25 -> 53.88, i.e. -6.4% and -7.5%).
- Not adopted: tile-major weight order, cache hints, prefetch, larger unroll.


## Part L. Does the 4-bit GEMM use the XMX efficiently? (before any 3-bit work)

Method: `xf-bench --cold` (weights rotated through copies > L2) for the production kernels, `XF_GEMM_EXP=A..H` for the controlled experiments (same thread layout, tile loop and epilogue in every mode; only the tile-loop body changes),
`kernels/probe/dpas_peak.cpp` for the XMX peak, ocloc compile + disassembly of the dumped SPIR-V for the ISA figures. Shapes: the out projection 5120 x 6144 and gate+up 34816 x 5120. Raw data: `benchmarks/results/m12/xmx_*`.

### L1. XMX peak with register operands (`dpas_peak.txt`, 1,280 threads, 8 independent accumulators per thread)
bf16 / fp16 x same -> f32: **98 TFLOPS**; s8 x s8 -> s32, **s4 x s8 -> s32**, u4 x s8 (3-bit): **196.5 TOPS** (s4 and u4 run at the s8 rate: one dpas covers 32 columns whatever the weight width).

### L2. m = 1, 8, 16 on the same shape (production kernels, cold; F = 2MNK is the logical work, the physical work counts the padding to 1 / 8 / 16 rows and the two byte planes of 16-bit activations)
### Production kernels, cold weights, 1 segment: time, bandwidth of the stored weights, F = 2MNK (logical), and the XMX work actually issued

| shape | weights | m | time us | stored MB | GB/s | F = 2MNK TFLOPS | DPAS ops issued (G) | XMX TOPS (physical) | share of the format's XMX peak | dpas per thread (dynamic) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| out_proj 5120x6144 | s4 + 16-bit act (2 planes) | 1 | 61.1 | 15.7 | 257 | 1.03 | 0.13 | 2.1 | 1% | 384 |
| out_proj 5120x6144 | s4 + 16-bit act (2 planes) | 8 | 65.9 | 15.7 | 239 | 7.64 | 1.01 | 15.3 | 8% | 384 |
| out_proj 5120x6144 | s4 + 16-bit act (2 planes) | 16 | 77.5 | 15.7 | 203 | 12.99 | 2.01 | 26.0 | 13% | 768 |
| out_proj 5120x6144 | s4>s8 + 8-bit act | 1 | 81.2 | 15.7 | 194 | 0.77 | 0.06 | 0.8 | 0% | 192 |
| out_proj 5120x6144 | s4>s8 + 8-bit act | 8 | 83.1 | 15.7 | 189 | 6.06 | 0.50 | 6.1 | 3% | 192 |
| out_proj 5120x6144 | s4>s8 + 8-bit act | 16 | 96.6 | 15.7 | 163 | 10.42 | 1.01 | 10.4 | 5% | 384 |
| out_proj 5120x6144 | s3 + 16-bit act (2 planes) | 1 | 70.2 | 11.8 | 168 | 0.90 | 0.13 | 1.8 | 1% | 384 |
| out_proj 5120x6144 | s3 + 16-bit act (2 planes) | 8 | 74.8 | 11.8 | 158 | 6.73 | 1.01 | 13.5 | 7% | 384 |
| out_proj 5120x6144 | s3 + 16-bit act (2 planes) | 16 | 73.8 | 11.8 | 160 | 13.64 | 2.01 | 27.3 | 14% | 768 |
| out_proj 5120x6144 | bf16 + bf16 act | 1 | 167.3 | 62.9 | 376 | 0.38 | 0.06 | 0.4 | 0% | 384 |
| out_proj 5120x6144 | bf16 + bf16 act | 8 | 170.5 | 62.9 | 369 | 2.95 | 0.50 | 3.0 | 3% | 384 |
| out_proj 5120x6144 | bf16 + bf16 act | 16 | 196.5 | 62.9 | 320 | 5.12 | 1.01 | 5.1 | 5% | 768 |
| merged.gate_up 34816x5120 | s4 + 16-bit act (2 planes) | 1 | 230.1 | 89.1 | 387 | 1.55 | 0.71 | 3.1 | 2% | 320 |
| merged.gate_up 34816x5120 | s4 + 16-bit act (2 planes) | 8 | 242.5 | 89.1 | 368 | 11.76 | 5.70 | 23.5 | 12% | 320 |
| merged.gate_up 34816x5120 | s4 + 16-bit act (2 planes) | 16 | 253.6 | 89.1 | 351 | 22.49 | 11.41 | 45.0 | 23% | 640 |
| merged.gate_up 34816x5120 | s4>s8 + 8-bit act | 1 | 256.8 | 89.1 | 347 | 1.39 | 0.36 | 1.4 | 1% | 160 |
| merged.gate_up 34816x5120 | s4>s8 + 8-bit act | 8 | 263.0 | 89.1 | 339 | 10.84 | 2.85 | 10.8 | 6% | 160 |
| merged.gate_up 34816x5120 | s4>s8 + 8-bit act | 16 | 270.7 | 89.1 | 329 | 21.07 | 5.70 | 21.1 | 11% | 320 |
| merged.gate_up 34816x5120 | s3 + 16-bit act (2 planes) | 1 | 194.3 | 66.8 | 344 | 1.83 | 0.71 | 3.7 | 2% | 320 |
| merged.gate_up 34816x5120 | s3 + 16-bit act (2 planes) | 8 | 221.8 | 66.8 | 301 | 12.86 | 5.70 | 25.7 | 13% | 320 |
| merged.gate_up 34816x5120 | s3 + 16-bit act (2 planes) | 16 | 242.1 | 66.8 | 276 | 23.56 | 11.41 | 47.1 | 24% | 640 |
| merged.gate_up 34816x5120 | bf16 + bf16 act | 1 | 837.9 | 356.5 | 425 | 0.43 | 0.36 | 0.4 | 0% | 320 |
| merged.gate_up 34816x5120 | bf16 + bf16 act | 8 | 854.9 | 356.5 | 417 | 3.34 | 2.85 | 3.3 | 3% | 320 |
| merged.gate_up 34816x5120 | bf16 + bf16 act | 16 | 873.8 | 356.5 | 408 | 6.53 | 5.70 | 6.5 | 7% | 640 |

### A-H (same thread layout, tile loop and epilogue), 8 tokens, 1 segment, cold; us and overlap


out_proj 5120x6144, s4: A 66.1 | B 66.0 | C 40.8 | D 98.7 | E 65.9 | F 67.4 | G 74.4 | H 24.3
  load time (A) 66.1 us, XMX time (H) 24.3 us (25% of D); D - A = 32.6 us; overlap factor of D = (A+H-D)/min(A,H) = -0.34, of E = 1.01

out_proj 5120x6144, s3: A 62.9 | B 68.5 | C 41.5 | D 80.3 | E 71.9 | F 73.7 | G 65.7 | H 24.4
  load time (A) 62.9 us, XMX time (H) 24.4 us (30% of D); D - A = 17.4 us; overlap factor of D = (A+H-D)/min(A,H) = 0.29, of E = 0.63

merged.gate_up 34816x5120, s4: A 237.1 | B 237.1 | C 72.0 | D 245.1 | E 241.9 | F 237.4 | G 239.9 | H 62.3
  load time (A) 237.1 us, XMX time (H) 62.3 us (25% of D); D - A = 8.0 us; overlap factor of D = (A+H-D)/min(A,H) = 0.87, of E = 0.92

merged.gate_up 34816x5120, s3: A 193.7 | B 199.7 | C 74.5 | D 254.3 | E 223.9 | F 206.5 | G 204.1 | H 61.9
  load time (A) 193.7 us, XMX time (H) 61.9 us (24% of D); D - A = 60.6 us; overlap factor of D = (A+H-D)/min(A,H) = 0.02, of E = 0.51

out_proj 5120x6144, s4exp8: A 66.1 | B 114.7 | C 41.4 | D 123.0 | E 89.2 | F 123.0 | G 74.5 | H 24.5
  load time (A) 66.1 us, XMX time (H) 24.5 us (20% of D); D - A = 56.9 us; overlap factor of D = (A+H-D)/min(A,H) = -1.32, of E = 0.06

merged.gate_up 34816x5120, s4exp8: A 237.2 | B 262.8 | C 75.0 | D 273.5 | E 265.4 | F 268.7 | G 239.9 | H 64.2
  load time (A) 237.2 us, XMX time (H) 64.2 us (23% of D); D - A = 36.3 us; overlap factor of D = (A+H-D)/min(A,H) = 0.43, of E = 0.56


### L3. ISA of the kernels (ocloc, device bmg; static instruction counts of the compiled kernel, one loop body plus prologue / epilogue)
```
run        kernel                                                GRF  SLM spill dpas(static)  send asm lines
exp_A      submit_exp<0, 0>                                      128    0    no            0    29       532
exp_A      submit<0, 8, 1, 2, false, true>                       128    0    no            6    32       593
exp_D      submit_exp<0, 3>                                      128    0    no            8    38       632
exp_D      submit<0, 8, 1, 2, false, true>                       128    0    no            6    32       593
exp_E      submit<0, 8, 1, 2, false, true>                       128    0    no            6    32       593
exp_E      submit_exp<0, 4>                                      128    0    no           20    50       713
exp_H      submit_exp<0, 7>                                      128    0    no            6    29       602
exp_H      submit<0, 8, 1, 2, false, true>                       128    0    no            6    32       593
prod_bf16  submit<3, 8, 2, 1, false, false>                      128    0    no            2    25       463
prod_bf16  submit<3, 8, 1, 2, false, false>                      128    0    no            2    19       376
prod_bf16  submit<3, 1, 1, 4, false, false>                      128    0    no            8    30       349
prod_s4    submit<0, 1, 1, 2, true, true>                        128    0    no           20    35       469
prod_s4    submit<0, 8, 2, 1, true, true>                        128    0    no           16    81      1134
prod_s4    submit<0, 8, 1, 2, true, true>                        128    0    no           20    56       805
prod_s4    submit<0, 8, 2, 1, false, true>                       128    0    no            8    52       837
prod_s4    submit<0, 8, 1, 2, false, true>                       128    0    no            6    32       593
prod_s4    submit<0, 1, 1, 2, false, true>                       128    0    no            6    18       353
```
Key: `submit<WF, R, G, U, A16, PIPE>` with WF 0 = s4, 3 = bf16; `submit_exp<WF, MODE>` the experiment kernel. All kernels use 128 GRF, no SLM, no spill, no barrier: independent threads (ESIMD), one thread per
(16 weight rows, 8 or 16 tokens, column segment): out projection 320 threads, gate+up 2,176 threads for 1 segment. The 8-token s4 loop body holds 20 `dpas` (2 stages x U = 2 tiles x 2 byte planes, plus the tail); dynamic count per thread = tiles x planes (x 2 groups for 16 tokens), e.g. 384 for the out projection at 8 tokens.

### L4. Findings
1. **The XMX is not the limit.** With every operand in registers the 8-token kernel needs 24 us (out projection) / 62 us (gate+up) = 25% of the production time; the physical rate is 15 to 24 TOPS in production against 196 TOPS peak (8 to 12%), and 91 TOPS (47% of peak) when only the DPAS runs (4 independent accumulators per thread are fewer than the 8 of the peak probe).
   The compute time would equal the load time only at about 30 tokens (prefill), not at the 1 to 16 rows of decoding. At m = 1 the dpas has repeat count 1 (1/8 of the work per instruction) and the XMX share is 1 to 2%, still memory-bound.
2. **Load time and XMX time overlap** when the next tiles are requested before the DPAS (E): gate+up D 245 -> E 242 us (load only: A 237, overlap factor of D 0.87); out projection D 98.7 -> E 65.9 us = A 66.1 (D was serialised: load + 32.6 us).
   Memory wait against compute wait of D: gate+up is 97% load stream (D - A = 8 us); the narrow matrix was 33% compute wait before the double buffer and is now at the load floor.
3. **Expanded BF16 weights** (4x the bytes): out projection 167 / 171 / 197 us and gate+up 838 / 855 / 874 us at m = 1 / 8 / 16 against s4 61 / 66 / 78 and 230 / 243 / 254 us (3.5x): they read at 408 to 425 GB/s (the probe's ceiling) and use 3 to 7% of the bf16 XMX peak.
   Memory-bound as well; there is nothing to gain from expanded weights in VRAM (and they would not fit: 54 GB for the model).
4. **Expansion in registers costs** (s4 -> s8 then s8 DPAS, `s4>s8` + 8-bit activations): out projection 83 us against 66, gate+up 263 against 243 at 8 rows (+9 to +26%); the expansion alone (B - A) costs 49 us on the narrow matrix and 26 us on gate+up. The native s4 DPAS (no expansion) is the right design.
5. **3-bit (`XF_W_S3`, 192-byte tiles, expansion to u4, same XMX rate)**: expansion is cheap (B - A = 6 us on gate+up), so XMX is not what limits it either; but the stored bytes are read at only 301 to 345 GB/s against 368 to 387 for s4 (the 192 B tile is not a multiple of the 256 B block load and of a cache line pair):
   gate+up 221.8 us against 242.5 at 8 rows (-8.5% for -25% bytes; ideal at the s4 read rate: about 178 us, -27%), -16% at 1 row, -4.5% at 16 rows, no gain on the down projection at 8 rows.
   So **fewer bytes is the lever, but the 3-bit tile layout has to be repacked to 256-byte units (4 tiles = 768 B) before it pays**; the accuracy of 3-bit weights is a separate question that was not tested here.
6. For the s4 kernel itself: stream rate 368 GB/s on gate+up (89% of the 415 GB/s probe ceiling and below the 417 GB/s of the bf16 kernel, which moves 512 B per tile step per thread): the remaining inefficiency of the 4-bit kernel is in the 256-byte step, not in the XMX.


## Part M. How much of the XMX does the 4-bit GEMM use? Measurement and cause analysis (no production kernel was changed; 3-bit work paused)

Sources and method. Hardware: Intel's [Arc Pro B60 datasheet](https://www.intel.com/content/dam/www/central-libraries/us/en/documents/2026-03/datasheet-b60-gpu.pdf) and
[Arc Pro B-series quick reference](https://www.intel.com/content/dam/www/central-libraries/us/en/documents/2026-03/intel-arc-pro-b-series-graphics-quick-reference-guide-v1-0.pdf): 20 Xe cores, 160 XMX engines, 2400 MHz, 197 INT8 TOPS, 456 GB/s.
The same configuration comes from the driver: Level Zero reports 5 slices x 4 subslices x 8 EUs = 160 EUs, 8 threads per EU (1,280 resident threads), core clock 2,400 MHz.
Standalone probes (`kernels/probe/`, no production kernel involved): `dpas_peak.cpp`, `dpas_chain.cpp`, `bw_probe.cpp`, `bw_shapes.cpp`, `xmx_probe.cpp`, `simd_int4.cpp`, `call_xfgemm.cpp`; production GEMM via `xf-bench --cold` (weights rotated through copies larger than L2) and `libxfk` `xf_gemm`.
All probes: in-order queue, cold weights, random data (constant or arithmetic-progression data reads 1.5 to 5x faster: memory compression), steady-state back-to-back launches. Raw data: `benchmarks/results/m12/`.

### M1. Theoretical peak and what the machine can sustain
| quantity | theory (datasheet, clock x engines) | measured with synthetic probes |
|---|---:|---:|
| INT8 / s4 x s8 / u4 x s8 XMX | 197 TOPS (160 engines x 512 OP/clk x 2.4 GHz = 196.6) | **196.5 TOPS** (99.9%, 1,280 threads, operands in registers) |
| BF16 / FP16 XMX | 98.3 TFLOPS (half the INT8 rate: 160 x 256 FLOP/clk x 2.4 GHz) | **98.2 TFLOPS** (bf16), 98.2 (fp16) |
| memory | 456 GB/s (192-bit GDDR6) | **440 GB/s asymptote** (97% of 456; fit of read-only kernel time against bytes), 415 GB/s at 1 to 90 MB |
A dpas.8x8 (s4 / s8, 8 x 16 x 32 MAC = 8,192 ops) occupies an XMX engine for 16 clocks at peak. s4 and u4 weights run at the s8 rate: one dpas covers 32 columns whatever the weight width, so 4-bit weights buy memory, not XMX speed.
Hardware counters (XMX activity, EU active / stall, cache hit rate, DRAM traffic) are **not available** here: `zetMetricGroupGet` returns 0 groups (0x7ffffffe) and `/proc/sys/dev/xe/observation_paranoid` is 1 (observation needs CAP_PERFMON; not changed).
Every utilisation figure below is therefore an estimate from synthetic kernels or from kernel times; measured quantities are times, instruction counts (disassembly) and byte counts.

### M2. What limits the DPAS rate in the kernels (`dpas_chain.txt`: s4 x s8, operands in registers, TOPS of 196.5)
| threads per EU \ independent accumulator chains | 1 | 2 | 4 | 8 | 16 |
|---|---:|---:|---:|---:|---:|
| 1 | 30.1 | 49.1 | 46.1 | 49.1 | 36.5 |
| 2 | 98.2 | 98.2 | 92.1 | 98.2 | 72.2 |
| 4 | 196.5 | 196.5 | 184.2 | 196.5 | 142.5 |
| 8 | 151.4 | 196.5 | 196.5 | 196.5 | 154.0 |
One thread cannot issue more than about one dpas.8x8 every 64 clocks (49 TOPS even with 8 chains; one dependent chain: about 100 clocks of latency per dpas), while the engine consumes one every 16: **the XMX needs at least 4 resident threads per EU (640 threads) to reach the peak**, 2 chains per thread are enough.
The 8-token GEMM kernel keeps 4 chains per thread (U = 2 tiles x 2 byte planes), the 16-token one 4 to 8. The narrow matrices launch 320 threads (2 per EU): the XMX cannot exceed about 98 TOPS there, whatever else happens.

### M3. Operand supply and what DPAS rates the loop structure reaches (`xmx_probe.txt`; same thread layout, tile loop and weight layout as the production kernel; us per call, cold)
| shape | m | read only us | DPAS only us (% of peak) | SLM operands + DPAS us (% of peak) | weights streamed + DPAS us | = with next tiles first (production-like) us | s4->s8 expansion + s8 DPAS us |
|---|---:|---:|---:|---:|---:|---:|---:|
| out projection | 8 | 54.9 | 13.2 (39%) | 6.3 (81%) | 56.3 | 56.1 | 112.0 |
| out projection | 16 | 85.6 | 22.8 (45%) | 11.4 (90%) | 87.6 | 65.3 | 114.6 |
| down | 8 | 110.0 | 35.7 (41%) | 15.6 (93%) | 112.1 | 122.9 | 296.7 |
| down | 16 | 181.0 | 62.9 (46%) | 30.1 (96%) | 188.4 | 183.8 | 307.6 |
| gate+up | 8 | 213.8 | 37.5 (77%) | 35.6 (82%) | 217.7 | 215.8 | 239.5 |
| gate+up | 16 | 217.9 | 73.7 (79%) | 68.1 (85%) | 223.2 | 219.2 | 248.3 |
| GDN in-proj | 8 | 102.2 | 18.0 (76%) | 17.6 (78%) | 104.5 | 103.2 | 115.0 |
| GDN in-proj | 16 | 100.4 | 35.2 (78%) | 32.4 (84%) | 102.7 | 102.1 | 120.4 |
| attention qkv | 8 | 90.4 | 18.0 (66%) | 14.3 (84%) | 92.4 | 95.2 | 110.9 |
| attention qkv | 16 | 89.6 | 35.2 (68%) | 26.9 (89%) | 91.8 | 94.2 | 117.7 |
| lm_head | 8 | 1455.1 | 216.6 (96%) | 219.3 (94%) | 1487.5 | 1504.9 | 1588.6 |
| lm_head | 16 | 1474.1 | 432.9 (96%) | 429.0 (96%) | 1512.2 | 1516.4 | 1620.8 |
- DPAS alone (operands in registers, the GEMM's own chain structure) reaches 76 to 79% of the INT8 peak on the large shapes (the head: 96%); with 8 chains 84%.
- **Operands supplied from SLM (staged once, read back every tile) + DPAS reach 78 to 96% of the peak** (down m = 16: 96%): SLM supply does not limit the XMX.
- Streaming the real 4-bit weights from memory + DPAS takes the read-only time plus 1 to 3% (gate+up m = 8: 217.7 against 213.8 us): the XMX work is hidden behind the loads when the threads are numerous (13.6 per EU on gate+up) and the next tiles are requested before the DPAS.
- Expansion s4 -> s8 in registers + s8 DPAS (the `s4>s8` variant): +12% on gate+up, **+100 to +170% on the 320-thread matrices** (out projection 112 us against 56, down 297 against 123): the expansion is vector-ALU work that few threads cannot hide.
- Packed-int4 on the vector ALUs without XMX (`simd_int4.txt`, results identical to the DPAS ones and to a host reference): at m = 1 it ties with the DPAS kernel on the large shapes (gate+up 220 against 208 us, GDN in-proj 100 against 101) because both wait for the weights, and loses on the narrow one (74 against 51 us);
  at m = 8 it is 2.6 to 3.2x slower (gate+up 561 against 216 us: 2 expansion ops plus one multiply-add per token for every weight), at m = 16 it collapses (register pressure). It never wins; the hypothesis that m = 1 favours SIMD is not supported, because the XMX kernel already reaches the read time at m = 1.

### M4. Per shape and per m: production 4-bit GEMM (s4 weights, 16-bit activations as two byte planes, pipelined loop, best segment count), peak and measured
F = 2MNK is the logical work; "DPAS ops issued" counts what the XMX executes (padding to 1 / 8 / 16 rows, two byte planes); "% of XMX peak" is that rate against 196.5 TOPS; GB/s is the stored 4-bit weight bytes over the call time.
| shape (N x K) | m | threads (per EU) | dpas / thread | DPAS ops issued (G) | XMX peak TOPS | production us | segs | effective TFLOPS (F = 2MNK) | physical XMX TOPS | % of XMX peak | GB/s (4-bit weights) | % of 456 | read-only us (same layout) | DPAS-only us | SLM-fed + DPAS us | weights + DPAS us | verdict |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| out projection 5120x6144 | 1 | 320 (2.0) | 384 | 0.13 | 196.5 | 61.2 | 1 | 1.03 | 2.1 | 1.1% | 257 | 56% | 63.5 | 8.7 | 8.2 | 60.0 | latency / occupancy limited stream: even the read-only kernel is 68% above the bandwidth floor (320 threads, short streams); dpas.8x1 (1/8 of the XMX work per instruction) |
| out projection 5120x6144 | 8 | 320 (2.0) | 384 | 1.01 | 196.5 | 65.9 | 1 | 7.64 | 15.3 | 7.8% | 239 | 52% | 54.9 | 13.2 | 6.3 | 56.3 | latency / occupancy limited stream: even the read-only kernel is 45% above the bandwidth floor (320 threads, short streams) |
| out projection 5120x6144 | 16 | 320 (2.0) | 768 | 2.01 | 196.5 | 77.5 | 1 | 12.99 | 25.9 | 13.2% | 203 | 45% | 85.6 | 22.8 | 11.4 | 87.6 | latency / occupancy limited stream: even the read-only kernel is 126% above the bandwidth floor (320 threads, short streams) |
| down 5120x17408 | 1 | 320 (2.0) | 1088 | 0.36 | 196.5 | 116.2 | 1 | 1.53 | 3.1 | 1.6% | 384 | 84% | 109.3 | 15.4 | 14.1 | 108.8 | memory-bandwidth bound (read-only 109 us, XMX 14% of it); dpas.8x1 (1/8 of the XMX work per instruction) |
| down 5120x17408 | 8 | 640 (4.0) | 1088 | 2.85 | 196.5 | 131.3 | 2 | 10.86 | 21.7 | 11.0% | 339 | 74% | 110.0 | 35.7 | 15.6 | 112.1 | memory bound + exposed load/compute serialisation |
| down 5120x17408 | 16 | 640 (4.0) | 2176 | 5.70 | 196.5 | 160.0 | 2 | 17.83 | 35.6 | 18.1% | 279 | 61% | 181.0 | 62.9 | 30.1 | 188.4 | latency / occupancy limited stream: even the read-only kernel is 69% above the bandwidth floor (640 threads, short streams) |
| gate+up 34816x5120 | 1 | 2176 (13.6) | 320 | 0.71 | 196.5 | 230.1 | 1 | 1.55 | 3.1 | 1.6% | 387 | 85% | 211.5 | 20.6 | 18.5 | 211.7 | memory-bandwidth bound (read-only 212 us, XMX 10% of it); dpas.8x1 (1/8 of the XMX work per instruction) |
| gate+up 34816x5120 | 8 | 2176 (13.6) | 320 | 5.70 | 196.5 | 242.5 | 1 | 11.76 | 23.5 | 12.0% | 368 | 81% | 213.8 | 37.5 | 35.6 | 217.7 | memory-bandwidth bound (read-only 214 us, XMX 18% of it) |
| gate+up 34816x5120 | 16 | 2176 (13.6) | 640 | 11.41 | 196.5 | 253.6 | 1 | 22.49 | 45.0 | 22.9% | 351 | 77% | 217.9 | 73.7 | 68.1 | 223.2 | memory bound + exposed load/compute serialisation |
| GDN in-proj 16384x5120 | 1 | 1024 (6.4) | 320 | 0.34 | 196.5 | 111.3 | 1 | 1.51 | 3.1 | 1.6% | 377 | 83% | 101.3 | 10.5 | 8.7 | 103.0 | memory-bandwidth bound (read-only 101 us, XMX 10% of it); dpas.8x1 (1/8 of the XMX work per instruction) |
| GDN in-proj 16384x5120 | 8 | 1024 (6.4) | 320 | 2.68 | 196.5 | 115.3 | 1 | 11.64 | 23.2 | 11.8% | 364 | 80% | 102.2 | 18.0 | 17.6 | 104.5 | memory-bandwidth bound (read-only 102 us, XMX 18% of it) |
| GDN in-proj 16384x5120 | 16 | 1024 (6.4) | 640 | 5.37 | 196.5 | 118.7 | 1 | 22.61 | 45.2 | 23.0% | 353 | 77% | 100.4 | 35.2 | 32.4 | 102.7 | memory bound + exposed load/compute serialisation |
| attention qkv 14336x5120 | 1 | 896 (5.6) | 320 | 0.29 | 196.5 | 103.3 | 1 | 1.42 | 2.8 | 1.4% | 355 | 78% | 90.2 | 10.5 | 7.7 | 91.5 | memory-bandwidth bound (read-only 90 us, XMX 12% of it); dpas.8x1 (1/8 of the XMX work per instruction) |
| attention qkv 14336x5120 | 8 | 896 (5.6) | 320 | 2.35 | 196.5 | 106.8 | 1 | 11.00 | 22.0 | 11.2% | 344 | 75% | 90.4 | 18.0 | 14.3 | 92.4 | memory bound + exposed load/compute serialisation |
| attention qkv 14336x5120 | 16 | 896 (5.6) | 640 | 4.70 | 196.5 | 109.1 | 1 | 21.53 | 43.1 | 21.9% | 336 | 74% | 89.6 | 35.2 | 26.9 | 91.8 | memory bound + exposed load/compute serialisation |
| lm_head 248320x5120 | 1 | 15520 (97.0) | 320 | 5.09 | 196.5 | 1473.3 | 1 | 1.73 | 3.5 | 1.8% | 431 | 95% | 1430.2 | 115.0 | 113.9 | 1430.5 | memory-bandwidth bound (read-only 1430 us, XMX 8% of it); dpas.8x1 (1/8 of the XMX work per instruction) |
| lm_head 248320x5120 | 8 | 15520 (97.0) | 320 | 40.68 | 196.5 | 1571.7 | 1 | 12.94 | 25.9 | 13.2% | 404 | 89% | 1455.1 | 216.6 | 219.3 | 1487.5 | memory-bandwidth bound (read-only 1455 us, XMX 15% of it) |
| lm_head 248320x5120 | 16 | 15520 (97.0) | 640 | 81.37 | 196.5 | 1771.1 | 1 | 22.97 | 45.9 | 23.4% | 359 | 79% | 1474.1 | 432.9 | 429.0 | 1512.2 | memory bound + exposed load/compute serialisation |


Verdict key. "memory-bandwidth bound": the read-only kernel with the same layout takes about the call time and the XMX alone takes 10 to 18% of it. "Latency / occupancy limited stream": even the read-only kernel is 45 to 126% above the sustained-bandwidth floor
(bytes / 415 GB/s): 320 threads, 2 per EU, short streams of 49 to 139 KB each, a fixed ramp and tail per launch. "Exposed load / compute serialisation": the call is more than 15% above the read-only time.
Static ISA (ocloc disassembly): all production kernels 128 GRF, no spill, no SLM, no barrier. The 8-token loop body is 8 `dpas.8x8` per trip (2 stages x U = 2 x 2 byte planes) in two groups of 4 issued back to back (`{Atomic}`), each group preceded by `sync.allwr` on the loads of its stage (the next stage's loads are issued before);
the 1-token kernel uses `dpas.8x1` (a repeat count of 1: one eighth of the work per instruction); 4 independent accumulator chains per stage, no dependency between consecutive dpas of a group. Dynamic count per thread = tiles x planes (x 2 groups at 16 tokens), column "dpas / thread".

### M5. Roofline reading
- Arithmetic intensity of the weight stream: 2 x M x 2 (two byte planes) operations of the XMX per 0.5 byte of weight = 16 M ops / byte (m = 8: 128, m = 16: 256, in physical ops) against a ridge point of 196.5 TOPS / 440 GB/s = 447 ops / byte: **every case is far left of the ridge (memory side)**;
  the XMX would become the limit only at about 28 tokens (two planes) or 56 (one 8-bit plane), i.e. prefill, not decoding.
- Floor of a call = fixed cost + bytes / bandwidth: the read-only kernel fits `t = 10.8 us + MB / 440 GB/s` over 15.7 MB to 636 MB (residuals within 4 us except the 320-thread out projection, +8.5 us).
  Production 8-row pass, the five layer GEMMs without the head: measured 35.4 ms; stream at 440 GB/s 27.6 ms; 256 launches x 10.8 us = 2.8 ms; **5.0 ms above the read-only floor are the production kernel's own overhead.**
- **Weight read is not the whole story**: the stream of the large matrices reaches 340 to 387 GB/s (77 to 85% of 456), the head 431 GB/s (95%), and the same loop in a standalone probe reaches the read-only time (gate+up m = 8: 215.8 us) while the production kernel takes 243.4 us.
  Bisection with the probe: production epilogue 0 us, 64-bit index arithmetic (division, modulo) +7 us, run-time strides +3 us: 226.5 us; **about 17 us (7%) of the gap remain unexplained** (not found in the loop structure, the allocation alignment, the number of rotated buffers, the build flags or the benchmark path:
  `libxfk` called from a C++ harness gives 243.4 us like `xf-bench`). Candidate causes still to bisect: remaining address arithmetic, register allocation of the production kernel (56 `send` against about 35), the order of loads and DPAS in the compiled loop.

### M6. Where the GEMM time goes (summary)
1. Not XMX throughput: XMX alone is 10 to 18% of the call at 8 tokens, 18 to 25% at 16; at the peak structure it could run 5 to 10x faster. SLM or expanded operands would not help, and expanding the weights (s4 -> s8, BF16) makes it slower.
2. Bandwidth: the large shapes stream at 77 to 85% of 456 GB/s; the sustained ceiling is 440 GB/s (97%). Remaining loss on them: the per-launch fixed cost (10.8 us x 256 per pass = 2.8 ms) and the 7% kernel overhead above (5 ms per pass).
3. Narrow matrices (out projection 64 per pass, down 64): 320 to 640 threads, 2 to 4 per EU: the read-only stream itself is at 52 to 74% of the floor, the XMX could reach only 50% of its peak, and short streams pay the ramp: latency / occupancy limited. Adding column segments adds threads but also partial sums.
4. m = 1: dpas.8x1, memory-bound at the read time (the large shapes); the 320-thread shapes are occupancy-bound.
5. "85 to 94% of the theoretical bandwidth" is measured only on the largest shapes and the head; the weighted share over a pass is 35.4 ms measured against a 30.4 ms floor from the fit (86%): the GEMM is **not** at its floor and not "optimised": 5.0 ms (14% of the GEMM time) lie above it, and the fixed cost per launch is a further 2.8 ms.
   What the measurements do not show: a gain from the XMX itself, from SLM operand supply or from expanded weights.

### M7. Estimates against measurements
Measured: all times, bytes, dpas counts (static from the ISA, dynamic = tiles x planes x groups), GRF / SLM / spill, thread counts, peak XMX and sustained read rates of the synthetic probes. Estimated (no counters): XMX busy share (= DPAS-only time / call time), stall split between memory and compute (from the read-only and DPAS-only kernels),
occupancy-based limits (from the chain / thread scaling probe), the fixed launch cost (from the fit), the unexplained 17 us.
