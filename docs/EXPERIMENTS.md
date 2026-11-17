# Experiment log

One entry per experiment: what was done, what was expected, what was measured,
and why it worked or did not. Raw outputs are under `benchmarks/results/`.
All GPU runs: Arc Pro B60, driver 1.18.40196+15 (compute runtime 26.40.40196),
oneAPI DPC++ 2026.2, one job at a time under `/tmp/b60.lock`.

## E0. Environment

* `Intel Arc Pro B60` on Level Zero, 23.91 GiB, 22.48 GiB free when idle.
  160 EU x 8 threads = 1280 hardware threads, 128 GRF mode, SLM 128 KiB.
* An RTX 5060 Ti is also in the machine. XeFlash never uses it: the runtime
  only accepts vendor 0x8086 on the Level Zero backend.
* Rust 1.100 (toolchain under `/data/B60special/toolchain`, the root disk has
  7 GB free), `icpx` 2026.2.
* A distillation job of another session uses the B60 in 300 s slices under the
  same lock, so every XeFlash run waits its turn.
* Empty kernel launch: 2.3 to 3.7 us queued, 7.7 to 9.3 us with a wait.

## E1. Which operand precisions does DPAS accept on Xe2?

*Question.* The plan assumed 4-bit weights must be expanded to 8 bits before
DPAS. Is that true?

*Method.* `kernels/probe/dpas_probe.cpp`: one `dpas` per precision pair with
random operands against a CPU model. `kernels/probe/dpas_map.cpp`: one-hot
operands to find the real layout where the first guess was wrong.

*Result.* All of s8, s4, s2 (and u8, u4) run on the hardware in any
combination. Low-precision operands are packed with no gaps: the weight
operand of a 16 x 32 tile is 256 bytes at 4 bits and 128 bytes at 2 bits.
The ESIMD header's size check describes this correctly; my first layout guess
(16-bit channels) was wrong and the one-hot map corrected it.

*Consequence.* The expansion step is unnecessary. Packed 4-bit weights in
tile order are a DPAS operand as loaded. This is the basis of the design.

## E2. GEMM kernels, first measurement

*Method.* `xf-bench`, real matrix shapes, uniformly random codes (the card
reads compressible data several times faster, so entropy matters), every case
checked against a CPU reference on sampled rows before timing. Time is the
steady-state cost of one GEMM with launches queued back to back.

*Expectation.* Decode is bandwidth bound: time ~ bytes / 435 GB/s.

*Result* (`gemm_v1.txt`, 1 token):

| format | 17408x5120 | Gw/s | GB/s |
|---|---|---|---|
| bf16 | 0.4218 ms | 211 | 423 |
| s8 | 0.2170 ms | 411 | 411 |
| s4 expanded to s8 in registers | 0.1260 ms | 708 | 354 |
| s4 native | 0.1130 ms | 789 | 394 |
| s2 native | 0.0455 ms | 1960 | 490 |

* Integer formats are bit-exact against the CPU for every token count and
  kernel variant. bf16 agrees to 1e-7 relative.
* The explicit s4 -> s8 expansion costs 11 %: it works, but native s4 is
  strictly better.
* 16-bit activations (second DPAS on loaded weights): +0.8 % at 1 token.
* 8 tokens: +4.6 %; 16 tokens: +10 % (s4, 17408x5120).
* Prefill-style batches reach 47 to 77 TOPS at s4 and up to 102 TOPS at s2,
  against a 196 TOPS peak. The prefill kernel has not been tuned yet.

*Why.* At 1 to 16 tokens the kernel is a memory stream with one DPAS per
256 bytes; XMX is nearly idle (1.6 TOPS of 196), so everything that does not
add bytes is free.

## E3. Few row blocks need column workers

*Observation.* `down_proj` (5120 x 17408) has 320 row blocks, hence 320 threads
when one thread owns a row block. With 16-bit activations and 8 tokens it took
0.211 ms against 0.118 ms for the same number of weights in `gate_proj`.

*Fix.* Split the columns into 4 segments (1280 threads); threads write exact
int32 partial sums and a combiner kernel adds them and applies the scales.

