#!/usr/bin/env bash
# Per-kernel profile of YASAKANI on the RTX 5060 Ti (YSKN_PROF=1: blocking timing of every launch, graphs off), same prompts as XeFlash.
cd "$(dirname "$0")/.."
R=benchmarks/results/m12; P=benchmarks/prompts; mkdir -p $R; rm -f $R/y_prof_status.txt
export PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=/data/yasakani/5060/yasakani/python
PY=/data/minimaxh3/ComfyUI/.venv/bin/python
p() { local n=$1 ctx=$2 item=$3
  flock /tmp/rtx5060.lock timeout 1500 $PY tools/compare5060/run_yasakani.py --max-ctx $ctx --item $P/$item --modes on --env YSKN_PROF=1 --spec use_graph=0 --json $R/y_prof_$n.json > $R/y_prof_$n.log 2>&1
  echo "$n $?" >> $R/y_prof_status.txt; }
p code 2048 code.json:256
p 8k 10240 long8000.json:256
p 30k 32768 long30000.json:256
p 60k 65536 long60000.json:256
