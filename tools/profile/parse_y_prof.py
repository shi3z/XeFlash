#!/usr/bin/env python3
"""Per-pass kernel table of a YSKN_PROF=1 YASAKANI log (blocking timing of every launch).
   parse_y_prof.py <log> <run.json> <libyskn.so> [rows=8]   (per pass = total / number of passes with that many rows)"""
import bisect
import collections
import json
import re
import subprocess
import sys

log, js, lib = sys.argv[1:4]
want = int(sys.argv[4]) if len(sys.argv) > 4 else 8
syms = []
for l in subprocess.run(["nm", "-C", "--defined-only", lib], capture_output=True, text=True).stdout.splitlines():
    p = l.split(" ", 2)
    if len(p) == 3 and p[1] in "tTwW":
        syms.append((int(p[0], 16), p[2]))
syms.sort()
addrs = [a for a, _ in syms]
def name(off):
    i = bisect.bisect_right(addrs, off) - 1
    s = syms[i][1] if i >= 0 else "?"
    return re.sub(r"\(.*$", "", re.sub(r"^void yskn::", "", s))
CAT = [("GEMM (lnord)", r"^lnord_kernel"), ("attention (KV read)", r"atxpk4|q35_combine|wk_attn_post"), ("GDN", r"wk_state|wk_conv|gdn_out|q35_mix"),
       ("norm / residual", r"res_norm"), ("MLP activation", r"q35_mlp"), ("head argmax", r"argmax"), ("drafter / sampler", r"bdr_|topk8|set_int")]
rows = collections.defaultdict(list)
for l in open(log, errors="ignore"):
    m = re.match(r"\[prof\] rows=(\d+) ms=([\d.]+) n=(\d+) (\S+)", l)
    if m:
        rows[int(m[1])].append((float(m[2]), int(m[3]), name(int(m[4], 16))))
hist = json.load(open(js))["rows"][0]["rows_hist"]
passes = hist.get(str(want), 0)
tot = sum(x[0] for x in rows[want])
print(f"rows={want}: {passes} passes, {tot / passes:.2f} ms per pass (sum of blocking kernel times, drafter kernels included)")
cats = collections.defaultdict(float); ncall = collections.defaultdict(int)
for ms, n, nm in rows[want]:
    c = next((k for k, pat in CAT if re.search(pat, nm)), "other")
    cats[c] += ms / passes; ncall[c] += n / passes
for c, v in sorted(cats.items(), key=lambda kv: -kv[1]):
    print(f"  {c:22s} {v:7.2f} ms/pass  {ncall[c]:7.0f} launches/pass")
print("  top kernels:")
for ms, n, nm in sorted(rows[want], reverse=True)[:8]:
    print(f"    {ms / passes:6.2f} ms/pass  {n / passes:6.1f} calls/pass  {ms / n * 1e3:7.1f} us/call  {nm[:70]}")
