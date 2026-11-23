#!/usr/bin/env bash
# Weight base offset (XF_GEMM_WOFF / XF_BENCH_WOFF, dwords): GEMM shapes, rows MS, 5 interleaved processes per setting; usage: woff_5x.sh <out> "offsets"
cd "$(dirname "$0")/.."; source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
out=$1; offs=${2:-"0 16 32"}; : > $out
MS=${MS:-"64"}; SHAPES=${SHAPES:-"merged.gate_up merged.qkvz merged.attn_qkv out_proj mlp.down"}
for r in 1 2 3 4 5; do for m in $MS; do for sh in $SHAPES; do for off in $offs; do
  if [ $off = 0 ]; then t=$(env -u XF_GEMM_WOFF -u XF_BENCH_WOFF -u XF_GEMM_WPAD -u XF_BENCH_WPAD scripts/b60run timeout 60 ./target/release/xf-bench --cold --format s4 --shape $sh --tokens $m --segs 1 2>&1 | grep "s4+a16" | awk '{print $7,$NF}')
  else t=$(XF_GEMM_WOFF=$off XF_BENCH_WOFF=$off scripts/b60run timeout 60 ./target/release/xf-bench --cold --format s4 --shape $sh --tokens $m --segs 1 2>&1 | grep "s4+a16" | awk '{print $7,$NF}'); fi
  echo "$sh m$m pad$off r$r $t" >> $out
done; done; done; done; echo done >> $out
