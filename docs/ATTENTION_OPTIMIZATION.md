# Attention: analysis of the current shared-K/V kernel (Phase A, step 1)

Kernel: `k_attn_part3<HG,TG,KV>` + `k_attn_comb` (model.cpp). No profiler or hardware counters are installed on this machine
(no unitrace / VTune / intel_gpu_top), so DRAM traffic could not be measured; everything below is either read from the source,
read from the compiled binary, or derived from measured kernel times. Logical traffic (bytes the kernel asks for) and DRAM
traffic (bytes the memory controller moves) are kept apart; only the former is known.

## 1. How often is a K/V tile loaded?
One thread = (kv head, group of HG query heads, 64-key block, group of TG tokens). It reads that block's K^T tile (256 dims x 64 keys,
64 KiB FP32) once for the scores and V tile (64 KiB) once for the weighted sum. Threads that share (kv head, block) but differ in
head group or token group read the same tiles again:

reads per tile = (6 / HG) x ceil(m / TG)   (6 query heads per KV head)

| rows m | HG:TG | reads of each K/V tile |
|---:|---|---:|
| 1 | 3:2 (<=200 blocks: 3; else 6:2) | 2 (6:2 -> 1) |
| 8 | 3:4 | 4 |
| 16 | 3:4 | 8 |
The minimum is 1 (one read shared by 6 heads x m tokens). TG=4 shares K/V only across 4 tokens and HG=3 across 3 of the 6 GQA heads;
there is no sharing between thread groups except what the L2 cache provides.

## 2. State, registers, barriers
- Softmax state: none across tiles. Each thread handles exactly one 64-key block, produces (max, sum, 256-dim weighted V) per (token, head)
  and stores it to global memory (pm/pd/pv); `k_attn_comb` merges the blocks. Query values are re-read from global per 16-dim chunk.
- SLM: 0 bytes, barriers: 0 (no work-group cooperation; each ESIMD thread is independent). SIMD lanes = 64 keys.
- GRF (from `ocloc compile` of the dumped SPIR-V for BMG, ze_info): 128 registers in every variant, SIMD "1" (ESIMD).
  Scratch/spill present only in **3:8** and **6:4** (binary 65.7 / 63.2 KB, scratch records), absent in 1:2, 1:8, 3:1, 3:2, 3:4, 6:2.
  That matches the timings: 3:8 and 6:4 are slow; the best configurations (3:4, 6:2) do not spill. Large-GRF mode (256) was not tried.
  Flag/predicate spills cannot be read from the binary without the finalizer dump; the dumped data is in work/igc (not kept).
- Kernel launches per full-attention layer: kv-store, q-prep, part3, comb = 4 (plus the GEMMs); 16 layers -> 64 attention-related
  launches per pass, all in one in-order queue without host sync. Per-launch overhead was not separately measured.

## 3. Logical KV traffic and effective bandwidth (FP32 KV, 16 layers)
Minimum KV bytes per pass = ctx x 8 KiB x 16. Times are the synced `attn` stage of the 8-row/16-row/1-row profile at that position
(sweep with fixed 3:4, `benchmarks/results/m6/attn_sweep.txt`, `l30k_prof.log`, `l48k_prof.log`).

| ctx | min KV | rows | reads/tile | logical GB | attn ms | logical GB/s | min-traffic GB/s |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 8,104 | 1.06 GB | 1 | 2 | 2.1 | 4.74 | 448 | 224 |
| | | 8 | 4 | 4.3 | 9.05 | 469 | 117 |
| | | 16 | 8 | 8.5 | 17.53 | 485 | 61 |
| 30,104 | 3.95 | 1 | 2 | 7.9 | 18.44 | 428 | 214 |
| | | 8 | 4 | 15.8 | 44.24 | 357 | 89 |
| | | 16 | 8 | 31.6 | 90.31 | 350 | 44 |
| 48,580 | 6.37 | 1 | 2 | 12.7 | 36.88 | 345 | 173 |
| | | 8 | 4 | 25.5 | 86.64 | 294 | 73 |
| | | 16 | 8 | 50.9 | 176.48 | 289 | 36 |

The B60's peak is 456 GB/s (192-bit GDDR6). At 8K the logical rate (450-485 GB/s) is at or above peak, so L2 is absorbing part of the repeated reads
(8K per-layer K+V is 128 MB for 16 layers... 66 MB per layer, far above L2, so the reuse is between threads running at the same time on the same tile).
At 30K and 48K the logical rate drops to 290-360 GB/s: the repeats no longer hit L2 as well, and the kernel is memory-bound at ~65-80% of peak
on 4-8x the minimum bytes. The floor for 8 rows at 456 GB/s with a single read per tile would be 2.3 ms (8K), 8.7 ms (30K), 14 ms (48K),
against 9.1, 44 and 87 ms measured. So the ceiling for an ideal tile-sharing kernel is a 4-6x faster attention at long contexts if
the DRAM traffic really is near the logical traffic; this cannot be confirmed without counters, and some of the gap may be L2 behaviour,
not DRAM.

