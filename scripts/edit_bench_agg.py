#!/usr/bin/env python3
"""Aggregate benchmarks/results/m23: speed (5 repeats), accept, Main/Draft ms, exactness vs the official expected answers."""
import json, glob, re, statistics as S, sys, hashlib
from transformers import AutoTokenizer
R = sys.argv[1] if len(sys.argv) > 1 else "benchmarks/results/m23"
tk = AutoTokenizer.from_pretrained("/data/B60special/models/Qwen3.8-27B")
tasks = {t["name"]: t for t in json.load(open("benchmarks/edit/edit_tasks.json"))["tasks"]}
IM_END = tk.convert_tokens_to_ids("<|im_end|>")
def answer(text):  # as YASAKANI editbench.answer_of
    g = text.strip()
    if g.startswith("```"):
        g = g.split("\n", 1)[1] if "\n" in g else g
        g = g.rsplit("```", 1)[0] if g.rstrip().endswith("```") else g
    return g.strip()
def decode(path):
    ids = json.load(open(path))
    if IM_END in ids: ids = ids[:ids.index(IM_END)]; ended = True
    else: ended = False
    return tk.decode(ids), ended
out = {}
lines = ["task|config|tok/s mean (min-max)|tokens/pass|accept1|Main ms/pass|Draft ms/pass|answer = expected|same tokens+state as greedy"]
for name in tasks:
    exp = tasks[name]["expected"].strip()
    cfg = {}
    g_tps, g_main, g_ok = [], [], []
    for f in sorted(glob.glob(f"{R}/{name}_r*.json")):
        rep = f.split("_r")[-1][:-5]
        rows = json.load(open(f))
        log = open(f[:-5] + ".log").read()
        m = re.search(r"none\s+([\d.]+) tok/s \| [\d.]+ tok/pass \| main\s+([\d.]+) ms/pass", log)
        if m: g_tps.append(float(m.group(1))); g_main.append(float(m.group(2)))
        txt, ended = decode(f"{R}/tok_{name}_r{rep}/edit_{name}__greedy.json"); g_ok.append(answer(txt) == exp and ended)
        for r in rows:
            c = cfg.setdefault(r["drafter"], dict(tps=[], tpp=[], acc=[], main=[], draft=[], same=[], ok=[], passes=[]))
            c["tps"].append(r["tok_per_s"]); c["tpp"].append(r["tokens_per_pass"]); c["acc"].append(r["accept1"])
            c["main"].append(r["main_ms"]); c["draft"].append(r["draft_ms"]); c["same"].append(r["same_tokens"] and r["same_state"])
            lab = r["drafter"].replace(":", "_")
            t2, e2 = decode(f"{R}/tok_{name}_r{rep}/edit_{name}__{lab}.json"); c["ok"].append(answer(t2) == exp and e2)
    if g_tps:
        lines.append(f"{name}|greedy|{S.mean(g_tps):.1f} ({min(g_tps):.1f}-{max(g_tps):.1f})|1.00|-|{S.mean(g_main):.2f}|-|{sum(g_ok)}/{len(g_ok)}|-")
    for d, c in cfg.items():
        m = lambda k: S.mean(c[k])
        lines.append(f"{name}|{d}|{m('tps'):.1f} ({min(c['tps']):.1f}-{max(c['tps']):.1f})|{m('tpp'):.2f}|{m('acc'):.3f}|{m('main'):.2f}|{m('draft'):.2f}|{sum(c['ok'])}/{len(c['ok'])}|{sum(c['same'])}/{len(c['same'])}")
print("\n".join(lines))
