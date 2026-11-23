#!/usr/bin/env python3
import json,glob,sys,collections,statistics as s
R=sys.argv[1]
d=collections.defaultdict(list)
for f in sorted(glob.glob(R+'/r*.json')):
    for r in json.load(open(f)): d[(r['prompt'],r['drafter'])].append(r)
prompts=sorted({k[0] for k in d}); dr=sorted({k[1] for k in d})
print('prompt | config | tok/s median (min..max) | tok/pass | accept1 | same tokens+state as greedy | n')
for p in prompts:
    for c in dr:
        v=d.get((p,c));
        if not v: continue
        t=[x['tok_per_s'] for x in v]
        print('%-18s %-18s %7.1f (%.1f..%.1f) %6.2f %5.3f %s n=%d'%(p,c,s.median(t),min(t),max(t),s.median(x['tokens_per_pass'] for x in v),s.median(x['accept1'] for x in v),all(x['same_tokens'] and x['same_state'] for x in v),len(v)))
