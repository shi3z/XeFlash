#!/usr/bin/env bash
# Effect of IGC / vISA scheduler registry keys on the 256-GRF 32-token GEMM (gate+up, 64 rows): kernel time, and the ISA (loads issued before the first scoreboard wait).
cd "$(dirname "$0")/.."
source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
R=benchmarks/results/m45/sched; mkdir -p $R; : > $R/summary.txt
run() { # name env...
  n=$1; shift
  rm -rf /tmp/igc_s_$n; mkdir -p /tmp/igc_s_$n
  env NEO_CACHE_PERSISTENT=0 IGC_ShaderDumpEnable=1 IGC_DumpToCustomDir=/tmp/igc_s_$n "$@" scripts/b60run timeout 200 ./target/release/xf-bench --cold --format s4 --shape merged.gate_up --tokens 64 --segs 1 > $R/$n.txt 2>&1
  t=$(grep -E "s4\+a16 +64" $R/$n.txt | awk '{print $7}')
  env "$@" ISA_OCLOC_OPTS="-ze-opt-large-register-file" python3 tools/profile/isa_analyze.py /tmp/igc_s_$n/*.spv --out $R/isa_$n > $R/isa_$n.jsonl 2>/dev/null
  python3 - "$n" "$t" <<'PY' >> $R/summary.txt
import json,sys
n,t=sys.argv[1],sys.argv[2]
for l in open(f"benchmarks/results/m45/sched/isa_{n}.jsonl"):
    try: d=json.loads(l)
    except: continue
    if d['label'].replace(' ','')=='submit<0,8,4,1,true,2,true>':
        print(f"{n}|{t}|GRF {d['grf']}|spill {d.get('spill_sends')}|loads {d['loads']}|dpas {d['dpas']}|loop instr {d.get('static_body')}|loads before 1st wait {d.get('loads_before_first_wait')}|waits {d.get('waits')}")
PY
}
run base  IGC_X=1
run nosched IGC_EnableVISANoSchedule=1
run presched1 IGC_ForceVISAPreSched=1
run presched_ctrl1 IGC_ForceVISAPreSched=1 IGC_VISAPreSchedCtrl=1
run presched_ctrl2 IGC_ForceVISAPreSched=1 IGC_VISAPreSchedCtrl=2
run presched_ctrl4 IGC_ForceVISAPreSched=1 IGC_VISAPreSchedCtrl=4
run presched_rp IGC_ForceVISAPreSched=1 IGC_VISAPreSchedRPThreshold=200
run presched_xgrf IGC_ForceVISAPreSched=1 IGC_VISAPreSchedExtraGRF=64
echo done >> $R/summary.txt
