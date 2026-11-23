#!/usr/bin/env python3
"""Median (min..max) over the repeats per task and strategy; usage: general_median.py <dir> [<dir> ...]"""
import json, glob, sys, collections, statistics as s
d = collections.defaultdict(list); order = []
for R in sys.argv[1:]:
    for f in sorted(glob.glob(R + '/*_r*.json')):
        for r in json.load(open(f)):
            d[(r['prompt'], r['drafter'])].append(r)
            if r['prompt'] not in order: order.append(r['prompt'])
print('%-16s %-18s %5s %24s %8s %8s %8s %8s %6s %s' % ('task', 'strategy', 'n', 'tok/s median (min..max)', 'tok/pass', 'cycle', 'Main', 'draft', 'copy%', 'tokens==greedy / state==greedy'))
for p in order:
    for (pp, k), v in d.items():
        if pp != p: continue
        t = [x['tok_per_s'] for x in v]
        print('%-16s %-18s %5d %8.1f (%6.1f..%6.1f) %8.2f %8.2f %8.2f %8.2f %6.1f %s / %s' % (p, k, len(v), s.median(t), min(t), max(t), s.median(x['tokens_per_pass'] for x in v), s.median(x['cycle_ms'] for x in v), s.median(x['main_ms'] for x in v), s.median(x['draft_ms'] for x in v), 100 * s.median(x['copy_passes'] / x['passes'] for x in v), all(x['same_tokens'] for x in v), all(x['same_state'] for x in v)))
