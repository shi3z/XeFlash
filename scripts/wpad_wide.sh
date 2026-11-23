#!/usr/bin/env bash
# 64-row wide pass with the padded weight layout: scripts/wpad_wide.sh <out dir> "pads"; compares tokens / logits / GDN state / KV cache of one wide pass against <=16-row passes within each run (the digest line is compared across pads by wpad_wide_cmp.sh)
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=$1; mkdir -p $R
for pad in ${2:-"0 16 48"}; do
  for c in "jsonl64 edit_edit_jsonl 64 4096" "code64 edit_edit_code 64 6144" "jsonl32 edit_edit_jsonl 32 4096" "jsonl16 edit_edit_jsonl 16 4096"; do
    set -- $c
    XF_WPAD=$pad XF_KV=xmx scripts/b60run timeout 600 ./target/release/xf-run wide $X benchmarks/prompts/$2.json --rows $3 --ctx $4 > $R/wide_${1}_pad$pad.log 2>&1
    echo "$1 pad$pad rc=$? $(grep -E 'output tokens|GDN state|KV cache:|whole-state' $R/wide_${1}_pad$pad.log | tr '\n' ';')" >> $R/status.txt
  done
done
echo done >> $R/status.txt
