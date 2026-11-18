#!/usr/bin/env python3
"""Markdown tables from the cmp json files of scripts/code_suite.sh.   summarize.py <results_dir> <name> [<name> ...]"""
import json
import sys
from pathlib import Path

R = Path(sys.argv[1])
LAB = {"bd2:fixed8": "fixed 8", "bd2:fixed16": "fixed 16", "bd2:adapt-old": "adaptive (old rule)", "bd2:adapt-cost": "adaptive (measured cost)"}
for name in sys.argv[2:]:
    f = R / f"{name}.json"
    if not f.exists():
        continue
    rows = json.load(open(f))
    print(f"\n### {name}\n")
    print("| prompt | config | tok/s | tok/pass | 1st-draft accept | 16-row passes | main ms | draft ms | new tokens | exact |")
    print("|---|---|---:|---:|---:|---:|---:|---:|---:|---|")
    for r in rows:
        p16 = f"{r['passes16']}/{r['passes']} ({100 * r['passes16'] / r['passes']:.0f}%)"
        ok = "tokens+state" if r["same_tokens"] and r["same_state"] else ("tokens" if r["same_tokens"] else "DIFFER")
        print(f"| {r['prompt']} | {LAB.get(r['drafter'], r['drafter'])} | {r['tok_per_s']:.1f} | {r['tokens_per_pass']:.2f} | {100 * r['accept1']:.0f}% | {p16} | "
              f"{r['main_ms']:.1f} | {r['draft_ms']:.1f} | {r['new_tokens']} | {ok} |")