*Result.* 0.211 -> 0.140 ms (s4+a16, 8 tokens); 0.213 -> 0.130 ms (s4, 16
tokens). At 1 token the split is neutral to slightly negative (0.116 ->
0.120 ms) because the single-token thread already has little work per tile.
Results stay bit-exact because the partials are integers.

## E4. Generated ISA

`IGC_ShaderDumpEnable=1` dumps, summarised by `tools/validation/isa_report.py`
(`isa_s4_v1.md`). For the s4 decode kernel:

* `dpas.8x1 (16|M0) r76:d r76:d r6:s4 r17.0:b` - the weight register is
  consumed at 4-bit precision, as intended.
* Per loop trip (4 tiles): 4 loads of 256 B (`load.ugm.d32x64t`), 4 loads of
  32 B, 4 `dpas.8x1`. No gather, no SLM, no barrier, no spill, 128-GRF mode.
* About 70 scalar instructions per trip are 64-bit address arithmetic
  (emulated 64-bit multiplies). They do not limit a bandwidth-bound kernel but
  are an obvious clean-up (32-bit offsets, strength reduction).
* The two "gather" entries the report shows for single-token kernels are
  one-element loads of the token scale and offset, not weight gathers.

## E5. Conversion of the real checkpoint

*Method.* `xf-convert convert`: every 2-D weight of at least 2^20 elements
except the embedding table becomes an s4 matrix (codes in tile order, f32 row
and column scales); everything else is copied verbatim. `xf-convert verify`
re-reads the container, unpacks the tiles, and recomputes the error against
the checkpoint.

*Result.* Full model: 14.56 GiB, 409 matrices (26.02 G weights), mean
18.92 dB, 457 tensors copied verbatim, 29 minutes on 12 CPU threads shared
with another job. `verify` over all 866 tensors: 0 mismatches.

One matrix is not quantisable this way: `mtp.fc` (5120 x 10240) reconstructs
at 5.4 dB at 4 bits and 6.5 dB at 8 bits, so it is far from the Gaussian rows
of every other matrix (the next worst is 17.8 dB). The converter now copies
any matrix below 16 dB verbatim, to be run by the bf16 kernel. The container
on disk was written before that rule and still holds `mtp.fc` at s4; nothing
uses the MTP block yet, and it must be reconverted before speculative
decoding work starts.

## E6. Converted weights on the GPU against the original model

`xf-validate gemm`, layer 3, 8 Gaussian test vectors
(`validate_l3_s4.txt`). GPU output with 16-bit activations differs from the
f64 evaluation of the quantised weights by 3e-5; with 8-bit activations by
9e-3; the quantised weights differ from the original by 0.108 to 0.117.
Conclusion: use 16-bit activations; the arithmetic is then not a source of
error and the kernel's scaling is verified end to end on real weights.

## E7. Same-metric comparison with YASAKANI's weight files

YASAKANI's decoder tool, run read-only on its Speed and Quality files against
the same checkpoint: Speed (trellis, 3 bpw) reconstructs layer 3 with relative
error 0.175 to 0.191; XeFlash s4 with 0.108 to 0.117. Details and caveats in
QUANTIZATION.md.

## E8. A 3-bit format

*Why.* DPAS has no 3-bit precision, but 3 bits per weight is where YASAKANI
Speed sits, and bytes are what a bandwidth-bound decode pays for.

*Design.* 192-byte tiles (per lane a 96-bit stream of 32 unsigned codes),
spread to u4 in registers with three shift-and-mask steps on the whole tile,
then `dpas` with a `u4` weight operand. Offset-binary codes remove the sign
extension; the offset joins the per-token scalar.

*Result.* Bit-exact. See PERFORMANCE.md for timings. The first version
expanded the tile once per activation plane, which made 16-bit activations
30 % slower than 8-bit; expanding once per tile fixed the structure.

## E9. VRAM: what "7.9 GiB" was

The earlier report's 7.9 GiB was free VRAM (22.48) minus the container size
(14.56): expected headroom, computed, never a measurement, and at that time
no more than one matrix had ever been on the card. `xf-run mem` now allocates
everything and prints each category and the driver's own figure: 16.17 GiB
requested, 16.20 GiB by the driver, with MTP and an 8192-token KV cache.
All matrices are resident; nothing is served from host memory.

## E10. Full forward pass

