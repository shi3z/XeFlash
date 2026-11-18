#!/usr/bin/env python3
"""Tables XeFlash (B60) vs YASAKANI (RTX 5060 Ti): same ids, same generation length, greedy."""
import json
import re
from pathlib import Path

R9, R8, R11 = (Path(f"benchmarks/results/{m}") for m in ("m9", "m8", "m11"))
def J(p): return {(r["prompt"], r["drafter"]): r for r in json.load(open(p))} if Path(p).exists() else {}
def Y(n):
    d = json.load(open(R11 / f"y_{n}.json")); return {(r["prompt"], r["mode"]): r for r in d["rows"]}, d["peak_mib"]
def vram(log):
    t = Path(log).read_text(); m = re.search(r"difference ([\d.]+) GiB", t); b = re.search(r"bdraft2 backend loaded: \+([\d.]+) GiB", t)
    return (float(m.group(1)) + (float(b.group(1)) if b else 0)) * 1024 if m else None
b60 = {}   # prompt -> (rows dict, vram MiB, ctx label)
for jf, lf, ctx in ((R9 / "A_code_xmx.json", R9 / "A_code_xmx.log", "ctx 1024"), (R9 / "C_code_xmx.json", R9 / "C_code_xmx.log", "ctx 1024"),
                    (R9 / "D_8k_xmx.json", R9 / "D_8k_xmx.log", "ctx 8960"), (R9 / "E_30k_xmx.json", R9 / "E_30k_xmx.log", "ctx 31040"),
                    (R8 / "e2e2_xmx_8k.json", R8 / "e2e2_xmx_8k.log", "ctx 8448"), (R8 / "e2e2_xmx_30k.json", R8 / "e2e2_xmx_30k.log", "ctx 30720"),
                    (R11 / "b60_60k_256.json", R11 / "b60_60k_256.log", "ctx 61440")):
    rows = J(jf)
    v = vram(lf) if Path(lf).exists() else None
    for (p, d), r in rows.items():
        b60.setdefault(p, {})[d] = r
        b60[p]["_vram"] = v; b60[p]["_ctx"] = ctx
y = {}
for n in ("short", "8k", "30k", "60k"):
    if (R11 / f"y_{n}.json").exists():
        rows, pk = Y(n)
        for (p, m), r in rows.items():
            y.setdefault(p, {})[m] = r; y[p]["_peak"] = pk
def line(p, ntok):
    b = b60.get(p); yy = y.get(p)
    if not b or not yy: return None
    best = max((k for k in b if k.startswith("bd2:")), key=lambda k: b[k]["tok_per_s"])
    a = b.get("bd2:adapt-cost", b[best]); f8 = b.get("bd2:fixed8"); f16 = b.get("bd2:fixed16")
    on = yy["on"]
    fmt = lambda r: f"{r['tok_per_s']:.1f}" if r else "-"
    return (f"| {p} | {ntok} | {fmt(f8)} | {fmt(f16)} | {fmt(a)} | **{on['tok_s']:.1f}** | {on['tok_s'] / a['tok_per_s']:.2f}x | "
            f"{a['tokens_per_pass']:.2f} / {on['tok_per_pass']:.2f} | {a['main_ms']:.1f} / {on['per_pass_ms']['verify']:.1f} | {a['draft_ms']:.1f} / {on['per_pass_ms']['draft']:.2f} | "
            f"{b['_vram'] / 1024 if b['_vram'] else float('nan'):.1f} ({b['_ctx']}) / {yy['_peak'] / 1024:.1f} |")
head = ("| prompt | new tokens | B60 fixed 8 | B60 fixed 16 | B60 adaptive | **5060 Ti** | 5060 / B60 adaptive | tok/pass B60 / 5060 | main verify ms B60 / 5060 | drafter ms B60 / 5060 | VRAM GiB B60 / 5060 |\n"
        "|---|---:|---:|---:|---:|---:|---:|---|---|---|---|")
groups = [("1. Code, 512 tokens", [("code", 512)]),
          ("1b. Code tasks, short, 768 tokens", [(p, 768) for p in ("py_merge", "py_csv", "py_lru", "rs_balanced", "rs_merge", "cpp_fib", "cpp_merge")]),
          ("2. Long context, summary prompt, 256 tokens", [("long8000", 256), ("long30000", 256), ("long60000", 256)]),
          ("2b. Code with real source in front, 768 tokens", [(p, 768) for p in ("codectx8k_py_csv", "codectx8k_rs_balanced", "codectx8k_cpp_fib", "codectx30k_py_csv", "codectx30k_rs_balanced")])]
for title, items in groups:
    print(f"\n#### {title}\n"); print(head)
    for p, n in items:
        l = line(p, n)
        if l: print(l)
print("\n#### YASAKANI reference rows (same runs): look-ahead off = plain decoding\n")
print("| prompt | on tok/s | off tok/s | prefill tok/s | rows histogram (on) |"); print("|---|---:|---:|---:|---|")
for p in ("code", "long8000", "long30000", "long60000"):
    if p in y:
        print(f"| {p} | {y[p]['on']['tok_s']:.1f} | {y[p]['off']['tok_s']:.1f} | {y[p]['on']['prefill_tok_s']:.0f} | {y[p]['on']['rows_hist']} |")
