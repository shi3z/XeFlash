#!/usr/bin/env bash
# General generation benchmark: code generation (py_merge, cpp_merge), code editing (edit_edit_code), English writing (explain, story), Japanese writing (japanese).
# 512 new tokens each, greedy (none), bdraft2 adaptive (0c), copy+bdraft2 hybrid 16 rows (hy4/8) and 64 rows (hv4/16); one process per repeat (all prompts in the process, model loaded once).
# usage: PAD=<dwords> REPS="1 2 3" R=<dir> scripts/normal_bench.sh
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
PAD=${PAD:-0}; R=${R:-benchmarks/results/m52/pad$PAD}; mkdir -p $R; P=benchmarks/prompts; export XF_WPAD=$PAD; [ "${LAYOUT:-}" = auto ] && export XF_WLAYOUT=auto
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
: > $R/status.txt
for rep in ${REPS:-1 2 3}; do
  XF_KV=xmx scripts/b60run timeout 3000 ./target/release/xf-run cmp $X $P/py_merge.json,$P/cpp_merge.json,$P/edit_edit_code.json,$P/explain.json,$P/story.json,$P/japanese.json 512 --only-bd --configs 0c,hy4/8,hv4/16 --ctx 8192 $BD --json $R/r$rep.json --save-tokens $R/tok_r$rep > $R/r$rep.log 2>&1
  echo "r$rep exit=$?" >> $R/status.txt
done
echo done >> $R/status.txt
