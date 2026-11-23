#!/usr/bin/env bash
# Independent re-measurement of the JSONL edit task (copy+bdraft2 hybrid, 64 rows): fresh processes, same flags as the suites. usage: LAYOUT=auto|0 REPS="1 2 3" R=<dir> scripts/remeasure_jsonl.sh
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=${R:-benchmarks/results/m53/remeasure}; mkdir -p $R; P=benchmarks/prompts
[ "${LAYOUT:-auto}" = auto ] && export XF_WLAYOUT=auto
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
: > $R/status.txt
for rep in ${REPS:-1 2 3}; do
  XF_KV=xmx scripts/b60run timeout 3600 ./target/release/xf-run cmp $X $P/edit_edit_jsonl.json 2854 --only-bd --configs 0c,hv4/16 --ctx 8192 $BD --json $R/jsonl_r$rep.json --save-tokens $R/tok_jsonl_r$rep > $R/jsonl_r$rep.log 2>&1
  echo "jsonl_r$rep exit=$?" >> $R/status.txt
done
echo done >> $R/status.txt
