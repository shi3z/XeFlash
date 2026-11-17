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

## 5. Status
Step 1 (analysis) done as far as possible without hardware counters. Step 2 (SLM kernel), step 3 (tile 32/64/128 comparison, 8K/30K/48K) not started.
