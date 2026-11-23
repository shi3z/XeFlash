#!/usr/bin/env bash
# Experiments A (XF_GEMM_RBPERM) and B (XF_GEMM_KROT): gate_up 64 rows, 5 interleaved processes per setting; usage: ab_knobs_5x.sh <out> "name:ENV=val[,ENV=val]" ...
cd "$(dirname "$0")/.."; source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
out=$1; shift; : > $out
for r in 1 2 3 4 5; do for nv in "$@"; do n=${nv%%:*}; e=${nv#*:}
  t=$(env -u XF_GEMM_NATIVE $(echo $e | tr ',' ' ') scripts/b60run timeout 60 ./target/release/xf-bench --cold --format s4 --shape merged.gate_up --tokens 64 --segs 1 2>&1 | grep "s4+a16" | awk '{print $7,$NF}')
  echo "$n r$r $t" >> $out
done; done; echo done >> $out
