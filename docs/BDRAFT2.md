# bdraft2 as a drafter for XeFlash (experimental backend)

YASAKANI's drafter, "bdraft2", can be driven from XeFlash's main model without
touching any YASAKANI file. This document records how it is wired, what was
checked, and what it measures. Numbers are in PERFORMANCE.md Part D.

Sources read (read-only): `~/yasakani-src/xe/src/draft.hpp`, `api.cpp`,
`fast.hpp`, `engine.hpp`, `head.hpp`, `spec/D_spec_api.md`, `PORT_NOTES.md`,
the headers of `bdraft2_k8.yskn` and `bdraft2_k8.shead`.

## 1. Tap states

* The drafter reads the main model's residual stream after 0-based layers
  5, 19, 33, 47, 61 (`l % 14 == 5`), taken right after that layer's MLP
  residual add: transformers' `hidden_states[l + 1]`. No normalisation at
  capture, ordinary (unrotated) basis, FP32 storage of bf16-rounded values.
* All rows of every main pass are captured; only committed rows enter the
  drafter's history.
* XeFlash side: flag `XF_FWD_CAPTURE` makes the pass copy `h` (plus the
  pending residual) after those five layers into a `[5][16][5120]` block of
  the workspace, which is exactly the drafter's own `cap` layout
  (`k_capture`, `Engine::set_capture`, `read_taps`, `taps_device_ptr`).
  XeFlash does not round to bf16.

## 2. The drafter

* 5 layers, hidden 5120, FFN 17408, 32 query / 8 KV heads of 128, block 8,
  mask token 248070, history window 2048.
* 46 matrices, all 4 bits per weight in YASAKANI's trellis format (12-bit
  state, 4096-entry table, row scales, Hadamard input rotation):
  `fc` 5120 x 25600 (the five taps concatenated), and per layer `q` 4096x5120,
  `k`, `v` 1024x5120, `o` 5120x4096, `gate`, `up` 17408x5120, `down`
  5120x17408, `akp`, `mkp` 1280x5120. 35 bf16 vectors (norms, gain tables,
  the `sel.*` correction tables).
* Context path, once per committed row: `c = rmsnorm(fc(taps))`, then each of
  the 5 layers stores `k = rope(rmsnorm(K_i c))` and `v = V_i c` in a ring of
  2048 positions (bf16, 2 x 21 MB). Newer rows overwrite older ones.
* Block, once per cycle: row 0 is the frontier token's embedding, rows 1..R-1
  the mask token's. Five layers with attention over the ring plus all block
  rows (bidirectional inside the block), a small 2-tap convolution over rows
  with input-dependent gains, and a SiLU-gated MLP. One shot yields R-1 drafts
  (7 or 15); nothing is autoregressive on the device.
* SHEAD (1.41 GB): `bt` 512x5120 FP32, `a` int8 [V][512] with per-row scale
  (low-rank scores), `w` int8 [V][5120] with per-row scale (its own copy of
  the output matrix for rescoring about 512 candidates chosen with a
  histogram). The top 16 are then re-ranked on the host with a rank-256
  predecessor/successor correction.

## 3. How it is connected

`experimental/bdraft2/xbd.cpp` is compiled in the XeFlash tree against the
YASAKANI port's headers (include path only) with that port's own flags, into
`libxbd.so`. It constructs `yx::Engine(main.yskn, upto = 0, 16)`, which loads
only the embedding of the YASAKANI main file (no layer of the 10 GB model),
and `yx::Draft`. libyskn is not used; it exports no drafter-only entry point.

C ABI: `xbd_open`, `xbd_reset`, `xbd_ctx` (append committed rows to the ring),
`xbd_step` (ring catch-up + one block, taps from host memory),
`xbd_step_dev` (the same with taps read from XeFlash's device buffer). Rust:
`tools/run/src/ext.rs`, behind the cargo feature `bdraft2`.

The two engines have separate SYCL queues. They turn out to share the default
platform context, so the drafter can copy the taps device-to-device once
XeFlash's queue has drained. That replaced a host round trip of 2 x 1.6 MB
(2.2 to 2.8 ms per cycle).

Cycle with committed position P and certain next token x:

1. `xbd_step_dev(taps of the n rows committed last, pos0 = P - n, R, x, P)`
   returns R - 1 drafts.
2. XeFlash verifies `[x, drafts]` in one pass (8 or 16 rows), commits the
   agreeing prefix; the pass captures the taps for the next cycle.

Rejected rows never reach the ring, so there is no drafter rollback.

## 4. What was checked

* Greedy output identical to non-speculative decoding, and identical
  committed state (DeltaNet states, conv histories, KV rows), on five prompts,
  with 8-row, 16-row and adaptive blocks, taps through host and
  device-to-device.
* Tap fidelity: XeFlash's taps against the original BF16 model on a held-out
  chat (`benchmarks/results/m5/tap_difference.txt`): relative error 0.05 at
  layer 5 rising to 0.22 at layer 61, median per-token cosine 0.9997 to
  0.981. They were not compared with YASAKANI's own taps (its main model was
  not run). The drafter was trained against YASAKANI's compressed main model;
  acceptance on XeFlash's main model is nevertheless high (Part D).

