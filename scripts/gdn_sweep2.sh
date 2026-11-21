#!/usr/bin/env bash
# GDN core / gemv-ab / commit variants at 64 rows (per-kernel net us per layer with XF_PROF_DETAIL, Main pass time, commit time).
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=benchmarks/results/m41/sweep; mkdir -p $R; : > $R/status.txt
source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
run() { # name env
  env $2 XF_PROF_DETAIL=1 XF_KV=xmx scripts/b60run timeout 300 ./target/release/xf-run gen $X benchmarks/prompts/edit_edit_jsonl.json 8 --profile --ctx 4096 > $R/$1.log 2>&1
  env $2 XF_KV=xmx scripts/b60run timeout 100 ./target/release/xf-run wide $X benchmarks/prompts/edit_edit_jsonl.json --rows 64 --ctx 4096 > $R/$1.wide.log 2>&1
  echo "$1 rc=$?" >> $R/status.txt
}
run base  "XF_X=1"
run cb4   "XF_GDN_CB=4"
run cb8   "XF_GDN_CB=8"
run cc2   "XF_GDN_COMMIT_CB=2"
run cc8   "XF_GDN_COMMIT_CB=8"
run rt22  "XF_GDN_GEMV_RT=22"
run rt24  "XF_GDN_GEMV_RT=24"
run rt42  "XF_GDN_GEMV_RT=42"
run rt44  "XF_GDN_GEMV_RT=44"
run rt82  "XF_GDN_GEMV_RT=82"
echo done >> $R/status.txt
