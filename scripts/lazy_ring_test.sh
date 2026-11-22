#!/usr/bin/env bash
# Experiment: skip the drafter's ring catch-up in copy cycles (XF_BD_LAZY=1) against the normal catch-up, on the JSONL edit and the code edit (64-row hybrid).
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=benchmarks/results/m45/lazy; mkdir -p $R; : > $R/status.txt
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
run() { # name lazy task n ctx
  XF_BD_LAZY=$2 XF_KV=xmx scripts/b60run timeout 1500 ./target/release/xf-run cmp $X benchmarks/prompts/edit_$3.json $4 --only-bd --configs hv4/8,hv4/16 --ctx $5 $BD --json $R/$1.json > $R/$1.log 2>&1
  echo "$1 rc=$?" >> $R/status.txt
}
run jsonl_eager 0 edit_jsonl 2854 8192
run jsonl_lazy  1 edit_jsonl 2854 8192
run code_eager  0 edit_code 4708 10240
run code_lazy   1 edit_code 4708 10240
echo done >> $R/status.txt
