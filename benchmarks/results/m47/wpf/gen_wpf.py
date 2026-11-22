#!/usr/bin/env python3
"""Rewrite the K loop of the 256-GRF 32-token GEMM (disassembly of submit<0,8,4,1,true,2,true>) with a deeper weight pipeline.
   usage: gen_wpf.py <orig.asm> <out.asm> [--dw N] [--noloads]    (N = weight prefetch distance in tiles, 1..3; 4 weight register sets)
   Taken only when the tile count is a multiple of 4 (else the original loop runs). Accumulators r138..r201, zero-initialised."""
import re, sys
src, dst = sys.argv[1], sys.argv[2]
DW = int(sys.argv[sys.argv.index('--dw') + 1]) if '--dw' in sys.argv else 3
L = open(src).read().split('\n')
# ---- register / token map ----
W = [133, 21, 25, 29]                         # weight sets (4 regs each)
AB = [[117, 121, 125, 129], [33, 37, 41, 45]]  # b plane (hi) per act set
AU = [[85, 101, 109, 113], [49, 53, 57, 61]]  # ub plane (lo)
ACB = [162, 154, 146, 138]; ACU = [194, 186, 178, 170]
TW = [2, 11, 12, 13]
TB = [[3, 4, 5, 6], [14, 15, 16, 17]]
TU = [[7, 8, 9, 10], [18, 19, 20, 21]]
RB = [22, 24]; RU = [23, 25]
WP, BP, UP, P4, P, CNT, TMP = 66, [67, 68, 69, 70], [71, 72, 73, 74], 75, 76, 77, 78
out = []
def e(s): out.append('        ' + s)
def lab(s): out.append(s + ':')
def load(dstreg, ptr, off, tok):
    out.append('        send.ugm (1|M0)          r%d      r%d  null:0  0x%X            0x0240F580           {I@1,$%d}' % (dstreg, ptr, off << 12 if off else 0, tok))
def dpas(acc, w, a, ty, flags):
    e('dpas.8x8 (16|M0)         r%d:d        r%d:d            r%d:s4            r%d.0:%s         {%s}' % (acc, acc, w, a, ty, flags))
def half(j, steady, last):
    """tile t = 4q+j.  steady: all loads; last: final trip (loads only where the tile exists)."""
    ja = (j + 1) % 2; jc = j % 2
    wload = steady or (j + DW <= 3 and j + DW >= 0) and last and (j + DW) <= 3
    aload = steady or (j <= 2)
    wl = (steady) or (last and j + DW <= 3)       # weight tile j+DW must exist in the last trip (index <= 3)
    e('sync.allrd                           ($%d,$%d)' % (RB[(j - 1) % 2], RU[(j - 1) % 2]))
    if wl:
        s = (j + DW) % 4
        load(W[s], WP, 0x100 * (j + DW), TW[s])
    if aload:
        for k in range(4): load(AB[ja][k], BP[j], 0x100 * k, TB[ja][k])
        for k in range(4): load(AU[ja][k], UP[j], 0x100 * k, TU[ja][k])
    e('sync.allwr                           ($%d,%s)' % (TW[j], ','.join('$%d' % t for t in TB[jc])))
    for k in range(4): dpas(ACB[k], W[j], AB[jc][k], 'b', 'Atomic' if k < 3 else '$%d' % RB[jc])
    e('sync.allwr                           (%s)' % ','.join('$%d' % t for t in TU[jc]))
    for k in range(4): dpas(ACU[k], W[j], AU[jc][k], 'ub', 'Atomic' if k < 3 else '$%d' % RU[jc])
    if steady:
        toks = []
        if aload: toks += TB[ja] + TU[ja]
        if wl: toks += [TW[(j + DW) % 4]]
        e('sync.allrd                           (%s)' % ','.join('$%d' % t for t in toks))
        e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (BP[j], BP[j], P4))
        e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (UP[j], UP[j], P4))
        if j == 3: e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    0x400:uw   {I@1}' % (WP, WP))
# ---- block ----
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
# prologue weight loads: tiles 1..DW-1 (tile 0 was loaded by the original prologue)
for t in range(1, DW):
    load(W[t], WP, 0x100 * t, TW[t])
for r in range(138, 202, 2): e('mov (32|M0)              r%d.0<1>:d   0:w' % r)
e('shr (1|M0)               r%d.0<1>:ud   r4.10<0;1,0>:ud   2:w' % CNT)
e('add (1|M0)               r%d.0<1>:d    r%d.0<0;1,0>:d    -1:w   {I@1}' % (CNT, CNT))
e('cmp (1|M0)    (le)f0.1   null<1>:d     r%d.0<0;1,0>:d    0:w   {I@1}' % CNT)
e('(W&f0.1) jmpi                                LN_final')
lab('LN_loop')
for j in range(4): half(j, True, False)
e('add (1|M0)               r%d.0<1>:d    r%d.0<0;1,0>:d    -1:w' % (CNT, CNT))
e('cmp (1|M0)    (gt)f0.1   null<1>:d     r%d.0<0;1,0>:d    0:w   {I@1}' % CNT)
e('(W&f0.1) jmpi                                LN_loop')
lab('LN_final')
for j in range(4): half(j, False, True)
e('sync.allrd                           null')
e('sync.allwr                           null')
e('(W)     jmpi                                 L3616')
blk = out
# insert after the "(W&f1.0) jmpi  L3360" line
i = next(k for k, l in enumerate(L) if re.match(r'\(W&f1\.0\) jmpi\s+L3360', l))
res = L[:i + 1] + blk + L[i + 1:]
open(dst, 'w').write('\n'.join(res))
print('inserted %d lines after line %d' % (len(blk), i + 1))
