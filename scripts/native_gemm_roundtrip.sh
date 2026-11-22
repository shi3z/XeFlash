#!/usr/bin/env bash
# Round trip of the 256-GRF 32-token GEMM kernel through native ISA:
#   IGC dump -> SPIR-V -> ocloc compile (bmg, large GRF) -> ocloc disasm -> (edit .asm) -> ocloc asm -> XF_GEMM_NATIVE=<zebin>
# usage: native_gemm_roundtrip.sh <spv> <workdir>   (the spv comes from IGC_ShaderDumpEnable=1 IGC_DumpToCustomDir=...)
set -euo pipefail
spv=$1; w=$2; mkdir -p "$w"; cd "$w"; rm -rf out dump
source /opt/intel/oneapi/setvars.sh >/dev/null 2>&1
ocloc compile -spirv_input -file "$spv" -device bmg -out_dir out -options "-ze-opt-large-register-file" >/dev/null
mkdir dump; ocloc disasm -file out/*.bin -device bmg -dump dump >/dev/null
echo "edit dump/.text*.asm, then: ocloc asm -file rt.zebin -dump dump -device bmg   (writes dump/rt.zebin)"
echo "run: XF_GEMM_NATIVE=$w/dump/rt.zebin xf-bench --cold --format s4 --shape merged.gate_up --tokens 64 --segs 1"
