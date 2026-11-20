#!/usr/bin/env bash
# XeFlash port of YASAKANI v0.1.6 `bench --edit`: the 3 official edit tasks (benchmarks/edit/edit_tasks.json, unchanged copy),
# s4-cal container, greedy ("none") vs bdraft2 fixed8 / fixed16 / adaptive (0c), 5 repeats (one process each), thinking off.
# n_new = token count of the expected answer + <|im_end|> (benchmarks/edit/meta.json): the run covers exactly the answer (the official
# bench stops at the model's end token; xf-run cmp has no EOS stop, so the length is fixed from the expected text).
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
R=benchmarks/results/m23; mkdir -p $R; P=benchmarks/prompts
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
: > $R/status.txt
run() { # task n_new ctx rep
  XF_KV=xmx scripts/b60run timeout 2400 ./target/release/xf-run cmp $X $P/edit_$1.json $2 --only-bd --configs 8,16,0c --ctx $3 $BD --json $R/$1_r$4.json --save-tokens $R/tok_$1_r$4 > $R/$1_r$4.log 2>&1
  echo "$1_r$4 exit=$?" >> $R/status.txt
}
for rep in 1 2 3 4 5; do
  run edit_code 4708 10240 $rep
  run edit_jsonl 2854 8192 $rep
  run edit_jsonl_long 6493 14336 $rep
done
echo done >> $R/status.txt
