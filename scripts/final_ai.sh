#!/usr/bin/env bash
# Part AI final measurement: JSONL edit (5 processes) then the general suite (5 repeats), configs 0c / hv4/16 / ad, auto weight layout, 64-row prefill.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; P=benchmarks/prompts; R=benchmarks/results/m55/final; mkdir -p $R/jsonl
export XF_WLAYOUT=auto
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
: > $R/status.txt
for rep in 1 2 3 4 5; do
  XF_KV=xmx scripts/b60run timeout 3600 ./target/release/xf-run cmp $X $P/edit_edit_jsonl.json 2854 --only-bd --configs 0c,hv4/16,ad --ctx 8192 $BD --json $R/jsonl/jsonl_r$rep.json --save-tokens $R/jsonl/tok_r$rep > $R/jsonl/jsonl_r$rep.log 2>&1
  echo "jsonl_r$rep exit=$?" >> $R/status.txt
done
R=$R/general CFG=0c,hv4/16,ad REPS="1 2 3 4 5" scripts/general_suite.sh
echo done >> benchmarks/results/m55/final/status.txt
