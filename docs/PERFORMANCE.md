# Performance

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
