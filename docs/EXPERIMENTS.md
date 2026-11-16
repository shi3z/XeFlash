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

## Things that did not work or were wrong

* First guess of the low-precision DPAS layout (16-bit channels): wrong, see E1.
* Summing per-segment partials in float: not bit-exact against the unsplit
  kernel (1e-6 to 2e-4 relative). Replaced by integer partials (E3).
* `quant_sqnr_v1`: tensor lookup by suffix matched `mtp.layers.0.self_attn.*`
  for "layer 0 self_attn" (layer 0 is a DeltaNet layer). Fixed; the affected
  rows are labelled in QUANTIZATION.md.
* Benchmarks taken while a 12-thread conversion was running on the host are
  not reliable: the submitting thread gets descheduled (launch-with-wait
  rises from 8 us to over 100 us). Final numbers are taken on an idle host.
