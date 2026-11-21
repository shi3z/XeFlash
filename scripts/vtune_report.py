#!/usr/bin/env python3
"""Build benchmarks/results/m37/vtune_report.html (self-contained, SVG + vanilla JS) from the VTune tables of benchmarks/results/m37 and the unit / profile logs."""
import json, re, sys
R = "benchmarks/results/m37"
# --- VTune a16 table
rows = []
for ln in open(f"{R}/vtune_a16_table.md").read().strip().splitlines()[1:]:
    c = ln.split("|")
    rows.append(dict(shape=c[0], m=int(c[1]), us=float(c[4]), xmx=float(c[11]), sbid=float(c[14]), send=float(c[15]), occ=float(c[10]), act=float(c[7]), stall=float(c[8]), idle=float(c[9]), dram=float(c[19]), l3=float(c[18])))
# --- unit table (TOPS, time)
J = json.load(open(f"{R}/unit_128.json"))
def best(mat, tok):
    c = [r for r in J if r["matrix"] == mat and r["tokens"] == tok and r["a16"] and r["format"] == "s4"]
    return min(c, key=lambda r: r["ms"])
cnt = {"merged.qkvz": 48, "merged.attn_qkv": 16, "out_proj": 64, "merged.gate_up": 64, "mlp.down": 64, "lm_head": 1}
W = sum(n * best(m, 16)["rows"] * best(m, 16)["cols"] for m, n in cnt.items())
PEAK = 196.5
tops = {m: {t: best(m, t)["tops"] for t in (16, 64, 128)} for m in cnt}
gemm = {t: sum(n * best(m, t)["ms"] for m, n in cnt.items()) for t in (16, 64, 128)}
# 32 rows: from Part Z final table (m28)
J2 = json.load(open("benchmarks/results/m28/unit_final2.json"))
gemm[32] = sum(n * min([r for r in J2 if r["matrix"] == m and r["tokens"] == 32 and r["a16"] and r["format"] == "s4"], key=lambda r: r["ms"])["ms"] for m, n in cnt.items())
floor = {t: 2 * W * t * 2 / (PEAK * 1e12) * 1e3 for t in (16, 32, 64, 128)}
# --- stage profile (3K, xmx)
stages = {}
for ln in open(f"{R}/detail_3k.log"):
    m = re.match(r"profile \(\s*(\d+) tokens/pass.*?\): norm ([\d.]+) quant ([\d.]+) gemm ([\d.]+) gdn ([\d.]+) attn ([\d.]+) mlp ([\d.]+) head ([\d.]+)", ln)
    if m and int(m.group(1)) in (1, 8, 16, 32, 48, 64) and int(m.group(1)) not in stages:
        stages[int(m.group(1))] = dict(norm=float(m.group(2)), quant=float(m.group(3)), gemm=float(m.group(4)), gdn=float(m.group(5)), attn=float(m.group(6)), mlp=float(m.group(7)), head=float(m.group(8)))
data = dict(vt=rows, tops=tops, peak=PEAK, gemm=gemm, floor=floor, stages={k: stages[k] for k in (16, 32, 64)},
            cycle=dict(cur64=92.3, need64=59.5, est128=164.0, need128=89.2, tpp64=59.48, tpp128=89.2))
tpl = open("scripts/vtune_report.tpl.html").read()
html = tpl.replace("/*DATA*/null", json.dumps(data))
open(f"{R}/vtune_report.html", "w").write(html)
print("wrote", f"{R}/vtune_report.html", len(html), "bytes", {k: round(v, 1) for k, v in gemm.items()}, {k: round(v, 1) for k, v in floor.items()})
