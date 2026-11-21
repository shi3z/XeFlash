#!/usr/bin/env bash
# New GDN kernels (core columns per thread, conv/gemv token blocks) against the original ones (XF_GDN_OLD=1): digest of tokens + logit bits + per-layer state hashes must be identical; plus the 16-row-pass comparison (xf-run wide) for up to 64 rows.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=benchmarks/results/m33/ab; mkdir -p $R; : > $R/ab_status.txt
t() { # name env kv prompt rows ctx
  env $2 XF_KV=$3 scripts/b60run timeout 600 ./target/release/xf-run wide $X benchmarks/prompts/$4.json --rows $5 --ctx $6 > $R/ab_$1.log 2>&1
  echo "$1 rc=$? $(grep -E 'output tokens|GDN state|KV cache:|whole-state|digest|rows:' $R/ab_$1.log | tr '\n' ';')" >> $R/ab_status.txt
}
for rows in 16 32 64; do
  t old_xmx_$rows  XF_GDN_OLD=1 xmx edit_edit_jsonl $rows 4096
  t new_xmx_$rows  XF_X=1       xmx edit_edit_jsonl $rows 4096
done
t old_fp32_32 XF_GDN_OLD=1 fp32 edit_edit_jsonl 32 4096
t new_fp32_32 XF_X=1       fp32 edit_edit_jsonl 32 4096
t new_fp32_64 XF_X=1       fp32 edit_edit_jsonl 64 4096
t new_xmx_64_long XF_X=1   xmx long8000 64 8192
for cb in 1 4; do t new_cb$cb XF_GDN_CB=$cb xmx edit_edit_jsonl 32 4096; done
for tb in 4; do t new_tb$tb "XF_GDN_CONV_TB=$tb XF_GDN_GEMV_TB=$tb" xmx edit_edit_jsonl 32 4096; done
echo done >> $R/ab_status.txt
