#!/usr/bin/env bash
# VTune EU stall sampling (instruction level) of the 64-row gate_up GEMM: scripts/vtune_stall.sh <out dir> <name> [zebin]   (zebin: XF_GEMM_NATIVE binary, default = JIT kernel)
cd "$(dirname "$0")/.."
R=$1; n=$2; z=$3
export PATH=$PATH:/opt/intel/oneapi/vtune/latest/bin64; source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
mkdir -p $R /tmp/claude-1000/vtr
read p k r < <(cut -d: -f2 benchmarks/results/m27/sysctl_orig.txt)
restore() { sudo sysctl -w kernel.yama.ptrace_scope=$p kernel.perf_event_paranoid=$k kernel.kptr_restrict=$r > $R/sysctl_restore.txt 2>&1; }
trap restore EXIT
sudo sysctl -w kernel.yama.ptrace_scope=0 kernel.perf_event_paranoid=0 kernel.kptr_restrict=0 > /dev/null
rm -rf /tmp/claude-1000/vtr/$n
[ -n "$z" ] && export XF_GEMM_NATIVE=$z
timeout 600 vtune -collect gpu-hotspots -knob profiling-mode=source-analysis -knob source-analysis=${VT_SA:-stall-sampling} -r /tmp/claude-1000/vtr/$n -- scripts/b60run timeout 300 ./target/release/xf-bench --cold --format s4 --shape merged.gate_up --tokens 64 --segs 1 > $R/$n.run.log 2>&1
echo "collect rc=$?" > $R/$n.status
vtune -report hotspots -group-by computing-task -r /tmp/claude-1000/vtr/$n -format csv -csv-delimiter tab > $R/$n.tasks.csv 2>$R/$n.report.err
echo "report rc=$?" >> $R/$n.status
