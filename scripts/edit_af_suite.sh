#!/usr/bin/env bash
# Width-adaptive copy hybrid (16 / 32 / 64 rows), 256-GRF 32-token GEMM for 33..96 rows on the 3 YASAKANI v0.1.6 edit tasks, 5 repeats, same conditions as edit_bench_suite.sh (m23).
# Configs: 0c = bdraft2 only; hy4/8 = copy hybrid at 16 rows; hw4/<blk> = candidates >= 16 tokens verified in one 32-row pass; hv4/<blk> = candidates >= 32 tokens in one 64-row pass (16..31 -> 32 rows, 4..15 -> 16 rows, else bdraft2 block <blk>).
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
R=benchmarks/results/m46; mkdir -p $R; P=benchmarks/prompts
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
: > $R/status.txt
run() { # task n_new ctx rep
  XF_KV=xmx scripts/b60run timeout 3600 ./target/release/xf-run cmp $X $P/edit_$1.json $2 --only-bd --configs 0c,hy4/8,hw4/16,hv4/16,hv4/8 --ctx $3 $BD --json $R/$1_r$4.json --save-tokens $R/tok_$1_r$4 > $R/$1_r$4.log 2>&1
  echo "$1_r$4 exit=$?" >> $R/status.txt
}
for rep in 1 2 3 4 5; do
  run edit_code 4708 10240 $rep
  run edit_jsonl 2854 8192 $rep
  run edit_jsonl_long 6493 14336 $rep
done
echo done >> $R/status.txt
