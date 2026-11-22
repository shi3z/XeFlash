#!/usr/bin/env bash
# VTune (overview) of one 64-row a16 GEMM variant: scripts/vtune_one.sh <XF_GEMM_A16_32 mode> <out dir> <shape>...   Sets the three sysctls and restores them on exit.
cd "$(dirname "$0")/.."
MODE=$1; R=$2; shift 2
export PATH=$PATH:/opt/intel/oneapi/vtune/latest/bin64; source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
mkdir -p $R /tmp/claude-1000/vtr
read p k r < <(cut -d: -f2 benchmarks/results/m27/sysctl_orig.txt)
restore() { sudo sysctl -w kernel.yama.ptrace_scope=$p kernel.perf_event_paranoid=$k kernel.kptr_restrict=$r > $R/sysctl_restore.txt 2>&1; }
trap restore EXIT
sudo sysctl -w kernel.yama.ptrace_scope=0 kernel.perf_event_paranoid=0 kernel.kptr_restrict=0 > /dev/null
: > $R/status.txt
for shape in "$@"; do
  n=${MODE}_$shape; rm -rf /tmp/claude-1000/vtr/$n
  XF_GEMM_A16_32=$MODE timeout 400 vtune -collect gpu-hotspots -knob characterization-mode=overview -r /tmp/claude-1000/vtr/$n -- scripts/b60run timeout 150 ./target/release/xf-bench --cold --format s4 --shape $shape --tokens 64 --segs 1 > $R/$n.run.log 2>&1
  vtune -report hotspots -group-by computing-task -r /tmp/claude-1000/vtr/$n -format csv -csv-delimiter tab > $R/$n.csv 2>/dev/null
  echo "$n $?" >> $R/status.txt
done
echo done >> $R/status.txt
