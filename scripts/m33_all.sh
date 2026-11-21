#!/usr/bin/env bash
cd "$(dirname "$0")/.."
scripts/gdn_ab.sh
scripts/wide_smoke.sh
echo done > benchmarks/results/m33_all.done
