#!/usr/bin/env python3
"""TIMING-ONLY prototype (results wrong): one thread = 16 rows x 64 tokens (the odd token-group thread exits at once), K loop of the 256-GRF kernel
   rewritten: 128 accumulator GRFs (r106..r233), weights 1 send / tile (2 sets), activation planes staged one plane (8 sends, 32 GRF) at a time in 2 buffers.
   usage: gen_b64_proto.py <orig.asm> <out.asm>"""
import re, sys
src, dst = sys.argv[1], sys.argv[2]
L = open(src).read().split('\n')
W = [21, 25]; X = [29, 61]                     # weight sets (4 GRF), plane buffers (32 GRF)
ACB = [106 + 8 * g for g in range(8)]; ACU = [170 + 8 * g for g in range(8)]
TW = [11, 12]; TX = [list(range(13, 21)), list(range(21, 29))]; R = [29, 30]
WP, BP, UP, P, CNT, TMP = 94, 95, 96, 97, 98, 99
out = []
def e(s): out.append('        ' + s)
def load(d, ptr, off, tok):
    out.append('        send.ugm (1|M0)          r%d      r%d  null:0  0x%X            0x0240F580           {I@1,$%d}' % (d, ptr, off << 12 if off else 0, tok))
def stage_loads(buf, ptr, tok): 
    for g in range(8): load(X[buf] + 4 * g, ptr, 0x100 * g, TX[buf][g])
def dpas(acc, w, a, ty, fl):
    e('dpas.8x8 (16|M0)         r%d:d        r%d:d            r%d:s4            r%d.0:%s         {%s}' % (acc, acc, w, a, ty, fl))
def tile(j, loads_next):
    """tile parity j: weights W[j]; plane b in X[0], plane ub in X[1]. At entry the b plane of this tile is loaded (X[0]); ub plane of this tile is loaded here."""
    e('sync.allrd                           ($%d,$%d)' % (R[0], R[1]))
    load_ub = True
    # ub plane of this tile into X[1]
    stage_loads(1, UP, None) if False else None
    for g in range(8): load(X[1] + 4 * g, UP, 0x100 * g, TX[1][g])
    if loads_next: load(W[1 - j], WP, 0x100, TW[1 - j])
    e('sync.allwr                           ($%d,%s)' % (TW[j], ','.join('$%d' % t for t in TX[0])))
    for g in range(8): dpas(ACB[g], W[j], X[0] + 4 * g, 'b', 'Atomic' if g < 7 else '$%d' % R[0])
    e('sync.allrd                           ($%d)' % R[0])
    e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (UP, UP, P))
    if loads_next:
        for g in range(8): load(X[0] + 4 * g, BP, 0x100 * g, TX[0][g])        # b plane of the next tile
        e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (BP, BP, P))
    e('sync.allwr                           (%s)' % ','.join('$%d' % t for t in TX[1]))
    for g in range(8): dpas(ACU[g], W[j], X[1] + 4 * g, 'ub', 'Atomic' if g < 7 else '$%d' % R[1])
    if loads_next:
        e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    0x100:uw   {I@1}' % (WP, WP))
# dispatch
e('and (1|M0)               r%d.0<1>:ud   r4.10<0;1,0>:ud   1:ud' % TMP)
e('cmp (1|M0)    (ne)f1.0   null<1>:ud    r%d.0<0;1,0>:ud   0:ud  {I@1}' % TMP)
e('(W&f1.0) jmpi                                L1728')
e('and (1|M0)               r%d.0<1>:ud   r18.10<0;1,0>:ud   0xFFFFFFFF:ud' % TMP)
e('cmp (1|M0)    (ne)f1.0   null<1>:ud    r%d.0<0;1,0>:ud   0:ud  {I@1}' % TMP)
e('(W&f1.0) jmpi                                L3616')
e('sync.allwr                           ($2,$3,$4,$5,$6,$7,$8,$9,$10)')          # the compiler prologue loads land in r85..r136
e('mov (1|M0)               r%d.0<1>:q    r18.0<0;1,0>:q' % WP)
e('add (1|M0)               r%d.0<1>:q    r19.0<0;1,0>:q    -r9.0<0;1,0>:q' % P)
e('mov (1|M0)               r%d.0<1>:q    r9.0<0;1,0>:q' % BP)
e('mov (1|M0)               r%d.0<1>:q    r10.0<0;1,0>:q' % UP)
for r in range(106, 234, 2): e('mov (32|M0)              r%d.0<1>:d   0:w' % r)
# tile 0 loads: weights W0, b plane
load(W[0], WP, 0, TW[0])
for g in range(8): load(X[0] + 4 * g, BP, 0x100 * g, TX[0][g])
e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (BP, BP, P))
e('shr (1|M0)               r%d.0<1>:ud   r4.10<0;1,0>:ud   1:w' % CNT)
e('add (1|M0)               r%d.0<1>:d    r%d.0<0;1,0>:d    -1:w   {I@1}' % (CNT, CNT))
e('cmp (1|M0)    (le)f0.1   null<1>:d     r%d.0<0;1,0>:d    0:w   {I@1}' % CNT)
e('(W&f0.1) jmpi                                LN_final')
out.append('LN_loop:')
tile(0, True); tile(1, True)
e('add (1|M0)               r%d.0<1>:d    r%d.0<0;1,0>:d    -1:w' % (CNT, CNT))
e('cmp (1|M0)    (gt)f0.1   null<1>:d     r%d.0<0;1,0>:d    0:w   {I@1}' % CNT)
e('(W&f0.1) jmpi                                LN_loop')
out.append('LN_final:')
tile(0, True); tile(1, False)
e('sync.allrd                           null')
e('sync.allwr                           null')
e('(W)     jmpi                                 L3616')
i = next(k for k, l in enumerate(L) if re.match(r'\(W&f1\.0\) jmpi\s+L3360', l))
open(dst, 'w').write('\n'.join(L[:i + 1] + out + L[i + 1:]))
