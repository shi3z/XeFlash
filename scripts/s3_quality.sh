#!/usr/bin/env bash
# Quality of a 3-bit (or mixed) container against the BF16 reference: teacher-forced logits on the held-out chat (KL, top-1), per-layer hidden error.
#   scripts/s3_quality.sh <tag> <container.xfm>      writes benchmarks/results/m21/q_<tag>.txt
cd "$(dirname "$0")/.."
tag=$1; X=$2
R=benchmarks/results/m21; mkdir -p $R
OUT=/data/B60special/work/m3/gpu_$tag
PY=/data/minimaxh3/ComfyUI/.venv/bin/python
scripts/b60run timeout 900 ./target/release/xf-run dump $X benchmarks/prompts/chat0.json $OUT > $R/q_${tag}.dump.log 2>&1
$PY tools/validation/compare.py /data/B60special/work/m3/ref_bf16_chat0 $OUT > $R/q_${tag}.txt 2>&1
tail -3 $R/q_${tag}.txt
