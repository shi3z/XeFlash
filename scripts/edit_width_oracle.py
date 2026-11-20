#!/usr/bin/env python3
"""Hybrid with adaptive verify width (16 or 32 rows), oracle replay of the m23 greedy outputs (tokens/pass exact for the copy candidates,
fallback passes (no candidate >= 4 tokens) modelled as bdraft2 at FB tokens/pass). Cost per pass (ms) = Main(rows) + draft; Main(16)=48.1 measured (m26),
Main(32): "today" = a8 kernels as measured (cold unit sums) -> 46.9+13.6+6.7 = 67.2 ms (a16 at 32 rows does not exist: lower bound on cost);
"narrow fixed" = down/out_proj at +20% instead of +75-80% -> 60.0 ms; (+ non-GEMM growth from the profile: GDN 0.25 ms/row, mlp 0.09, attn 0.04, norm/quant 0.02).
Estimates; the candidate acceptance (tokens/pass) is exact."""
import json, sys
sys.argv=[sys.argv[0]]
exec(open("scripts/edit_copy_oracle2.py").read().split("for name in meta:")[0])   # run(), load()
import collections
def replay(prompt, out, K1=15, K2=31, minhit=4, wide_from=16, FB=3.5):
    seq=list(prompt); occ=collections.defaultdict(list)
    for p in range(2,len(seq)): occ[tuple(seq[p-2:p+1])].append(p)
    i=0; ptr=None; L=len(out); stats=dict(p16=0,p32=0,fb=0,tok16=0,tok32=0,tokfb=0)
    while i<L:
        src=None
        if ptr is not None and ptr<len(seq) and seq[ptr-1]==seq[-1]: src=ptr
        if src is None and len(seq)>=3:
            best,bl=None,0
            for p in occ.get(tuple(seq[-3:]),[])[-64:]:
                if p==len(seq)-1: continue
                l=0
                while l<64 and p-l>=0 and seq[p-l]==seq[-1-l]: l+=1
                if l>=bl: best,bl=p,l
            if best is not None: src=best+1
        cand=seq[src:src+K2] if src is not None else []
        acc=0
        while acc<len(cand) and i+acc<L and cand[acc]==out[i+acc]: acc+=1
        if len(cand)>=minhit:
            wide = len(cand)>=wide_from      # candidate longer than a 15-token block -> 32-row pass
            if not wide: cand=cand[:K1]; acc=min(acc,len(cand))
            take=min(acc+1,L-i); k='p32' if wide else 'p16'; stats[k]+=1; stats['tok32' if wide else 'tok16']+=take; ptr=src+take
        else:
            take=min(1,L-i); stats['fb']+=1; ptr=None   # fallback pass: counted below with FB tokens
            stats['tokfb']+=take
        for t in out[i:i+take]:
            seq.append(t)
            if len(seq)>=3: occ[tuple(seq[-3:])].append(len(seq)-1)
        i+=take
    return stats
MAIN16=48.1; D=1.8; FB_MS=48.1+7.4
for name in meta:
    prompt,o=load(name); L=len(o)
    for label,main32 in (("today(a8 cost)",67.2),("narrow fixed",60.0)):
        s=replay(prompt,o)
        # fallback passes: bdraft2 3.5 tokens/pass instead of the 1 token counted in replay -> adjust token budget
        fb_tok_equiv=s['tokfb']; fb_passes=s['fb']/3.5   # FB tokens/pass
        t=s['p16']*(MAIN16+D)+s['p32']*(main32+D)+fb_passes*FB_MS
        toks=L
        print(f"{name}|{label}|16-row copy passes {s['p16']}|32-row passes {s['p32']}|fallback passes {fb_passes:.0f}|est tok/s {toks/t*1e3:.0f}")
    s=replay(prompt,o,wide_from=10**9)   # 16 only
    t=s['p16']*(MAIN16+D)+s['fb']/3.5*FB_MS
    print(f"{name}|16-row only (model of m26)|est tok/s {L/t*1e3:.0f}")
