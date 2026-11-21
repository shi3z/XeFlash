#!/usr/bin/env bash
# VTune gpu-hotspots (overview) of the 16-bit-activation s4 GEMM at 16 / 64 / 128 rows, cold weights, 1 segment. Sets the three sysctls and restores them on exit (1 4 1).
cd "$(dirname "$0")/.."
export PATH=$PATH:/opt/intel/oneapi/vtune/latest/bin64; source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
R=benchmarks/results/m37/vtune; mkdir -p $R /tmp/claude-1000/vtr
read p k r < <(cut -d: -f2 benchmarks/results/m27/sysctl_orig.txt)
restore() { sudo sysctl -w kernel.yama.ptrace_scope=$p kernel.perf_event_paranoid=$k kernel.kptr_restrict=$r > $R/sysctl_restore.txt 2>&1; }
trap restore EXIT
sudo sysctl -w kernel.yama.ptrace_scope=0 kernel.perf_event_paranoid=0 kernel.kptr_restrict=0 > /dev/null
: > $R/status.txt
for shape in merged.gate_up mlp.down merged.qkvz out_proj; do
  for m in 16 64 128; do
    n=${shape}_m$m; rm -rf /tmp/claude-1000/vtr/$n
    timeout 400 vtune -collect gpu-hotspots -knob characterization-mode=overview -r /tmp/claude-1000/vtr/$n -- scripts/b60run timeout 150 ./target/release/xf-bench --cold --format s4 --shape $shape --tokens $m --segs 1 > $R/$n.run.log 2>&1
    vtune -report hotspots -group-by computing-task -r /tmp/claude-1000/vtr/$n -format csv -csv-delimiter tab > $R/$n.csv 2>/dev/null
    echo "$n $?" >> $R/status.txt
  done
done
echo done >> $R/status.txt
