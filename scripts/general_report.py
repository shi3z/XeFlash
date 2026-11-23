#!/usr/bin/env python3
"""Part AI report: per task and strategy, effective tok/s decomposed into tokens per pass and ms per pass (tok/s = 1000 * tokens per pass / cycle ms).
usage: general_report.py <result dir> [more dirs ...]   (medians over the repeats found)"""
import json, glob, re, sys, collections, statistics as s
rows = collections.defaultdict(list); greedy = collections.defaultdict(list); order = []
for R in sys.argv[1:]:
    for f in sorted(glob.glob(R + '/*_r*.json')):
        for r in json.load(open(f)):
            k = (r['prompt'], r['drafter']); rows[k].append(r)
            if r['prompt'] not in order: order.append(r['prompt'])
    for f in sorted(glob.glob(R + '/*_r*.log')):
        for l in open(f):
            m = re.match(r'(\S+)\s+none\s+([\d.]+) tok/s \| [\d.]+ tok/pass \| main\s+([\d.]+) ms/pass', l)
            if m: greedy[m.group(1)].append((float(m.group(2)), float(m.group(3))))
print('task | strategy | tok/s | tok/pass | accepted drafts/pass | accept1 | cycle ms | Main ms | draft ms | other ms | copy passes % | prefill tok/s | exact')
for p in order:
    g = greedy.get(p)
    if g: print('%-15s %-18s %6.1f %6.2f %6s %6s %7.2f %7.2f %7s %7s %6s %8s' % (p, 'greedy', s.median(x[0] for x in g), 1.0, '-', '-', 1000 / s.median(x[0] for x in g), s.median(x[1] for x in g), '-', '-', '-', ''))
    for (pp, d), v in rows.items():
        if pp != p: continue
        t = lambda k: s.median(x[k] for x in v)
        cyc = t('cycle_ms'); main = t('main_ms'); dr = t('draft_ms')
        print('%-15s %-18s %6.1f %6.2f %6.2f %6.3f %7.2f %7.2f %7.2f %7.2f %6.1f %8.0f %s' % (p, d, t('tok_per_s'), t('tokens_per_pass'), t('tokens_per_pass') - 1, t('accept1'), cyc, main, dr, cyc - main - dr, 100 * t('copy_passes') / t('passes'), t('prefill_tok_s'), all(x['same_tokens'] and x['same_state'] for x in v)))
