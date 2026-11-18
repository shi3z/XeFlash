#!/usr/bin/env bash
# Code-focused speculative-decoding study (XeFlash + bdraft2, XF_KV=xmx shared XMX attention vs the FP32-KV kernels).
# Every GPU run goes through scripts/b60run (flock /tmp/b60.lock). Results: benchmarks/results/m9/.
cd "$(dirname "$0")/.."
X=/data/B60special/models/xfm/qwen38-27b-s4-cal.xfm
R=benchmarks/results/m9; mkdir -p $R; rm -f $R/status.txt
P=benchmarks/prompts
BD="--sketch /data/xeflash-drafter/checkpoints/export/xeflash_mtp_v2/f_fc_fq4 --rank 512 --groups 40 --bdraft /data/yasakani/model-speed/qwen38_27b_speed.yskn,/data/yasakani/model-speed/bdraft2_k8.yskn"
CF=8,16,0,0c
run() { # name kv prompts n_new ctx configs timeout
  local n=$1 kv=$2 pr=$3 nt=$4 ctx=$5 cf=$6 to=$7
  XF_KV=$kv scripts/b60run timeout $to ./target/release/xf-run cmp $X $pr $nt --only-bd --configs $cf --ctx $ctx $BD \
    --json $R/$n.json --save-tokens $R/tok_$n > $R/$n.log 2>&1
  echo "$n $?" >> $R/status.txt
}
J() { local o=""; for a in "$@"; do o="$o,$P/$a.json"; done; echo ${o#,}; }
# A. the old benchmark prompt, same conditions as the 115.1 tok/s measurement (512 tokens, short context)
run A_code_xmx   xmx  $P/code.json 512 1024 $CF 1500
run A_code_fp32  none $P/code.json 512 1024 $CF 1500
# B. overall table, short context, 512 tokens
OLD=$(J explain code story proof japanese)
run B_all_xmx   xmx  $OLD 512 1024 $CF 3000
run B_all_fp32  none $OLD 512 1024 $CF 3000
# C. new code prompts, short context, 768 tokens (room for code plus tests)
CODE=$(J py_merge py_csv py_lru rs_balanced rs_merge cpp_fib cpp_merge)
run C_code_xmx  xmx  $CODE 768 1024 $CF 3000
run C_code_fp32 none $CODE 768 1024 $CF 3000
# D. 8K context with real code in front
run D_8k_xmx  xmx  $(J codectx8k_py_csv codectx8k_rs_balanced codectx8k_cpp_fib) 768 8960 $CF 3000
run D_8k_fp32 none $(J codectx8k_py_csv codectx8k_rs_balanced codectx8k_cpp_fib) 768 8960 $CF 3000
# E. 30K context
run E_30k_xmx  xmx  $(J codectx30k_py_csv codectx30k_rs_balanced) 768 31040 8,16,0c 5400
run E_30k_fp32 none $(J codectx30k_py_csv codectx30k_rs_balanced) 768 31040 8,16,0c 5400
