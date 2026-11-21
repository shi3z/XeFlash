#!/usr/bin/env bash
# Per-kernel GDN time (XF_PROF_DETAIL, net us per layer) at 1/8/16/32/48/64 rows for the original kernels and variants of the new ones.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=benchmarks/results/m32/detail; mkdir -p $R; : > $R/status.txt
run() { # name env
  env $2 XF_PROF_DETAIL=1 XF_KV=xmx scripts/b60run timeout 400 ./target/release/xf-run gen $X benchmarks/prompts/edit_edit_jsonl.json 8 --profile --ctx 4096 > $R/$1.log 2>&1
  echo "$1 rc=$?" >> $R/status.txt
}
run old    XF_GDN_OLD=1
run cb1    XF_GDN_CB=1
run cb2    XF_GDN_CB=2
run cb4    XF_GDN_CB=4
run tb2    "XF_GDN_CONV_TB=2 XF_GDN_GEMV_TB=2"
run tb8    "XF_GDN_CONV_TB=8 XF_GDN_GEMV_TB=8"
run tb16   "XF_GDN_CONV_TB=16 XF_GDN_GEMV_TB=16"
echo done >> $R/status.txt
