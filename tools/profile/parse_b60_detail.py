#!/usr/bin/env python3
"""Per-pass tables from an XF_PROF_DETAIL log of `xf-run gen ... --profile` (6 profiled passes per row count)."""
import re
import sys
from collections import defaultdict

REPS = 6
GEMM_NAME = {"5120x17408": "down (5120x17408)", "34816x5120": "gate+up (34816x5120)", "16384x5120": "GDN in-proj qkv+z (16384x5120)",
             "5120x6144": "out-proj GDN+attn (5120x6144)", "14336x5120": "attn qkv (14336x5120)", "248320x5120": "lm_head (248320x5120)"}
def parse(path):
    d = defaultdict(dict)            # m -> tag -> (calls, total ms)
    unprof, stage = {}, {}
    ms = []
    for l in open(path, errors="ignore"):
        m = re.match(r"profile \(\s*(\d+) tokens/pass.*?: (.*)\| total ([\d.]+)", l)
        if m:
            ms.append(int(m[1])); stage[int(m[1])] = float(m[3])
        m = re.match(r"\s+unprofiled: ([\d.]+) ms/pass", l)
        if m and len(ms) > len(unprof):
            unprof[ms[len(unprof)]] = float(m[1])
        m = re.match(r"\[prof-detail\] m=(\d+) (.+?)\s+(\d+)\s+([\d.]+)\s+[\d.]+\s+[-\d.]+\s+[\d.]+\s*$", l)
        if m:
            d[int(m[1])][m[2].strip()] = (int(m[3]), float(m[4]))
    return d, unprof, stage
def per_pass(d, m, key): return d[m][key][1] / REPS if key in d[m] else 0.0
def table(path, title):
    d, unprof, stage = parse(path)
    ms = [m for m in (1, 8, 16) if m in d]
    out = [f"\n#### {title}\n", "| part | " + " | ".join(f"m={m} (ms/pass)" for m in ms) + " | calls/pass | m=8 share |", "|---|" + "---:|" * len(ms) + "---:|---:|"]
    groups = defaultdict(lambda: defaultdict(float)); calls = {}
    ref_calls = {k: c // REPS for k, (c, t) in d[8].items()} if 8 in d else {}
    for m in ms:
        for k, (c, t) in d[m].items():
            if k.startswith("gemm"):
                shape = re.search(r"(\d+x\d+)", k)[1]
                name = "GEMM " + (GEMM_NAME.get(shape, shape)) + (" [head]" if "(head)" in k else "")
            elif k.startswith("gdn:"): name = "GDN " + k[4:]
            elif k.startswith("attn:"): name = "attention " + k[5:]
            else: name = k
            # m=1 passes also contain other single-row passes (MTP/draft chains): use the time per call times the calls of a real pass
            groups[name][m] += (t / c) * ref_calls.get(k, c // REPS) if m == 1 else t / REPS
            calls[name] = ref_calls.get(k, c // REPS)
    tot = {m: sum(g[m] for g in groups.values()) for m in ms}
    ref = 8 if 8 in ms else ms[0]
    for name, g in sorted(groups.items(), key=lambda kv: -kv[1][ref]):
        out.append(f"| {name} | " + " | ".join(f"{g[m]:.2f}" for m in ms) + f" | {calls[name]} | {100 * g[ref] / tot[ref]:.1f}% |")
    out.append("| **sum of synchronised kernels** | " + " | ".join(f"**{tot[m]:.2f}**" for m in ms) + " | | |")
    out.append("| **real pass time (no per-kernel sync)** | " + " | ".join(f"**{unprof.get(m, float('nan')):.2f}**" for m in ms) + " | | |")
    gem = {m: sum(g[m] for n, g in groups.items() if n.startswith("GEMM")) for m in ms}
    out.append("| GEMM total | " + " | ".join(f"{gem[m]:.2f}" for m in ms) + " | | |")
    # effective weight bandwidth per shape (GB/s) and time growth with rows
    out.append("\n| GEMM shape | weights MB (4-bit) | us/call m=1 | m=8 | m=16 | GB/s m=1 | m=8 | m=16 |\n|---|---:|---:|---:|---:|---:|---:|---:|")
    shapes = sorted({re.search(r"(\d+)x(\d+)", k)[0] for m in ms for k in d[m] if k.startswith("gemm")}, key=lambda s: -int(s.split("x")[0]) * int(s.split("x")[1]))
    for sh in shapes:
        r, c = map(int, sh.split("x")); mb = r * c / 2 / 1e6
        cells, bw = [], []
        for m in (1, 8, 16):
            key = next((k for k in d.get(m, {}) if k.startswith("gemm") and sh in k.replace(" ", "")), None)
            key = next((k for k in d.get(m, {}) if k.startswith("gemm") and re.search(rf"\b{r}x\s*{c}\b", k)), None) if key is None else key
            if key:
                n, t = d[m][key]; us = t * 1e3 / n; cells.append(f"{us:.0f}"); bw.append(f"{mb / us * 1e3:.0f}")
            else: cells.append("-"); bw.append("-")
        out.append(f"| {sh} | {mb:.1f} | " + " | ".join(cells) + " | " + " | ".join(bw) + " |")
    return "\n".join(out)
if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(table(p, p.split("/")[-1].replace("b60_prof_", "").replace(".log", "")))