## 4. Consequence for the design (not yet implemented)
- What must change: reads per tile 4/8 -> 1. That needs the six query heads and all m (8/16) tokens of one KV head to consume a tile while it is resident:
  - one work-group per (kv head, key range); the K^T tile (64 keys x 256 dims FP32 = 64 KiB; 128 keys = 128 KiB) staged in SLM in 256-dim chunks
    (e.g. 32-dim x 64-key = 8 KiB per chunk, double buffered), and the six heads x 16 tokens = 96 query rows spread over the work-group's threads;
  - Score and V passes stay two separate kernels/phases (no fused giant kernel, per the fa48 lesson); scores for the 96 rows x 64 keys (24 KiB FP32)
    fit SLM.
- Open risks to check on hardware: SLM capacity per work-group on BMG (128 KiB per Xe core), SLM bank conflicts on the K^T read pattern (lane = key, stride 64 floats),
  barrier cost, GRF pressure of 96 rows per thread group, and whether ESIMD slm_block_load matches the 64-lane layout.
- 16-bit KV halves the tile traffic and SLM footprint; combined effect to be measured separately.

## 5. SLM work-group kernel `k_attn_slm<HPT,KV,NCK>` (implemented, default for m >= 2)
Design: one work-group per (kv head, 64-key block); thread = (token, 6/HPT-th of the 6 GQA heads); the group has m * 6/HPT threads (HPT=3: 2m threads,
limit 64 work-items per group, so HPT=1 fails at 16 rows). The K^T tile is staged in SLM in NCK chunks (all threads copy, barrier, compute scores,
barrier), the V tile in 4 chunks of 64 dims (16 KiB); scores/softmax stay in registers (same pm/pd/pv partials as before, `k_attn_comb` unchanged);
scores and V sums are separate phases, not fused across blocks. SLM = max(64 KiB / NCK, 16 KiB); every K/V byte is read from global memory once per pass.
Selected automatically: m >= 2 -> HPT=3, NCK=4, except m <= 8 with 48 <= blocks < 112 (3K-7K tokens) where `part3` is slightly faster.
`XF_ATTN_SLM=0` = old kernel, `=2|3|6` force HPT, `XF_ATTN_SLMC=1|2|4` chunking. 16-bit KV uses HPT=3, NCK=4.

Attention stage, ms for 16 layers (synced profile, `benchmarks/results/m7/slm*_sweep_*.log`):
| ctx | rows | part3 3:4 | SLM HPT=3 NCK=4 | other SLM variants |
|---:|---:|---:|---:|---|
| 1.1K | 8 / 16 | 3.82 / 3.81 | 1.64 / 2.58 | |
| 2.1K | 8 / 16 | 3.84 / 4.33 | 2.82 / 4.78 | |
| 4.2K | 8 / 16 | 4.41 / 8.56 | 4.92 / 8.63 | |
| 8.1K | 8 / 16 | 9.04 / 17.54 | 8.71 / 15.89 | HPT=2 (NCK 1): 10.96 / 18.91; HPT=3 NCK1: 12.03 / 15.71 |
| 30.1K | 8 / 16 | 44.2 / 90.4 | 29.2 / 54.8 | HPT=3 NCK2: 29.6 / 54.4; HPT=2: 36.8 / 65.4; HPT=1: 50.1 / n.a. (64-thread limit) |
| 48.6K | 8 / 16 | 86.6 / 176.3 | 46.3 / 87.2 | HPT=2 NCK2: 58.6 / 104.4 |
1-row passes are unchanged (the old kernel stays). HPT=6 (NCK 1) was worse than HPT=3 at 8K-48K (e.g. 48K: 80.8 / 93.8 for 8 / 16 rows).

Correctness: logits over 3,200 teacher-forced tokens, chunks of 8 and 16, are **bit-identical** to the previous kernel (max |dlogit| = 0, 0 greedy flips)
because every output element is accumulated in the same order; the earlier 1,600-token check was identical for HPT = 2, 3, 6.
Registers/spill of the new kernels were not inspected; no spill reports were checked beyond the part3 variants in section 2.

End to end (bdraft2, same prompts and settings, `benchmarks/results/m7/f1_*`, `f2_*`):
| case | before | SLM (auto) |
|---|---:|---:|
| 8K, adaptive-cost / fixed 8 / fixed 16 | 53.07 / 53.05 / 43.24 | 53.39 / 53.34 / 44.06 |
| 30K adaptive-cost | 31.5 (m6) | 38.47 (fixed 16: 29.0) |
| 5 short prompts, mean | 69.94 | 72.01 |
| 60K, BF16 KV, 64 tokens, fixed 8 | 34.4 | 40.4 (main pass 124.7 -> 105.1 ms) |
The 30K "before" is the m6 measurement (not re-run with the old kernel in this session), the others were measured back to back.

## 6. What limits it now
At 30K, 8 rows, 29 ms for 94 GFLOP (16 layers x 24 heads x 8 tokens x 30K keys x 2 x 256 x 2 FLOP) is ~3.3 TFLOP/s, against ~9 ms for memory at 456 GB/s with one read per tile.
Both the 8- and 16-row runs land at the same ~3.3 TFLOP/s, i.e. the kernel is now bounded by vector FMA / SLM-load issue, not by DRAM traffic.
(Inference from FLOP counts; no hardware counters were available.) Reaching the memory floor would need XMX (DPAS) for QK and PV, which needs 16-bit Q/K/V
operands: that is the BF16/XMX attention step, not done here.
