# KV and VRAM budget on the Arc Pro B60 (24 GB)

Driver-visible free VRAM at start: **22.484 GiB** (xe driver; xf_alloc refuses to overcommit).
Measured allocation tables are the `device allocations` blocks in `benchmarks/results/m6/l30k_auto.log` (ctx 30,720, bdraft2)
and `l48k_prof.log` (ctx 49,152). Sizes below are GiB.

## 1. Inventory (measured, ctx 30,720, MTP present)

| item | GiB | scales with ctx? |
|---|---:|---|
| body INT4 matrices (256) | 11.343 | no |
| embedding (bf16) | 2.368 | no |
| lm_head | 0.592 | no |
| MTP head (5 allocations) | 0.369 | no |
| head sketch | 0.129 | no |
| small tensors + matrix scales/metadata | 0.137 | no |
| DeltaNet state (48 layers, S + conv) | 0.217 | no |
| RoPE table | 0.007 (0.012 at 49K) | yes |
| **KV cache, 16 layers, FP32** | **3.750** (= 128 KiB/token) | yes |
| MTP KV cache | 0.234 | yes |
| workspace (pass buffers, attention partials) | 0.208 (0.315 at 49K) | yes |
| **requested total** | **19.355** | |
| bdraft2 backend (weights + its own KV ring, driver delta) | +2.808 | small |

Non-context part: 15.16 GiB. Context part: 128 KiB/token KV + 8 KiB/token MTP KV + ~7 KiB/token workspace.
bdraft2's own state is inside its 2.808 GiB (driver-measured); its KV ring is a fixed window and does not grow with ctx.
The driver difference matches the sum of requests within 0.04 GiB (19.391 vs 19.355), so allocator overhead and fragmentation are small
(each allocation is a single contiguous buffer; the largest, the 3.75 GiB KV per layer set, is 0.23 GiB per layer).

## 2. Required vs available (model; checked against two measured points)

| ctx | KV FP32 | total, no bdraft2 | + bdraft2 | free 22.484 | result |
|---:|---:|---:|---:|---|---|
| 8,448 | 1.03 | 16.47 | 19.27 | | fits (measured 16.37 + 2.81) |
| 30,720 | 3.75 | 19.35 | 22.16 | 0.32 spare | fits (measured 22.20) |
| 49,152 | 6.00 | 21.85 | 24.66 | | no bdraft2 only (measured 21.73) |
| 61,440 | 7.50 | 23.52 | 26.32 | | **does not fit**, xf_alloc OutOfMemory (measured) |

Missing for 60K with bdraft2: 26.32 - 22.48 = **3.84 GiB** (1.04 GiB even without bdraft2).

## 3. 16-bit KV (this round)

KV halves: 61,440 tokens = 3.75 GiB.

| ctx | KV 16-bit | total, + bdraft2 | with MTP head/KV dropped (-0.37 -0.13 -0.47 GiB) |
|---:|---:|---:|---:|
| 30,720 | 1.88 | 20.29 | 19.8 |
| 49,152 | 3.00 | 21.66 | 21.1 |
| 61,440 | 3.75 | **22.57** | **21.6** |

BF16 alone at 61,440 + bdraft2 is 0.09 GiB over the limit; it fits only if the unused MTP head/sketch and MTP KV are not loaded
when bdraft2 is the drafter (they are not used then). Margin ~0.9 GiB.
INT8 KV would give 20.7 GiB (1.8 GiB margin) but needs scales and a dequantise step; only if 16-bit is too slow or too lossy.

## 4. Measured: 16-bit KV (`XF_KV=bf16|fp16`, experimental, FP32 stays the default)

Same model, prompts and conditions; raw data in `benchmarks/results/m7/`.

| ctx | KV | allocation | bdraft2 fixed-8 tok/s | note |
|---|---|---|---:|---|
| 8,448 | FP32 | 1.03 GiB | 53.0 | m6 |
| 8,448 | BF16 | 0.52 GiB | 53.7 (adaptive 53.8) | same tokens/state as plain decode in the same KV mode |
| 8,448 | FP16 | 0.52 GiB | 53.6 | |
| 61,440 | BF16 | 3.75 GiB | **34.4** (4.57 tok/pass; plain K=0 15.4) | 64 generated tokens only; total 19.57 + 2.82 (bdraft2) = 22.40 of 22.48 GiB |

60K fits with the MTP head still loaded (total requested 19.54 GiB), but the margin is only 0.08 GiB. Dropping the unused MTP head/KV would give ~0.9 GiB.
The 60K run is short (64 tokens); it shows feasibility and exactness (same tokens, same committed state as plain decode), not a stable tok/s figure.

Quality versus FP32 KV, teacher-forced 3,200 tokens (`kv_quality_3200.txt`):

| KV | KL mean | KL max | greedy flips | flips with fp32 margin < 0.02 |
|---|---:|---:|---:|---:|
| BF16 | 4.0e-5 | 1.2e-2 | 10/3200 | 9 (the other: margin 0.073) |
| FP16 | 3.1e-5 | 4.8e-2 | 8/3200 | 7 (margins 0.073, 0.015 ...) |

Both are of the same size as the old-vs-new attention difference (KL 5.2e-5, 9/3200 flips). Neither is lossless; FP16 is a little closer and as fast.
Not yet measured: retrieval / multi-needle, Japanese/code/math tasks, prefix reuse, EOS at 60K, 60K quality, 30K timing with 16-bit KV.
