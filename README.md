# XeFlash

An LLM inference engine for Qwen3.8-27B built for one GPU: the Intel Arc Pro
B60 (Xe2, 24 GB). Rust host, C++20 SYCL/ESIMD kernels.

The engine is designed around a property of the Xe2 systolic array: `dpas`
consumes packed 4-bit and 2-bit integer operands directly. Weights are stored
in the order DPAS reads them, so decoding a token is a memory stream feeding
XMX with no unpacking, no table lookups and no shared local memory.

**Status.** The whole model runs on the B60 and is verified against the
official layer code: 22.4 tok/s greedy without speculation, 61.8 tok/s with
the checkpoint's own MTP block as drafter and a sketch of the lm_head for the
drafts (mean of four benchmark prompts, identical output and state), 16.3 GiB
resident with an 8192-token cache. That is below
the existing YASAKANI engine on the same card (86 tok/s), and fidelity to the
original model (KL 0.069 on a held-out chat) is not yet at its published
level. No tokenizer in Rust, no sampling other than greedy, no API yet. See
`docs/PERFORMANCE.md` first.

## Layout

```
crates/xeflash-core      errors, weight formats, small utilities
crates/xeflash-runtime   safe wrapper over the kernel library (device, RAII buffers, GEMM)
crates/xeflash-quant     XMX tile packing, quantiser
crates/xeflash-model     safetensors reader, .xfm container
kernels/                 libxfk.so: C ABI runtime + ESIMD kernels; probe/ holds the DPAS experiments
tools/benchmark          xf-bench     GEMM benchmark with CPU cross-check
tools/convert            xf-convert   inspect / analyze / convert / verify
tools/validation         xf-validate  converted weights on the GPU vs the original; isa_report.py
scripts/b60run           run a command on the B60 under the machine-wide GPU lock
docs/                    ARCHITECTURE, QUANTIZATION, PERFORMANCE, EXPERIMENTS
benchmarks/results/      raw outputs behind every number in the docs
```

## Build

Needs the oneAPI DPC++ compiler (`icpx`, tested with 2026.2) and Rust 1.85+
(2024 edition). `cargo build` runs `kernels/build.sh`, which finds `icpx` on
`PATH` or sources `/opt/intel/oneapi/setvars.sh`.

```sh
cargo build --release
cargo test --release
```

## Run

Everything that touches the GPU goes through `scripts/b60run`. It sets up the
runtime library path and holds `/tmp/b60.lock` for the duration, so two jobs
never share the card.

```sh
# GEMM benchmark (add --quick, --shape gate|down|qkv, --format s4|s3|s2|s8|bf16)
scripts/b60run target/release/xf-bench --json benchmarks/results/run.json

# inspect and convert the original checkpoint (CPU only)
target/release/xf-convert inspect  /path/to/Qwen3.8-27B
target/release/xf-convert convert  /path/to/Qwen3.8-27B model-s4.xfm
target/release/xf-convert verify   /path/to/Qwen3.8-27B model-s4.xfm

# converted matrices on the GPU against the original weights
scripts/b60run target/release/xf-validate gemm /path/to/Qwen3.8-27B model-s4.xfm layers.3.

# calibrated conversion and a run
python tools/validation/calib_stats.py /path/to/Qwen3.8-27B benchmarks/calib/chats.json stats/
target/release/xf-convert convert /path/to/Qwen3.8-27B model.xfm --stats stats/ --merge
python tools/validation/make_ids.py /path/to/Qwen3.8-27B benchmarks/prompts
scripts/b60run target/release/xf-run mem model.xfm
scripts/b60run target/release/xf-run gen model.xfm benchmarks/prompts/explain.json 512 --mtp 0,6

# ISA dump and summary
NEO_CACHE_PERSISTENT=0 SYCL_CACHE_PERSISTENT=0 IGC_ShaderDumpEnable=1 IGC_DumpToCustomDir=$PWD/isa/ \
  scripts/b60run target/release/xf-bench --quick --format s4
tools/validation/isa_report.py isa/
```

Keep GPU runs short or wrap them in `timeout`: the lock is shared, and a
stuck kernel holds it until the process is killed.

Benchmark on an idle host: a CPU-heavy job starves the submitting thread and
inflates kernel times.
