#!/usr/bin/env bash
# Generation-speed suite on the production container (s4-cal, 4-bit), bdraft2 drafter, XF_KV=xmx (FP16 KV; needed for 60K), greedy.
#  A. 8K / 30K / 60K context, fixed8 / fixed16 / adaptive (measured cost, "0c"), 256 new tokens, 1 warm-up (short code prompt, same process) + 5 measured repeats
#     (one process per repeat so that the GPU lock is released between repeats).
#  B. sustained: 2048 new tokens at 8K context.
#  C. code tasks (7 prompts, 2048 new tokens, short context), graded with tools/code_eval/code_eval.py.
# Results: benchmarks/results/m22/. Every GPU run goes through scripts/b60run (flock /tmp/b60.lock).
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
R=benchmarks/results/m22; mkdir -p $R; P=benchmarks/prompts
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
cmp_run() { # name prompts n_new ctx timeout
  XF_KV=xmx scripts/b60run timeout $5 ./target/release/xf-run cmp $X $2 $3 --only-bd --configs 8,16,0c --ctx $4 $BD --json $R/$1.json --save-tokens $R/tok_$1 > $R/$1.log 2>&1
  echo "$1 exit=$?" >> $R/status.txt
}
: > $R/status.txt
for rep in 1 2 3 4 5; do cmp_run A_8k_r$rep   $P/code.json,$P/long8000.json  256 8448  1500; done
for rep in 1 2 3 4 5; do cmp_run A_30k_r$rep  $P/code.json,$P/long30000.json 256 30720 3000; done
for rep in 1 2 3 4 5; do cmp_run A_60k_r$rep  $P/code.json,$P/long60000.json 256 61440 5400; done
cmp_run B_sustained_8k $P/long8000.json 2048 10240 3000
C=""; for a in py_merge py_csv py_lru rs_balanced rs_merge cpp_fib cpp_merge; do C="$C,$P/$a.json"; done
cmp_run C_code ${C#,} 2048 2304 5400
echo done >> $R/status.txt
