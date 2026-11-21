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


## Part N. Why the production xf_gemm is 7 to 11% slower than the same loop in a probe: instruction comparison and variant sweep (production kernel not changed)

Tools: `kernels/probe/gemm_variants.cpp` (experimental copies of the 8 / 16-token s4 loop that share libxfk's queue, so their output is compared **bit for bit** with `xf_gemm` on the same buffers and their time is measured in the same harness),
`call_xfgemm.cpp`, `xmx_probe.cpp`; ISA from ocloc disassembly of the IGC-dumped kernels. Raw data: `benchmarks/results/m12/variants_*.txt`, `loop_compare.txt`.

### N1. Loads, DPAS and dependencies in the main loop (gate+up, 8 tokens; one trip = 4 tiles = 2 stages of U = 2)
| kernel | instructions per trip | `dpas.8x8` | loads (`send.ugm`, 256 B each) | integer ALU incl. mov | 64-bit multiply (`mul`/`macl`/`mach`) | GRF | spill | us |
|---|---:|---:|---:|---:|---:|---:|---|---:|
| production `xf_gemm` | 91 | 8 | 12 | 46 | 24 | 128 | no | 243.5 |
| variant ADDR=1 (production's address arithmetic) | 91 | 8 | 12 | 64 | 24 | 128 | no | 235.1 |
| variant ADDR=0 (constant offsets, 64-bit loop counters and division) | 53 | 8 | 12 | 22 | 0 | 128 | no | 233.5 |
| variant ADDR=2 (32-bit counters, no division, pointers advanced once per trip) | 49 | 8 | 12 | 17 | 0 | 128 | no | 216.6 |
| **variant ADDR=3 (initial addresses computed outside the loop, pointer += stride after every tile)** | **40** | 8 | 12 | **14** | **0** | 128 | no | **216.8** |
| probe mode 8 (constant strides) | 39 | 8 | 12 | 13 | 0 | 128 | no | 216.0 |
- **The loads (12 x 256 B per trip, the same message descriptor) and the DPAS (8 per trip, two groups of 4 issued back to back with `{Atomic}`, 4 independent accumulators) are identical.** The difference is the integer arithmetic in between.
- Production recomputes each tile's address from the tile index with 64-bit multiplications (`mul` -> `macl` -> `mach` -> `add3`, 24 instructions per trip) and 64-bit compares for the loop condition; **every `send` carries an integer dependency (`{I@n}`) on its address chain**, so the 12 loads are issued spread over about 60 instructions
  instead of back to back (variant ADDR=3 / probe: 12 loads inside 16 instructions, immediate offsets). Later requests leave the thread later, fewer are in flight at a time.
- Before the loop the production kernel also divides (64-bit `idx % rowblks`, `idx / rowblks`, `tiles / segs`): +7 us on gate+up (probe mode 10 against mode 9).
- GRF 128 for every kernel: 8 resident threads per EU, 1,280 in the machine; no spill, no SLM, no barrier. Launched threads: gate+up 2,176 (1.7 waves of resident threads), GDN in-proj 1,024, attention qkv 896, down and out projection 320 (2.0 per EU).
  Large-GRF mode (256 GRF, 4 threads per EU) was not used or needed (nothing spills).

### N2. Variant sweep: how far the production time goes down (output bit-identical to `xf_gemm` for every row below; 2-stage software pipeline, one thread = RB row blocks x all tiles of a segment)
Time of one call, cold weights, in-order queue, us.
| shape | m | production | best variant | % of production | best configuration |
|---|---:|---:|---:|---:|---|
| gate+up 34816 x 5120 | 8 | 243.5 | **216.6** | 89% | U=2, 1 segment, ADDR=2 / 3 |
| gate+up | 16 | 253.8 | 228.3 | 90% | U=1, 1 segment, ADDR=3 |
| GDN in-proj 16384 x 5120 | 8 | 115.3 | 101.6 | 88% | U=1, RB=2 (activation tiles loaded once for two row blocks) |
| GDN in-proj | 16 | 118.7 | 106.1 | 89% | U=1 |
| attention qkv 14336 x 5120 | 8 | 106.8 | 89.7 | 84% | U=1, RB=2 |
| attention qkv | 16 | 109.9 | 93.5 | 85% | U=1 |
| down 5120 x 17408 | 8 | 131.7 (2 segments) | 111.4 | 85% | U=2, **1 segment** (no combine kernel) |
| down | 16 | 159.2 (2 segments) | 146.9 | 92% | U=1, 4 segments |
| out projection 5120 x 6144 | 8 | 66.3 | 52.7 | **80%** | U=2, 1 segment |
| out projection | 16 | 77.1 | 57.9 | **75%** | U=1, 1 segment |
| lm_head 248320 x 5120 | 8 | 1568.5 | 1499.1 | 96% | U=2 |
Effect of each knob (gate+up, 8 tokens; the others behave alike): address arithmetic is the dominant one (ADDR=1 235 us -> ADDR=3 217 us); **work-group size does not matter** (plain range, 1, 4, 16 threads per work-group: within 1 to 2 us); U = 4 tiles per stage is 30% slower (register pressure) and
RB = 2 helps only the two 14 to 16 thousand row matrices (the activation traffic is halved) and hurts gate+up (+8% to +20%); more column segments help only down at 16 tokens (4) and cost a combine kernel everywhere else.
Estimate (isolated calls, not an engine run): replacing the production GEMM loop by these variants would save per 8-row pass 64 x 26.9 (gate+up) + 64 x 20.3 (down) + 48 x 13.7 (GDN in-proj) + 16 x 17.1 (attention qkv) + 64 x 13.6 (out projection) + 0.07 ms (head) = **4.9 ms** (about 10% of the 46 ms pass; the 16-row pass 4.5 ms).
The production epilogue (loading scales, offsets) accounts for the remaining ~8 us between ADDR=1 (235) and production (243) on gate+up.

### N3. What this settles
- The 17 us left unexplained in Part M are the 64-bit division / modulo (+7 us), the 64-bit loop counters and compares and the 64-bit multiplications of the address arithmetic (together +17 us to ADDR=0 / 1), plus ~8 us in the production prologue / epilogue: all integer overhead around identical loads and DPAS.
- With 32-bit arithmetic and plain pointer increments the same loop reaches the probe's time (216.6 against 216.0 us), which is 1.7% above the read-only kernel of the same layout (213.8 us): **gate+up is then within 2% of the read floor; the narrow matrices (out projection 52.7 us, floor 46 us from the fit) within 15%.**
- Not done: the production kernel was not modified; the variants were checked on random weights and activations against `xf_gemm`, not on the model's weights; the saving is an estimate from isolated calls.


## Part O. Pointer-bumped 32-bit addressing in the production 4-bit GEMM, and an assembly-level analysis of what limits it (XeFlash, B60)

### O1. What was changed in production (commit 3983e34)
`submit<..., PIPE=2>` in `kernels/gemm/gemm.cpp`: the pipelined integer loop forms the weight / activation addresses once before the loop, adds the constant tile size (weights) or the activation stride to running 64-bit pointers after every tile load, and uses a 32-bit trip counter and thread index
(`segs == 1 && tgroups == 1`, which is every engine shape at 1 / 8 / 16 rows with one segment, skips the division and modulo). The previous loop (`PIPE=1`) is compiled as well: `XF_GEMM_ADDR=old` selects it at run time, and `addr32_ok()` falls back to it automatically
when the thread count, the tile counters or `tiles * mpad * 8` would not fit 32 bits. Pointers stay 64-bit, so tensor sizes never enter a 32-bit computation; the largest shape (head, 248,320 x 5,120) has 15,520 threads, 160 tiles, 160 x 16 x 8 dwords of activation.
Float formats and s8 with 16-bit activations keep their old loops.

Checks: all six shapes at m = 1 / 8 / 16 are exact against the CPU reference with both loops; the logits of 1,600 teacher-forced tokens are bit-identical between old and new loop at pass sizes 1, 8 and 16, and between pass sizes (`benchmarks/results/m13/`).

### O2. Measured effect (1K context unless noted; `XF_GEMM_ADDR=old` against the default)
Unit benchmark, cold weights, best segment count of each loop (us):

| shape | weights | m | old loop, best segs (us) | new loop, best segs (us) | change | exact vs CPU reference (old / new) |
|---|---|---:|---:|---:|---:|---|
| out projection 5120x6144 | s4+16-bit act | 1 | 61.1 (segs 1) | 50.5 (segs 1) | -17.3% | exact / exact |
| out projection 5120x6144 | s4+16-bit act | 8 | 65.9 (segs 1) | 55.6 (segs 1) | -15.6% | exact / exact |
| out projection 5120x6144 | s4+16-bit act | 16 | 77.5 (segs 1) | 65.8 (segs 1) | -15.1% | exact / exact |
| down 5120x17408 | s4+16-bit act | 1 | 116.2 (segs 1) | 105.4 (segs 1) | -9.3% | exact / exact |
| down 5120x17408 | s4+16-bit act | 8 | 131.4 (segs 2) | 120.8 (segs 2) | -8.1% | exact / exact |
| down 5120x17408 | s4+16-bit act | 16 | 160.0 (segs 2) | 147.7 (segs 4) | -7.7% | exact / exact |
| gate+up 34816x5120 | s4+16-bit act | 1 | 230.2 (segs 1) | 207.5 (segs 1) | -9.9% | exact / exact |
| gate+up 34816x5120 | s4+16-bit act | 8 | 242.5 (segs 1) | 216.5 (segs 1) | -10.7% | exact / exact |
| gate+up 34816x5120 | s4+16-bit act | 16 | 253.6 (segs 1) | 226.8 (segs 1) | -10.6% | exact / exact |
| GDN in-proj 16384x5120 | s4+16-bit act | 1 | 111.3 (segs 1) | 102.3 (segs 1) | -8.1% | exact / exact |
| GDN in-proj 16384x5120 | s4+16-bit act | 8 | 115.3 (segs 1) | 103.2 (segs 1) | -10.5% | exact / exact |
| GDN in-proj 16384x5120 | s4+16-bit act | 16 | 118.7 (segs 1) | 105.9 (segs 1) | -10.8% | exact / exact |
| attention qkv 14336x5120 | s4+16-bit act | 1 | 103.4 (segs 1) | 92.3 (segs 1) | -10.7% | exact / exact |
| attention qkv 14336x5120 | s4+16-bit act | 8 | 106.7 (segs 1) | 94.7 (segs 1) | -11.2% | exact / exact |
| attention qkv 14336x5120 | s4+16-bit act | 16 | 109.0 (segs 1) | 96.6 (segs 1) | -11.4% | exact / exact |
| lm_head 248320x5120 | s4+16-bit act | 1 | 1472.7 (segs 1) | 1442.8 (segs 1) | -2.0% | exact / exact |
| lm_head 248320x5120 | s4+16-bit act | 8 | 1571.0 (segs 1) | 1508.7 (segs 1) | -4.0% | exact / exact |
| lm_head 248320x5120 | s4+16-bit act | 16 | 1770.8 (segs 1) | 1567.2 (segs 1) | -11.5% | exact / exact |
| out projection 5120x6144 | s3+16-bit act | 1 | 70.3 (segs 1) | 54.4 (segs 1) | -22.6% | exact / exact |
| out projection 5120x6144 | s3+16-bit act | 8 | 59.9 (segs 4) | 46.0 (segs 4) | -23.2% | exact / exact |
| out projection 5120x6144 | s3+16-bit act | 16 | 73.6 (segs 2) | 56.1 (segs 1) | -23.8% | exact / exact |
| down 5120x17408 | s3+16-bit act | 1 | 144.3 (segs 1) | 115.3 (segs 1) | -20.1% | exact / exact |
| down 5120x17408 | s3+16-bit act | 8 | 117.7 (segs 4) | 100.8 (segs 4) | -14.4% | exact / exact |
| down 5120x17408 | s3+16-bit act | 16 | 139.8 (segs 4) | 140.5 (segs 4) | +0.5% | exact / exact |
| gate+up 34816x5120 | s3+16-bit act | 1 | 194.4 (segs 1) | 176.5 (segs 1) | -9.2% | exact / exact |
| gate+up 34816x5120 | s3+16-bit act | 8 | 221.8 (segs 1) | 183.0 (segs 1) | -17.5% | exact / exact |
| gate+up 34816x5120 | s3+16-bit act | 16 | 242.1 (segs 1) | 239.3 (segs 1) | -1.2% | exact / exact |
| GDN in-proj 16384x5120 | s3+16-bit act | 1 | 96.8 (segs 1) | 81.8 (segs 1) | -15.5% | exact / exact |
| GDN in-proj 16384x5120 | s3+16-bit act | 8 | 106.3 (segs 1) | 87.9 (segs 1) | -17.3% | exact / exact |
| GDN in-proj 16384x5120 | s3+16-bit act | 16 | 118.7 (segs 1) | 112.0 (segs 1) | -5.6% | exact / exact |
| attention qkv 14336x5120 | s3+16-bit act | 1 | 83.8 (segs 1) | 73.3 (segs 1) | -12.5% | exact / exact |
| attention qkv 14336x5120 | s3+16-bit act | 8 | 97.8 (segs 1) | 79.0 (segs 1) | -19.2% | exact / exact |
| attention qkv 14336x5120 | s3+16-bit act | 16 | 106.4 (segs 1) | 98.9 (segs 1) | -7.0% | exact / exact |

Real pass, no per-kernel synchronisation (m = 1 / 8 / 16 rows): **37.7 / 42.0 / 48.1 ms new against 41.2 / 45.8 / 52.1 ms old** (-3.5 / -3.8 / -4.0 ms); GEMM sum of the synchronised profile (8 rows) 40.05 -> 36.31 ms. (An earlier message of this session quoted the 1-row column as the 8-row pass; the 8-row figures are these.)
The sum of the unit benchmarks for one 8-row pass (64 gate+up, 64 down, 48 GDN in-proj, 16 attention qkv, 64 out projections, 1 head) is 36.96 -> 33.12 ms against a read-floor fit (10.8 us + MB / 440 GB/s per call) of 31.86 ms: **16% above the floor before, 4% after**
(gate+up +2%, attention qkv +1%, GDN in-proj -3%, down +8%, out projection +20%, head +4%).

End to end, bdraft2, same prompts and token counts, tokens and committed state identical to the old loop in every run (`benchmarks/results/m13/e2e_*.json`):

| context | config | old tok/s | new tok/s | gain | main pass old→new (ms) | tok/cycle | tokens & state identical |
|---|---|---:|---:|---:|---|---:|---|
| code | fixed8 | 115.0 | 123.7 | +7.5% | 45.9→42.1 | 6.17 | True |
| code | fixed16 | 132.9 | 142.3 | +7.1% | 52.1→48.1 | 8.08 | True |
| code | adapt-cost | 130.6 | 139.9 | +7.1% | 51.4→47.5 | 7.83 | True |
| 8k | fixed8 | 62.7 | 67.1 | +7.2% | 48.4→44.6 | 3.53 | True |
| 8k | fixed16 | 55.8 | 59.6 | +6.7% | 55.8→51.8 | 3.62 | True |
| 8k | adapt-cost | 61.2 | 65.6 | +7.3% | 49.6→45.7 | 3.53 | True |
| 30k | fixed8 | 52.0 | 55.3 | +6.3% | 55.6→51.9 | 3.31 | True |
| 30k | fixed16 | 47.3 | 50.0 | +5.7% | 66.0→62.0 | 3.55 | True |
| 30k | adapt-cost | 51.9 | 55.1 | +6.3% | 55.9→52.1 | 3.31 | True |
| 48k | fixed8 | 46.2 | 48.8 | +5.7% | 61.7→57.9 | 3.21 | True |
| 60k | fixed8 | 42.7 | 44.9 | +5.3% | 65.3→61.5 | 3.12 | True |

The Main pass shortens by 3.7 to 4.0 ms at every context; the tok/s gain is smaller than the GEMM gain (about 6 to 7% of the cycle) because a cycle also holds the drafter (6.1 ms) and 1.7 ms of host / read-back time, which did not change.

### O3. Hot-loop instructions, old against new (gate+up, 8 rows, one trip = 4 tiles; `tools/profile/isa_analyze.py`, IGC dump -> ocloc disasm for `bmg`)
| per trip | old loop (PIPE=1) | new loop (PIPE=2) | removed |
|---|---:|---:|---:|
| instructions | 91 | 40 | 51 |
| `send.ugm` loads (12 x 256 B: 4 weight, 8 activation) | 12 | 12 | 0 |
| `dpas.8x8` (s4 x s8 / u8, `:s4` weights fed straight to the DPAS, **no unpack instructions exist in the loop**) | 8 | 8 | 0 |
| integer ALU | 27 | 13 | 14 |
| 32-bit `mul` + 64-bit `macl` / `mach` multiplies | 12 + 12 | 0 | 24 |
| `mov` | 10 | 0 | 10 |
| `cmp` | 3 | 1 | 2 |
| `sync` (scoreboard waits) | 5 | 4 | 1 |
| branches (back edge + early-exit of the 2-stage pipeline) | 2 | 2 | 0 |
| issue spread of the 12 loads (instructions between first and last) | 42 | 16 | 26 |
| loads issued before the first scoreboard wait | 5 | 6 | +1 |
Other tokens: m = 1: 98 -> 48 instructions (12 loads of 256 B / 32 B, 8 DPAS), m = 16 (2 tiles per trip): 58 -> 36 (10 loads, 8 DPAS).
- **The DPAS and load streams are identical; the removed instructions are the 64-bit address multiplications (`mul`/`macl`/`mach`/`add3` chains rebuilt per tile from the run-time strides), their `mov`s and the 64-bit loop compare.** Every `send` of the old loop waited on an integer dependency (`I@n`) of that chain, so the loads left the thread over 42 instructions instead of 16.
- Dynamic count for gate+up, 8 rows: 2,176 threads x 40 trips = 87,040 trips; 51 instructions per trip fewer = **4.44 M thread-instructions removed per call** (old 7.92 M, new 3.48 M). Spread over 160 EUs and issued at 1 per clock that is 27.7 K instructions per EU = 11.6 us at 2.4 GHz;
  the measured gain is 27 us (243.5 -> 216.5). So the gain is more than the issue slots: it is the earlier load issue (estimate; the instruction-level timing cannot be measured, hardware counters are not available, see O6).
- The 64-bit division / modulo emulation (`call` into IGC's helper routines, 3 call sites in the prologue) exists in both kernels; in the new one it runs only when `segs > 1` or `tgroups > 1` (down projection, 2 segments): about 3 calls per thread, once.
- GRF 128 for every variant (8 threads per EU, 1,280 resident), no scratch / spill send, no SLM, no barrier, no predicate save / restore (`mov` to a flag register in the loop: 0), no `cvt`-type conversions in the loop.
- The DPAS group: 4 independent accumulators (two s8 / u8 planes x two unrolled tiles), two updates each per trip, at least 1 other DPAS between dependent updates (m = 8 new) and 3 for the old order; 6 of the 8 `dpas` are `{Atomic}`-chained in groups of 4. The XMX is not waiting on its own dependencies (see O5: DPAS alone takes 9 to 37% of the call).
- Load messages: `load.ugm.d32x64t.a64` for the weights (256 B, contiguous 256 B per tile, the tiles of a thread are consecutive: stride 256 B, other threads are `tiles x 256` B = 40 KB away), the same message for the activation planes (identical address in every thread: served from L1 / L2),
  no cache-control suffix (default policy), 64-bit addresses (`.a64`), immediate offsets `flat[A+0x100..0x300]` used for four tiles; all in one `send` each, no SLM.

### O4. Static and dynamic counts per shape (new loop, 1 / 8 / 16 rows; engine segment counts; "load-pipe MB" = bytes delivered by the load messages, i.e. weights **plus the activation planes re-read by every thread**)

| shape | m | prod. time us | eff. read GB/s | threads (thr/EU, waves of 1280) | trips x dpas/trip = DPAS per thread | DPAS per call (dynamic) | loads per call (dyn.), load-pipe MB | int ALU+mul+mov+cmp per call (M) | sync waits / trip | weights-only us | DPAS-only us (XMX busy %) | full / weights-only | dominant bottleneck |
|---|---:|---:|---:|---|---|---:|---|---:|---:|---:|---|---:|---|
| gate+up | 1 | 207.8 | 429 | 2176 (8.0, 1.70) | 40 x 8 | 0.70 M | 1.04 M, 134 | 1.2 | 12 | 210.2 | 18.9 (9%) | 0.99 | weight stream (DRAM); XMX waits for data |
| gate+up | 8 | 217.0 | 411 | 2176 (8.0, 1.70) | 40 x 8 | 0.70 M | 1.04 M, 267 | 1.2 | 4 | 218.1 | 40.2 (19%) | 1.00 | weight stream (DRAM); XMX waits for data |
| gate+up | 16 | 226.9 | 393 | 2176 (8.0, 1.70) | 80 x 8 | 1.39 M | 1.74 M, 446 | 1.9 | 4 | 227.0 | 75.8 (33%) | 1.01 | weight stream (DRAM); XMX waits for data |
| down | 1 | 105.6 | 422 | 320 (2.0, 0.25) | 136 x 8 | 0.35 M | 0.52 M, 67 | 0.6 | 12 | 103.1 | 15.7 (15%) | 1.02 | weight stream (DRAM); XMX waits for data |
| down | 8 | 121.2 | 368 | 640 (4.0, 0.50) | 68 x 8 | 0.35 M | 0.52 M, 134 | 0.6 | 4 | 116.2 | 18.0 (17%) | 0.92 | weight stream; segmented K-split (extra loads in flight help) + combine kernel / 2-way split |
| down | 16 | 148.9 | 299 | 640 (4.0, 0.50) | 136 x 8 | 0.70 M | 0.87 M, 223 | 1.0 | 4 | 115.4 | 32.9 (27%) | 1.06 | weight stream + activation-load traffic (X/XL loads add 6% over weights alone; 640 threads) + combine kernel / 2-way split |
| out proj | 1 | 50.4 | 312 | 320 (2.0, 0.25) | 48 x 8 | 0.12 M | 0.18 M, 24 | 0.2 | 12 | 49.9 | 6.5 (13%) | 1.01 | weight stream (DRAM); XMX waits for data |
| out proj | 8 | 55.8 | 282 | 320 (2.0, 0.25) | 48 x 8 | 0.12 M | 0.18 M, 47 | 0.2 | 4 | 50.5 | 12.6 (22%) | 1.12 | weight stream + activation-load traffic (X/XL loads add 12% over weights alone; 320 threads) |
| out proj | 16 | 65.2 | 241 | 320 (2.0, 0.25) | 96 x 8 | 0.25 M | 0.31 M, 79 | 0.3 | 4 | 55.4 | 23.7 (36%) | 1.18 | weight stream + activation-load traffic (X/XL loads add 18% over weights alone; 320 threads) |
| attn qkv | 1 | 92.7 | 396 | 896 (5.6, 0.70) | 40 x 8 | 0.29 M | 0.43 M, 55 | 0.5 | 12 | 89.6 | 9.7 (10%) | 1.03 | weight stream (DRAM); XMX waits for data |
| attn qkv | 8 | 95.1 | 386 | 896 (5.6, 0.70) | 40 x 8 | 0.29 M | 0.43 M, 110 | 0.5 | 4 | 92.8 | 18.7 (20%) | 1.02 | weight stream (DRAM); XMX waits for data |
| attn qkv | 16 | 97.0 | 378 | 896 (5.6, 0.70) | 80 x 8 | 0.57 M | 0.72 M, 184 | 0.8 | 4 | 94.9 | 36.1 (37%) | 1.02 | weight stream (DRAM); XMX waits for data |
| GDN in-proj | 1 | 101.2 | 414 | 1024 (6.4, 0.80) | 40 x 8 | 0.33 M | 0.49 M, 63 | 0.6 | 12 | 99.1 | 9.7 (10%) | 1.02 | weight stream (DRAM); XMX waits for data |
| GDN in-proj | 8 | 103.7 | 404 | 1024 (6.4, 0.80) | 40 x 8 | 0.33 M | 0.49 M, 126 | 0.6 | 4 | 103.3 | 18.7 (18%) | 1.00 | weight stream (DRAM); XMX waits for data |
| GDN in-proj | 16 | 105.9 | 396 | 1024 (6.4, 0.80) | 80 x 8 | 0.66 M | 0.82 M, 210 | 0.9 | 4 | 107.0 | 36.1 (34%) | 0.99 | weight stream (DRAM); XMX waits for data |

Reading the table: the load pipe carries 3.0x (8 rows), 5.0x (16 rows) and 1.5x (1 row) the weight bytes, because every thread re-reads the activation tiles of its token group (from cache, not DRAM).
The threads per EU are an upper bound from the GRF count (8 at 128 GRF); the actual number resident at one time was not observed.

### O5. Isolating load, DPAS and their combination on the production layout and shapes (`kernels/probe/gemm_modes.cpp`, new loop, main kernel only, no combine kernel; us)
Raw output: `benchmarks/results/m14/modes_all.txt`. Same thread layout, tile loop and epilogue as xf_gemm; modes 1 to 4 compute nothing useful. Times are **not added**: the question is whether they overlap.
- **Mode 0 (full) is equal to mode 1 (weights read only) within 0 to 3% for gate+up, GDN in-proj, attention qkv and down at 1 row; the DPAS adds nothing**. Example gate+up, 8 rows: full 217.1, weights only 218.1, all loads without DPAS 218.6, weights + DPAS with resident activations 217.9, **DPAS only 40.2**.
  (Loads and DPAS overlap completely: 218.1 + 40.2 would be 258 if they were serial.)
- The XMX is therefore **idle 64 to 91% of the call waiting for data** (XMX busy: 9% at 1 row, 17 to 22% at 8 rows, 27 to 37% at 16 rows); it would not matter if it were infinitely fast. The effective rate is 13.1 TFLOPS (F = 2MNK) at 8 rows (25.0 at 16 rows),
  26 TOPS of executed int8 DPAS work (two planes) = 13% of the 196.5 TOPS peak; DPAS alone reaches 71 TFLOPS-equivalent (36% of that peak, 40.2 us at 2,176 threads).
- Exceptions where the activation loads show up: out projection (320 threads, 2 per EU): full 56.4 against weights only 50.5 at 8 rows (+12%), 65.2 against 55.4 at 16 rows (+18%); in mode 2 the all-loads kernel already costs the same as the full kernel (57.1 / 64.4). With only 320 threads a thread has too few weight loads in flight when the activation loads share its scoreboard.
  Down with 2 segments (640 threads): the weights-only kernel is slower (116.2) than the full kernel (107.1) at 8 rows, i.e. extra loads in flight help; at 16 rows it is the other way (+6%).
- 4-bit unpacking is not part of the production loop (the DPAS takes `s4` weights directly), so there is no "unpack only" run for production. The earlier expansion experiment (s4 -> s8, Part M) costs +9 to +26% and is not used.

### O6. Hardware counters
XMX utilisation, EU stall, cache hit rates and memory bandwidth counters are not available on this system (Level Zero metrics / `zet` tracing fails for the card, no `nsys` / `ncu` equivalent installed; measured in Part L and not re-attempted here). **Everything above on stalls is inferred from the ISA, the scoreboard structure and the isolation kernels, not measured with counters.**
Estimates marked as such: (a) the in-flight bytes needed for 440 GB/s at an assumed 0.8 us load latency (latency not measured) are about 350 KB; the narrow shapes (320 threads x ~1.5 KB of outstanding weight loads) sit near that, the wide ones (2,176 threads) far above it.

### O7. Where the time goes now, per shape (8 rows, new loop)
| shape | time us | weights-only us | read floor fit us | gap to floor | dominant bottleneck (from the table and O5) |
|---|---:|---:|---:|---:|---|
| gate+up | 216.5 | 218.1 | 213.3 | +1.5% | weight stream; nothing left to remove |
| GDN in-proj | 103.2 | 103.3 | 106.0 | -3% | weight stream |
| attention qkv | 94.7 | 92.8 | 94.2 | +0.5% | weight stream |
| down (2 segments) | 120.8 | 116.2 | 112.2 | +8% | weight stream split in two, + combine kernel + per-thread division in the prologue |
| out projection | 55.6 | 50.5 | 46.5 | +20% | too few threads (320), activation loads cost 5 us on top of the weights |
| head | 1,508.7 | n/a | 1,455.6 | +4% | weight stream, 12 waves of threads |

### O8. Candidates supported by the assembly and the isolation runs, ordered by expected saving per 8-row pass
1. **Down projection with one segment (or another split that avoids the combine kernel): about 10 us per call, 64 calls = 0.6 ms per pass.** Basis: `gemm_variants` (Part N) reached 111.4 us with one segment and U = 2 against 120.8 us; the ISA shows the three division `call`s in the 2-segment prologue and the combine is a separate launch (about 13 us above the 107.1 us main kernel).
   (16 rows: the 4-segment variant gained only 2 us.) Expected: 0.6 ms of 42 ms (1.5%).
2. **Out projection: remove the 5 us (8 rows) / 10 us (16 rows) that the activation loads add to the weight stream: 5 us x 64 = 0.3 ms per pass (16 rows 0.6 ms).** Basis: mode 0 against mode 1 (O5) and the ISA: 8 of the 12 loads per trip are activation tiles that every thread re-reads. Options not yet tried: keep the two activation planes in registers across several row blocks (RB = 2 gave 52.7 us in Part N), or a larger group of loads in flight for the weight stream.
3. **Attention qkv and GDN in-proj with two row blocks per thread (activation tiles loaded once for both): 5 us x 16 + 1.6 us x 48 = about 0.16 ms per pass** (Part N variants 89.7 and 101.6 us against 94.7 and 103.2 now).
Not an assembly finding but visible in the table: the head is 53 us above its read floor (12 waves of threads, the last wave partly empty), estimated 0.05 ms per pass. Gate+up, GDN in-proj and attention qkv (together 29 of the 36 ms of 8-row GEMM time) are within 0 to 2% of the weight-stream time of the same kernel without DPAS: **no instruction-level change can reduce them; only fewer bytes per weight can** (the format work, which stays paused).

### O9. Not done / caveats
- Production kernels were not changed in the analysis step. The mode kernels are copies of the new loop in `kernels/probe/gemm_modes.cpp` (R, G, U and the epilogue as in production; row and thread mapping identical); the production time is printed in the same run for reference and agrees within 1 us (gate+up 8 rows 217.0 against 217.1).
- No hardware counters (O6). Dynamic instruction counts are the static loop size times trips times threads; prologue / epilogue instructions (about 130 / 380 to 900 static, once per thread) and cache effects are not included.
- Load and DPAS isolation was done with cold, random weights and activations (data-independent timing is assumed for the DPAS; fixed patterns would be faster).
- YASAKANI / 5060 Ti comparison of tokens per second per cycle (the request that preceded this one) is still to be done; its data collection is not part of this part.


## Part P. VTune GPU hardware counters for the production 4-bit GEMM (B60, Arc Pro B60 / Battlemage G21)

### P1. Setup (and what was needed)
Intel VTune Profiler 2026.6.0 was installed from the oneAPI apt repository (`intel-oneapi-vtune`, with the user's agreement). Its self-check fails for the CPU-side analyses (`CPU name: Unknown`, the i7-8700 host is not recognised, no sampling driver),
but **`gpu-hotspots` works with GPU metrics**: `vtune -collect gpu-hotspots -knob characterization-mode=overview | compute-extended | instruction-count -- scripts/b60run ... xf-bench --cold --format s4 --shape S --tokens M --segs N`.
Needed for it: `kernel.yama.ptrace_scope=0`, `kernel.perf_event_paranoid=0`, `kernel.kptr_restrict=0` (set with sudo for the measurement and **restored afterwards to 1 / 4 / 1**). `collect-memory-bandwidth` needs the CPU sampling driver and is not available; the "GPU Memory Bandwidth" columns of the GPU metric sets are.
This replaces the statement of Parts L / O6 that no hardware counters exist: they exist through VTune; Level Zero metrics from our own code were never needed.
Raw data: `benchmarks/results/m15/*.csv` (one file per kernel / shape / loop), the tables below are generated from them (`vtune_overview.md`, `vtune_instr.md`). Each number is the average over 7,000 to 10,000 kernel instances of the benchmark (cold weights, ~210 us per call for gate+up).
Overhead of the collection: the average kernel times in the VTune runs (216 / 107 / 103 / 95 / 56 us for gate+up / down / GDN in-proj / attention qkv / out projection, 8 rows) equal the unprofiled ones, so the counters describe the normal runs.

### P2. Counters per shape, rows 1 / 8 / 16, new loop (and old loop for 8 rows) — `GPU Time` basis, XVE = the 160 execution units
Stall columns are the share of XVE stalled time attributed to each reason (several reasons can hold at the same time, so they do not add up). SBID = waiting for the result of an earlier load (`send`), Send = the load could not be issued because the send / memory queue was full, Dist/Acc = dependency on a previous ALU / accumulator result.

| shape | m | loop | avg us | XVE active % | stalled % | idle % | thread occupancy % | XMX pipe active % | stall SBID % | stall Send % | stall Dist/Acc % | stall Pipe % | L3 miss % | DRAM read GB/s |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| gate+up | 1 | new | 207.0 | 3.8 | 76.2 | 20.0 | 76.5 | 1.6 | 75.1 | 71.4 | 4.1 | 0.0 | 99.1 | 404 |
| down | 1 | new | 105.0 | 3.3 | 40.2 | 56.5 | 21.6 | 1.5 | 40.1 | 10.5 | 2.3 | 0.0 | 99.2 | 379 |
| GDN in-proj | 1 | new | 102.0 | 3.4 | 65.8 | 30.8 | 58.4 | 1.5 | 65.0 | 52.3 | 3.1 | 0.0 | 99.0 | 362 |
| attn qkv | 1 | new | 92.0 | 3.3 | 62.1 | 34.7 | 48.3 | 1.4 | 61.5 | 41.7 | 2.8 | 0.0 | 99.0 | 347 |
| out proj | 1 | new | 50.0 | 2.3 | 34.9 | 62.8 | 18.1 | 1.0 | 34.7 | 10.9 | 1.8 | 0.0 | 98.7 | 243 |
| gate+up | 8 | new | 216.0 | 8.7 | 71.4 | 19.9 | 77.2 | 12.6 | 71.5 | 67.8 | 4.0 | 0.1 | 95.7 | 391 |
| gate+up | 8 | old | 242.0 | 19.1 | 63.1 | 17.8 | 78.0 | 11.3 | 62.2 | 54.3 | 8.3 | 1.9 | 96.2 | 349 |
| down | 8 | new | 107.0 | 14.1 | 66.1 | 19.8 | 44.2 | 9.8 | 65.3 | 34.6 | 3.6 | 0.1 | 96.6 | 304 |
| down | 8 | old | 118.0 | 19.4 | 61.7 | 18.9 | 44.3 | 9.1 | 59.0 | 1.0 | 9.7 | 1.4 | 96.6 | 284 |
| GDN in-proj | 8 | new | 103.0 | 8.1 | 66.0 | 25.9 | 62.2 | 11.7 | 66.1 | 55.5 | 3.4 | 0.1 | 96.2 | 352 |
| GDN in-proj | 8 | old | 115.0 | 18.0 | 56.5 | 25.5 | 62.8 | 10.6 | 55.1 | 36.3 | 8.5 | 1.8 | 96.0 | 325 |
| attn qkv | 8 | new | 95.0 | 7.6 | 62.2 | 30.1 | 51.5 | 11.0 | 62.3 | 46.4 | 3.1 | 0.1 | 96.4 | 341 |
| attn qkv | 8 | old | 107.0 | 16.9 | 53.8 | 29.4 | 52.2 | 10.0 | 51.7 | 23.7 | 8.7 | 1.7 | 96.0 | 306 |
| out proj | 8 | new | 56.0 | 5.1 | 33.1 | 61.8 | 18.7 | 7.4 | 33.1 | 15.3 | 2.0 | 0.0 | 93.3 | 228 |
| out proj | 8 | old | 66.0 | 10.2 | 29.5 | 60.3 | 19.5 | 6.5 | 27.2 | 0.6 | 6.8 | 1.0 | 93.3 | 204 |
| gate+up | 16 | new | 227.0 | 15.3 | 70.1 | 14.6 | 77.2 | 24.1 | 67.7 | 57.7 | 1.2 | 0.1 | 95.2 | 373 |
| down | 16 | new | 124.0 | 22.7 | 61.5 | 15.9 | 48.9 | 16.6 | 59.7 | 31.6 | 2.2 | 0.1 | 94.2 | 255 |
| GDN in-proj | 16 | new | 106.0 | 14.5 | 66.4 | 19.1 | 66.1 | 22.9 | 64.6 | 48.6 | 0.8 | 0.1 | 93.8 | 356 |
| attn qkv | 16 | new | 96.0 | 13.9 | 64.1 | 22.0 | 56.0 | 21.9 | 62.6 | 39.6 | 0.7 | 0.1 | 94.6 | 339 |
| out proj | 16 | new | 66.0 | 8.2 | 31.9 | 59.9 | 19.1 | 12.9 | 31.5 | 2.0 | 0.7 | 0.0 | 89.0 | 196 |

### P3. Instructions per call measured by the counters (cold gate+up and out projection, 8 rows)
| kernel | loop | calls measured | send / call (M) | DPAS / call (M) (XMX instr / 8) | ALU1 / call (M) | ALU0 / call (M) | INT64 / call (M) | INT16 / call (M) | control / call (M) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| gate+up m=8 | old | 7372 | 1.04 | 0.66 | 13.17 | 0.62 | 3.65 | 1.47 | 0.50 |
| gate+up m=8 | new | 8152 | 1.03 | 0.66 | 1.55 | 0.14 | 1.06 | 0.02 | 0.09 |
| out proj m=8 | old | 10002 | 0.16 | 0.10 | 1.85 | 0.08 | 0.51 | 0.20 | 0.07 |
| out proj m=8 | new | 10002 | 0.16 | 0.10 | 0.22 | 0.02 | 0.16 | 0.00 | 0.01 |

(XMX instructions are counted 8 per `dpas`, hence the division; ALU1 is the integer / FP pipe that executes the address arithmetic.) Measured send count 1.03 M and DPAS 0.66 M per gate+up call agree with the static estimate of Part O (1.04 M / 0.70 M); **the old loop executes 8.5x the ALU1 instructions of the new one (13.2 M against 1.55 M)**,
more than the 2.3x of the static instruction count, because the 32 x 32 and 64-bit multiplies are issued as several 16-bit passes (INT16: 1.47 M -> 0.02 M per call, INT64 3.65 M -> 1.06 M). The loads and DPAS are the same.

### P4. What the counters say
1. **The XMX is idle about 88% of the time at 8 rows** (pipe active 11 to 13% for the four wide shapes, 7% for the out projection); 22 to 24% at 16 rows; 1.5% at 1 row. The XVE array is stalled 62 to 76% of the time (wide shapes), and **the dominant stall reason is SBID (62 to 72%): threads waiting for load results**,
   together with Send stalls (40 to 68%: the memory pipe does not accept more requests). ALU, instruction-fetch, control and pipe stalls are 0 to 4%. This is the signature of a memory-system-limited kernel, now measured, not inferred.
2. **Old against new loop (gate+up, 8 rows)**: XVE active 19.1% -> 8.7%, ALU1 pipe active 14.1% -> 1.9%, Dist/Acc stall 8.3% -> 4.0%, Send stall 54% -> 68% (the loads now arrive faster than the memory system takes them), DRAM read 349 -> 391 GB/s, time 242 -> 216 us.
   The same for the other shapes (down 118 -> 107, GDN in-proj 115 -> 103, attention qkv 107 -> 95, out projection 66 -> 56 us): ALU pipe load falls by 6 to 12 points and the DRAM read rate rises 8 to 12%.
3. **Wide shapes** (gate+up, GDN in-proj, attention qkv): thread occupancy 48 to 77% (the tail wave), L3 miss ratio 94 to 99% (the weights stream through), DRAM read 341 to 404 GB/s as measured by the counters (gate+up 404 at 1 row, 391 at 8, 373 at 16).
   VTune's GB/s is an average over its sampling windows, so it is lower than bytes / time (gate+up 8 rows: 412 GB/s by time, 391 by counters; out projection 280 / 228; down 417 / 304 because the second kernel and the gaps lie in the same windows): use it for comparing loops, not as the bandwidth.
4. **Narrow shapes** (out projection 320 threads, down 640): thread occupancy 18.7% and 44% (`Work Size Limit` 25% / 50%: the launch has too few threads), XVE idle 62% (out projection) and 20% (down); stalled 33% and 66%. The out projection is **idle, not stalled**: the machine does not hold enough loads in flight.
   This agrees with Part O5 (activation loads slow the narrow kernel by 12 to 18% while the wide ones are unaffected) and with the segment-count effect of Part I4.
5. **Not obtained**: per-instruction / basic-block stall attribution (the `source-analysis` mode collected data, but the JIT-compiled ESIMD kernels have no code-location mapping in the report: addresses are `[Unknown]`); the cache hit rate of the activation loads in L1 (only L3 metrics exist: L3 miss ratio 89 to 99% of the traffic that reaches L3).

### P5. Consequences for the candidates of Part O8
- The counters confirm that no instruction-level work is left in the three wide shapes: ALU stalls 4% or less, instruction mix = loads + DPAS, XMX pipe waiting for SBID.
- The measurable inefficiency is concentrated in the narrow shapes, where the cause is **occupancy / too little memory parallelism** (O 18.7% occupancy, idle 62%): candidates remain (1) more loads in flight per thread (a deeper software pipeline, 3 stages) or more threads per matrix for the 5,120-row shapes, (2) one segment instead of two for down, (3) shared activation loads (RB = 2) for the 14 to 16 thousand-row matrices.
  Each of them is a kernel change; none was made here. The expected gains are those of Part O8 (estimates; the counters do not give a number for them).


## Part Q. Work-group launch of the 4-bit GEMM for 8 / 16 rows, and down with one segment (adopted)

### Q1. The finding and the change
In the variant sweep of Part N the best configurations for the 5,120-row matrices always carried `local=4`. A plain `parallel_for(range)` lets the runtime choose a work-group of **32 threads** (VTune shows `Work Size:Local = 32`); a work-group cannot span Xe cores, so the 320 threads of a 5,120-row matrix
(and the 640 of down with two segments) are packed into groups of 32 that the dispatcher places on a few cores. `kernels/gemm/gemm.cpp`: the pointer-bumped loop (`PIPE == 2`) is now launched with `nd_range<1>(threads, XF_GEMM_WG)` (default **4**) **when tokens_per_thread is 8 or 16**; if the thread count is not divisible by the work-group size, or for 1 row per thread, the plain launch is used.
`kernels/model/model.cpp`: with the small work-group, down (5,120 x 17,408) uses **one segment** (no combine kernel, no division in the prologue) instead of two.
Switch back: `XF_GEMM_WG=0` (or 1) restores both the plain launch and the two segments of down. The thread body is the same code (`run` lambda), results unchanged. The 1-row kernel keeps the plain launch (Q4); `XF_GEMM_WG_M1=n` is an experiment-only switch for it (default 0).

### Q2. Unit benchmark, before (`XF_GEMM_WG=0`: plain launch, down 2 segments) and after (default), cold weights, us
| shape | m | before (XF_GEMM_WG=0) us | after (default) us | change | exact vs CPU (before/after) |
|---|---:|---:|---:|---:|---|
| out_proj | 1 | 50.7 (segs 1) | 50.4 (segs 1) | -0.6% | exact/exact |
| out_proj | 8 | 55.8 (segs 1) | 50.9 (segs 1) | -8.8% | exact/exact |
| out_proj | 16 | 63.5 (segs 1) | 57.1 (segs 1) | -10.1% | exact/exact |
| mlp.down | 1 | 105.4 (segs 1) | 105.4 (segs 1) | +0.0% | exact/exact |
| mlp.down | 8 | 120.8 (segs 2) | 111.3 (segs 1) | -7.9% | exact/exact |
| mlp.down | 16 | 142.9 (segs 2) | 132.0 (segs 1) | -7.6% | exact/exact |
| merged.gate_up | 1 | 207.4 (segs 1) | 207.5 (segs 1) | +0.0% | exact/exact |
| merged.gate_up | 8 | 216.4 (segs 1) | 216.6 (segs 1) | +0.1% | exact/exact |
| merged.gate_up | 16 | 228.1 (segs 1) | 227.7 (segs 1) | -0.2% | exact/exact |
| merged.qkvz | 1 | 102.4 (segs 1) | 102.4 (segs 1) | +0.0% | exact/exact |
| merged.qkvz | 8 | 103.3 (segs 1) | 101.9 (segs 1) | -1.4% | exact/exact |
| merged.qkvz | 16 | 106.5 (segs 1) | 104.5 (segs 1) | -1.9% | exact/exact |
| merged.attn_qkv | 1 | 92.5 (segs 1) | 92.5 (segs 1) | +0.0% | exact/exact |
| merged.attn_qkv | 8 | 94.8 (segs 1) | 91.6 (segs 1) | -3.4% | exact/exact |
| merged.attn_qkv | 16 | 96.9 (segs 1) | 91.9 (segs 1) | -5.2% | exact/exact |
| lm_head | 1 | 1442.7 (segs 1) | 1442.6 (segs 1) | -0.0% | exact/exact |
| lm_head | 8 | 1508.5 (segs 1) | 1500.5 (segs 1) | -0.5% | exact/exact |
| lm_head | 16 | 1567.9 (segs 1) | 1560.7 (segs 1) | -0.5% | exact/exact |

Work-group size and segment count separated (same data, every segment count of each launch, `benchmarks/results/m16/gemm_wg.txt`; before = plain launch, after = work-group 4):
| shape | m | before: best (segs) us | after: best (segs) us | change | segs 1 / 2 / 4 before | segs 1 / 2 / 4 after | exact (before/after) |
|---|---:|---|---|---:|---|---|---|
| out projection 5120x6144 | 1 | 50.4 (1) | 56.0 (1) | +11.1% | 50.4 / nan / nan | 56.0 / nan / nan | exact / exact |
| out projection 5120x6144 | 8 | 55.8 (1) | 51.4 (1) | -7.9% | 55.8 / 73.9 / 95.5 | 51.4 / 73.8 / 95.4 | exact / exact |
| out projection 5120x6144 | 16 | 63.8 (1) | 57.1 (1) | -10.5% | 63.8 / 88.5 / 114.4 | 57.1 / 93.5 / 120.8 | exact / exact |
| down 5120x17408 | 1 | 105.4 (1) | 115.5 (1) | +9.6% | 105.4 / nan / nan | 115.5 / nan / nan | exact / exact |
| down 5120x17408 | 8 | 120.8 (2) | 111.3 (1) | -7.9% | 128.5 / 120.8 / 125.6 | 111.3 / 120.9 / 125.6 | exact / exact |
| down 5120x17408 | 16 | 142.8 (2) | 132.1 (1) | -7.5% | 156.7 / 142.8 / 149.0 | 132.1 / 143.7 / 149.2 | exact / exact |
| gate+up 34816x5120 | 1 | 207.4 (1) | 206.5 (1) | -0.4% | 207.4 / nan / nan | 206.5 / nan / nan | exact / exact |
| gate+up 34816x5120 | 8 | 216.4 (1) | 216.6 (1) | +0.1% | 216.4 / nan / nan | 216.6 / nan / nan | exact / exact |
| gate+up 34816x5120 | 16 | 228.0 (1) | 227.6 (1) | -0.2% | 228.0 / nan / nan | 227.6 / nan / nan | exact / exact |
| GDN in-proj 16384x5120 | 1 | 102.4 (1) | 103.3 (1) | +0.9% | 102.4 / nan / nan | 103.3 / nan / nan | exact / exact |
| GDN in-proj 16384x5120 | 8 | 103.3 (1) | 101.9 (1) | -1.4% | 103.3 / nan / nan | 101.9 / nan / nan | exact / exact |
| GDN in-proj 16384x5120 | 16 | 106.5 (1) | 104.5 (1) | -1.9% | 106.5 / nan / nan | 104.5 / nan / nan | exact / exact |
| attention qkv 14336x5120 | 1 | 92.4 (1) | 92.7 (1) | +0.3% | 92.4 / nan / nan | 92.7 / nan / nan | exact / exact |
| attention qkv 14336x5120 | 8 | 94.8 (1) | 91.8 (1) | -3.2% | 94.8 / nan / nan | 91.8 / nan / nan | exact / exact |
| attention qkv 14336x5120 | 16 | 96.8 (1) | 91.9 (1) | -5.1% | 96.8 / nan / nan | 91.9 / nan / nan | exact / exact |
| lm_head 248320x5120 | 1 | 1442.5 (1) | 1438.5 (1) | -0.3% | 1442.5 / nan / nan | 1438.5 / nan / nan | exact / exact |
| lm_head 248320x5120 | 8 | 1508.5 (1) | 1500.8 (1) | -0.5% | 1508.5 / nan / nan | 1500.8 / nan / nan | exact / exact |
| lm_head 248320x5120 | 16 | 1568.1 (1) | 1560.8 (1) | -0.5% | 1568.1 / nan / nan | 1560.8 / nan / nan | exact / exact |

- For down the work-group size is what helps: at 1 segment 128.5 -> 111.3 us (8 rows) and 156.7 -> 132.1 us (16 rows), at 2 or 4 segments the work-group changes nothing (120.8 / 120.9, 125.6 / 125.6; there the thread count already spreads). The segment count then matters only through the combine kernel: one segment with the work-group (111.3) beats the best of the old launch (120.8 with 2 segments) by 8%.
- Local sizes in the production build (us, 1 segment, `wg_sweep.txt`):

| shape | m | WG 0 | WG 1 | WG 2 | WG 4 | WG 8 | WG 16 | WG 20 | WG 32 | WG 40 | WG 64 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mlp.down | 8 | 128.8 | 128.6 | 111.2 | 111.3 | 111.3 | 112.8 | 112.0 | 128.5 | - | - |
| mlp.down | 16 | 156.7 | 156.6 | 131.9 | 132.1 | 132.1 | 132.3 | 135.3 | 156.7 | - | - |
| out_proj | 8 | 55.7 | 55.8 | 50.5 | 51.0 | 51.0 | 50.7 | 48.0 | 55.8 | - | - |
| out_proj | 16 | 63.9 | 63.9 | 57.0 | 57.0 | 56.9 | 57.6 | 57.4 | 63.5 | - | - |
| merged.attn_qkv | 8 | 94.9 | 94.7 | 91.7 | 91.7 | 91.7 | 91.7 | 94.8 | 94.8 | - | - |
| merged.attn_qkv | 16 | 96.9 | 96.9 | 94.2 | 91.9 | 91.9 | 91.3 | 96.9 | 96.9 | - | - |
| merged.qkvz | 8 | 103.3 | 103.3 | 102.0 | 101.9 | 102.4 | 107.8 | 103.3 | 103.4 | - | - |
| merged.qkvz | 16 | 106.5 | 106.4 | 106.5 | 104.5 | 104.6 | 108.7 | 106.5 | 106.4 | - | - |
| merged.gate_up | 8 | 216.4 | 216.4 | 216.3 | 216.6 | 216.8 | 218.2 | 216.3 | 216.4 | - | - |
| merged.gate_up | 16 | 228.1 | 228.0 | 227.7 | 227.7 | 227.9 | 227.4 | 228.0 | 228.1 | - | - |
| mlp.down | 1 | 105.4 | - | 115.5 | 115.3 | 115.6 | 115.0 | 105.0 | 105.4 | 114.0 | 165.8 |
| out_proj | 1 | 50.6 | - | 55.7 | 55.8 | 55.9 | 55.8 | 47.7 | 50.3 | 59.7 | 84.3 |
| merged.attn_qkv | 1 | 92.5 | - | 92.9 | 92.8 | 92.8 | 90.3 | 92.6 | 92.5 | 92.5 | 86.0 |
| merged.qkvz | 1 | 102.4 | - | 103.9 | 103.5 | 104.2 | 105.9 | 102.5 | 102.4 | 102.4 | 98.9 |
| merged.gate_up | 1 | 207.5 | - | 206.6 | 206.6 | 206.8 | 208.4 | 207.4 | 207.4 | 207.4 | 205.2 |

  For 8 / 16 rows every group size from 2 to 16 is the same within noise (down 111.2 to 112.8, out projection 50.5 to 51.0); **local = 2 is as good as 4** and 1 is the plain launch. Sizes where the thread count is not divisible (20 for 896 / 1,024 threads) or equal to 32 fall back to the plain behaviour.
  20 threads gives the out projection 48.0 us at 8 rows but not at 16 rows (57.4), a size-specific effect that was not adopted.

### Q3. ISA, GRF, spill, bit identity
- IGC dump of `submit<0,8,1,2,true,2>` (8 rows) and `submit<0,8,2,1,true,2>` (16 rows) with and without the work-group launch: **GRF 128, no scratch / spill, loop 40 / 35 instructions, 8 DPAS, 12 / 10 loads** in all four; the launch form does not change the loop.
- Logits of 1,600 teacher-forced tokens: **bit-identical** between `XF_GEMM_WG=0` and the default at pass sizes 1, 8 and 16, and between pass sizes (`benchmarks/results/m16`, comparison done on the raw logits). Unit benchmark outputs are exact against the CPU reference in every row above.

### Q4. Why only for 8 / 16 rows? Work-group size sweep for 1 row (`XF_GEMM_WG_M1`, us), and the counters
For 1 row per thread the plain launch is best or equal (down 105.4, out projection 50.6); work-groups of 2 to 16 are 10% slower (115.5, 55.8), 20 is equal / better (105.0, 47.7), 32 equal to plain, 64 much slower for the narrow matrices (165.8, 84.3) but 7% faster for attention qkv (86.0) and 3% for GDN in-proj (98.9).
VTune GPU counters (`benchmarks/results/m17/`; overview, 5 repetitions of 7,000+ calls):

| shape | m | work-group | avg us | XVE active % | stalled % | idle % | thread occupancy % | work-size occupancy limit % | stall SBID % | stall Send % | L3 miss % | DRAM read GB/s |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mlp.down | 1 | plain (32) | 105.0 | 3.3 | 40.1 | 56.6 | 21.6 | 25 | 40.0 | 10.4 | 99.2 | 378 |
| mlp.down | 1 | 4 | 116.0 | 3.1 | 74.5 | 22.5 | 19.2 | 25 | 73.9 | 0.0 | 98.5 | 348 |
| mlp.down | 1 | 20 | 105.0 | 3.3 | 62.2 | 34.4 | 20.6 | 25 | 61.9 | 1.5 | 98.6 | 381 |
| mlp.down | 8 | plain (32) | 128.0 | 6.8 | 38.0 | 55.2 | 22.4 | 25 | 38.5 | 21.3 | 99.5 | 316 |
| mlp.down | 8 | 4 | 111.0 | 7.9 | 81.3 | 10.8 | 22.3 | 25 | 81.9 | 1.1 | 99.3 | 365 |
| out_proj | 1 | plain (32) | 51.0 | 2.3 | 35.4 | 62.3 | 18.3 | 25 | 35.1 | 11.0 | 98.7 | 253 |
| out_proj | 1 | 4 | 56.0 | 2.1 | 58.7 | 39.2 | 14.4 | 25 | 57.7 | 0.0 | 97.7 | 233 |
| out_proj | 1 | 20 | 48.0 | 2.4 | 51.0 | 46.6 | 16.3 | 25 | 50.4 | 1.1 | 98.2 | 259 |
| out_proj | 8 | plain (32) | 56.0 | 5.2 | 32.9 | 61.9 | 18.7 | 25 | 33.1 | 15.4 | 93.3 | 229 |
| out_proj | 8 | 4 | 51.0 | 5.7 | 64.5 | 29.8 | 16.8 | 25 | 64.1 | 0.2 | 88.6 | 257 |

- **Plain launch: the XVE array is idle 55 to 62% of the time** (threads occupancy of the whole GPU is 18 to 22%, which is exactly the work-size limit of 25%, but the idle share shows the threads sit on part of the cores); with work-groups of 4 the idle share drops to 11 to 30% for 8 rows, and the DRAM read rises 316 -> 365 GB/s (down) and 229 -> 257 GB/s (out projection). That is the effect measured in time (-13% / -9% in the counter runs).
- **The hypothesis "small work-groups cost scheduling overhead at 1 row" is not supported by the counters**: at 1 row with work-groups of 4 the idle share also falls (56.6% -> 22.5%) but stalls rise to 74.5% (SBID, i.e. waiting for loads) and the DRAM read falls 378 -> 348 GB/s; the Send-queue stalls disappear (10.4% -> 0%). So spreading the threads removes idle time but the 1-row kernel then gets less memory bandwidth.
  The 1-row load stream is mostly 32-byte activation loads (8 of 12 sends per trip) plus the 256-byte weight loads; a plausible but **untested** explanation is that threads that share a core also share the activation lines and the weight-row pages better when packed (the 20-thread groups, which land between the two, are the best for the out projection). The mechanism was not isolated; the rule (work-group only for 8 / 16 rows) rests on the measurements.

### Q5. Main pass and generation speed (1K context pass profile; 8K / 30K / code with bdraft2, tokens and committed state identical to the old launch in every run)
Real pass time without per-kernel synchronisation (1 / 8 / 16 rows): 37.72 / 42.03 / 48.09 ms before, **37.72 / 41.27 / 46.24 ms after** (-0 / -0.76 / -1.85 ms).
GEMM sums of the synchronised profile (1 / 8 / 16 rows): 33.48 / 36.18 / 39.26 -> 33.51 / 35.06 / 37.02 ms; per shape (8 rows) down 8.68 -> 8.08 ms (-0.60), out projections 4.09 -> 4.01 ms (-0.08; 16 rows 4.56 -> 4.22).
The out projections gain less in the model (80 us per call there against 56 us in the unit benchmark) than in isolation: the unit gain of 5 us per call (0.3 ms per pass) is only 0.08 ms in the engine; this difference was not investigated.

| context | config | WG=0 (before) tok/s | default (after) tok/s | gain | Main pass ms before→after | tok/cycle | same tokens & state |
|---|---|---:|---:|---:|---|---:|---|
| code | fixed8 | 123.7 | 125.4 | +1.4% | 42.1→41.4 | 6.17 | True |
| code | fixed16 | 142.4 | 147.2 | +3.4% | 48.1→46.2 | 8.08 | True |
| code | adapt-cost | 139.9 | 145.7 | +4.2% | 47.5→46.0 | 7.95 | True |
| 8k | fixed8 | 67.1 | 68.2 | +1.5% | 44.7→43.9 | 3.53 | True |
| 8k | fixed16 | 59.5 | 61.4 | +3.1% | 51.8→50.0 | 3.62 | True |
| 8k | adapt-cost | 65.6 | 65.8 | +0.3% | 45.7→45.4 | 3.53 | True |
| 30k | fixed8 | 55.3 | 56.1 | +1.3% | 51.9→51.0 | 3.31 | True |
| 30k | fixed16 | 50.0 | 51.3 | +2.6% | 62.0→60.2 | 3.55 | True |
| 30k | adapt-cost | 55.1 | 55.7 | +1.1% | 52.1→51.4 | 3.31 | True |

The generation speed gain is about 1 to 4% (fixed 16 rows: +2.6 to +3.4%, fixed 8 rows: +1.3 to +1.5%): the Main pass is shorter by 0.8 ms (8 rows) and 1.8 to 1.9 ms (16 rows) of a 44 to 62 ms cycle; the unit gain of 8 to 10% on two of the six matrices is 1.8% of the 8-row GEMM time.

### Q6. Decision
Adopted: the Main pass is shorter in every configuration, the tokens and the committed state are identical, logits are bit-identical, GRF / spill unchanged, the previous launch stays available (`XF_GEMM_WG=0`). Not adopted: work-groups for 1 row (no gain; one shape-dependent size, 20, gives -6% on the out projection at 1 row = 0.2 ms per 1-row pass, not understood), RB = 2 (postponed).
Next candidates for the narrow shapes: more loads in flight per thread (the idle share with the work-group is still 11 to 30% and the stalls are SBID), checked with the VTune counters of Part P.


## Part R. VTune: memory hierarchy of the 4-bit GEMM, and a first profile of the whole engine (B60)
Setup as in Part P (`gpu-hotspots`, `ptrace_scope` / `perf_event_paranoid` lowered for the runs and restored). Raw data: `benchmarks/results/m18/*.csv` and `*.summary.txt`; collection scripts are in the commit message history of Part P / Q (`characterization-mode=global-memory-accesses`).

### R1. Where the loads are served (micro benchmark, cold weights, `xf-bench`, 1 segment; GB/s are averages over the sampling windows, so lower than bytes / time)
| shape | m | launch | avg us | LSC read GB/s (load pipe, all threads) | LSC miss % | LSC->L3 read GB/s | L3 read GB/s | L3 miss % | DRAM read GB/s | LSC input avail % | LSC output ready % | SLM GB/s |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| merged.gate_up | 1 | plain | 207 | 510 | 17.1 | 408 | 409 | 99.1 | 407 | 89 | 10 | 0 |
| merged.gate_up | 8 | plain | 216 | 1176 | 9.1 | 408 | 409 | 95.8 | 394 | 89 | 9 | 0 |
| merged.gate_up | 8 | WG 4 | 216 | 1168 | 9.1 | 405 | 405 | 95.7 | 391 | 91 | 9 | 0 |
| mlp.down | 1 | plain | 105 | 474 | 17.2 | 381 | 382 | 99.2 | 379 | 43 | 9 | 0 |
| mlp.down | 1 | WG 4 | 116 | 435 | 17.9 | 354 | 354 | 98.5 | 348 | 20 | 8 | 0 |
| mlp.down | 8 | plain | 128 | 947 | 9.0 | 336 | 336 | 99.5 | 318 | 45 | 7 | 0 |
| mlp.down | 8 | WG 4 | 111 | 1072 | 9.5 | 402 | 402 | 99.3 | 360 | 80 | 8 | 0 |
| out_proj | 1 | plain | 51 | 305 | 17.3 | 245 | 245 | 98.7 | 243 | 36 | 6 | 0 |
| out_proj | 1 | WG 4 | 56 | 285 | 18.0 | 231 | 231 | 97.7 | 227 | 14 | 6 | 0 |
| out_proj | 8 | plain | 56 | 708 | 9.2 | 251 | 251 | 93.3 | 236 | 37 | 5 | 0 |
| out_proj | 8 | WG 4 | 51 | 749 | 9.8 | 284 | 284 | 88.6 | 250 | 40 | 6 | 0 |

- **The load pipe carries about 3x the DRAM traffic at 8 rows** (gate+up: 1,176 GB/s read through the load-store cache against 394 GB/s from DRAM, 91% of the load-store cache requests hit, miss 9.1%); at 1 row 510 against 407 GB/s (miss 17%). This is the 3.0x / 1.25x load-byte ratio computed from the ISA in Part O4, now measured:
  the activation tiles come from the cache, the weights stream from DRAM (L3 miss ratio 95.7 to 99.5%, L3 read bandwidth equal to DRAM read bandwidth: no weight reuse anywhere). SLM is not used (0 GB/s).
- **The load-store cache sees a pending request 89% of the time for gate+up** (`Input Available`), against 36 to 45% for the narrow matrices (down, out projection): the wide kernels keep the load pipe full, the narrow ones do not. With the work-group launch the narrow 8-row kernels rise from 45 to 80% (down) and 37 to 40% (out projection), and L3 read bandwidth from 336 to 402 GB/s (down) and 251 to 284 GB/s (out projection).
  This is the counter-level picture of Part Q: the dispatch change gives the narrow kernels more simultaneous requests.
- 1 row, down: work-groups of 4 **lower** the pending-request share from 43% to 20% and the DRAM read from 379 to 348 GB/s, in line with the 10% slower time. So for 1 row the spread launch has fewer loads in flight, not more; the reason (which threads share a core, and what the 32-byte activation loads do) is still unexplained.

### R2. Whole-engine profile (`xf-run gen` and `xf-run cmp` with bdraft2 under VTune; `eng_gen`, `eng_bd`)
- Both collections ran (305 MB result for the gen run). `gen` has 82 distinct GPU kernels / 228 thousand launches in the run (it times several loops, so this is not one pass); with bdraft2 attached 178 distinct kernels: **the drafter adds about 96 kernel types**.
- The two programs contain the host-device copies of the benchmark scaffolding (`zeCommandListAppendMemoryCopy`, 5 to 6 s in total) and warm-up passes, so their totals are not a per-pass breakdown; the per-kernel averages (e.g. the 1-row GEMM 78 to 209 us, `k_gdn_core` 37 to 55 us, `k_mlp_act` 25 us, `k_addnorm_quant` 5 us) are usable, the cycle split between Main and drafter was not extracted from them.
- GEMM kernels dominate GPU task time; XMX pipe active 13.6 to 14.6% for the 16-row GEMMs in the engine, 9 to 9.4% for the 8-row ones, about 1% for the 1-row ones (the same numbers as in the micro benchmark). The DRAM read figures of the engine profile (216 to 224 GB/s for the GEMMs) are time averages that include launch gaps and are not comparable with the micro benchmark.
- Not done: a per-pass timeline (kernel gaps inside one verify pass, kernel launch count per pass for the comparison with the 5060 Ti's ~850), and instruction-level attribution (`source-analysis` collects but the JIT-compiled ESIMD kernels have no code mapping).

## Part S. Work-group size 2 / 4 / 8 for down and out projection (m=8/16, B60)
Same conditions for all three: interleaved unit bench, 5 rounds (`benchmarks/results/m19/wg248_unit.txt`), engine pass time, 3 repeats per size (`wg248_pass.txt`, `unprofiled:` values of the first three profile lines; mapping of the columns to row counts is inferred, not verified).

| shape | wg=2 us | wg=4 us | wg=8 us |
|---|---:|---:|---:|
| mlp.down m=8 | 111.16 | 111.24 | 111.34 |
| mlp.down m=16 | 132.00 | 132.08 | 132.16 |
| out_proj m=8 | 50.56 | 50.86 | 50.90 |
| out_proj m=16 | 57.32 | 57.08 | 56.76 |

Engine pass (ms): wg=2 37.71 / 41.26 / 46.20; wg=4 37.72 / 41.27 / 46.21; wg=8 37.72 / 41.32 / 46.25.

- Differences are at most 0.6% in the unit bench, within round-to-round noise, with no consistent direction (out_proj m=8 favours 2, m=16 favours 8).
- Pass time: 2 and 4 are identical; 8 is 0.04 to 0.06 ms slower in all 3 repeats.
- Conclusion: the default of 4 stays; there is nothing to gain from the work-group size any more. Remaining headroom for the out projection is load parallelism per thread (not started).

## Part T. 3-bit weights again: bottleneck analysis, a new layout (`s3p`), and what it buys end to end (B60)
3-bit work was resumed on request; the 4-bit production path is unchanged (logits of `qwen38-27b-s4-cal.xfm` on the held-out chat are bit-identical between the HEAD kernels and the new build; 4-bit unit times unchanged). Raw data: `benchmarks/results/m20/` (unit benchmarks, ISA), `m21/` (quality, generation, pass times).

### T1. Why the old s3 kernel (192-byte tiles, generic 3-to-4-bit spread) did not reach the byte ratio
Unit time s3 / s4 (cold, 16-bit activations, 1 segment; ideal 0.75): gate+up 0.86 / 0.85 / 1.02 at m = 1 / 8 / 16, lm_head 0.76 / 0.76 / 1.07, out proj 1.11 / 1.07 / 1.00, down 1.12 / 1.06 / 1.59. Static ISA (`isa_analyze.py`, m = 8, 16-bit act.): **187 instructions per 4-tile trip** (s4: 40), 128 integer ALU, **16 loads** (weights as 128 B + 64 B messages: a 192-byte tile is not one 256-byte block load), 8 DPAS, 128 GRF, no spill. On the narrow matrices (320 threads) s3 is per-thread latency bound; with segment counts 2 or 4 down m = 8 is 100 us and out proj m = 8 45.8 us (s4: 112 / 50), i.e. the s4-tuned segment rule is not right for s3.

### T2. New layout `s3p` (format id 6; `XF_W_S3P`, `WeightFormat::S3P`; container name "s3p"; `xf-convert convert --s3p`, `xf-convert repack` turns an s3 container into s3p)
- Super-tile of 4 tiles per 16-row block = **768 bytes = three 256-byte loads** ([tile][x][lane], 12 registers). Register x of a tile holds in nibble i the low 3 bits of the code of column 8x+i and, in bit 3 of the nibble, bit x of the code of column 24+i. The u4 operand is `r & 0x77777777` for r0..r2 and `((r0>>3)&0x11111111)|((r1>>2)&0x22222222)|((r2>>1)&0x44444444)` for the fourth register: **9 instructions of 16 lanes per tile** (the generic spread: about 32). Same number of DPAS as s4 (one u4 DPAS per plane and tile).
- Weights are prefetched two super-tiles ahead (24 registers of buffers, the 3-bit thread holds only 768 B per super-tile, so a one-ahead prefetch keeps 25% fewer bytes in flight than the 4-bit loop); activations one stage ahead as before.
- Per-token offset: codes are unsigned (u = q + 4), the kernel multiplies the per-token offset by -7 (`sum(q x) + 0.5 sum(x) = sum(u x) - 3.5 sum(x)`), in the main kernel and in the segment combiner; the benchmark reference does the same. Bit-exact against the CPU reference for all shapes, m = 1 / 8 / 16 (24 of 24 cases `exact`); the whole model gives bit-identical logits to the s3 container with the old kernel.
- ISA (gate+up, m = 8, 16-bit act.): see `m20/isa_s3p.jsonl`; the first version (u2 plane + 1-bit plane, two DPAS per tile) had 79 instructions per trip, 11 loads of 256 B, 16 DPAS; the final nibble-carry version is the one measured below. GRF 128, no spill.
- A first variant (u2 DPAS for the low bits + a u4 DPAS carrying bit 2, no ALU spread) was as fast at m = 8 (gate+up 189 us) and slower at m = 16, so the DPAS count is not what limits m = 8.

### T3. Unit benchmark, us, cold weights, 16-bit activations, 1 segment (`m20/unit2_*.txt`, `unit4_s3p.txt`)
| shape | m | s4 | s3 (old) | s3p | s3p / s4 |
|---|---:|---:|---:|---:|---:|
| gate+up 34816x5120 | 1 / 8 / 16 | 207.7 / 216.2 / 228.1 | 177.6 / 184.0 / 232.3 | 176.5 / 189.0 / 203.5 | 0.85 / 0.87 / 0.89 |
| qkvz 16384x5120 | 1 / 8 / 16 | 100.4 / 101.9 / 104.1 | 83.0 / 88.3 / 114.1 | 82.1 / 88.4 / 97.1 | 0.82 / 0.87 / 0.93 |
| attn qkv 14336x5120 | 1 / 8 / 16 | 92.1 / 89.5 / 92.2 | 73.3 / 77.9 / 101.3 | 75.1 / 78.2 / 86.9 | 0.82 / 0.87 / 0.94 |
| down 5120x17408 | 1 / 8 / 16 | 105.7 / 112.3 / 133.6 | 118.8 / 118.7 / 212.8 | 86.4 / 126.7 / 160.2 | 0.82 / 1.13 / 1.20 |
| out proj 5120x6144 | 1 / 8 / 16 | 49.4 / 50.0 / 56.3 | 54.5 / 53.6 / 56.4 | 41.2 / 36.8 / 41.7 | 0.83 / 0.74 / 0.74 |
| lm_head 248320x5120 | 1 / 8 / 16 | 1442.6 / 1501.2 / 1560.3 | 1094.6 / 1142.9 / 1675.4 | 1102.7 / 1151.3 / 1221.9 | 0.76 / 0.77 / 0.78 |
Ideal 0.75. m = 1 and the lm_head reach 0.76 to 0.85; at m = 8 the wide shapes stop at 0.87: with 3 KB per trip through the load pipe of which 2 KB are activation re-reads the load pipe (about 1.2 TB/s, Part R) limits, not the bytes of the weights (s4 gate+up 8 rows reads 1.18 TB/s through the load-store cache; s3p at 189 us would need 1.23 TB/s). Narrow shapes with 1 segment (down) are worse than s4 (320 threads, deeper prefetch needs more registers); not tuned (segment rule for s3p not done).

### T4. End to end (xf-run, B60, XF_KV=xmx; containers: `s3mixp` = gate+up, qkvz, attn qkv and lm_head at 3 bits (calibrated, centred-variance statistics as s4-cal, bias-corrected), all else s4; `s3allp` = every body matrix and lm_head at 3 bits; MTP block s4)
Main pass (unprofiled, ms, 1 / 8 / 16 tokens per pass, `m21/pass_times.txt`, 2 repeats within 0.03 ms): s4-cal 37.72 / 41.30 / 46.20; s3mixp 33.90 / 37.65 / 42.77 (-10.1 / -8.8 / -7.4%); s3allp 32.03 / 35.85 / 42.24 (-15.1 / -13.2 / -8.6%).
Quality against the BF16 reference (teacher-forced logits, 160-token held-out chat): s4-cal KL mean 0.125, median 0.024, top-1 88.1%; s3mix(p) KL 0.226, median 0.061, top-1 86.9%; s3allp KL 0.335, top-1 81.3%.
Generation, bdraft2 fixed-16, 7 code prompts x 768 tokens, 1024 context (`m21/gen_*.json`, graded with `tools/code_eval/code_eval.py`, solution-only pass count):
| container | tok/s (mean of prompts) | tokens / pass | 1st-draft accept | Main ms / pass | code tasks passed (solution only) |
|---|---:|---:|---:|---:|---:|
| s4-cal | 131.9 | 7.57 | 87.6% | 47.1 | 5 / 7 |
| s3mixp | 126.0 | 6.61 | 82.9% | 43.0 | 3 / 7 |
| s3allp | 81.6 | 4.18 | 70.3% | 42.5 | 0 / 7 |
(s3mix with the old kernel: 112.6 tok/s, same tokens / pass as s3mixp: the new layout is worth +12% over the old s3 kernel at equal output.)
- **Result: 3-bit scalar weights are not a gain.** The mixed container makes a pass 8.8% shorter but loses 12.7% of the tokens per pass: net -4.5% tok/s and fewer code tasks solved (3 of 7 against 5 of 7, small sample, 768-token cut-offs). The all-3-bit container collapses (accept 70%, 0 of 7).
- The break-even for the mixed container is 6.9 tokens per pass (it has 6.61); for all-3-bit about 6.6 (it has 4.18). Quality is what is missing, not kernel speed.
- Weight-space error explains it (relative 0.20 at 3 bits against 0.11 at 4 bits, Part QUANTIZATION; YASAKANI's trellis 3 bpw is 0.176); a GPTQ-like (activation-aware, full covariance) rounding on the same grid or a trellis format would be the way to make 3 bits worth its speed. Not done.

### T5. Not done / status
- RB = 2 (32 rows per thread to halve the activation re-reads, the limit at m = 8 above) was not implemented: it helps the 4-bit kernel as much as the 3-bit one and needs a register budget study; separate item.
- s3p-specific segment / work-group rules for down and out projection were not applied in the engine (not worth it while no 3-bit container is usable).
- Production default is unchanged (s4-cal). `s3p` support stays in the tree (kernel path chosen only by the container's format); `scripts/s3_quality.sh`, `scripts/s3_gen.sh` reproduce the quality and generation numbers.

## Part U — s4-cal generation speed, fixed container (2026-11-20)

Container `qwen38-27b-s4-cal.xfm`, bdraft2 drafter, `XF_KV=xmx`, WG local=4 (default), no code changes.
Suite: `scripts/gen_speed_suite.sh` (results `benchmarks/results/m22/`, aggregation `scripts/gen_speed_agg.py`, table `m22/summary.md`).
Command per run: `XF_KV=xmx scripts/b60run timeout T ./target/release/xf-run cmp <xfm> <prompts.json> <n_new> --only-bd --configs 8,16,0c --ctx <ctx> <bdraft flags> --json ... --save-tokens ...`.
A: 5 repeats (separate process each; a short code prompt is a discarded warm-up), 256 new tokens, ctx 8K/30K/60K.
B: 2048 tokens at 8K. C: 7 code prompts x 2048 tokens. Every row: same tokens and same state hash as the greedy baseline.

| ctx | config | tok/s mean (min-max) | Main ms | draft ms | tok/pass | accept1 |
|---|---|---|---|---|---|---|
| 8K | fixed8 | 67.9 (67.0-68.2) | 43.9 | 6.3 | 3.53 | 0.77 |
| 8K | fixed16 | 61.3 (61.0-61.4) | 50.0 | 7.4 | 3.62 | 0.76 |
| 8K | adaptive | 65.8 (65.7-65.9) | 45.4 | 6.4 | 3.53 | 0.76 |
| 30K | fixed8 | 56.0 (55.6-56.1) | 51.1 | 6.3 | 3.31 | 0.82 |
| 30K | fixed16 | 51.2 (51.1-51.3) | 60.2 | 7.4 | 3.55 | 0.85 |
| 30K | adaptive | 55.8 (55.7-55.8) | 51.4 | 6.2 | 3.31 | 0.82 |
| 60K | fixed8 | 44.9 (44.5-45.0) | 60.7 | 6.3 | 3.08 | 0.77 |
| 60K | fixed16 | 36.4 (36.3-36.4) | 74.0 | 7.4 | 3.02 | 0.75 |
| 60K | adaptive | 45.0 (45.0-45.0) | 60.7 | 6.1 | 3.08 | 0.77 |

VRAM (driver free 22.48 GiB before load; model+KV+bdraft2, bdraft2 +2.8 GiB): 8K 15.8 GiB used, 30K 17.3, 60K 19.3 (3.2 GiB free).
Sustained, 8K ctx, 2048 tokens: fixed8 76.4, fixed16 74.0, adaptive 79.4 tok/s.
Code bench (2048 tokens, 7 prompts): fixed16 reaches 140.9 (py_csv) and 142.0 (cpp_fib) tok/s; these two are the only prompts near 140, because tok/pass ~7.9. Other prompts 39-92 tok/s (rs_merge 39-43 lowest). Mean over 7 prompts: see `m22/summary.md`.
Correctness: all 3 configs give identical tokens/state to greedy on every prompt. Solution grading (`eval_C_code.json`): 3/7 pass (cpp_merge, py_lru, rs_merge) identically for greedy and all configs; the 4 failures are also failures of greedy (compile errors cpp_fib, rs_balanced; wrong py_csv, py_merge), i.e. model/quantization, not speculation.

Conclusions: ~140 tok/s reproduces only for highly predictable code (tok/pass >= 7.8, accept1 ~0.89) at short context with fixed16 (or adaptive, 140-142). Typical sustained speed: 40-95 tok/s on code, 74-79 at 8K prose, 56 at 30K, 45 at 60K. Fastest quality-preserving setting overall: adaptive (cost-ratio) — within 1% of the best everywhere (fixed8 is best at long ctx, fixed16 only wins on easy code); quality is identical to greedy in all configs.


## Part V — YASAKANI v0.1.6 `bench --edit` port: edit tasks on XeFlash (2026-11-20)

**Reference.** YASAKANI v0.1.6 (github.com/yasakani-dev/yasakani, tag v0.1.6, Apache-2.0) `yasakani bench --edit`
(`python/yasakani/editbench.py`) runs three tasks from the package file `edit_tasks.json`: `edit_code` (rename local `margin` ->
`common_margin` inside `dedent` of CPython `textwrap.py`, return the whole file, limit 8192), `edit_jsonl` (60 JSONL records, change
status of ORD-0042, limit 8192) and `edit_jsonl_long` (160 records, change 3 records, limit 12000). Greedy, thinking off, until the
model ends; speed = (tokens-1)/seconds of the generation only; the answer is compared with the expected text (whitespace/one code fence
ignored). Tasks, expected answers and their SHA-256 are used **unchanged** (`benchmarks/edit/edit_tasks.json`, copy with licence).
The local YASAKANI tree is v0.1.1 and has no `--edit`; the tag was downloaded to /tmp only.

**XeFlash port.** `scripts/edit_prepare.py` (Qwen3.8 chat template, thinking off -> token ids, `benchmarks/prompts/edit_*.json`, prompt
4769 / 2927 / 6576 tokens), `scripts/edit_bench_suite.sh`, `scripts/edit_bench_agg.py`. Production s4-cal container, XF_KV=xmx, WG local=4,
`xf-run cmp ... --only-bd --configs 8,16,0c` (greedy baseline "none" + bdraft2 fixed8/fixed16/adaptive), 5 repeats = 5 processes per task
(kernels warmed inside the process by cmp; run-to-run spread < 1%). **Difference:** `xf-run cmp` has no end-token stop, so `n_new` is the
token count of the expected answer + `<|im_end|>` (4708 / 2854 / 6493); the speed covers the same span the official bench measures when the
model answers as expected. Time excludes load/prefill/hash. Results: `benchmarks/results/m23/` (`*.json`, `*.log`, `tok_*`, `summary.md`).

task|config|tok/s mean (min-max)|tokens/pass|accept1|Main ms/pass|Draft ms/pass|answer = expected|same tokens+state as greedy
edit_code|greedy|24.8 (24.8-24.8)|1.00|-|40.34|-|0/5|-
edit_code|bd2:fixed8|100.4 (100.0-100.6)|5.17|0.977|43.34|6.16|0/5|5/5
edit_code|bd2:fixed16|96.2 (96.2-96.3)|5.65|0.976|49.32|7.34|0/5|5/5
edit_code|bd2:adapt-cost|101.4 (101.4-101.5)|5.42|0.976|45.00|6.44|0/5|5/5
edit_jsonl|greedy|25.1 (25.1-25.1)|1.00|-|39.88|-|5/5|-
edit_jsonl|bd2:fixed8|157.0 (156.4-157.1)|7.95|1.000|42.28|6.15|5/5|5/5
edit_jsonl|bd2:fixed16|261.4 (260.8-261.6)|15.26|1.000|48.11|7.41|5/5|5/5
edit_jsonl|bd2:adapt-cost|262.0 (261.9-262.1)|15.26|1.000|48.02|7.36|5/5|5/5
edit_jsonl_long|greedy|24.5 (24.5-24.5)|1.00|-|40.83|-|5/5|-
edit_jsonl_long|bd2:fixed8|151.2 (151.1-151.3)|7.96|1.000|44.26|6.12|5/5|5/5
edit_jsonl_long|bd2:fixed16|247.1 (247.0-247.1)|15.06|1.000|50.70|7.40|5/5|5/5
edit_jsonl_long|bd2:adapt-cost|248.0 (247.9-248.1)|15.10|1.000|50.63|7.38|5/5|5/5

(answer = expected: the greedy and speculative outputs, cut at `<|im_end|>`, compared with the official expected text; same tokens+state =
speculative output identical to greedy, token and state hash.)

**Findings.**
* JSONL tasks: exact answers (5/5, all configs), accept1 = 1.000. fixed16 / adaptive reach 247-262 tok/s (about 10x greedy 25 tok/s,
  15 tokens/pass of the 16 maximum); fixed8 is capped at 151-157 (8 tokens/pass). On these tasks fixed16/adaptive is clearly better than fixed8.
* Code edit: **0/5 exact**, for greedy too: the 4-bit model rewrites `behaviour`->`behavior` and changes regex placeholders
  (`%(wp)s` -> `%s`, 42 chars shorter). That is a model/quantization deviation, not a speculation error (all configs reproduce greedy
  bit-exactly). YASAKANI's speed model returns this task exactly (README logs: speed model exact, quality model differs by 2 lines),
  so this is a quality gap of our 4-bit container on copy fidelity. After each deviation the drafter loses sync: tokens/pass 5.2-5.7,
  100 tok/s with fixed8/adaptive (fixed16 is slower, 96).
* For reference, YASAKANI's README logs (RTX 5090, different hardware/model, not comparable one-to-one) show 1221 tok/s for edit_code.

### Copy/edit-specialised drafter: headroom (offline estimate, not implemented)
`scripts/edit_copy_oracle.py`: replays the measured greedy outputs and simulates prompt lookup (propose up to K tokens that followed the
latest earlier occurrence of the last n tokens in prompt+output; verifier accepts the longest correct prefix; no future information used).
tok/pass is exact for that rule; tok/s is an **estimate** (measured cost m=1 40.3 ms, m=8 43.3, m=16 49.3; beyond 16 rows
extrapolated +0.75 or +1.5 ms/row; a verify pass above 16 rows is not implemented in the kernels today; hybrid assumes fallback to bdraft2 at 3.5 tok/pass).

task|n|K|passes|tok/pass (copy only)|est tok/s copy-only (slope .75 / 1.5)|hybrid est tok/s
edit_code|3|15|592|7.95|169 / 169|191
edit_code|3|31|399|11.80|220 / 193|259
edit_code|3|63|299|15.75|250 / 195|302
edit_code|5|15|568|8.29|181 / 181|229
edit_code|5|31|416|11.32|227 / 205|306
edit_code|5|63|339|13.89|252 / 208|354
edit_jsonl|3|15|668|4.27|87 / 87|88
edit_jsonl|3|31|581|4.91|83 / 70|83
edit_jsonl|3|63|546|5.23|66 / 48|66
edit_jsonl|5|15|383|7.45|152 / 152|154
edit_jsonl|5|31|275|10.38|171 / 144|173
edit_jsonl|5|63|128|22.30|278 / 200|284
edit_jsonl_long|3|15|1667|3.90|80 / 80|80
edit_jsonl_long|3|31|1663|3.90|65 / 55|66
edit_jsonl_long|3|63|1653|3.93|51 / 37|51
edit_jsonl_long|5|15|860|7.55|154 / 154|155
edit_jsonl_long|5|31|400|16.23|268 / 224|271
edit_jsonl_long|5|63|401|16.19|200 / 143|201

Reading (n=5 suffix): at today's 16-row width a copy drafter alone gives edit_code 8.3 tok/pass (est. 181 tok/s vs 101 measured with
bdraft2), but only 7.5 tok/pass on the JSONL tasks (est. 152-154 vs 248-262 measured): bdraft2 already copies near-perfectly there.
Gains on JSONL need wide verification: K=63 -> 16-22 tok/pass, est. 200-278 tok/s (+0-10%, depends on the extra row cost; the ceiling is
bounded by pass cost, not acceptance). The real headroom is edit_code: 2.2-3.5x (est. 230-350 tok/s) from a copy proposer that
re-syncs after each deviation, combined with bdraft2 as fallback (hybrid column, upper-bound assumptions). Risks/costs: wide
(32-64 row) verify kernels (activation re-reads make m=8 already ~3x weight traffic through the load pipe), longer n-gram ambiguity in
repetitive JSONL (n=3 selects the wrong line: 3.9 tok/pass; n>=5 needed), and exactness remains guaranteed by greedy verification.

## Part W — Main-pass cost at 32/64 verify rows, and the updated copy-drafter estimate (2026-11-20)

No production code changed. `xf-bench --format s4 --tokens 1,8,16,32,64` (`benchmarks/results/m24/unit_s4_m1_64.{txt,json}`).
Above 16 rows only the 8-bit-activation kernel exists (tokens_per_thread 32; m=64 runs two 32-row groups that each re-read the weights);
the production 16-bit-activation path (two planes) exists for m<=16 only, and the model (attention, GDN, drafter) has no >16-row pass.
Unit times, ms (s4, exact vs CPU reference):

| shape | m=1 a16 | m=8 a16 | m=16 a16 | m=32 a8 | m=64 a8 |
|---|---|---|---|---|---|
| gate_up 34816x5120 | 0.207 | 0.217 | 0.229 | 0.268 | 0.531 |
| down 5120x17408 | see json | | 0.133 | 0.242 | 0.235 |
| qkvz 16384x5120 | 0.096 | 0.099 | 0.104 | 0.124 | 0.225 |
| attn_qkv 14336x5120 | 0.086 | 0.086 | 0.091 | 0.111 | 0.195 |
| out_proj 5120x6144 | 0.014 | 0.015 | 0.026 | 0.070 | 0.077 |
| lm_head | 1.442 | 1.501 | 1.561 | 1.849 | 3.647 |

Weighted by layer counts (48 qkvz, 16 attn_qkv, 64 out_proj/gate_up/down, 1 lm_head) the GEMM part of a Main pass is
28.3 / 29.5 / 32.9 ms at m=1/8/16 (a16) and 46.7 / 71.5 ms at m=32/64 (a8 only): per extra row 0.5 ms (m 16->32) and 0.8 ms (32->64), i.e.
the weight-streaming efficiency falls from ~410 GB/s (m=16) to ~340 (m=32) and ~170 GB/s at m=64 (second weight pass).
Non-GEMM part of the pass (attention, GDN, norms; Main minus GEMM) is 9.5 ms at m=1 and 13.3 ms at m=16 (extrapolated +0.25 ms/row; not measured above 16).
Estimated Main pass (ms): A (a8 GEMM as measured) 64 at 32 rows, 97 at 64 rows; B (a16 proxy = a8 GEMM of 2m rows) 89 at 32, 168 at 64; measured 49.3 at 16.

Updated copy-oracle (n=5, `scripts/edit_copy_oracle.py`, `m24/copy_oracle_v2.md`; tok/pass exact, tok/s estimated):

| task | K+1 rows | tok/pass | est tok/s copy-only A / B | hybrid with bdraft2 fallback A / B | measured bdraft2 |
|---|---|---|---|---|---|
| edit_code | 16 | 8.29 | 181 / 181 | 229 / 229 | 101 |
| edit_code | 32 | 11.32 | 222 / 182 | 297 / 229 | |
| edit_code | 64 | 13.89 | 236 / 169 | 323 / 209 | |
| edit_jsonl | 16 | 7.45 | 152 / 152 | 154 | 262 |
| edit_jsonl | 32 | 10.38 | 164 / 119 | 166 / 120 | |
| edit_jsonl | 64 | 22.30 | 247 / 146 | 252 / 147 | |
| edit_jsonl_long | 16 | 7.55 | 154 | 155 | 248 |
| edit_jsonl_long | 32 | 16.23 | 256 / 186 | 259 / 187 | |
| edit_jsonl_long | 64 | 16.19 | 177 / 104 | 179 / 105 | |

Conclusions (estimates, not measurements of an implemented drafter):
* With the real GEMM costs the earlier 200-280 tok/s JSONL estimate for wide verification shrinks to 105-256 tok/s: no wide setting beats the
  measured 16-row bdraft2 on JSONL (248-262). The remaining headroom is edit_code (101 -> ~230-320 est. with a hybrid), where acceptance is the limit.
* Ceiling at 64 rows: 64 tokens per 97 ms pass (model A) = 660 tok/s even with 100% acceptance; model B 380 tok/s. 1000 tok/s is therefore not reachable
  by wider verification of this kernel family; it would need ~64 tokens per <=64 ms (m=64 at the m=16 efficiency would be ~60 ms, about 1.6x better than measured),
  i.e. a new wide-verify path (weights read once per pass for all 64 rows, not per 32-row group), or fewer verified positions (e.g. sparse/tree checks).
* The bottleneck has moved from acceptance to "tokens verified per pass and their cost", as stated; measuring a real 32/64-row pass would
  additionally need a16 >16-row GEMM, >16-row attention/GDN passes and a >16-row drafter interface (not implemented).


## Part X — copy + bdraft2 hybrid at 16 rows, measured (2026-11-20)

Implementation (experimental, `xf-run cmp` only; configs without `hy` behave exactly as before, bd2 numbers below reproduce Part V):
`--configs hy<min>/<blk>` (e.g. `hy4/8`, `hy4/0c`, `hy4/16`). Per cycle a copy candidate is built from the committed text (prompt + output):
a 3-gram index, the occurrence whose backward match with the current context is longest (<=64, ties latest, 64 latest occurrences compared),
or "sticky": the continuation of the source the previous copy pass was aligned with while the frontier token equals the source token.
If the candidate holds >= `min` tokens (up to 15) it is verified instead of the drafter's block (`ids = [next] + candidate`, <= 16 rows) and bdraft2
is only caught up with the committed tap rows (`read_taps` + `ctx`); otherwise bdraft2 drafts with block `<blk>`. Greedy verification, so the output
is bit-identical to greedy (checked: same tokens and state hash in every run). Code: `tools/run/src/ext.rs` (`CopyIndex`), `tools/run/src/main.rs`
(`run_ext_mode`, parameter `hy`). Proposer variants were chosen offline first (`scripts/edit_copy_oracle2.py`: latest-5-gram = 7.5 tok/pass on
JSONL, longest match + sticky = 15.3-15.6).
Suite `scripts/edit_hybrid_suite.sh` (same conditions as Part V: s4-cal, XF_KV=xmx, 5 repeats = 5 processes, n_new = expected answer length), `benchmarks/results/m26/`.

task|config|tok/s mean (min-max)|tokens/pass|accept1|Main ms/pass|Draft ms/pass|answer = expected|same tokens+state as greedy
edit_code|greedy|24.8 (24.8-24.8)|1.00|-|40.33|-|0/5|-
edit_code|bd2:fixed16|96.2 (96.2-96.3)|5.65|0.976|49.32|7.34|0/5|5/5
edit_code|bd2:adapt-cost|101.4 (101.4-101.4)|5.42|0.976|45.00|6.44|0/5|5/5
edit_code|hy4+bd2:fixed8|241.5 (241.4-241.5)|12.90|0.806|48.32|2.46|0/5|5/5
edit_code|hy4+bd2:adapt-cost|240.3 (240.3-240.4)|12.90|0.806|48.54|2.50|0/5|5/5
edit_code|hy4+bd2:fixed16|236.7 (236.7-236.7)|12.94|0.806|49.34|2.67|0/5|5/5
edit_jsonl|greedy|25.1 (25.1-25.1)|1.00|-|39.88|-|5/5|-
edit_jsonl|bd2:fixed16|261.5 (261.4-261.6)|15.26|1.000|48.10|7.39|5/5|5/5
edit_jsonl|bd2:adapt-cost|262.0 (261.9-262.1)|15.26|1.000|48.02|7.36|5/5|5/5
edit_jsonl|hy4+bd2:fixed8|295.9 (295.8-295.9)|15.60|1.000|48.06|1.77|5/5|5/5
edit_jsonl|hy4+bd2:adapt-cost|295.9 (295.9-295.9)|15.60|1.000|48.05|1.77|5/5|5/5
edit_jsonl|hy4+bd2:fixed16|298.6 (298.6-298.7)|15.77|1.000|48.12|1.79|5/5|5/5
edit_jsonl_long|greedy|24.5 (24.5-24.5)|1.00|-|40.83|-|5/5|-
edit_jsonl_long|bd2:fixed16|247.1 (247.0-247.1)|15.06|1.000|50.70|7.40|5/5|5/5
edit_jsonl_long|bd2:adapt-cost|247.9 (247.5-248.1)|15.09|1.000|50.63|7.38|5/5|5/5
edit_jsonl_long|hy4+bd2:fixed8|284.2 (284.1-284.2)|15.72|1.000|50.68|1.74|5/5|5/5
edit_jsonl_long|hy4+bd2:adapt-cost|284.2 (284.0-284.3)|15.72|1.000|50.68|1.74|5/5|5/5
edit_jsonl_long|hy4+bd2:fixed16|284.6 (284.5-284.7)|15.76|1.000|50.71|1.74|5/5|5/5

Share of passes that verified a copy candidate: edit_code 83%, edit_jsonl 98.9%, edit_jsonl_long 99.5%.

Result vs bdraft2 only (adaptive): code edit 101.4 -> 240-242 tok/s (2.4x, 5.4 -> 12.9 tokens/pass), JSONL edit 262.0 -> 295.9-298.6 (+13-14%),
long JSONL 247.9 -> 284.2-284.6 (+15%). Greedy baseline 24.5-25.1 tok/s, so JSONL is now ~12x greedy. The fallback block matters little
(fixed16 best on JSONL, fixed8/adaptive best on code by 0.5-2%).
The copy cycle costs 1.7-2.5 ms of "draft" time (host tap read + ring catch-up of bdraft2), versus 6.1-7.4 ms for a bdraft2 draft; the
Main pass (48.1-50.7 ms at 16 rows) is now 96-97% of the cycle. Ceiling of this scheme at 16 rows: 16 tokens / (48.1 + ~0.2 ms) = 331 tok/s
(JSONL), reached 90%. Correctness caveat unchanged: the code-edit answer is still not equal to the official expected text (0/5, also for greedy; a
4-bit model deviation), so that speedup is for the model's own output.
Next limits: Main pass cost per row count (Part W), a device-side ring catch-up to remove the 1.7 ms, and copy proposals longer than 16 rows.


## Part Y — 32-row verify: where the Main pass loses time, and what 32-row candidates would accept (2026-11-20)

Goal: can a 32-row Main pass get close to the 16-row cost, and is it worth it for the copy+bdraft2 hybrid? Measured: GEMM kernels at 16/32/64 rows (ISA,
VTune counters, work-group and segment sweeps), the Main-pass stage profile at 1/8/16 rows, and the exact acceptance of 32/64-row copy candidates.
All GPU runs through `scripts/b60run`; VTune needed the three sysctls, set by `scripts/vtune_m32.sh` and restored afterwards (verified 1 / 4 / 1,
`benchmarks/results/m27/vtune/sysctl_restore.txt`). Raw data: `benchmarks/results/m27/` (`isa/`, `vtune/`, `unit_s4_cold_m1_64.*`, `profile_*.log`, `*_sweep*.txt`, `width_oracle.md`).
Code touched: one experiment hook in `kernels/gemm/gemm.cpp` (`XF_GEMM_WG32`, default 0 = unchanged launch); nothing else.

### Y1. Cold GEMM times (the unit table of Part W used warm weights; small matrices stayed in L3) — `xf-bench --cold`, best variant, ms
| shape (x layers) | m=1 | 8 | 16 | 32 (a8) | 64 (a8) | 32 vs 16 (a8) |
|---|---|---|---|---|---|---|
| gate_up (64) | 0.208 | 0.216 | 0.228 | 0.266 | 0.531 | +16% |
| qkvz (48) | 0.101 | 0.102 | 0.104 | 0.124 | 0.226 | +19% |
| attn_qkv (16) | 0.092 | 0.089 | 0.092 | 0.112 | 0.198 | +21% |
| down (64) | 0.106 | 0.112 | 0.134 | 0.243 | 0.237 | **+82%** |
| out_proj (64) | 0.049 | 0.050 | 0.057 | 0.099 | 0.099 | **+74%** |
| lm_head (1) | 1.443 | 1.501 | 1.561 | 1.843 | 3.637 | +18% |
| **GEMM sum per pass** | 30.96 (a16) | 32.07 (a16) | 34.84 (a16) / 33.70 (a8) | **48.44** | 73.14 | **+14.7 ms** |
Of the +14.7 ms from 16 to 32 rows, down contributes 7.0, out_proj 2.7, gate_up 2.4, qkvz 1.0, attn_qkv 0.3, lm_head 0.3: **two narrow shapes cause 66%**.
At m=16 the 16-bit-activation kernel costs only +3% over the 8-bit one (memory bound); only the 8-bit kernel exists for 32 rows.

### Y2. Static ISA (`isa_analyze.py`, `m27/isa/`)
The 32-row kernel is `submit<R=8,G=4,U=1,a16=false,PIPE=0>`: the **old non-pipelined loop**, 128 GRF, no spill (scratch none), 5 loads (1 weight tile + 4 activation
loads of 256 B) and 4 DPAS per trip, three 64-bit multiplies in the address arithmetic, no software prefetch. The 16-row kernel is the pipelined PIPE=2 loop (10 loads, 8 DPAS
per two-stage trip, pointer-bumped 32-bit addresses). Registers: accumulators of 16 rows x 32 tokens are 32 GRF with 8-bit activations; with two 16-bit planes they are 64 GRF
plus two stages of activation tiles: does not fit 128 GRF, a 32-row 16-bit-activation kernel needs 256 GRF mode (4 instead of 8 threads per EU) or another decomposition.

### Y3. VTune counters (gpu-hotspots overview, cold, 1 segment; m=16 rows are a8 and a16 variants, 32/64 a8)
shape|m|kernel|global|local|avg us|n|spill|GRF|XVE act%|stall%|idle%|occ%|XMX%|SBID%|Send%|DistAcc%|L3 miss%|DRAM GB/s
merged.gate_up|16|W0 R8 G2 U1 a16=0 P2|2176|4|226.0|7897|0|128|8.9|78.5|12.6|77.6|12.1|82.4|57.2|2.8|95.3|372
merged.gate_up|16|W0 R8 G2 U1 a16=1 P2|2176|4|228.0|7797|0|128|15.4|73.2|11.4|78.6|24.1|69.6|64.6|1.7|94.6|374
merged.gate_up|32|W0 R8 G4 U1 a16=0 P0|2176|32|265.0|6712|0|128|25.0|67.8|7.2|80.6|20.8|65.8|10.5|19.3|95.1|326
merged.gate_up|64|W0 R8 G4 U1 a16=0 P0|4352|32|535.0|3457|0|128|25.4|68.5|6.2|86.8|21.2|66.9|16.1|22.5|95.2|331
mlp.down|16|W0 R8 G2 U1 a16=0 P2|320|4|115.0|10002|0|128|7.9|80.0|12.1|21.9|11.4|83.7|0.0|1.8|99.3|354
mlp.down|16|W0 R8 G2 U1 a16=1 P2|320|4|132.0|10002|0|128|12.5|77.3|10.1|22.4|20.1|78.3|0.0|0.4|99.2|312
mlp.down|32|W0 R8 G4 U1 a16=0 P0|320|32|243.0|7272|0|128|10.4|36.3|53.3|23.3|11.3|35.5|0.0|8.1|98.8|176
mlp.down|64|W0 R8 G4 U1 a16=0 P0|640|32|237.0|7387|0|128|21.3|72.4|6.3|46.7|23.1|71.2|0.0|16.8|92.3|182
merged.attn_qkv|16|W0 R8 G2 U1 a16=0 P2|896|4|93.0|10002|0|128|8.3|73.2|18.4|56.6|11.2|77.0|10.7|2.2|96.2|341
merged.attn_qkv|16|W0 R8 G2 U1 a16=1 P2|896|4|92.0|10002|0|128|14.8|71.6|13.7|60.0|23.0|69.6|65.6|0.9|97.4|347
merged.attn_qkv|32|W0 R8 G4 U1 a16=0 P0|896|32|112.0|10002|0|128|23.1|62.2|14.7|59.4|19.1|58.9|0.7|14.6|93.2|296
merged.attn_qkv|64|W0 R8 G4 U1 a16=0 P0|1792|32|197.0|8637|0|128|27.1|57.6|15.3|69.2|22.7|54.6|10.0|20.0|89.3|272
out_proj|16|W0 R8 G2 U1 a16=0 P2|320|4|65.0|10002|0|128|5.0|74.0|21.0|19.3|6.7|75.7|0.0|1.8|88.2|211
out_proj|16|W0 R8 G2 U1 a16=1 P2|320|4|57.0|10002|0|128|9.6|68.6|21.8|19.0|14.8|68.7|0.0|1.0|81.8|234
out_proj|32|W0 R8 G4 U1 a16=0 P0|320|32|103.0|10002|0|128|10.3|33.0|56.7|21.2|8.9|30.9|0.0|8.0|87.0|137
out_proj|64|W0 R8 G4 U1 a16=0 P0|640|32|103.0|10002|0|128|20.3|65.6|14.0|41.9|17.6|61.4|0.0|15.7|87.8|139

Reading: (i) no spill, 128 GRF everywhere. (ii) Launch: the m=32/64 kernels run with Work Size:Local = 32 (runtime default); the m=16 kernels with local 4.
(iii) Wide shapes at 32 rows: XVE active 23-25% (m=16: 9-15%), XMX pipe 19-21% (a8 m=16: 11-12%, a16 24%), thread occupancy 59-81%, DRAM 296-326 GB/s (m=16: 341-374), Send stall only
1-11% (m=16: 57-66% on gate_up): the loads are *not* saturating the memory pipe, the threads wait for results (SBID 59-66%) because the loop has no prefetch. Latency bound.
(iv) Narrow shapes at 32 rows: only 320 threads: XVE idle 53-57%, occupancy 21-23%, DRAM 137-176 GB/s: **idle, not stalled** (same diagnosis as Part P4 for 8 rows).
(v) m=64 is two sequential 32-row groups: DRAM bytes per weight double, time x2 on wide shapes (gate_up 535 us).
Work-group sweep (`XF_GEMM_WG32`, `m27/wg32_sweep.txt`): local 2-16 changes gate_up/qkvz by <1% and out_proj by 1%; down improves 6% (0.2435 -> 0.229): placement is not the main cause.
Segments (`segs_narrow_m32.txt`): down at 32 rows with 4 column segments 0.2432 -> **0.1886 ms (-22%)** with the existing kernel (the default segment rule excludes m>16); out_proj does not improve. That alone would save 3.5 ms per pass.

### Y4. Main-pass stage profile (`xf-run gen --profile`, synchronised stages, ms; GEMM column excludes the head)
| ctx | rows | norm | quant | GEMM | GDN | attn | mlp | head | unprofiled pass |
|---|---|---|---|---|---|---|---|---|---|
| ~3K | 1 | 1.73 | 1.74 | 31.98 | 3.74 | 1.44 | 0.97 | 1.49 | 37.9 |
| ~3K | 8 | 1.91 | 1.97 | 33.55 | 4.52 | 1.69 | 1.45 | 1.56 | 41.7 |
| ~3K | 16 | 2.05 | 2.08 | 35.61 | 6.52 | 2.03 | 2.16 | 1.64 | 46.9 |
| ~8K | 1 | 1.78 | 1.75 | 32.16 | 3.76 | 2.17 | 0.96 | 1.49 | 38.7 |
| ~8K | 8 | 1.93 | 2.03 | 33.63 | 4.55 | 3.51 | 1.47 | 1.56 | 43.5 |
| ~8K | 16 | 2.04 | 2.06 | 35.61 | 6.51 | 4.69 | 2.13 | 1.64 | 49.6 |
Non-GEMM stages at 16 rows: 14.9 ms (3K) / 17.4 ms (8K); per extra row (8->16): GDN 0.25 ms (the recurrence is sequential in tokens), mlp 0.09, attention 0.04 (3K) / 0.15 (8K), norm and quant 0.02 each.
Extrapolated to 32 rows (not measurable: the engine limit is `XF_MAX_TOKENS = 16`): non-GEMM +6.7 ms (3K) / +8.4 ms (8K), i.e. GDN is the biggest non-GEMM growth (+4 ms).
Main(32) estimate = 46.9 (measured 16-row) + 13.6 (GEMM, a8 kernels as they are) + 6.7 = **67 ms** today (a16 would cost more), ~**60 ms** if down and out_proj
scaled like the wide shapes (+20%). Ratio to the 16-row pass 1.28-1.43 for twice the rows.

### Y5. Acceptance of 32/64-row candidates (exact: replay of the measured greedy outputs, proposer = longest match + sticky alignment as in Part X, `scripts/edit_copy_oracle2.py`)
edit_code|longest|K=15|passes 480|copy passes 330|tok/pass 9.81
edit_code|longest|K=31|passes 343|copy passes 193|tok/pass 13.73
edit_code|longest|K=63|passes 276|copy passes 126|tok/pass 17.06
edit_code|sticky|K=15|passes 480|copy passes 330|tok/pass 9.81
edit_code|sticky|K=31|passes 343|copy passes 193|tok/pass 13.73
edit_code|sticky|K=63|passes 276|copy passes 126|tok/pass 17.06
edit_jsonl|longest|K=15|passes 186|copy passes 181|tok/pass 15.34
edit_jsonl|longest|K=31|passes 98|copy passes 93|tok/pass 29.12
edit_jsonl|longest|K=63|passes 54|copy passes 49|tok/pass 52.85
edit_jsonl|sticky|K=15|passes 186|copy passes 181|tok/pass 15.34
edit_jsonl|sticky|K=31|passes 98|copy passes 93|tok/pass 29.12
edit_jsonl|sticky|K=63|passes 54|copy passes 49|tok/pass 52.85
edit_jsonl_long|longest|K=15|passes 579|copy passes 574|tok/pass 11.21
edit_jsonl_long|longest|K=31|passes 280|copy passes 275|tok/pass 23.19
edit_jsonl_long|longest|K=63|passes 168|copy passes 163|tok/pass 38.65
edit_jsonl_long|sticky|K=15|passes 416|copy passes 411|tok/pass 15.61
edit_jsonl_long|sticky|K=31|passes 215|copy passes 210|tok/pass 30.20
edit_jsonl_long|sticky|K=63|passes 113|copy passes 108|tok/pass 57.46
JSONL edits: 29-30 tokens/pass of a 32-row pass (91-94%), 53-57 of 64; code edit 13.7 of 32 (43%), 17.1 of 64: the candidates are long where the text is copied and
the model's own deviations (code edit) cap it. So with 32 rows acceptance does not limit JSONL; the pass cost does.

### Y6. What it would buy (estimate; `scripts/edit_width_oracle.py`, `m27/width_oracle.md`)
Policy: copy candidate >= 16 tokens -> 32-row pass, shorter -> 16-row pass, no candidate -> bdraft2 16 rows (3.5 tokens/pass assumed); 32-row cost 67 / 60 ms;
the replay of the current 16-row hybrid gives 250 / 313 / 315 against the measured 241 / 296 / 284 (model is 4-10% optimistic).
edit_code|today(a8 cost)|16-row copy passes 5|32-row passes 188|fallback passes 43|est tok/s 302
edit_code|narrow fixed|16-row copy passes 5|32-row passes 188|fallback passes 43|est tok/s 330
edit_code|16-row only (model of m26)|est tok/s 250
edit_jsonl|today(a8 cost)|16-row copy passes 0|32-row passes 93|fallback passes 1|est tok/s 439
edit_jsonl|narrow fixed|16-row copy passes 0|32-row passes 93|fallback passes 1|est tok/s 490
edit_jsonl|16-row only (model of m26)|est tok/s 313
edit_jsonl_long|today(a8 cost)|16-row copy passes 0|32-row passes 210|fallback passes 1|est tok/s 446
edit_jsonl_long|narrow fixed|16-row copy passes 0|32-row passes 210|fallback passes 1|est tok/s 497
edit_jsonl_long|16-row only (model of m26)|est tok/s 315
Scaled by the model's bias: code edit ~280-310, JSONL ~410-455, long JSONL ~415-460 tok/s (now 241 / 296 / 284). All of this assumes a 16-bit-activation 32-row GEMM at about the 8-bit cost;
the current 8-bit kernel is not usable for verification (different activation precision than the greedy reference).

### Y7. Conclusions and order of work
1. 32 rows can come close to 16 rows on the wide shapes (+16-21% for 2x rows, latency bound, DRAM 74%); the gap is the **narrow shapes (down, out_proj)**, 66% of the extra GEMM time, idle machine (320 threads), not DPAS or registers.
2. Cheap first step without a new kernel: segment rule for m=32 (down: -22%). Then a pipelined (PIPE=2-style, prefetching, 32-bit addresses) loop for 32 rows; expected GEMM(32) ~41 ms (a8) instead of 48.
3. The blocking item is a **16-bit-activation 32-row kernel**: it does not fit 128 GRF (needs 256-GRF mode or a split such as two 16-token halves sharing each weight tile through registers/SLM); its cost is unknown, this is the main risk.
4. The engine needs `MAX_TOKENS` 32, and GDN grows 0.25 ms/row (+4 ms at 32 rows): GDN's per-token recurrence is the next non-GEMM target.
5. Payoff if all holds: JSONL ~410-460 tok/s (+40-55%), code edit ~+15-25%. 1000 tok/s still needs ~64 rows at Main <= ~65 ms, i.e. a different verification structure.


## Part Z — 32-row GEMM: segment rule and pipelined loop (adopted; engine still limited to 16 rows) (2026-11-20)

Done: items 1 and 2 of Part Y7, in `kernels/gemm/gemm.cpp`, `kernels/model/model.cpp`, `tools/benchmark/src/main.rs`. The 16-row and shorter paths are unchanged
(unit times identical to the old build, 34.90 vs 34.93 ms GEMM sum; end-to-end hybrid JSONL edit 298.4 tok/s, Main 48.13 ms = Part X; `m28/regress2_jsonl.log`).
1. **Segment rule for more than 16 rows** (`model.cpp`): `down` (cols > 8192) uses 4 segments when m > 16 (-22% at 32 rows in Part Y, `segs_narrow_m32.txt`). Not reachable from the engine yet.
2. **Pipelined loop for 32 rows**. Three variants were measured (`m28/`, `xf-bench --cold --format s4 --tokens 16,32,64`, all results exact against the CPU reference, also s8/s3/s2/bf16 at 32/64 rows, `other_formats_exact.txt`):
   * 8-bit activations, 4 token groups per thread, software-pipelined pointer-bumped loop: GEMM sum 45.1 -> **36.1 ms** (16 rows: 33.8); every narrow shape drops to 16-row cost +17-25% (`unit_p32_*.txt`). Not used by the engine (activations are 16-bit there).
   * 16-bit activations, the same kernel: **79.8 ms**, slower than the old loop (49.3): two planes x 4 groups x 2 stages do not fit 128 GRF (spills). Kept as `XF_GEMM_A16_32=pipe` for study only.
   * **16-bit activations, "split" (default now)**: the 16-row pipelined kernel runs for two token groups and the two groups of a row block are **adjacent threads** (`tg = gid % groups`), so
     the second group reads the weight tile from cache instead of DRAM. With the groups far apart (`XF_GEMM_TGFAST=0` experiment, since removed: order is now always group-fastest; it equals the old order for one group) the same kernel is much slower (gate_up 0.447 vs 0.268 ms, qkvz 0.192 vs 0.129).
     Needs no extra registers (128 GRF, no spill), no new loop. `XF_GEMM_P32=0` or `XF_GEMM_A16_32=old` restore the old plain loop.
   Final cold unit table, ms, 16-bit activations (best segment count per shape, all exact):

| shape | 16 rows (unchanged) | 32 rows (old -> new) | 64 rows (old -> new) |
|---|---|---|---|
|gate_up (64)|0.229|0.284 -> 0.256|0.589 -> 0.369|
|qkvz (48)|0.104|0.134 -> 0.129|0.250 -> 0.206|
|attn_qkv (16)|0.092|0.125 -> 0.123|0.227 -> 0.159|
|down (64)|0.135|0.214 -> 0.179|0.296 -> 0.198|
|out_proj (64)|0.056|0.110 -> 0.066|0.108 -> 0.087|
|lm_head (1)|1.561|2.043 -> 1.706|3.986 -> 2.961|
|**GEMM sum per pass**|**34.93**|**49.31 -> 41.93**|**83.21 -> 57.20**|

   Main-pass GEMM at 32 rows: **41.9 ms (was 49.3)**, i.e. +7.0 ms over 16 rows instead of +14.4; 64 rows: **57.2 ms (was 83.2)**, +22.3 ms over 16 rows: two sequential 32-row passes no longer re-read the weights from DRAM.
   The narrow shapes: down 0.243 -> 0.180 (32 rows), out_proj 0.099 -> 0.068, i.e. about 1.2-1.3x the 16-row time.

Updated estimate of the hybrid with a width policy (`scripts/edit_width_oracle2.py`, `m28/width_oracle2.md`; candidate acceptance exact, pass cost modelled:
Main(32) = 48.1 + 7.0 GEMM + 6.7 non-GEMM = 61.8 ms, Main(64) = 48.1 + 22.3 + ~20 = 90.4 ms; the non-GEMM growth is extrapolated from the 1/8/16-row profile and is the
least certain part; the model overstates the measured 16-row hybrid by 4-10%):
edit_code|widths (16,)|est tok/s 250|passes {16: 330, 32: 0, 64: 0, 'fb': 150}
edit_code|widths (16, 32)|est tok/s 323|passes {16: 5, 32: 188, 64: 0, 'fb': 150}
edit_code|widths (16, 32, 64)|est tok/s 346|passes {16: 5, 32: 6, 64: 115, 'fb': 150}
edit_jsonl|widths (16,)|est tok/s 313|passes {16: 181, 32: 0, 64: 0, 'fb': 5}
edit_jsonl|widths (16, 32)|est tok/s 476|passes {16: 0, 32: 93, 64: 0, 'fb': 5}
edit_jsonl|widths (16, 32, 64)|est tok/s 625|passes {16: 0, 32: 1, 64: 48, 'fb': 5}
edit_jsonl_long|widths (16,)|est tok/s 315|passes {16: 411, 32: 0, 64: 0, 'fb': 5}
edit_jsonl_long|widths (16, 32)|est tok/s 483|passes {16: 0, 32: 210, 64: 0, 'fb': 5}
edit_jsonl_long|widths (16, 32, 64)|est tok/s 649|passes {16: 0, 32: 1, 64: 107, 'fb': 5}
Scaled by that bias: JSONL edits ~440-450 tok/s with 32 rows (now 296 / 284 measured), ~580-600 with 64 rows; code edit ~300 / ~320 (now 241).
Still to do before any of this is real: the engine at 32 / 64 rows (`XF_MAX_TOKENS`, scratch buffers, GDN recurrence of 32+ tokens, attention for 32+ query rows), the bdraft2 interface for longer blocks, and
the verification-side candidate policy; none of it is implemented here.


## Part AA — the engine runs 32-row passes (2026-11-20)

`XF_MAX_TOKENS` / `MAXM` / `MAX_TOKENS` 16 -> 32 (`kernels/include/xfk.h`, `kernels/model/model.cpp`, `crates/xeflash-runtime/src/engine.rs`). Changes:
the workspace scales with MAXM (logits, activations, partial sums; attention row groups 6 -> 12 for `q16`, `pseg`, `psm`, `psd`); the id/io block is 4 x MAXM words
(pass ids [0,32), verify ids [32,64), greedy ids [64,96), greedy logits [96,128)); passes of 17..32 rows use 32 tokens per thread in the GEMM (the split 16-bit-activation kernel of Part Z);
the tap capture keeps `[5][16][5120]` for rows 0..15 (the layout the external drafter reads, unchanged) and a second block for rows 16..31
(`Engine::read_taps_hi`, `taps_device_ptr_hi`); the 32-row segment rule added in Part Z was removed again (with the split kernel one segment is fastest for every shape: down 0.179 vs 0.198 ms).
No other kernel needed a change: GDN, attention (all KV modes), norm, quantisation, MLP and argmax were already written for m rows.

### AA1. Exactness: one wide pass against passes of at most 16 rows (`xf-run wide`, `scripts/wide_check.sh`, `benchmarks/results/m29/wide_*.log`)
The last `rows` tokens of a real prompt are run (a) as passes of <= 16 rows with commit, (b) as one pass of `rows` tokens with commit, from the same prefilled state. Compared:
greedy token and the bit pattern of its logit for every row, the GDN state matrices + convolution history of each of the 48 DeltaNet layers, the KV cache of each of the 16 attention layers
(per-layer hashes, XF_KV = fp32 / bf16 / fp16 / xmx), and the whole-state hash.

| case | KV | rows | position | output tokens + logit bits | GDN state (48 layers) | KV cache (16 layers) | whole state |
|---|---|---|---|---|---|---|---|
| JSONL edit | fp32 | 32 | 2895 | 0 of 32 differ | 0 differ | 0 differ | identical |
| JSONL edit | fp32 | 17 | 2910 | 0 of 17 | 0 | 0 | identical |
| code edit | fp32 | 24 | 4745 | 0 of 24 | 0 | 0 | identical |
| JSONL edit | xmx | 32 / 31 / 20 | 2895 / 2896 / 2907 | 0 | 0 | 0 | identical |
| long 8K | xmx | 32 | 7968 | 0 of 32 | 0 | 0 | identical |
| code edit | xmx | 32 | 4737 | 0 of 32 | 0 | 0 | identical |
| JSONL edit | fp16 / bf16 | 32 | 2895 | 0 of 32 | 0 | 0 | identical |
(rows cross a 64-position block boundary in the JSONL cases). Bit-identical in all 11 cases.
16-row path unchanged: hybrid JSONL edit 298.1 tok/s, Main 48.2 ms (Part X: 298.4 / 48.1), same tokens and state as greedy; the MTP path gives identical tokens for K=0 and K=7.
Memory: workspace at 60K context 0.123 -> 0.245 GiB; 60K + bdraft2 still loads (0.15 GiB free, `m29/fit60k_bdraft2.log`).

### AA2. Measured Main pass at 32 rows (`xf-run gen --profile`, XF_KV=xmx; unprofiled = real time; stages synchronised)
| ctx | rows | norm | quant | GEMM | GDN | attn | mlp | head | **unprofiled pass** |
|---|---|---|---|---|---|---|---|---|---|
| ~3K | 16 | 2.00 | 2.00 | 35.50 | 6.50 | 2.02 | 2.10 | 1.64 | **47.0 ms** |
| ~3K | 24 | 2.35 | 2.42 | 44.47* | 8.00 | 2.87 | 2.87 | 1.82 | 59.7* |
| ~3K | 32 | 2.32 | 2.51 | 41.52 | 10.16 | 3.14 | 3.38 | 1.86 | **59.8 ms** |
| ~8K | 16 | 2.07 | 2.08 | 35.66 | 6.51 | 4.70 | 2.12 | 1.65 | **49.7 ms** |
| ~8K | 32 | 2.33 | 2.52 | 41.57 | 10.17 | 7.24 | 3.41 | 1.85 | **64.0 ms** |
(* 24 rows was measured before the segment rule was removed; every pass of 17..32 rows runs as 32.) 32 rows cost 1.27x (3K) / 1.29x (8K) of 16 rows. 16 -> 32 rows (3K): GEMM +6.0 ms, GDN +3.7, attention +1.1 (+2.5 at 8K), mlp +1.3, norm + quant +0.8.
The estimate of Part Z was 61.8 ms (3K): measured 59.8. The extrapolation of the non-GEMM stages (GDN 0.25 ms/row) held.

### AA3. Consequence
With a 32-row Main pass of 60-64 ms the width-adaptive hybrid (Part Z estimate, JSONL candidates of 29-30 tokens per pass) is estimated at ~440 tok/s after the model's bias correction (measured 16-row hybrid: 296 / 284).
Not done yet: the hybrid itself at 32 rows in `xf-run cmp` (candidate longer than 15 tokens -> 32-row verify; bdraft2 tap catch-up of up to 32 rows through the two tap blocks), and its end-to-end measurement.


## Part AB — where the GDN time grows with the number of rows (2026-11-20)

`XF_PROF_DETAIL=1 XF_KV=xmx xf-run gen <s4-cal> edit_jsonl.json 8 --profile --ctx 4096` (log `benchmarks/results/m30/gdn_detail_3k.log`; 6 passes x 48 DeltaNet layers per row count;
"net" = per-kernel time without the empty-queue synchronisation, per layer). GDN is independent of the context length, so one position is enough.

kernel|m=1 us/layer|m=8 us/layer|m=16 us/layer|m=24 us/layer|m=32 us/layer|16->32 (us/layer)|16->32 (ms/pass, x48)|share of growth|slope us/row/layer (16->32)
gdn:core|43.5|59.0|77.9|96.2|114.8|+36.9|+1.77|49%|2.31
gdn:gemv-ab|28.0|25.7|40.7|44.9|58.4|+17.7|+0.85|23%|1.11
gdn:conv|15.8|15.8|23.3|30.9|38.0|+14.7|+0.71|19%|0.92
gdn:post|14.9|15.3|15.9|15.5|21.3|+5.4|+0.26|7%|0.34
gdn:gate|9.4|9.9|9.7|9.6|10.6|+0.9|+0.04|1%|0.06
gdn:qk-norm|9.6|10.3|10.0|10.3|10.4|+0.4|+0.02|1%|0.03
sum|121.2|136.0|177.5|207.4|253.5|+76.0|+3.65|100%|4.75
sum ms/pass (x48)|5.82|6.53|8.52|9.96|12.17

Measured: **gdn:core is half of the growth (49%), not all of it.** From 16 to 32 rows the GDN stage grows by 76 us per layer = 3.65 ms per pass (the stage profile of Part AA gave +3.7 ms): core +1.77 ms,
gemv-ab (the a/b gate projections, 96 rows) +0.85 ms, conv +0.71 ms, post +0.26 ms; gate and qk-norm are flat (10 us, launch-bound). Per extra row: core 2.3 us/layer
(0.11 ms per pass), gemv-ab 1.1, conv 0.9, post 0.3. Linear extrapolation to 64 rows: GDN about 20 ms (now 12.2 at 32 rows in this accounting, 8.5 at 16), i.e. the next-largest
non-GEMM growth after attention at long context.

Why (hypotheses from the code, not yet tested): all three growing kernels re-read data per token that does not depend on the token.
* `gdn:core` (`k_gdn_core`): one thread per (value head, column) walks the tokens; every token it reloads k and q (2 x 512 B) that all 128 threads of the head load too:
  6144 threads x 1 KB x 32 tokens = 200 MB of L1/L3 loads per layer in 115 us, about 1.7 TB/s, the ceiling seen for activation re-reads in Part P. The chain (decay, hsum, update, hsum) per token is also serial.
* `gdn:gemv-ab` (`k_gemv_f32`, 96 x m threads): each thread streams its own 20 KB weight row for every token: 63 MB of cached weight re-reads at 32 rows.
* `gdn:conv` (`k_conv`, m x 160 threads): each output row re-reads 4 input rows (window overlap), 4x the loads of a sliding window.

What is compatible with the bit-exact condition (identical results to the 16-row / 1-row passes, tested by `xf-run wide`): changes that keep the arithmetic of every output element unchanged and only share loads:
two or four value columns per thread in the core (k, q loaded once, independent chains interleaved), several tokens per thread in gemv-ab (one weight row read, per-token accumulators in the same order),
a sliding window over tokens in conv. Estimated gain at 32 rows 3-5 ms of the 60 ms pass (6-8%), ~10 ms at 64 rows; to be measured.
Rewriting the delta rule as a matrix product over 16-32 tokens (chunked / WY form) removes the token-serial dependency but changes the floating-point summation order, so the result is no longer bit-identical to
single-token decoding: the verifier would then define the "greedy" output only up to rounding, and the same-tokens / same-state guarantee used throughout these measurements would have to be replaced by a tolerance and a measured divergence rate. Not attempted; it only pays if the bit-exact load sharing above is not enough.


## Part AC — width-adaptive copy hybrid at 32 / 64 rows: reproducibility, device-side ring catch-up, faster GDN kernels, 64-row engine (2026-11-21)

### AC1. Reproducibility of the 32-row hybrid (Part AA state, `scripts/edit_wide_hybrid_suite.sh`, `benchmarks/results/m31/`)
5 repeats = 5 processes per task, 450.7 tok/s (450.6-450.7) on the JSONL edit (single run before: 450.5), 419.9 (419.6-420.1) on the long JSONL edit, 315.7 on the code edit (hw4/fixed8); every run identical to greedy (tokens and state); the greedy answer of the JSONL tasks equals the official expected text 5/5.

### AC2. Device-side ring catch-up of the drafter
`xbd_ctx_dev` (`experimental/bdraft2/xbd.cpp`): the tap block of the main engine is copied device-to-device into the drafter's capture buffer (waited for, the main engine overwrites its taps next) and the ring update is queued without waiting; `Bdraft2::ctx_dev` and `ctx_block` in `tools/run`.
Passes of 17..64 rows keep their taps in blocks of 16 rows (`Engine::read_taps_block`, `taps_device_ptr_block`). Draft time per pass of the 32-row hybrid on the JSONL edit: **3.47 -> 0.78 ms** (`XF_BD_HOSTCTX=1` = old host path, `m33/host_hw.log` against `dev_hw.log`), 484.4 -> 502.3 tok/s; the 16-row hybrid 1.8 -> 0.15 ms.

### AC3. GDN kernels (bit-identical to the originals; originals kept with `XF_GDN_OLD=1`)
`k_gdn_core_cb<CB>` (CB value columns per thread: k and q loaded once, CB independent chains), `k_gdn_commit_cb`, `k_conv_tb<TB>` (TB tokens per thread, sliding window, weights loaded once), `k_gemv_f32_tb<TB>` (a weight row read once for TB tokens);
per-token arithmetic unchanged. Per-kernel time (`XF_PROF_DETAIL`, net us per layer; `scripts/gdn_detail_sweep.sh`, `m32/detail/`): cb* rows = core variants with conv/gemv at TB 4, tb* rows = conv/gemv token block 2/8/16 with the core at CB 2.

config|kernel|m=16|m=32|m=64   (net us per layer)
old|gdn:core|78.9|117.0|193.9
cb1|gdn:core|79.0|116.4|194.1
cb2|gdn:core|51.7|77.8|135.6
cb4|gdn:core|49.3|77.5|135.2
tb2|gdn:core|51.3|77.8|135.7
tb8|gdn:core|52.0|77.4|135.2
tb16|gdn:core|51.8|77.6|135.0
old|gdn:gemv-ab|40.8|58.5|90.9
cb1|gdn:gemv-ab|45.9|50.8|92.4
cb2|gdn:gemv-ab|46.5|51.0|92.7
cb4|gdn:gemv-ab|46.8|51.1|92.3
tb2|gdn:gemv-ab|35.1|58.1|85.7
tb8|gdn:gemv-ab|78.1|76.7|87.3
tb16|gdn:gemv-ab|140.9|137.9|137.2
old|gdn:conv|23.5|38.4|63.0
cb1|gdn:conv|15.5|18.1|28.3
cb2|gdn:conv|15.9|18.5|28.5
cb4|gdn:conv|15.9|18.3|28.1
tb2|gdn:conv|16.0|23.2|37.7
tb8|gdn:conv|15.8|17.6|23.6
tb16|gdn:conv|18.4|18.7|22.3

config|GDN sum m=16 (ms/pass)|m=32|m=64
old|8.59|12.30|19.03
cb1|8.43|10.87|17.47
cb2|7.20|9.06|14.70
cb4|7.10|9.04|14.64
tb2|6.61|9.65|14.77
tb8|8.72|10.22|14.17
tb16|11.83|13.29|16.47

Findings: the core gains 34% with 2 columns per thread (117 -> 78 us at 32 rows, 194 -> 136 at 64) and nothing more with 4: it is bound by the serial per-token chain (decay, 128-lane reduction, update, reduction), not by the k/q loads.
conv: 8 tokens per thread -54% (38.4 -> 17.6 us at 32 rows, 63 -> 24 at 64). gemv-ab only has 96 x m / TB threads, so wide blocks starve the GPU: best TB 2 (m <= 16, 40.8 -> 35.1 us), 4 (17..32 rows, 58.5 -> 51.0), 2 (64 rows, 90.9 -> 85.7); a thread count high enough would need splitting the sum over K, which changes the summation order (not bit-identical).
Defaults: CB 2, conv TB 8, gemv TB by row count. Exactness (`scripts/gdn_ab.sh`, `m32/`, `m33/ab/`): digest of tokens + logit bits + per-layer state hashes identical to `XF_GDN_OLD=1` for 16, 32 and 64 rows (xmx), 32 rows (fp32) and for the CB 1/4 and TB 4 variants.
Main pass (unprofiled, `xf-run wide`, position 2927): **16 rows 46.72 -> 44.80 ms, 32 rows 59.80 -> 56.64, 64 rows 90.08 -> 85.06**; the commit kernel (the same state update for the accepted tokens) is included in every hybrid cycle.

### AC4. The engine at 64 rows
`MAXM` / `XF_MAX_TOKENS` / `MAX_TOKENS` = 64. Passes of 33..64 rows use 32 tokens per thread (pad of 32) in the GEMM; the split kernel (Part Z) now gets the padded token count: **bug found by the exactness test**, rows 33..48 (stride mismatch between the 32-token activation layout and the 16-token kernel pad) gave wrong results in all rows
(`m34/wide`: 48 of 48 rows differ), fixed in `kernels/gemm/gemm.cpp`; 32 and 64 rows were not affected. The SLM attention kernel is limited to 32 rows (work-group of 2 threads per row <= 64); above that the register-tile kernel runs (fp32 / bf16 / fp16 KV).
Memory: rows per pass are capped by context: 64 up to a context of 32,768, 16 above (the 64-row workspace, with per-layer GDN scratch replicated in 48 layers, would take the 0.4 GiB that is left for the drafter at 60K: the first version used 0.21 GiB more, found by `fit60k`); the 60K footprint is back to exactly the previous one (19.2767 GiB requested, 3.17 GiB free before the drafter, `m36/fit60k_bdraft2.log`).
Exactness, one pass of n rows against passes of <= 16 rows (`scripts/wide_check.sh`, `m34/wide2/`): 23 cases, **0 differences** in tokens + logit bits, GDN state (48 layers), KV cache (16 layers), whole state: rows 17, 20, 24, 31, 32, 33, 40, 48, 49, 56, 63, 64; xmx / fp32 / fp16 / bf16 KV; JSONL, code and 8K prompts.
`xf-run cmp --configs hv<min>/<blk>` verifies candidates of >= 32 tokens (up to 63) in one 64-row pass, 16..31 tokens in 32 rows, 4..15 in 16 rows, otherwise bdraft2 with block `<blk>`.

### AC5. End-to-end, 5 repeats (one process each; `scripts/edit_wide64_suite.sh`, `benchmarks/results/m35/`; s4-cal, XF_KV=xmx, n_new = length of the expected answer)
task|config|tok/s mean (min-max)|tokens/pass|accept1|Main ms/pass|Draft ms/pass|answer = expected|same tokens+state as greedy
edit_code|greedy|25.6 (25.6-25.6)|1.00|-|39.11|-|0/5|-
edit_code|bd2:adapt-cost|105.0 (104.8-105.1)|5.45|0.973|44.39|6.58|0/5|5/5
edit_code|hy4+bd2:fixed8|260.6 (260.5-260.6)|12.90|0.806|47.02|1.11|0/5|5/5
edit_code|hw4+bd2:fixed16|336.4 (336.3-336.5)|20.65|0.806|57.18|2.38|0/5|5/5
edit_code|hw4+bd2:fixed8|344.1 (344.0-344.1)|20.56|0.806|55.90|2.04|0/5|5/5
edit_code|hv4+bd2:fixed16|363.7 (363.7-363.8)|29.07|0.806|74.07|3.53|0/5|5/5
edit_code|hv4+bd2:fixed8|371.8 (371.7-371.8)|28.89|0.806|72.36|3.04|0/5|5/5
edit_jsonl|greedy|25.9 (25.9-25.9)|1.00|-|38.63|-|5/5|-
edit_jsonl|bd2:adapt-cost|277.5 (277.3-277.5)|15.26|1.000|46.10|7.39|5/5|5/5
edit_jsonl|hy4+bd2:fixed8|323.4 (323.3-323.4)|15.60|1.000|46.56|0.15|5/5|5/5
edit_jsonl|hw4+bd2:fixed16|502.3 (502.3-502.4)|31.03|1.000|58.62|0.77|5/5|5/5
edit_jsonl|hw4+bd2:fixed8|492.9 (492.8-493.0)|30.37|1.000|58.54|0.73|5/5|5/5
edit_jsonl|hv4+bd2:fixed16|644.4 (644.3-644.5)|59.48|1.000|86.46|1.86|5/5|5/5
edit_jsonl|hv4+bd2:fixed8|620.8 (620.7-620.9)|57.10|1.000|86.38|1.74|5/5|5/5
edit_jsonl_long|greedy|25.3 (25.3-25.3)|1.00|-|39.55|-|5/5|-
edit_jsonl_long|bd2:adapt-cost|262.4 (262.3-262.5)|15.10|1.000|48.66|7.39|5/5|5/5
edit_jsonl_long|hy4+bd2:fixed8|309.5 (309.5-309.6)|15.72|1.000|49.15|0.11|5/5|5/5
edit_jsonl_long|hw4+bd2:fixed16|465.2 (465.2-465.3)|30.78|1.000|63.09|0.67|5/5|5/5
edit_jsonl_long|hw4+bd2:fixed8|463.6 (463.5-463.6)|30.63|1.000|63.03|0.66|5/5|5/5
edit_jsonl_long|hv4+bd2:fixed16|590.9 (590.8-590.9)|59.58|1.000|95.10|1.69|5/5|5/5
edit_jsonl_long|hv4+bd2:fixed8|586.5 (586.5-586.6)|59.04|1.000|94.99|1.65|5/5|5/5

Result: JSONL edit **323 (16 rows) / 502 (32) / 644 tok/s (64)** from 277 with bdraft2 alone and 25.9 greedy; long JSONL edit 310 / 465 / **591**; code edit 261 / 344 / 372 (from 105). Every configuration gives the same tokens and state as greedy in all 5 repeats (the JSONL answers equal the official expected text 5/5; the code edit stays 0/5 for greedy and all configurations, the 4-bit model's own deviation).
The spread over 5 processes is below 0.2 tok/s; the final binary reproduces 323.2 / 502.1 / 644.1 on the JSONL edit (`m36/final_jsonl.log`). 600 tok/s is reached on the JSONL edit (644), not yet on the long JSONL edit (591) and not on the code edit (372: only 62% of its passes are copy passes of that length, the rest is the model's own text).
Main pass at 64 rows 86-95 ms (9% over the 85 ms of a plain pass: commit + the drafter catch-up), so the cycle is now 94% Main; what is left is Main itself: GEMM 57 ms at 64 rows (Part Z), GDN ~14 ms, attention (+7 ms at 8K).


## Part AD — 64-row GEMM: why the XMX stays at 60-70%, a faster kernel for 33..96 rows, and where 1000 tok/s stops (2026-11-21)

### AD1. What 1000 tok/s needs (JSONL edit)
tok/s = tokens per pass / cycle. Measured at 64 rows (Part AC): 59.5 tokens per pass, so 1000 tok/s needs a cycle (Main + draft + commit) of **59.5 ms**; the cycle was 88.5 ms.
At 128 rows the copy candidates would give 89.2 tokens per pass (JSONL edit; 101.5 on the long JSONL edit; exact offline replay, `m37_k_accept.md`), needing **89 ms** (100 ms).
Floors: all s4 weights are 25.6 G; a 64-row pass does 6.55 TOP of int8 work (weights x 2 x rows x 2 planes of the 16-bit activations) = **33.3 ms at the 196.5 TOPS XMX peak** (66.7 ms at 128 rows).
The rest of the pass at 64 rows (profile `m37/detail_3k.log`, synchronised stages, ms): GEMM 56.9 + head 3.2, GDN 14.2, attention 6.5, mlp-act 6.1, norm 3.1, quant 3.4 (total 93.4 with the waits, 85.3 unprofiled): everything except the GEMM is ~29 ms.
So 59.5 ms is out of reach even with the GEMM at 100% of the peak (33.3 + 29 = 62.3 ms).

### AD2. VTune and ISA of the 16-bit-activation GEMM (rows 16 / 64 / 128; `scripts/vtune_a16.sh`, `m37/vtune/`; interactive charts: `m37/vtune_report.html`)
GEMM at 64 rows: 57.5 ms = **58% of the XMX peak** (128 rows: 101 ms, 66%); best single kernel 75% (gate+up with the new kernel). Counters of the old (split) kernel, gate+up: 16 rows XMX 24%, 64 rows 61%, 128 rows 68%; DRAM read 374 / 235 / 131 GB/s
(a64 row pass reads each weight once: not DRAM bound); XVE stalled 55%, SBID 38%, Send 40%, occupancy 92%, no spill, 128 GRF.
Every DPAS (16 rows x 8 tokens x 32 K) consumes a fresh 256-byte activation tile from L1 (the weight tile sits in registers and is reused over the 8 DPAS of a tile): at 71% of the peak that is 17 G DPAS/s x 256 B = **4.4 TB/s of L1 load traffic**
(1.4 GB per gate+up call against 0.09 GB of weights); the L3 sees only 0.5-0.6 TB/s, the DRAM 0.2-0.3. The XMX is limited by this operand stream (load-queue full: Send stall, and load latency: SBID stall), not by DRAM, DPAS issue or registers.

### AD3. Four kernel variants against the split kernel at 64 rows (`xf-bench --cold`, `XF_GEMM_A16_32`; hardware counters `scripts/vtune_modes.sh`, `m38/vtune/`)
ISA of the hot loop, 2 tiles per trip (`isa_analyze.py`; for the 256-GRF kernels `ISA_OCLOC_OPTS=-ze-opt-large-register-file`, which is what the runtime applies for the `grf_size<256>` kernel property):

variant|label|GRF|scratch|spill sends|loads/trip|load B/trip|dpas/trip|loop instr|SBID waits|loads before 1st wait|int-alu|sync
split (128 GRF, 16 tok/thread)|submit<0,8,2,1,true,2,false>|128|False|0|10|2560|8|35|4|5|7|3
lgrf (256 GRF, 32 tok/thread)|submit<0,8,4,1,true,2,true>|256|False|0|18|4608|16|55|9|9|7|7
rb2 (256 GRF, 2 row blocks x 16 tok)|submit<0,8,2,1,true,2,true,2>|256|False|0|12|3072|16|49|5|6|9|4
rb2s (128 GRF, 2 row blocks x 16 tok)|submit<0,8,2,1,true,2,false,2>|128|False|0|12|3072|16|51|7|6|9|6
pd2 (128 GRF, distance 2, 16 tok)|submit<0,8,2,1,true,3,false,1>|128|False|0|20|5120|16|59|9|5|12|7
pd2l (256 GRF, distance 2, 32 tok)|submit<0,8,4,1,true,3,true,1>|256|False|0|36|9216|32|94|14|1|12|10

Unit time per shape, ms (all exact against the CPU reference):

shape (64 rows)|split ms (exact)|lgrf ms (exact)|rb2 ms (exact)|rb2s ms (exact)|pd2 ms (exact)|pd2l ms (exact)
merged.qkvz|0.2063 (y)|0.1684 (y)|0.2117 (y)|0.1658 (y)|0.2037 (y)|0.1805 (y)
merged.attn_qkv|0.1592 (y)|0.1334 (y)|0.1652 (y)|0.1596 (y)|0.1621 (y)|0.1389 (y)
out_proj|0.0871 (y)|0.0795 (y)|0.0868 (y)|0.0927 (y)|0.0926 (y)|0.0916 (y)
merged.gate_up|0.3692 (y)|0.3101 (y)|0.3810 (y)|0.3520 (y)|0.3737 (y)|0.3301 (y)
mlp.down|0.1997 (y)|0.2330 (y)|0.2123 (y)|0.2331 (y)|0.2222 (y)|0.2626 (y)
lm_head|2.9729 (y)|2.3579 (y)|2.6238 (y)|2.3949 (y)|2.5655 (y)|2.3840 (y)
GEMM sum @64 rows|57.4 ms|52.4 ms|59.0 ms|56.3 ms|59.0 ms|57.1 ms

Counters at 64 rows (spill 0 everywhere):

mode|shape|avg us|spill|GRF|XVE act%|stall%|idle%|occ%|XMX%|ALU0%|ALU1%|SBID%|Send%|DistAcc%|L3 miss%|DRAM GB/s|L3 read GB/s|XMX instr/call (M)|ALU1 instr/call (M)
split|merged.gate_up|369|0|128|38.3|55.3|6.4|92.3|60.8|1.0|6.0|38.0|39.7|1.7|44.0|235|527|5.39|8.48
split|mlp.down|196|0|128|33.4|59.8|6.7|93.0|55.7|0.3|4.1|39.5|47.6|0.6|78.0|225|428|2.61|3.05
split|merged.qkvz|206|0|128|31.5|46.7|21.8|75.8|50.0|0.8|4.9|32.1|32.5|1.2|47.5|194|405|2.47|3.88
lgrf|merged.gate_up|312|0|256|42.1|51.7|6.1|91.2|71.5|1.0|4.3|31.1|20.1|3.3|47.1|276|593|5.33|5.08
lgrf|mlp.down|225|0|256|28.0|66.2|5.8|94.1|48.7|0.2|1.9|34.5|59.6|0.6|97.0|196|373|2.62|1.67
lgrf|merged.qkvz|170|0|256|35.6|49.8|14.6|77.8|59.9|0.9|3.6|32.1|19.4|2.6|48.0|233|517|2.45|2.33
rb2|merged.gate_up|383|0|256|34.7|58.8|6.5|92.3|58.7|0.9|3.9|38.0|34.1|1.9|47.1|228|475|5.42|5.76
rb2|mlp.down|208|0|256|29.8|63.8|6.4|93.5|52.5|0.2|2.5|42.0|45.8|0.5|83.5|210|399|2.59|1.96
rb2|merged.qkvz|211|0|256|29.0|50.7|20.3|77.5|49.0|0.7|3.3|33.1|29.5|1.5|48.5|190|388|2.48|2.63
rb2s|merged.gate_up|352|0|128|37.1|55.6|7.3|83.6|63.6|0.9|4.2|30.8|22.0|0.8|83.4|249|388|5.35|5.66
rb2s|mlp.down|228|0|128|27.1|67.4|5.5|47.2|48.2|0.2|2.3|49.3|7.6|0.3|94.0|196|373|2.66|2.00
rb2s|merged.qkvz|166|0|128|35.5|47.5|17.0|69.0|61.2|0.9|4.1|22.4|11.0|1.0|67.2|242|444|2.45|2.60

Reading:
* **lgrf = 256 GRF, 32 tokens per thread (adopted for 33..96 rows):** the weight tile is loaded and expanded once per 32 tokens instead of twice, ALU1 instructions -40% (8.5 -> 5.1 M per call), Send stall 40% -> 20%, XMX 61% -> 71.5%, 369 -> 312 us (-15%) although occupancy is the same 91% of a half-size thread pool. Loads per DPAS 1.25 -> 1.13.
* **rb2 (two row blocks per thread, activation tile shared by two weight tiles, 256 GRF) is not faster** although it has the fewest loads per DPAS (0.75): Send 34%, SBID 38%, XMX 59%, 383 us. With 4 threads per EU there is too little latency hiding: the occupancy loss cancels the saved loads. **rb2s** (same at 128 GRF, no spill) reaches 63.6% / 352 us (+5% over split), 83% occupancy; on `qkvz` it is the best (166 us).
* **`down` gets slower with lgrf** (196 -> 225 us, XMX 56 -> 49%, Send 60%): 320 row blocks x 2 token groups = 640 threads = exactly 4 per EU, K = 17408: a long loop with too few threads in flight. So `down` stays on the split kernel.
* **A longer prefetch distance does not reduce the stalls.** Variants with the loads of tile t + 2 issued before the DPAS of tile t (four rotating buffers, `pd2`: 128 GRF / `pd2l`: 256 GRF) are slower than their prefetch-1 versions (59.0 vs 57.4 ms and 57.1 vs 52.4 ms): IGC reschedules the loads close to their use (`pd2l`: 1 load before the first SBID wait, against 9 of 18 in `lgrf`), so the source-level distance does not become a real one.
* **Where are the duplicate loads?** Weights: the 4 (2 with lgrf) token groups of a row block are adjacent threads of one work-group and read the same tile from L1 (L3 read 2.2x the DRAM traffic, DRAM = one read of the weights); activations: every thread re-reads its token planes from L1 (87% L1 hit, 4.4 TB/s), halving this with rb2 did not pay because of the occupancy.
Not adopted: rb2, rb2s, pd2, pd2l (kept behind `XF_GEMM_A16_32=rb2|rb2s|pd2|pd2l`; 32-token pipelined loop at 128 GRF `pipe` spills, 79.8 ms).

### AD4. Dispatch (default, `kernels/gemm/gemm.cpp`): 33..96 rows and K <= 8192 -> lgrf, otherwise the split kernel
Per-shape, per-row-count measurement (split / lgrf, ms; `m38/unit_rows.md`): 24 rows 41.9 / 40.3, 32 rows 41.8 / 42.4 (one token group: too few threads), 48 rows 57.0 / 50.8, 96 rows 84.9 / 80.8, 128 rows 101.5 / 104.6 (best per shape: 100.0).

rows|merged.qkvz: split / lgrf (ms)|merged.attn_qkv: split / lgrf (ms)|out_proj: split / lgrf (ms)|merged.gate_up: split / lgrf (ms)|mlp.down: split / lgrf (ms)|lm_head: split / lgrf (ms)|sum split|sum lgrf|sum best-per-shape
24|0.128 / 0.123|0.122 / 0.115|0.063 / 0.064|0.257 / 0.250|0.183 / 0.169|1.712 / 1.631|41.9|40.3|40.2
32|0.128 / 0.130|0.122 / 0.120|0.063 / 0.065|0.257 / 0.256|0.180 / 0.188|1.716 / 1.641|41.8|42.4|41.6
48|0.206 / 0.169|0.159 / 0.134|0.087 / 0.076|0.369 / 0.309|0.195 / 0.212|2.906 / 2.312|57.0|50.8|49.6
96|0.243 / 0.213|0.237 / 0.206|0.128 / 0.113|0.525 / 0.472|0.354 / 0.402|4.932 / 4.143|84.9|80.8|77.8
128|0.331 / 0.317|0.285 / 0.274|0.123 / 0.121|0.670 / 0.685|0.375 / 0.432|6.297 / 5.823|101.5|104.6|100.0

Unit GEMM sum per pass, 16-bit activations, new default: **16 rows 35.0 ms (unchanged), 32 rows 42.0 (unchanged), 64 rows 50.5 (was 57.4)**:

shape|16 rows ms|32 rows ms|64 rows ms (TOPS, % of peak)
merged.qkvz|0.1041|0.1287|0.1709 (126, 64%)
merged.attn_qkv|0.0924|0.1230|0.1364 (138, 70%)
out_proj|0.0571|0.0665|0.0791 (102, 52%)
merged.gate_up|0.2286|0.2566|0.3107 (147, 75%)
mlp.down|0.1349|0.1785|0.1998 (114, 58%)
lm_head|1.5602|1.7064|2.3439 (139, 71%)
GEMM sum|35.0 ms|42.0 ms|50.5 ms

### AD5. Exactness and end-to-end
* One pass of n rows against passes of <= 16 rows (`scripts/wide_check.sh`, `m39/wide/`): 23 cases (17..64 rows, xmx / fp32 / fp16 / bf16 KV, JSONL / code / 8K prompts), **0 differences** in tokens + logit bits, GDN state (48 layers), KV cache (16 layers), whole state; the digest (logits, per-layer states) of the new default equals `XF_GEMM_A16_32=split` at 32 and 64 rows.
* Main pass (position 2927, `xf-run wide`): 16 rows 44.81 ms (unchanged), 32 rows 56.63 (unchanged), **64 rows 85.10 -> 81.26**. In the engine the GEMM stage of a 64-row pass went 56.9 -> 52.0 ms and the head 3.2 -> 2.6 (profile); less than the unit gain (57.4 -> 50.5) because the engine alternates 128- and 256-GRF kernels.
* 5 repeats, one process each (`scripts/edit_lgrf_suite.sh`, `m40/`; s4-cal, XF_KV=xmx; same tokens and state as greedy in all 5 repeats; JSONL answers equal the official expected text 5/5, code edit 0/5 as before):

task|config|tok/s mean (min-max)|tokens/pass|accept1|Main ms/pass|Draft ms/pass|answer = expected|same tokens+state as greedy
edit_code|greedy|25.6 (25.6-25.6)|1.00|-|39.10|-|0/5|-
edit_code|bd2:adapt-cost|104.9 (104.9-105.0)|5.48|0.973|44.62|6.62|0/5|5/5
edit_code|hy4+bd2:fixed8|260.6 (260.6-260.6)|12.90|0.806|47.01|1.11|0/5|5/5
edit_code|hw4+bd2:fixed16|336.4 (336.4-336.5)|20.65|0.806|57.17|2.38|0/5|5/5
edit_code|hv4+bd2:fixed16|374.7 (374.7-374.7)|29.07|0.806|71.74|3.52|0/5|5/5
edit_code|hv4+bd2:fixed8|383.3 (383.3-383.4)|28.89|0.806|70.01|3.04|0/5|5/5
edit_jsonl|greedy|25.9 (25.9-25.9)|1.00|-|38.63|-|5/5|-
edit_jsonl|bd2:adapt-cost|277.4 (277.2-277.5)|15.26|1.000|46.11|7.40|5/5|5/5
edit_jsonl|hy4+bd2:fixed8|323.3 (323.3-323.4)|15.60|1.000|46.57|0.15|5/5|5/5
edit_jsonl|hw4+bd2:fixed16|502.2 (502.2-502.3)|31.03|1.000|58.63|0.77|5/5|5/5
edit_jsonl|hv4+bd2:fixed16|671.8 (671.6-671.9)|59.48|1.000|82.70|1.87|5/5|5/5
edit_jsonl|hv4+bd2:fixed8|647.4 (647.1-647.5)|57.10|1.000|82.61|1.74|5/5|5/5
edit_jsonl_long|greedy|25.3 (25.3-25.3)|1.00|-|39.55|-|5/5|-
edit_jsonl_long|bd2:adapt-cost|262.4 (262.3-262.5)|15.10|1.000|48.66|7.38|5/5|5/5
edit_jsonl_long|hy4+bd2:fixed8|309.5 (309.5-309.6)|15.72|1.000|49.15|0.11|5/5|5/5
edit_jsonl_long|hw4+bd2:fixed16|465.2 (465.2-465.3)|30.78|1.000|63.09|0.67|5/5|5/5
edit_jsonl_long|hv4+bd2:fixed16|613.8 (613.7-613.8)|59.58|1.000|91.33|1.69|5/5|5/5
edit_jsonl_long|hv4+bd2:fixed8|609.3 (609.3-609.3)|59.04|1.000|91.22|1.65|5/5|5/5

JSONL edit 644.4 -> **671.8 tok/s** (64 rows), long JSONL edit 590.9 -> **613.8**, code edit 371.8 -> 383.3 (fixed8); 16 / 32 rows unchanged (323.3 / 502.2 on the JSONL edit).

### AD6. 128 rows: realistic cycle (estimate from measured parts) and tokens per pass
GEMM at 128 rows: 100.0 ms (best per shape; the 256-GRF kernel does not help there, 66% of the peak), non-GEMM stages extrapolated linearly from the 32 -> 64-row slopes: GDN ~24.5, attention ~12, mlp-act ~12, norm + quant ~10 (profile scale), x0.92 for the synchronisation of the profile = ~54 ms; commit + draft ~5 ms: **cycle ~160 ms**.
Tokens per pass 89.2 (JSONL edit) / 101.5 (long): **~560 / ~630 tok/s, no better than the measured 64 rows (672 / 614)**. VRAM: the 128-row workspace is ~0.5 GiB at 8K (logits 127 MB, attention partials 107 MB at 8K); fits at short contexts, not at 60K. Not implemented: the estimate says it cannot beat 64 rows.

### AD7. What limits the XMX, and where 1000 tok/s stops
1. The XMX reaches 58% (old) / 71% (new kernel, 75% on the best shape) of the 196.5 TOPS peak at 64 rows. The limit is the **operand stream**: each DPAS needs a fresh 256-byte activation tile loaded from L1 (4.4 TB/s at 71%), the load queue is full (Send stall 20-40%) and the load latency is exposed (SBID 31-38%) because the compiler keeps only about one tile of loads in flight and 256 GRF halves the number of threads that could hide it.
   Sharing the activation tile between two weight tiles (rb2) halves the traffic but costs registers, and the lost occupancy cancels it; a deeper source-level prefetch is undone by IGC's scheduling. Not tried: staging the activation planes in SLM per work-group, or a hand-scheduled loop with explicit load/DPAS interleaving.
2. The 16-bit activations double the work (2 planes); with 8-bit activations the 64-row GEMM would be 36 ms, but that changes the results (not allowed).
3. 1000 tok/s on the JSONL edit needs a 59.5 ms cycle at 64 rows: GEMM floor 33.3 ms + 29 ms of GDN / attention / norm / mlp that does not shrink with the XMX. Today: 88.5 ms (GEMM 50.5 + head ~2.6 + the rest ~29 + commit/draft ~4). At 128 rows 89 ms would be needed against ~160.
   **Not reached; the measured best is 671.8 tok/s (JSONL edit), 613.8 (long JSONL edit).** Remaining levers by size: GDN core (14 ms at 64 rows, bound by its serial chain), the GEMM operand stream (up to ~10 ms if the XMX reached 90%), attention (6.5 ms, more at long context), mlp-act / norm / quant (13 ms of mostly launch-bound small kernels).


## Part AE — cycle accounting, fused small kernels, GDN commit / gemv, and the GEMM operand-supply experiments (2026-11-21)

Baseline: commit 36b5653 (Part AD), 64-row hybrid, JSONL edit 671.8 tok/s (cycle 88.5 ms). Final: **743.2 tok/s (+10.6%), cycle 80.0 ms**, bit-identical. 800 tok/s (cycle 74.4 ms) was **not reached**; the numbers below say what is left.

### AE1. Where the cycle went (the 4 ms nobody counted)
cycle 88.58 ms = Main 82.71 + draft 1.89 + **4.0 ms not in any timer**. Host work is not it (candidate search 0.000 ms, token bookkeeping 0.005 ms per pass, `m41/host_jsonl.log`).
The missing time is the **commit** of the accepted tokens (the DeltaNet state update of the accepted rows, 48 layers x 2 kernels), which runs on the device after the verify pass and is waited for at the top of the next cycle (`xf-run wide` now times it, `m41`): 1.96 / 2.88 / **4.74 ms** for 16 / 32 / 64 rows.

### AE2. Changes adopted (all bit-identical; digest of tokens + logit bits + per-layer states equal to the previous build at 16 / 32 / 64 rows, xmx KV)
| change | 64-row Main pass (ms) | other |
|---|---|---|
| MLP activation fused with the down projection's activation quantisation (`k_mlpact_quant`: one work-group per token, silu(gate) x up kept in registers, row maximum through SLM, 16-bit quantisation; `XF_MLP_FUSE=0` = old) | 81.24 -> 76.28 (-5.0) | 16 rows -1.6 ms |
| commit: state update + convolution history in one launch, 8 value columns per thread (`XF_GDN_COMMIT_CB`, 1 = old) | (commit time) | 4.74 -> 3.00 ms (CB 2: 4.51, CB 4: 3.88) |
| gdn:gemv-ab: 4 rows x 2 tokens per thread above 32 rows (`XF_GDN_GEMV_RT`) | 76.25 -> 75.02 (-1.2) | 88.7 -> 63.5 us per layer |
| GDN output norm fused with the out-projection's quantisation (`k_gdn_post_quant`, `XF_POST_FUSE=0` = old) | with the two rows above 76.28 -> 74.19 | post + act-quant 1.37 + 0.9 -> 1.0 ms |
| next-token loads issued before the update chain in the GDN core / commit, vector load / store of the per-column scalars | 74.19 -> 74.06 (-0.13) | commit 3.00 -> 2.94: negligible, kept |
Result of the Main pass at position 2927 (`m43/wide_*.log`): **16 rows 44.81 -> 42.88 ms, 32 rows 56.63 -> 53.46, 64 rows 81.26 -> 74.06**; commit **1.47 / 1.95 / 2.94 ms**.
GDN core / gemv / commit sweep at 64 rows (`scripts/gdn_sweep2.sh`, `m41/sweep/`; cb = core columns per thread, cc = commit columns per thread, rt = gemv rows x tokens per thread):

variant|core us/layer (m=64)|gemv-ab us|conv us|Main pass 64 rows (ms)|commit 64 rows (ms)|exact (tokens/state)
base|135.3|88.7|24.1|76.25|3.74|identical
cb4|136.4|88.4|23.5|76.23|3.74|identical
cb8|149.5|88.4|23.6|76.86|3.74|identical
cc2|134.7|88.6|23.7|76.25|4.51|identical
cc8|135.3|89.2|23.8|76.21|3.00|identical
rt22|134.8|94.0|23.3|76.53|3.73|identical
rt24|134.5|86.1|23.7|76.15|3.73|identical
rt42|134.8|63.5|23.5|75.02|3.73|identical
rt44|135.0|86.0|23.6|76.07|3.74|identical
rt82|135.1|108.4|23.9|77.18|3.74|identical

Core columns per thread: 2 = 4 (135-136 us), 8 is slower (150 us, register pressure): the core is bound by its serial per-token chain, not by loads.

### AE3. GEMM operand-supply experiments (64 rows, `xf-bench --cold`; none adopted; kernels removed or kept behind `XF_GEMM_A16_32=slm|slm4|slm8`)
1. **Weight prefetch** (explicit `prefetch` of the weight stream 4..32 tiles ahead into L1 / L2, which IGC cannot move): no gain, worse for longer distances (the weights are not the latency problem; the added instructions cost 1.4% even at distance 0, so the code was removed):

prefetch distance (tiles)|16 rows GEMM sum (ms)|64 rows GEMM sum (ms)|gate_up 64 rows (ms)|down 64 rows (ms)|all exact
0|35.51|50.88|0.3091|0.2115|True
4|37.24|50.99|0.3056|0.2177|True
8|37.45|51.62|0.3108|0.2176|True
16|39.08|52.78|0.3200|0.2187|True
32|42.76|56.63|0.3554|0.2251|True

2. **Work-group size** (2 / 4 / 8 / 16 threads) has no effect on the GEMM:

XF_GEMM_WG (threads per work-group)|16 rows GEMM sum|64 rows GEMM sum|gate_up 64|qkvz 64|down 64|out_proj 64
2|35.63|51.16|0.3089|0.1677|0.2123|0.0796
4|35.47|50.89|0.3090|0.1680|0.2115|0.0787
8|35.47|50.93|0.3100|0.1694|0.2122|0.0784
16|35.59|51.17|0.3135|0.1725|0.2116|0.0775

3. **Column segments for `down` at 64 rows** (2 / 4 / 8): 0.316 / 0.337 / 0.386 ms against 0.207 ms with 1 segment (the combine kernel costs more than the extra threads gain).
4. **SLM sharing of the activation planes** (`submit_slm`: 8 threads = 8 row blocks of one 16-token group, each loads one eighth of the stage's activation tiles from L1, stores to SLM (double buffer), one barrier per stage of 2 / 4 / 8 tiles, all threads read the complete tiles from SLM; exact, 128 GRF, no spill; ISA: 16 DPAS and 35 sync instructions per stage). Unit time gate+up 0.434 / 0.432 / 0.595 ms (stage of 2 / 4 / 8 tiles) against 0.310 ms for the adopted kernel, qkvz 0.234 against 0.168, down 0.210 against 0.200.
   Counters (gate+up, 64 rows): **the L1 operand traffic is removed (Send stall 40% -> 5.9%) but the XMX falls from 71.5% to 52%**, because the stage now waits at a barrier (23%), on the SLM store -> load dependency (Dist/Acc 20%) and on SBID (29%); a longer stage does not amortise it:

kernel|shape|avg us|GRF|XVE act%|stall%|idle%|occ%|XMX%|SBID%|Send%|Barrier%|DistAcc%|L3 miss%|DRAM GB/s|sync instr/call (M)
slm|merged.gate_up|435|128|56.5|38.7|4.8|93.1|51.8|28.9|5.9|22.9|19.6|63.0|202|0.68
slm|mlp.down|207|128|51.6|41.8|6.6|93.3|52.5|35.2|6.9|29.1|22.2|86.7|211|0.33

5. **L1 against SLM bandwidth** (`kernels/probe/l1_slm_bw.cpp`, 512-byte loads, TB/s; L1 = global loads hitting a resident buffer):

```
threads wg | L1 TB/s (N=4) | SLM TB/s (N=4)
  1280  4 |   6.17 |   9.05
  1280  8 |   8.59 |   9.66
  2560  4 |   6.47 |   9.44
  2560  8 |   8.16 |   9.72
  5120  4 |   6.59 |  10.14
  5120  8 |   8.98 |  10.74
```
   The GEMM draws 4.4 TB/s of operand traffic from L1, below the 6.2-9.0 TB/s the L1 sustains in this probe: the L1 data port is not saturated, the limit is the latency / issue of the load -> DPAS dependency, so moving the traffic to SLM (9-10 TB/s) cannot pay for a barrier per stage.
6. Earlier in Part AD (same conclusion): 2 row blocks per thread (fewest loads per DPAS) loses to the lost occupancy; a source-level prefetch distance 2 is undone by IGC (loads sunk to their use).

### AE4. End-to-end, 5 processes per task (`scripts/edit_ae_suite.sh`, `m43/`; s4-cal, XF_KV=xmx; same tokens and state as greedy in every repeat; the JSONL answers equal the official expected text 5/5, the code edit stays 0/5 for greedy and all configurations)
task|config|tok/s mean (min-max)|tokens/pass|accept1|Main ms/pass|Draft ms/pass|answer = expected|same tokens+state as greedy
edit_code|greedy|26.2 (26.2-26.2)|1.00|-|38.15|-|0/5|-
edit_code|bd2:adapt-cost|108.7 (108.7-108.8)|5.51|0.975|43.07|6.65|0/5|5/5
edit_code|hy4+bd2:fixed8|272.6 (272.6-272.6)|12.90|0.806|45.08|1.11|0/5|5/5
edit_code|hw4+bd2:fixed16|356.4 (356.3-356.4)|20.65|0.806|54.20|2.38|0/5|5/5
edit_code|hv4+bd2:fixed16|405.2 (405.2-405.3)|29.07|0.806|66.58|3.52|0/5|5/5
edit_code|hv4+bd2:fixed8|414.0 (413.9-414.0)|28.89|0.806|65.13|3.04|0/5|5/5
edit_jsonl|greedy|26.5 (26.5-26.5)|1.00|-|37.70|-|5/5|-
edit_jsonl|bd2:adapt-cost|289.7 (289.6-289.8)|15.26|1.000|44.06|7.40|5/5|5/5
edit_jsonl|hy4+bd2:fixed8|339.9 (339.8-339.9)|15.60|1.000|44.53|0.15|5/5|5/5
edit_jsonl|hw4+bd2:fixed16|536.6 (536.5-536.7)|31.03|1.000|55.38|0.78|5/5|5/5
edit_jsonl|hv4+bd2:fixed16|743.2 (743.1-743.4)|59.48|1.000|75.65|1.86|5/5|5/5
edit_jsonl|hv4+bd2:fixed8|715.8 (715.6-716.0)|57.10|1.000|75.58|1.74|5/5|5/5
edit_jsonl_long|greedy|25.9 (25.9-25.9)|1.00|-|38.62|-|5/5|-
edit_jsonl_long|bd2:adapt-cost|273.5 (273.4-273.6)|15.10|1.000|46.61|7.38|5/5|5/5
edit_jsonl_long|hy4+bd2:fixed8|324.6 (324.6-324.6)|15.72|1.000|47.09|0.11|5/5|5/5
edit_jsonl_long|hw4+bd2:fixed16|495.1 (495.0-495.1)|30.78|1.000|59.81|0.68|5/5|5/5
edit_jsonl_long|hv4+bd2:fixed16|673.8 (673.7-674.0)|59.58|1.000|84.18|1.68|5/5|5/5
edit_jsonl_long|hv4+bd2:fixed8|668.9 (668.8-669.0)|59.04|1.000|84.07|1.65|5/5|5/5

| task (64-row hybrid, fixed16 / code: fixed8) | Part AD | Part AE | change |
|---|---|---|---|
| JSONL edit | 671.8 | **743.2** | +10.6% |
| long JSONL edit | 613.8 | **673.8** | +9.8% |
| code edit | 383.3 | **414.0** | +8.0% |
| JSONL edit, 32 rows | 502.2 | 536.6 | +6.9% |
| JSONL edit, 16 rows | 323.3 | 339.9 | +5.1% |
Spread over 5 processes <= 0.3 tok/s. Exactness: one pass of n rows against passes of <= 16 rows, 23 cases (17..64 rows, xmx / fp32 / fp16 / bf16 KV, JSONL / code / 8K prompts), 0 differences in tokens + logit bits, GDN state (48 layers), KV cache (16 layers), whole state (`m43/wide/`; the two 8K cases first reported rc=1 only because the new commit timing loop ran past the context, fixed and re-run). Unit GEMM sums unchanged: 34.9 / 41.9 / 50.4 ms (16 / 32 / 64 rows).

### AE5. What is left at 64 rows (stage-synchronised per-kernel table, `m43/detail_3k.log`)
kernel (64 rows, position ~3K)|calls/pass|net us/call|ms/pass|share
gemm 34816x5120|64|331.7|21.25|27%
gemm  5120x17408|64|194.7|12.48|16%
gemm 16384x5120|48|188.9|9.08|11%
gdn:core|48|138.5|6.66|8%
gemm  5120x6144|64|95.2|6.11|8%
attn:xmx-main|16|272.1|4.36|5%
mlp-act+quant|64|50.5|3.25|4%
addnorm+quant|128|24.6|3.19|4%
gdn:gemv-ab|48|62.8|3.03|4%
gemm 14336x5120|16|151.6|2.43|3%
gemm 248320x5120  (head)|1|2373.5|2.37|3%
gdn:conv|48|23.6|1.15|1%
gdn:post+quant|48|20.6|1.00|1%
attn:combine|16|56.9|0.92|1%
sum (stage-synchronised) ms: 80.1

800 tok/s needs the cycle at 74.4 ms: 5.6 ms more than today (80.0 = Main 74.06 incl. commit overlap + draft 1.9 + commit ~3 not overlapped). Candidates with their measured size: GEMM 53.7 ms at 65% of the XMX peak (every point of XMX utilisation is ~0.8 ms);
GDN core 6.7 ms (chain-bound), attention 6.5 ms, MLP activation + quantisation 3.2 (50 us per layer for 64 tokens), addnorm + quant 3.2 (128 launches at 24.6 us, launch / latency bound), gemv-ab 3.0, conv 1.2. Fusing conv / qk-norm / gate (~0.9 ms) and speeding up addnorm + quant (~1 ms) would not close the gap alone; 800 needs the GEMM too.

### AE6. The most promising way to 1000 tok/s (from the data above)
1. The GEMM is the lever (65% of the cycle). The best kernel reaches 71% XMX with Send stall 20% and SBID 31%; the SLM experiment proved the L1 operand supply can be taken off the critical path (Send 5.9%) but a plain barrier per stage cost more than it saved (XMX 52%).
   The step that keeps the SLM benefit without the barrier stall is a **producer / consumer split with named (split) barriers**: one thread per work-group streams the next activation stage into SLM with big loads and signals, the 7 compute threads only wait on that signal for the stage they need (the previous stage is read while the next one is produced), and no thread waits at a full barrier. Expected: XMX 75-80% on every shape, i.e. GEMM 50 -> ~42 ms (-8 ms), cycle ~72 ms = 825 tok/s. Not implemented here (new kernel structure with `named_barrier`; the SLM data path and the exactness of the integer arithmetic are already validated by `submit_slm`).
2. A 16-bit-activation GEMM with fewer DPAS per weight tile does not exist without changing the result (8-bit planes would be 36 ms but change the output).
3. 1000 tok/s (59.5 ms) additionally needs ~15 ms out of the non-GEMM 27 ms (GDN chain, attention, ~900 small launches): a persistent / fused GDN layer kernel (conv + qk-norm + gate + core + post in one launch per layer, state kept in SLM / registers across tokens) is the only structural option there that keeps the floating-point order; it is a large rewrite with a ceiling of about -6 ms.
