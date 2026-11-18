#!/usr/bin/env bash
# Re-run the code tasks with room for the whole answer (2048 new tokens) so that no answer is cut off; XMX attention for all, FP32 KV for the answers that were cut off before.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
R=benchmarks/results/m10; mkdir -p $R; rm -f $R/status.txt
P=benchmarks/prompts
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
run() { local n=$1 kv=$2 pr=$3 ctx=$4 to=$5
  XF_KV=$kv scripts/b60run timeout $to ./target/release/xf-run cmp $X $pr 2048 --only-bd --configs 16,0c --ctx $ctx $BD --json $R/$n.json --save-tokens $R/tok_$n > $R/$n.log 2>&1
  echo "$n $?" >> $R/status.txt; }
J() { local o=""; for a in "$@"; do o="$o,$P/$a.json"; done; echo ${o#,}; }
run short_xmx  xmx  $(J py_merge py_csv py_lru rs_balanced rs_merge cpp_fib cpp_merge) 2304 3600
run short_fp32 none $(J cpp_fib cpp_merge py_lru) 2304 2400
run k8_xmx     xmx  $(J codectx8k_py_csv codectx8k_rs_balanced codectx8k_cpp_fib) 10240 5400
run k8_fp32    none $(J codectx8k_cpp_fib) 10240 2400
run k30_xmx    xmx  $(J codectx30k_py_csv codectx30k_rs_balanced) 32256 7200
