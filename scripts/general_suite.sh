#!/usr/bin/env bash
# Part AI Phase 1: general generation tasks with every existing strategy (greedy, bdraft2 adaptive 0c, copy hybrid 16 / 32 / 64 rows).
# usage: [LAYOUT=auto] [CFG=0c,hy4/8,hw4/16,hv4/16] [REPS="1 2 3"] [R=dir] scripts/general_suite.sh
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=${R:-benchmarks/results/m54/base}; P=benchmarks/prompts; mkdir -p $R
export XF_WLAYOUT=${LAYOUT:-auto}
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
CFG=${CFG:-0c,hy4/8,hw4/16,hv4/16}
: > $R/status.txt
run() { # name prompts n_new ctx rep
  XF_KV=xmx scripts/b60run timeout 3000 ./target/release/xf-run cmp $X $2 $3 --only-bd --configs $CFG --ctx $4 $BD --json $R/$1_r$5.json --save-tokens $R/tok_$1_r$5 > $R/$1_r$5.log 2>&1
  echo "$1_r$5 exit=$?" >> $R/status.txt
}
for rep in ${REPS:-1 2 3}; do
  A=""; for n in py_merge cpp_merge gen_ja_chat gen_en_chat gen_math explain japanese story gen_ja_write proof; do A="$A,$P/$n.json"; done
  run A_gen512 ${A#,} 512 8192 $rep
  run B_edit1024 $P/edit_edit_code.json,$P/gen_cpp_edit.json 1024 8192 $rep
  run C_summary $P/long8000.json 384 9216 $rep
done
echo done >> $R/status.txt
