#!/usr/bin/env bash
# 17..32-row pass against passes of <= 16 rows over the same tokens: output tokens + logit bits, GDN state + conv history (per layer), KV cache (per layer), whole-state hash.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=${WIDE_OUT:-benchmarks/results/m29}; mkdir -p $R; : > $R/wide_status.txt
t() { # name kv prompt rows ctx
  XF_KV=$2 scripts/b60run timeout 600 ./target/release/xf-run wide $X benchmarks/prompts/$3.json --rows $4 --ctx $5 > $R/wide_$1.log 2>&1
  echo "$1 rc=$? $(grep -E 'output tokens|GDN state|KV cache:|whole-state' $R/wide_$1.log | tr '\n' ';')" >> $R/wide_status.txt
}
t fp32_jsonl32   fp32 edit_edit_jsonl 32 4096
t fp32_jsonl17   fp32 edit_edit_jsonl 17 4096
t fp32_code24    fp32 edit_edit_code 24 6144
t xmx_jsonl32    xmx  edit_edit_jsonl 32 4096
t xmx_jsonl31    xmx  edit_edit_jsonl 31 4096
t xmx_jsonl20    xmx  edit_edit_jsonl 20 4096
t xmx_long8000_32 xmx long8000 32 8192
t xmx_code32     xmx  edit_edit_code 32 6144
t fp16_jsonl32   fp16 edit_edit_jsonl 32 4096
t bf16_jsonl32   bf16 edit_edit_jsonl 32 4096
t xmx_jsonl64    xmx  edit_edit_jsonl 64 4096
t xmx_jsonl48    xmx  edit_edit_jsonl 48 4096
t xmx_jsonl33    xmx  edit_edit_jsonl 33 4096
t xmx_long8000_64 xmx long8000 64 8192
t fp32_jsonl64   fp32 edit_edit_jsonl 64 4096
t fp16_jsonl64   fp16 edit_edit_jsonl 64 4096
t bf16_jsonl64   bf16 edit_edit_jsonl 64 4096
t xmx_code64     xmx  edit_edit_code 64 6144
t xmx_jsonl40    xmx  edit_edit_jsonl 40 4096
t xmx_jsonl49    xmx  edit_edit_jsonl 49 4096
t xmx_jsonl56    xmx  edit_edit_jsonl 56 4096
t xmx_jsonl63    xmx  edit_edit_jsonl 63 4096
t fp32_jsonl48   fp32 edit_edit_jsonl 48 4096
echo done >> $R/wide_status.txt
