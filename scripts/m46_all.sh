#!/usr/bin/env bash
# Part AG validation: exactness (23 cases, shadow-state commit on), Main pass + commit timing, then the E2E suite (5 processes per task).
cd "$(dirname "$0")/.."
R=benchmarks/results/m46; mkdir -p $R
WIDE_OUT=$R/wide scripts/wide_check.sh
source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
for rows in 16 32 64; do XF_KV=xmx scripts/b60run timeout 300 ./target/release/xf-run wide $X benchmarks/prompts/edit_edit_jsonl.json --rows $rows --ctx 4096 > $R/wide_$rows.log 2>&1; done
echo pre > $R/pre.done
scripts/edit_af_suite.sh
echo done > $R/all.done
