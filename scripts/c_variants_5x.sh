#!/usr/bin/env bash
# 5 interleaved processes per variant (gate_up 64 rows, native-ISA variants); usage: c_variants_5x.sh <out> name=zebin ...
cd "$(dirname "$0")/.."; source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
out=$1; shift; : > $out
for r in 1 2 3 4 5; do for nv in "$@"; do n=${nv%%=*}; z=${nv#*=}
  if [ "$z" = jit ]; then unset XF_GEMM_NATIVE; else export XF_GEMM_NATIVE=$z; fi
  t=$(scripts/b60run timeout 60 ./target/release/xf-bench --cold --format s4 --shape merged.gate_up --tokens 64 --segs 1 2>&1 | grep "s4+a16" | awk '{print $7,$NF}')
  echo "$n r$r $t" >> $out
done; done; echo done >> $out
