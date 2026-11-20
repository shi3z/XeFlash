#!/usr/bin/env python3
"""Width policy 16 / 32 / 64 rows for the copy+bdraft2 hybrid, oracle replay of the m23 greedy outputs (copy-candidate acceptance exact).
Pass cost (ms): Main(16)=48.1 (m26 measured); Main(32) = 48.1 + dGEMM(16->32 rows, a16, m28 final unit table: +7.0) + dnonGEMM (profile slopes, +6.7);
Main(64) = 48.1 + 22.3 + 20.0 (non-GEMM extrapolated linearly: GDN 0.25 ms/row, mlp 0.09, attn 0.04-0.15, norm+quant 0.04) -- ESTIMATES (the engine is limited to 16 rows)."""
import sys, collections, json
sys.argv=[sys.argv[0]]
exec(open("scripts/edit_copy_oracle2.py").read().split("for name in meta:")[0])
D=1.8; FB_MS=48.1+7.4; FB=3.5
COST={16:48.1+D, 32:61.8+D, 64:90.4+D}
def replay(prompt,out,widths):
    seq=list(prompt); occ=collections.defaultdict(list)
    for p in range(2,len(seq)): occ[tuple(seq[p-2:p+1])].append(p)
    i=0; ptr=None; L=len(out); t=0.0; n={16:0,32:0,64:0,'fb':0}; Kmax=max(widths)-1
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
        cand=seq[src:src+Kmax] if src is not None else []
        if len(cand)>=4:
            w=16
            for ww in sorted(widths):
                if len(cand)>=ww-1 and ww>16: w=ww      # candidate fills (or exceeds) the 15-token block: use the wider pass
            cand=cand[:w-1]
            acc=0
            while acc<len(cand) and i+acc<L and cand[acc]==out[i+acc]: acc+=1
            take=min(acc+1,L-i); t+=COST[w]; n[w]+=1; ptr=src+take
        else:
            take=min(1,L-i); t+=FB_MS/FB; n['fb']+=1; ptr=None
        for tk in out[i:i+take]:
            seq.append(tk)
            if len(seq)>=3: occ[tuple(seq[-3:])].append(len(seq)-1)
        i+=take
    return L/t*1e3, n
for name in meta:
    prompt,o=load(name)
    for widths in ((16,),(16,32),(16,32,64)):
        v,n=replay(prompt,o,widths)
        print(f"{name}|widths {widths}|est tok/s {v:.0f}|passes {n}")
