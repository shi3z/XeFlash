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

A launch costs about 3 us queued. The engine will submit a whole pass and
wait once; a per-pass plan (a fixed list of kernel descriptors built at load
time) is the next step, with a recorded Level Zero command list as an
optimisation to evaluate after the full model runs.

## 6. Status

Implemented: runtime, tile packing, quantiser, GEMM kernels (bf16, s8, s4,
s4 expanded to s8, s2; 8/16-bit activations), benchmark, checkpoint reader.

Not yet implemented: the model itself (Gated DeltaNet state update, attention,
norms, sampling), the XeFlash model container, speculative decoding, the API.
See EXPERIMENTS.md for what has been measured and PERFORMANCE.md for numbers.
