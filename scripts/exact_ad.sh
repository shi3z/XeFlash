#!/usr/bin/env bash
# Exactness of the controller: tokens AND committed state against plain greedy (the state hash is taken at the first pass boundary after 64 tokens, the reference covers every possible length)
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; P=benchmarks/prompts; R=benchmarks/results/m55/exact; mkdir -p $R
export XF_WLAYOUT=auto
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
: > $R/status.txt
A=""; for n in py_merge gen_math gen_en_chat gen_ja_chat explain story; do A="$A,$P/$n.json"; done
XF_KV=xmx scripts/b60run timeout 3000 ./target/release/xf-run cmp $X ${A#,} 256 --only-bd --configs ad,hv4/16 --ctx 4096 $BD --json $R/A.json > $R/A.log 2>&1; echo "A exit=$?" >> $R/status.txt
XF_KV=xmx scripts/b60run timeout 3000 ./target/release/xf-run cmp $X $P/edit_edit_code.json,$P/gen_cpp_edit.json 512 --only-bd --configs ad,hv4/16 --ctx 8192 $BD --json $R/B.json > $R/B.log 2>&1; echo "B exit=$?" >> $R/status.txt
XF_KV=xmx scripts/b60run timeout 3000 ./target/release/xf-run cmp $X $P/edit_edit_jsonl.json 1024 --only-bd --configs ad,hv4/16 --ctx 8192 $BD --json $R/C.json > $R/C.log 2>&1; echo "C exit=$?" >> $R/status.txt
echo done >> $R/status.txt
