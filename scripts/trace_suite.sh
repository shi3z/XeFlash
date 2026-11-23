#!/usr/bin/env bash
# Part AI: oracle traces (greedy tokens + bdraft2 block drafts of 8 and 16 rows at every position + real pass costs) for the offline simulator.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=${R:-benchmarks/results/m54/trace}; P=benchmarks/prompts; mkdir -p $R
export XF_WLAYOUT=auto
BD="--bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
t() { XF_KV=xmx scripts/b60run timeout 3000 ./target/release/xf-run trace $X $1 $2 --ctx $3 $BD --out $R > $R/log_$4.txt 2>&1; echo "$4 exit=$?" >> $R/status.txt; }
: > $R/status.txt
A=""; for n in py_merge cpp_merge gen_ja_chat gen_en_chat gen_math explain japanese story gen_ja_write proof; do A="$A,$P/$n.json"; done
t ${A#,} 512 8192 A
t $P/edit_edit_code.json,$P/gen_cpp_edit.json 1024 8192 B
t $P/long8000.json 384 9216 C
t $P/edit_edit_jsonl.json 2854 8192 D
echo done >> $R/status.txt
