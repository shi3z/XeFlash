# Quantisation

Status: data-free scalar quantisation is implemented and measured in weight
space. Nothing here has been evaluated on generated text yet; that needs the
full model to run (Milestone 3).

## The format is dictated by the hardware

DPAS on Xe2 consumes 8-, 4- and 2-bit integer operands directly (see
ARCHITECTURE.md). XeFlash therefore uses uniform scalar codes and puts every
other degree of freedom where the kernel gets it for free:

```
W[i][j] ~= r[i] * (q[i][j] + 0.5) * c[j]
```

| term | where it is applied at run time | cost |
|---|---|---|
| `q` | DPAS weight operand, straight from memory | the weight stream itself |
| `r[i]` per output row | int32 accumulator -> float conversion | one multiply per output |
| `c[j]` per input column | multiplied into the activation before it is quantised | none per weight |
| `+0.5` (symmetric level grid) | `0.5 * sum_j c[j] x[j]`, one scalar per token | none per weight |

The same per-token scalar absorbs the offset of unsigned codes, which is how
the 3-bit format avoids sign extension (`u = q + 4`, DPAS `u4` operand).

A scale per (row, column block) was considered and not implemented: it would
force an int-to-float conversion and a multiply inside the column loop. The
measurements below show the weights do not need it.

## Fitting (`xeflash-quant::quantize`)

1. Column scales start at the column RMS (geometric mean normalised to 1).
2. Per row: try 14 step sizes around the Gaussian-optimal step, quantise, fit
   the row scale by weighted least squares, keep the best.
3. Refit column scales by least squares for the current codes; repeat 3 rounds.

It minimises `|W - W^|` only. It is not activation-aware.

## Measured: weight-space error on the real checkpoint

SQNR in dB, `Qwen/Qwen3.8-27B` revision `1d4bf0f2`, layers 0, 3, 31, 32
(`benchmarks/results/quant_sqnr_v1.json`; in that first table the rows labelled
`L0.self_attn.*` are the `mtp.layers.0.self_attn.*` tensors, a name-matching
bug that has since been fixed).

| format | range over 30 matrices | Gaussian theory |
|---|---|---|
| s8, row scale | 31.6 .. 40.8 | - |
| s4, row scale | 16.6 .. 19.3 | 19.4 |
| s4, row + column scale | 18.4 .. 19.3 | 19.4 |
| s3, row + column scale | 13.5 .. 14.2 | 14.3 |
| s2, row scale | 7.9 .. 9.2 | 9.3 |
| s2, row + column scale | 8.6 .. 9.2 | 9.3 |

Observations:

* Rows of this model are close to Gaussian: plain uniform quantisation lands
  within 0.2 to 0.5 dB of the theoretical optimum for most matrices.
* Column scales matter for a few matrices only (`o_proj`, `k_proj`: up to
  +1.8 dB at 4 bits, +1.0 dB at 2 bits) and are free, so they are always on.

## Measured: against YASAKANI on the same matrices

Relative Frobenius error against the original weights, layer 3. YASAKANI
numbers come from its own `tools/yskn_decode.py compare --engine-table`
(read-only use of the released tool).

| matrix | YASAKANI Speed, trellis 3 bpw | XeFlash s4 | XeFlash s3 (scalar) |
|---|---|---|---|
| self_attn.q_proj | 0.1756 | 0.1102 | ~0.197 |
| self_attn.k_proj | 0.1768 | 0.1144 | ~0.199 |
| self_attn.v_proj | 0.1751 | 0.1142 | ~0.200 |
| self_attn.o_proj | 0.1802 | 0.1173 | ~0.203 |
| mlp.gate_proj | 0.1833 | 0.1085 | ~0.195 |
| mlp.up_proj | 0.1830 | 0.1083 | ~0.195 |
| mlp.down_proj | 0.1914 | 0.1097 | ~0.196 |

(The s3 column is derived from the SQNR table; the s4 column is the error
measured on the GPU output, see below.)

The YASAKANI Quality file stores `mlp.down_proj` of this layer at 4 bpw with a
relative error of 0.1002.

Reading:

* XeFlash s4 has about 60 % of the weight error of YASAKANI Speed
  (roughly 4 dB better), at 4 instead of 3 bits per weight.
* At equal 3 bits, trellis coding is better than scalar by 0.2 to 1.1 dB.
* At equal 4 bits, trellis coding is better than scalar by about 0.8 dB (one matrix).

**Caveat.** Weight-space error is a proxy. YASAKANI's reported quality
(Speed: 93.0 % same top-1 token, KL 0.030; Quality: 95.2 %, KL 0.012 against
the original) is measured on text. XeFlash has no such number yet, and an
activation-aware encoder can beat a data-free one at equal weight error. The
table says s4 is very likely at least as good as Speed; it does not prove it.

## Measured: what the arithmetic costs

`xf-validate gemm` runs converted layer-3 matrices on the B60 with Gaussian
test vectors (`benchmarks/results/validate_l3_s4.txt`):

| comparison | relative error |
|---|---|
| GPU, 16-bit activations vs the quantised model in f64 | 3.2e-5 .. 3.9e-5 |
| GPU, 8-bit activations vs the quantised model in f64 | 8.2e-3 .. 9.9e-3 |
| quantised model vs original weights | 0.108 .. 0.117 |

With 16-bit activations (two DPAS on the same weight registers, under 1 % of
decode time) the arithmetic contributes nothing measurable: the difference
from the original model is the weight format alone. This is the separation
between "quantisation method" and "floating-point method" that the evaluation
plan asks for, and it also makes results independent of token batch size
(integer accumulation is exact), which speculative decoding relies on.

## Capacity

| format | body (25.6 G weights) | + lm_head (1.27 G) | embedding (bf16) |
|---|---|---|---|
| s4 | 12.8 GB | 0.64 GB | 2.54 GB |
| s3 | 9.6 GB | 0.48 GB | 2.54 GB |
| s2 | 6.4 GB | 0.32 GB | 2.54 GB |

Scales add `(rows + cols) * 4` bytes per matrix (about 13 MB in total). All
variants fit the 22.3 GiB usable on the card with the model fully resident.

## Open questions, in the order they will be answered

1. Text-level quality of s4 (KL, top-1 agreement, task suites) against the
   BF16 model and both YASAKANI files. Blocked on Milestone 3.
2. Activation-aware rounding (GPTQ-style) on the same grid. Needs calibration
   activations; the format and kernels do not change.
3. Mixed precision. A data-free mix is unattractive: matching Speed's error
   with s4 + s2 needs about 82 % s4, i.e. 3.6 bits per weight. s3 everywhere
   is 3.0 bits at Speed-like error. Mixed precision becomes interesting only
   with sensitivity measured on text.
4. Whether s2 is usable at all for this model depends on distillation /
   quantisation-aware training; at 9 dB it is not usable data-free.
