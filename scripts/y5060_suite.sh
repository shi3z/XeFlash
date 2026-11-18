#!/usr/bin/env bash
# YASAKANI on the RTX 5060 Ti with the same token-id prompts / generation lengths as the XeFlash runs (greedy). Results: benchmarks/results/m11/.
cd "$(dirname "$0")/.."
R=benchmarks/results/m11; P=benchmarks/prompts; mkdir -p $R; rm -f $R/y_status.txt
export PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=/data/yasakani/5060/yasakani/python
PY=/data/minimaxh3/ComfyUI/.venv/bin/python
y() { local n=$1 ctx=$2 to=$3; shift 3; local items=""; for i in "$@"; do items="$items --item $P/$i"; done
  flock /tmp/rtx5060.lock timeout $to $PY tools/compare5060/run_yasakani.py --max-ctx $ctx $items --modes on,off --json $R/y_$n.json --save-ids $R/y_ids_$n > $R/y_$n.log 2>&1
  echo "$n $?" >> $R/y_status.txt; }
y short 2048 1500 code.json:512 py_merge.json:768 py_csv.json:768 py_lru.json:768 rs_balanced.json:768 rs_merge.json:768 cpp_fib.json:768 cpp_merge.json:768
y 8k 10240 1500 long8000.json:256 codectx8k_py_csv.json:768 codectx8k_rs_balanced.json:768 codectx8k_cpp_fib.json:768
y 30k 32768 2400 long30000.json:256 codectx30k_py_csv.json:768 codectx30k_rs_balanced.json:768
y 60k 65536 2400 long60000.json:256