## 5. D0 / D1 and the 8/16 rule

* D0 copies what followed the most recent earlier occurrence of the current
  n-gram (n = 8 down to 2); D1 follows tables of the main model's choice after
  the last one to three tokens, built at run time. XeFlash has its own small
  implementation of that description (`ext::Lookup`) for the "lookup only"
  comparison. It is not YASAKANI's code and does not include its controller
  that arbitrates between D0 and the drafter.
* The adaptive block rule is YASAKANI's (exponential averages of the tokens a
  16-row pass adds beyond the first seven against the extra cost of 16 rows),
  with the cost ratio measured on XeFlash (1.16).
* How much D0/D1 add on top of bdraft2 inside YASAKANI is not recorded in its
  notes for the B60; here they were only measured alone.

## 6. Status and caveats

* Experimental. The backend needs the YASAKANI source tree at build time and
  its three model files at run time, and adds 2.80 GiB of device memory
  (including its own 1.41 GB head and its own copy of the embedding).
* The drafter is YASAKANI's work (Apache-2.0 according to its LICENSE file);
  shipping it as XeFlash's default is a decision for the owner of both
  projects, not a technical one.
* A native version would decode the 46 matrices with YASAKANI's
  `tools/yskn_decode.py`, re-quantise them to XeFlash's format and reimplement
  about fifteen kernels; then the head could be shared with the main model's.

## 7. Adapting bdraft2 to XeFlash's INT4 main model: negative result

Study in `/data/B60special/bdraft2-ft` (PyTorch port of the drafter verified against the engine: first draft equal in
99.5 % of recorded cycles; teacher data collected from XeFlash with the `xf-run collect` subcommand: 338 sequences,
ja/en/code/math/logic, topics disjoint between train, val and test; test untouched).

Untuned bdraft2 on XeFlash's main model, validation, tokens per pass: all 3.45, ja 2.11, en 2.95, code 4.86, math 5.25,
logic 4.54. Japanese is low on all 14 validation prompts, not on one.

Tried, each against the untuned drafter with a paired sequence bootstrap on the last checkpoint:
per-tap scale and bias before `fc`; `fc` itself; LoRA rank 8 and 16 on q/k/v/o of the five layers; the selector
projection `sel.hp`. None moved all-category or Japanese tokens/pass outside +-0.04 / +-0.03 (intervals contain zero);
the larger variants fit the training sequences (held-in tokens/pass up to +0.1) without any validation gain. A
sensitivity test explains the first two: scaling the taps by 0.8 to 1.25, adding 0.4 sigma noise, or a constant bias
barely changes acceptance; only dropping tap 47 or 61 does.

The candidate set is not the limit either: forcing the target into the SHEAD candidates changes the first draft by
+1.2 points on Japanese (60.8 -> 62.0 %), and a perfect candidate step would add 0.03 tokens/pass overall. The target is
in the drafter's exact top-3 in 78 % of Japanese blocks and first in 61 %: a ranking problem inside the drafter.

Decision: untuned bdraft2 stays the baseline; no tuned weights are ported. Full table, defects found in the experiments
and the reasoning: `/data/B60special/bdraft2-ft/docs/TRAINING_REPORT.md`. Japanese is a separate study (re-ranking of
the top-16, a different training objective, much more Japanese data).

Next priorities for XeFlash speed instead (from PERFORMANCE.md): long-context attention (8K-token decode is 2x slower
per pass than at short context, FP32 unfused attention), the non-GEMM part of the main pass (about 10 ms of 51), and
the cost of the verification pass for 8 and 16 rows.
