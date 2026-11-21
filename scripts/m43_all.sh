#!/usr/bin/env bash
# Part AE final validation: exactness (23 cases), unit GEMM 16/32/64, Main pass + commit timing, stage profile, then the E2E suite (5 processes per task).
cd "$(dirname "$0")/.."
R=benchmarks/results/m43; mkdir -p $R
WIDE_OUT=$R/wide scripts/wide_check.sh
source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
scripts/b60run timeout 900 ./target/release/xf-bench --cold --format s4 --tokens 16,32,64 --segs 1 --json $R/unit_final.json > $R/unit_final.txt 2>&1
for rows in 16 32 64; do XF_KV=xmx scripts/b60run timeout 300 ./target/release/xf-run wide $X benchmarks/prompts/edit_edit_jsonl.json --rows $rows --ctx 4096 > $R/wide_$rows.log 2>&1; done
XF_PROF_DETAIL=1 XF_KV=xmx scripts/b60run timeout 300 ./target/release/xf-run gen $X benchmarks/prompts/edit_edit_jsonl.json 8 --profile --ctx 4096 > $R/detail_3k.log 2>&1
echo pre > $R/pre.done
sed -e 's#results/m40#results/m43#' scripts/edit_lgrf_suite.sh > /tmp/edit_ae_suite.sh; bash /tmp/edit_ae_suite.sh
echo done > $R/all.done
