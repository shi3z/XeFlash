#!/usr/bin/env bash
# After the auto-dispatched 256-GRF 32-token GEMM (33..96 rows): exactness (wide_check), unit GEMM at 16/32/64 rows, Main pass timing, then the E2E suite.
cd "$(dirname "$0")/.."
R=benchmarks/results/m39; mkdir -p $R
WIDE_OUT=$R/wide scripts/wide_check.sh
source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
scripts/b60run timeout 900 ./target/release/xf-bench --cold --format s4 --tokens 16,32,64 --segs 1 --json $R/unit_final.json > $R/unit_final.txt 2>&1
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
for rows in 16 32 64; do for mode in auto split; do
  env XF_GEMM_A16_32=$mode XF_KV=xmx scripts/b60run timeout 300 ./target/release/xf-run wide $X benchmarks/prompts/edit_edit_jsonl.json --rows $rows --ctx 4096 > $R/wide_${mode}_$rows.log 2>&1
done; done
echo done > $R/pre.done
