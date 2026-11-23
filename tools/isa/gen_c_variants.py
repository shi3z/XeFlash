#!/usr/bin/env python3
"""Experiment C: variants of the unedited 256-GRF 32-token GEMM loop (disassembly) with the same thread count / GRF count /
weight access pattern, changing only how much work is attached to the weight stream (results wrong on purpose).
  name -> (keep activation loads, DPAS groups kept of the 4 per trip: [h1 b, h1 ub, h2 b, h2 ub])
usage: gen_c_variants.py <orig.asm> <outdir>"""
import re, sys, os
L = open(sys.argv[1]).read().split('\n'); od = sys.argv[2]; os.makedirs(od, exist_ok=True)
s = next(i for i, l in enumerate(L) if l.startswith('L2536:')); e = next(i for i, l in enumerate(L) if l.startswith('L3344:'))
WREG = {53, 133}
def ld(l): return 'send.ugm' in l and '0x0240F580' in l
def isw(l):
    m = re.search(r'send\.ugm \(1\|M0\)\s+r(\d+)\s', l); return bool(m) and int(m.group(1)) in WREG
# DPAS groups
groups = []; cur = []
for i in range(s, e):
    if 'dpas.8x8' in L[i]:
        cur.append(i)
        if len(cur) == 4: groups.append(cur); cur = []
assert len(groups) == 4, len(groups)
VAR = {
 'v_w_only':      (False, [0, 0, 0, 0]),   # weights only, no DPAS, no activation loads
 'v_w_act':       (True,  [0, 0, 0, 0]),   # weights + activation loads, no DPAS
 'v_w_d1':        (False, [1, 0, 0, 0]),   # weights only + 25% of the DPAS
 'v_w_d2':        (False, [1, 1, 0, 0]),   # 50%
 'v_w_d3':        (False, [1, 1, 1, 0]),   # 75%
 'v_w_d4':        (False, [1, 1, 1, 1]),   # 100% DPAS, no activation loads
 'v_all_d1':      (True,  [1, 0, 0, 0]),
 'v_all_d2':      (True,  [1, 1, 0, 0]),
 'v_all_d3':      (True,  [1, 1, 1, 0]),
}
for name, (act, keep) in VAR.items():
    drop = set(); repl = {}
    for g, k in zip(groups, keep):
        if not k:
            for i in g:
                drop.add(i)
                m = re.search(r'\$(\d+)\.dst', L[i])
                if m: repl[i] = '        sync.allwr                           ($%s)' % m.group(1)   # keep the wait for the loads
    M = []
    for i, l in enumerate(L):
        if s <= i < e:
            if ld(l) and not isw(l) and not act: continue
            if i in drop:
                if i in repl: M.append(repl[i])
                continue
        M.append(l)
    open('%s/%s.asm' % (od, name), 'w').write('\n'.join(M))
print('ok', list(VAR))
