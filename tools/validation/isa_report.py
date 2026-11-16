#!/usr/bin/env python3
"""Summarise IGC assembly dumps of the XeFlash ESIMD kernels.

Produce the dumps with (the persistent caches must be off or nothing is dumped):

    NEO_CACHE_PERSISTENT=0 SYCL_CACHE_PERSISTENT=0 IGC_ShaderDumpEnable=1 \\
    IGC_DumpToCustomDir=$PWD/isa/ scripts/b60run target/release/xf-bench ...

    tools/validation/isa_report.py isa/ [--md]

Columns: static instruction count, GRF mode, DPAS instructions by form and
operand precision, block loads / stores by size, gathers / scatters, SLM
accesses, spill size reported by the register allocator, barriers.
"""
import collections
import re
import sys
from pathlib import Path

FORMATS = {0: "s4", 1: "s2", 2: "s8", 3: "bf16", 4: "s4>s8", 5: "s3"}


def kernel_label(mangled: str) -> str:
    m = re.search(r"submitILi(\d+)ELi(\d+)ELi(\d+)ELi(\d+)ELb([01])E", mangled)
    if m:
        wf, r, g, u, a16 = (int(x) for x in m.groups())
        return f"gemm {FORMATS.get(wf, wf)}{'+a16' if a16 else ''} R{r} G{g} U{u}"
    m = re.search(r"combine_intILb([01])E", mangled)
    if m:
        return "combine_int" + ("+a16" if m.group(1) == "1" else "")
    if "combine_float" in mangled:
        return "combine_float"
    return mangled[:40]


def analyse(path: Path) -> dict:
    text = path.read_text(errors="replace")
    head = text[:4000]
    info = {
        "kernel": kernel_label(re.search(r"//\.kernel (\S+)", head).group(1)),
        "inst": int(re.search(r"//\.instCount (\d+)", head).group(1)),
        "grf": int(re.search(r"numGRF=(\d+)", head).group(1)),
    }
    spill = re.search(r"//\.spill size (\d+)", text)
    info["spill_bytes"] = int(spill.group(1)) if spill else 0
    dpas = collections.Counter()
    loads = collections.Counter()
    stores = collections.Counter()
    gathers = slm = barriers = 0
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("//"):
            continue
        s = re.sub(r"^\([^)]*\)\s*", "", s)  # predicate / write-enable prefix
        op = s.split(" ", 1)[0]
        if op.startswith("dpas"):
            prec = re.findall(r":(s4|u4|s2|u2|b|ub|bf|hf)\b", s)
            dpas[f"{op} {'x'.join(prec[-2:])}"] += 1
        elif op.startswith("load") or op.startswith("store"):
            if ".slm." in op:
                slm += 1
            # d32x64t = one transposed block of 64 dwords; plain d32 with an
            # address vector is a gather / scatter.
            block = re.search(r"\.d(\d+)x(\d+)t\.", op)
            target = loads if op.startswith("load") else stores
            if block:
                target[f"{int(block.group(1)) * int(block.group(2)) // 8}B"] += 1
            else:
                gathers += 1
        elif op in ("barrier", "wait") or "barrier" in s.split("//")[0]:
            barriers += 1
    info.update(dpas=dict(dpas), loads=dict(loads), stores=dict(stores), gathers=gathers, slm=slm, barriers=barriers)
    return info


def fmt(counter: dict) -> str:
    return ", ".join(f"{v}x {k}" for k, v in sorted(counter.items())) or "-"


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    rows = [analyse(p) for p in sorted(Path(args[0]).rglob("VC_asm*.asm"))]
    rows.sort(key=lambda r: r["kernel"])
    if "--md" in sys.argv:
        print("| kernel | inst | GRF | DPAS | block loads | block stores | gather/scatter | SLM | spill | barriers |")
        print("|---|---|---|---|---|---|---|---|---|---|")
        for r in rows:
            print(f"| {r['kernel']} | {r['inst']} | {r['grf']} | {fmt(r['dpas'])} | {fmt(r['loads'])} | "
                  f"{fmt(r['stores'])} | {r['gathers']} | {r['slm']} | {r['spill_bytes']} B | {r['barriers']} |")
    else:
        for r in rows:
            print(f"{r['kernel']:<26} inst={r['inst']:<5} grf={r['grf']} spill={r['spill_bytes']}B "
                  f"gather={r['gathers']} slm={r['slm']} barrier={r['barriers']}")
            print(f"    dpas  : {fmt(r['dpas'])}")
            print(f"    loads : {fmt(r['loads'])}    stores: {fmt(r['stores'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