*Method.* `xf-run dump` (layer by layer on the GPU) against
`ref_forward.py --xfm` (official transformers layer classes on the CPU with
the same quantised weights).

*Result.* First run: relative error 2.7e-4 after layer 0, 4.9e-3 after layer
63, logits KL 9e-5, top-1 30/30, greedy tokens identical. No layer stands
out. Passes of 1, 8 and 16 tokens are bit-identical to each other.

## E11. Data-free weights fail on the model

Against the original weights the same run gave KL 1.18 on the prompt
positions and a hidden-state cosine of 0.76 at the last layer; positions with
very large hidden states (chat markers) were predicted wrongly. On a held-out
chat: KL 0.28, top-1 agreement 83.7 %. The 11 % weight error of E5/E7 said
nothing about this.

## E12. Calibration: three wrong turns and one fix

4-layer loop on a held-out chat (`quick_eval.sh`), details in QUANTIZATION.md.

* Weighting the error by E[x^2] per input channel made layer 0 worse by a
  factor of 4.4 (0.068 -> 0.300). Expected an improvement.
* Normalising every token before taking statistics: no change (0.318). The
  hypothesis that a few huge tokens dominated was wrong, or not the main cause.
* Hypothesis that held: the mean of the hidden states dominates E[x^2] and its
  quantisation error is a constant per row. Centred variance as weights plus a
  per-row bias: 0.016 at layer 0, 0.032 at layer 3.
* With energy-weighted statistics `layers.2.mlp.down_proj` had a weighted
  error of 0.41 and was (wrongly, by the fallback rule) left unquantised,
  which made that container unloadable. With centred statistics it is
  ordinary. The fallback now escalates to 8 bits first.

Full model, held-out chat: KL 0.069, top-1 agreement 88.7 %.

## E13. A GEMM variant that never returns

*Symptom.* With the calibrated container, decoding stopped after a few dozen
passes: GPU at full clock, host spinning in a blocking copy, engine reset
logged only when the process was killed. Two earlier runs held the GPU lock
for 83 and 15 minutes because of this before the in-lock timeout was
shortened; that was a mistake in how the runs were launched.

*Search.* Not queue depth (waiting after every layer did not help), not the
bias path, not MTP, not the merged shapes (benchmarked alone: fine). The stage
trace always stopped inside a GEMM.

*Cause.* The calibrated container has one s8 matrix, and s8 weights with
16-bit activations at one token per pass used the 4-tiles-per-trip kernel
(32 weight registers plus two activation planes), a variant the benchmark had
never run. `xf-bench --format s8` with 16-bit activations reproduces the hang
in isolation.

*Fix.* That variant now processes one tile per trip; it is exact and runs at
380 Gw/s. Why the 4-tile version spins is not known (the s4 version with the
same structure is fine); the ISA has not been examined.

*Lesson.* Every kernel variant the engine can select must be in the benchmark.

## E14. Merging matrices that share an input

`--merge` stacks qkv+z, q+k+v and gate+up row-wise: 400 body matrices become
256, with one activation quantisation and one launch per group. Non-speculative
decode went from 49.3 to 44.5 ms per token. Fusing residual add + RMSNorm and
quantisation + offset sum (SLM, one barrier) had given 50.8 -> 49.3 ms before.

## E15. MTP

Graph from vLLM and llama.cpp, confirmed by accuracy on the CPU (64.6 % for
the documented reading, 0 % with the concatenation swapped). Decode sweep in
PERFORMANCE.md A4: best fixed draft length 6, 57.7 tok/s mean over the four
benchmark prompts, identical tokens to plain greedy for every K.

## E16. Where this leaves the targets

* Goal 1 (correct full forward on the B60): met.
* Goal 2 (fair non-speculative benchmark): 22.4 tok/s against YASAKANI's
  reported 18.1 to 18.6 on the same card and prompts. YASAKANI was not re-run.
* Goal 3 (official MTP speculation): met, exact.
* Goal 4 (beat 86 tok/s): **not met, 57.7 tok/s.**
* Final goal (145 tok/s): not met.
* Quality relative to YASAKANI Speed: unknown on equal terms; by published
  figures XeFlash s4 is still behind.

## E17. Draft chain on the device

*Expectation.* Removing one host read-back per draft should save the
synchronisation, perhaps 0.1 to 0.3 ms per draft.

