#!/usr/bin/env bash
# Hybrid copy + bdraft2 (16-row verify) on the 3 YASAKANI v0.1.6 edit tasks, 5 repeats, same conditions as edit_bench_suite.sh (m23).
# Configs: 16, 0c = bdraft2 only; hy4/<blk> = copy candidate when it holds >= 4 tokens, else bdraft2 with block <blk>.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
R=benchmarks/results/m26; mkdir -p $R; P=benchmarks/prompts
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
: > $R/status.txt
run() { # task n_new ctx rep
  XF_KV=xmx scripts/b60run timeout 2400 ./target/release/xf-run cmp $X $P/edit_$1.json $2 --only-bd --configs 16,0c,hy4/8,hy4/0c,hy4/16 --ctx $3 $BD --json $R/$1_r$4.json --save-tokens $R/tok_$1_r$4 > $R/$1_r$4.log 2>&1
  echo "$1_r$4 exit=$?" >> $R/status.txt
}
for rep in 1 2 3 4 5; do
  run edit_code 4708 10240 $rep
  run edit_jsonl 2854 8192 $rep
  run edit_jsonl_long 6493 14336 $rep
done
echo done >> $R/status.txt
