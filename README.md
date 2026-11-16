# XeFlash

An LLM inference engine for Qwen3.8-27B built for one GPU: the Intel Arc Pro
B60 (Xe2, 24 GB). Rust host, C++20 SYCL/ESIMD kernels.

The engine is designed around a property of the Xe2 systolic array: `dpas`
consumes packed 4-bit and 2-bit integer operands directly. Weights are stored
in the order DPAS reads them, so decoding a token is a memory stream feeding
XMX with no unpacking, no table lookups and no shared local memory.

**Status: early.** The GEMM layer, the weight format, the converter and the
measurement tools exist and are verified on the B60. The model itself
(DeltaNet, attention, sampling), speculative decoding and the API do not exist
yet, so there is no tokens-per-second figure. See `docs/PERFORMANCE.md` for
what has been measured and what is only projected.

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

# ISA dump and summary
NEO_CACHE_PERSISTENT=0 SYCL_CACHE_PERSISTENT=0 IGC_ShaderDumpEnable=1 IGC_DumpToCustomDir=$PWD/isa/ \
  scripts/b60run target/release/xf-bench --quick --format s4
tools/validation/isa_report.py isa/
```

Benchmark on an idle host: a CPU-heavy job starves the submitting thread and
inflates kernel times.
