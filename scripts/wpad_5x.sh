#!/usr/bin/env bash
# Weight stream pitch padding (XF_GEMM_WPAD / XF_BENCH_WPAD, dwords): all GEMM shapes, 16/32/64 rows, 5 interleaved processes per setting; usage: wpad_5x.sh <out> "pads..." ; xf-bench --cold
cd "$(dirname "$0")/.."; source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
out=$1; pads=${2:-"0 16 48"}; : > $out
MS=${MS:-"64"}; SHAPES=${SHAPES:-"merged.gate_up merged.qkvz merged.attn_qkv out_proj mlp.down"}
for r in 1 2 3 4 5; do for m in $MS; do for sh in $SHAPES; do for pad in $pads; do
  if [ $pad = 0 ]; then t=$(env -u XF_GEMM_WPAD -u XF_BENCH_WPAD scripts/b60run timeout 60 ./target/release/xf-bench --cold --format s4 --shape $sh --tokens $m --segs 1 2>&1 | grep "s4+a16" | awk '{print $7,$NF}')
  else t=$(XF_GEMM_WPAD=$pad XF_BENCH_WPAD=$pad scripts/b60run timeout 60 ./target/release/xf-bench --cold --format s4 --shape $sh --tokens $m --segs 1 2>&1 | grep "s4+a16" | awk '{print $7,$NF}'); fi
  echo "$sh m$m pad$pad r$r $t" >> $out
done; done; done; done; echo done >> $out
