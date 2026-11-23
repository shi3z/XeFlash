#!/usr/bin/env python3
"""TIMING-ONLY prototype (wrong results): role-swapped K loop (weights src2 M=8 rows s4, activations src1 N=16 tokens)
   with a settable weight prefetch distance DW (1..3, 4 weight sets of 8 GRF) and 1-tile-ahead activations (2 sets).
   usage: gen_swap_proto2.py <orig.asm> <out.asm> --dw N"""
import re, sys
src, dst = sys.argv[1], sys.argv[2]
DW = int(sys.argv[sys.argv.index('--dw') + 1])
L = open(src).read().split('\n')
WS = [21, 29, 37, 45]                                  # weight sets, 8 GRF
AS = [dict(B=53, U=61), dict(B=69, U=77)]               # activation sets, 8 GRF per plane
ACB = [162, 154, 146, 138]; ACU = [194, 186, 178, 170]
TW = [[2, 3], [4, 5], [6, 7], [8, 9]]
TA = [dict(B=[10, 11], U=[12, 13]), dict(B=[14, 15], U=[16, 17])]
RB = [18, 20]; RU = [19, 21]
WP = 206; BP = [207, 208, 209, 210]; UP = [211, 212, 213, 214]; P4, P, CNT, TMP = 215, 216, 217, 218
out = []
def e(s): out.append('        ' + s)
def load(d, ptr, off, tok):
    out.append('        send.ugm (1|M0)          r%d      r%d  null:0  0x%X            0x0240F580           {I@1,$%d}' % (d, ptr, off << 12 if off else 0, tok))
def dpas(acc, a, w, ty, fl):
    e('dpas.8x8 (16|M0)         r%d:d        r%d:d            r%d:%s            r%d.0:s4         {%s}' % (acc, acc, a, ty, w, fl))
def wload(u, last):               # weights of tile u = base tile (4q) + off
    pass
def half(j, steady, last):
    jc = j % 2; ja = (j + 1) % 2
    wl = steady or (last and j + DW <= 3)
    al = steady or (j <= 2)
    e('sync.allrd                           ($%d,$%d)' % (RB[(j - 1) % 2], RU[(j - 1) % 2]))
    if wl:
        s = (j + DW) % 4; o = j + DW
        for h in range(2): load(WS[s] + 4 * h, WP, 0x100 * (o + ((-h if last else h))), TW[s][h])
    if al:
        for h in range(2): load(AS[ja]['B'] + 4 * h, BP[j], 0x100 * h, TA[ja]['B'][h])
        for h in range(2): load(AS[ja]['U'] + 4 * h, UP[j], 0x100 * h, TA[ja]['U'][h])
    e('sync.allwr                           (%s)' % ','.join('$%d' % t for t in TW[j] + TA[jc]['B']))
    for rg in range(4): dpas(ACB[rg], AS[jc]['B'], WS[j] + 2 * rg, 'b', 'Atomic' if rg < 3 else '$%d' % RB[jc])
    e('sync.allwr                           (%s)' % ','.join('$%d' % t for t in TA[jc]['U']))
    for rg in range(4): dpas(ACU[rg], AS[jc]['U'], WS[j] + 2 * rg, 'ub', 'Atomic' if rg < 3 else '$%d' % RU[jc])
    if steady:
        toks = []
        if wl: toks += TW[(j + DW) % 4]
        if al: toks += TA[ja]['B'] + TA[ja]['U']
        e('sync.allrd                           (%s)' % ','.join('$%d' % t for t in toks))
        e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (BP[j], BP[j], P4))
        e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (UP[j], UP[j], P4))
        if j == 3: e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    0x400:uw   {I@1}' % (WP, WP))
e('and (1|M0)               r%d.0<1>:ud   r4.10<0;1,0>:ud   3:ud' % TMP)
e('cmp (1|M0)    (ne)f1.0   null<1>:ud    r%d.0<0;1,0>:ud   0:ud  {I@1}' % TMP)
e('(W&f1.0) jmpi                                L1728')
e('mov (1|M0)               r%d.0<1>:q    r18.0<0;1,0>:q' % WP)
e('add (1|M0)               r%d.0<1>:q    r19.0<0;1,0>:q    -r9.0<0;1,0>:q' % P)
e('shl (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    2:w   {I@1}' % (P4, P))
e('mov (1|M0)               r%d.0<1>:q    r19.0<0;1,0>:q' % BP[0])
e('mov (1|M0)               r%d.0<1>:q    r20.0<0;1,0>:q' % UP[0])
for j in range(1, 4):
    e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (BP[j], BP[j - 1], P))
    e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (UP[j], UP[j - 1], P))
for t in range(0, DW):            # weights of tiles 0..DW-1 (own loads; the compiler's prologue data lands unused in r85..r136)
    for h in range(2): load(WS[t] + 4 * h, WP, 0x100 * (t + h), TW[t][h])
for h in range(2): load(AS[0]['B'] + 4 * h, 9, 0x100 * h, TA[0]['B'][h])
for h in range(2): load(AS[0]['U'] + 4 * h, 10, 0x100 * h, TA[0]['U'][h])
for r in range(138, 202, 2): e('mov (32|M0)              r%d.0<1>:d   0:w' % r)
e('shr (1|M0)               r%d.0<1>:ud   r4.10<0;1,0>:ud   2:w' % CNT)
e('add (1|M0)               r%d.0<1>:d    r%d.0<0;1,0>:d    -1:w   {I@1}' % (CNT, CNT))
e('cmp (1|M0)    (le)f0.1   null<1>:d     r%d.0<0;1,0>:d    0:w   {I@1}' % CNT)
e('(W&f0.1) jmpi                                LN_final')
out.append('LN_loop:')
for j in range(4): half(j, True, False)
e('add (1|M0)               r%d.0<1>:d    r%d.0<0;1,0>:d    -1:w' % (CNT, CNT))
e('cmp (1|M0)    (gt)f0.1   null<1>:d     r%d.0<0;1,0>:d    0:w   {I@1}' % CNT)
e('(W&f0.1) jmpi                                LN_loop')
out.append('LN_final:')
for j in range(4): half(j, False, True)
e('sync.allrd                           null')
e('sync.allwr                           null')
e('(W)     jmpi                                 L3616')
i = next(k for k, l in enumerate(L) if re.match(r'\(W&f1\.0\) jmpi\s+L3360', l))
open(dst, 'w').write('\n'.join(L[:i + 1] + out + L[i + 1:]))
