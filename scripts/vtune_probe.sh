#!/usr/bin/env bash
# VTune overview of a standalone probe binary: scripts/vtune_probe.sh <out dir> <name> <binary> [args]; csv per computing task in <out dir>/<name>.csv
cd "$(dirname "$0")/.."
R=$1; n=$2; shift 2
export PATH=$PATH:/opt/intel/oneapi/vtune/latest/bin64; source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
mkdir -p $R /tmp/claude-1000/vtr
read p k r < <(cut -d: -f2 benchmarks/results/m27/sysctl_orig.txt)
restore() { sudo sysctl -w kernel.yama.ptrace_scope=$p kernel.perf_event_paranoid=$k kernel.kptr_restrict=$r > $R/sysctl_restore.txt 2>&1; }
trap restore EXIT
sudo sysctl -w kernel.yama.ptrace_scope=0 kernel.perf_event_paranoid=0 kernel.kptr_restrict=0 > /dev/null
rm -rf /tmp/claude-1000/vtr/$n
timeout 900 vtune -collect gpu-hotspots -knob characterization-mode=${VT_MODE:-overview} -r /tmp/claude-1000/vtr/$n -- scripts/b60run timeout 600 "$@" > $R/$n.run.log 2>&1
vtune -report hotspots -group-by computing-task -r /tmp/claude-1000/vtr/$n -format csv -csv-delimiter tab > $R/$n.csv 2>/dev/null
echo "$n $?" > $R/$n.status
