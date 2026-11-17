# XeFlash

An LLM inference engine for Qwen3.8-27B built for one GPU: the Intel Arc Pro
B60 (Xe2, 24 GB). Rust host, C++20 SYCL/ESIMD kernels.

XeFlash is a reconstruction of [YASAKANI](https://github.com/yasakani-dev/yasakani)
for the Intel Xe architecture: it starts from the YASAKANI engine and rebuilds
it around what the Xe2 GPU does well. It follows YASAKANI's licence (Apache
License 2.0); see `LICENSE` and `NOTICE`.

The engine is designed around a property of the Xe2 systolic array: `dpas`
consumes packed 4-bit and 2-bit integer operands directly. Weights are stored
in the order DPAS reads them, so decoding a token is a memory stream feeding
XMX with no unpacking, no table lookups and no shared local memory.

**Status.** The whole model runs on the B60 and is verified against the
official layer code. Greedy decode, mean of four benchmark prompts, output and
state identical in every mode: 22.4 tok/s without speculation; 61.8 tok/s with
the checkpoint's own MTP block as drafter; 86.6 tok/s with YASAKANI's bdraft2
drafter attached through an optional experimental backend (level with the
YASAKANI engine's reported 86.3 on the same card, not above it). 16.3 GiB
resident with an 8192-token cache, 19.1 GiB with both drafters. Fidelity to
the original model (KL 0.069 on a held-out chat) is not yet at YASAKANI's
published level. No tokenizer in Rust, no sampling other than greedy, no API
yet. See `docs/PERFORMANCE.md` first.

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

# draft sources compared on the same main model (needs ~/yasakani-src and its model files)
cargo build --release --features xf-run/bdraft2
scripts/b60run timeout 360 target/release/xf-run cmp model.xfm benchmarks/prompts/code.json 512 --block 0 \\
  --sketch /path/to/head_sketch_dir --bdraft main.yskn,bdraft2_k8.yskn

# ISA dump and summary
NEO_CACHE_PERSISTENT=0 SYCL_CACHE_PERSISTENT=0 IGC_ShaderDumpEnable=1 IGC_DumpToCustomDir=$PWD/isa/ \
  scripts/b60run target/release/xf-bench --quick --format s4
tools/validation/isa_report.py isa/
```

Keep GPU runs short or wrap them in `timeout`: the lock is shared, and a
stuck kernel holds it until the process is killed.

Benchmark on an idle host: a CPU-heavy job starves the submitting thread and
inflates kernel times.

## Licence

Apache License 2.0, the same as YASAKANI, on which this project is based.
`NOTICE` says what derives from YASAKANI and how model files are treated.
