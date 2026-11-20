#!/usr/bin/env bash
# Generation with the bdraft2 drafter on the 7 code prompts (768 new tokens): tok/s, acceptance, tokens saved for grading.
#   scripts/s3_gen.sh <tag> <container.xfm>      -> benchmarks/results/m21/gen_<tag>.{json,log}, tok_<tag>/
cd "$(dirname "$0")/.."
tag=$1; X=$2; R=benchmarks/results/m21; mkdir -p $R
P=benchmarks/prompts
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
PR=""; for a in py_merge py_csv py_lru rs_balanced rs_merge cpp_fib cpp_merge; do PR="$PR,$P/$a.json"; done
XF_KV=xmx scripts/b60run timeout 1500 ./target/release/xf-run cmp $X ${PR#,} 768 --only-bd --configs 16,0c --ctx 1024 $BD --json $R/gen_$tag.json --save-tokens $R/tok_$tag > $R/gen_$tag.log 2>&1
echo "$tag exit=$?" >> $R/status.txt
