#!/usr/bin/env bash
# After the 32-row engine change: (1) 16 vs 32 row exactness (wide_check.sh), (2) stage profile at 1/8/16/24/32 rows, (3) 16-row regression (hybrid cmp), (4) MTP path check.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm; R=benchmarks/results/m29; mkdir -p $R
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
scripts/wide_check.sh
for p in edit_edit_jsonl long8000; do XF_KV=xmx scripts/b60run timeout 500 ./target/release/xf-run gen $X benchmarks/prompts/$p.json 8 --profile --ctx 9024 > $R/profile32b_$p.log 2>&1; done
XF_KV=xmx scripts/b60run timeout 900 ./target/release/xf-run cmp $X benchmarks/prompts/edit_edit_jsonl.json 2854 --only-bd --configs 16,hy4/16 --ctx 8192 $BD --json $R/regress_jsonl.json > $R/regress_jsonl.log 2>&1
scripts/b60run timeout 300 ./target/release/xf-run gen $X benchmarks/prompts/code.json 96 --mtp 0,7 --ctx 1024 > $R/mtp_check.log 2>&1
echo done > $R/suite.done