*Result.* 69.6 -> 68.8 ms per cycle at K = 6. The read-backs were cheap; the
gain is real but under 1 ms. Kept, because it is also what lets the whole
cycle be one submission.

## E18. Head sketch

*Expectation.* The exact head is 1.5 ms of a 2.5 ms draft step; the sketch
table is 127 MB instead of 636 MB, so about 1 ms per draft should disappear.

*Result.* 0.85 ms per draft saved (2.52 -> 1.67 ms). First attempt (one
candidate per 512 consecutive ids) was a net loss because acceptance fell by
8 points; candidates per id-mod-64 class recovered it. 2560 candidates is the
best of the settings tried; fewer candidates lose acceptance, the cost of
rescoring more is small. Mean of four prompts 57.7 -> 61.8 tok/s.

Not tried: exact global top-k selection on the device, a 4-bit table, `fc`
through the bf16 DPAS kernel (0.42 ms per draft is embedding + norms + `fc`,
which reads 210 MB of FP32), a confidence-based stop.

## E19. Fine-tuned MTP weights

Both exports convert unchanged and run; on four prompts they are within
+-0.5 % of the official weights. Not adopted.

## E20. State comparison

A hash of the committed DeltaNet states, convolution histories and KV rows is
identical between speculative and plain runs at equal length for every
configuration measured, including 8K context.

## E21. Targets after this round

61.8 tok/s mean on the benchmark prompts; YASAKANI on the B60 is 86.3. With a
free drafter the same acceptance would give 79. The next gains have to come
from the trunk pass (about 10 ms of non-GEMM time, and the cost of extra
rows), from acceptance on prose, and, for long prompts, from attention.

## E22. YASAKANI's bdraft2 on XeFlash's main model

*Question.* The drafter was trained against YASAKANI's 3-bit main model. Does
it still draft well from XeFlash's INT4 hidden states, and is it faster than
the official MTP?

*Method.* Out-of-tree shim over the YASAKANI port's headers (BDRAFT2.md), tap
capture in XeFlash, `xf-run cmp`.

*Result.* Worked on the first run. 8-row block: 4.4 / 6.2 / 2.5 / 6.0 tokens
per pass on explain / code / story / proof against 3.9 / 5.0 / 2.4 / 5.2 for
the official MTP. Taps device-to-device instead of through host: drafter time
9.6 -> 5.8 ms per cycle. Adaptive 8/16 rows: mean 80.0 -> 86.6 tok/s.
Japanese is the exception (worse than MTP). Lookup-only: 1.1 to 1.5 tokens per
pass. All outputs and states identical to plain greedy.

*Expectation that was wrong.* I expected a clear acceptance loss from the
main-model mismatch. There is none visible on English, code and proofs.

## E23. Fine-tuning bdraft2 for XeFlash: closed, negative

Input adapter, `fc`, attention LoRA (r8, r16) and the selector projection do not improve acceptance beyond noise on
held-out text, Japanese included (paired bootstrap, every interval contains zero), while fitting the training data. A
better SHEAD candidate set is worth under 1.5 % in any category. Details and the list of defects in the experiments
(a KL anchor that was silently zero for LoRA, a frozen-block backward error, a reference pass using tuned selector
tables) are in `docs/BDRAFT2.md` section 7 and `/data/B60special/bdraft2-ft/docs/TRAINING_REPORT.md`.

## Things that did not work or were wrong

* First guess of the low-precision DPAS layout (16-bit channels): wrong, see E1.
* Summing per-segment partials in float: not bit-exact against the unsplit
  kernel (1e-6 to 2e-4 relative). Replaced by integer partials (E3).
* `quant_sqnr_v1`: tensor lookup by suffix matched `mtp.layers.0.self_attn.*`
  for "layer 0 self_attn" (layer 0 is a DeltaNet layer). Fixed; the affected
  rows are labelled in QUANTIZATION.md.
* `pkill -f calib_stats.py` inside a shell command whose own text contained
  that string killed the shell before the edits it was about to make.
* Benchmarks taken while a 12-thread conversion was running on the host are
  not reliable: the submitting thread gets descheduled (launch-with-wait
  rises from 8 us to over 100 us). Final numbers are taken on an idle host.
