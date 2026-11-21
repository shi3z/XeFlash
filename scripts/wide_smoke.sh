#!/usr/bin/env bash
# One JSONL-edit run each: host ring catch-up (XF_BD_HOSTCTX=1) against the device-side catch-up, 32-row (hw) and 64-row (hv) hybrids.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=benchmarks/results/m33; mkdir -p $R
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
: > $R/smoke_status.txt
r() { # name env task n ctx configs
  env $2 XF_KV=xmx scripts/b60run timeout 900 ./target/release/xf-run cmp $X benchmarks/prompts/edit_$3.json $4 --only-bd --configs $6 --ctx $5 $BD --json $R/$1.json > $R/$1.log 2>&1
  echo "$1 rc=$?" >> $R/smoke_status.txt
}
r host_hw  XF_BD_HOSTCTX=1 edit_jsonl 2854 8192 hw4/16
r dev_hw   XF_X=1          edit_jsonl 2854 8192 hw4/16
r dev_hv   XF_X=1          edit_jsonl 2854 8192 hv4/16,hv4/8
echo done >> $R/smoke_status.txt
