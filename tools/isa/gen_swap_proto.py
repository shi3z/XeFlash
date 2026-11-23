#!/usr/bin/env python3
"""TIMING-ONLY prototype (results are wrong on purpose) of the operand-role-swapped K loop:
   weights = src2 (M = 8 rows, s4, 2 GRF per row group), activations = src1 (N = 16 tokens, 8 GRF per plane).
   One thread = 32 rows x 16 tokens (same 64 accumulator GRFs, same thread count as the 16 rows x 32 tokens loop).
   Per tile: weights 512 B (2 sends), act planes 2 x 512 B (4 sends) = 6 sends, 1536 B, 8 DPAS (vs 9 sends, 2304 B).
   usage: gen_swap_proto.py <orig.asm> <out.asm>"""
import re, sys
src, dst = sys.argv[1], sys.argv[2]
DIST = '--dup' not in sys.argv
L = open(src).read().split('\n')
S = [dict(W=21, AB=29, AU=37), dict(W=45, AB=53, AU=61)]       # per set: W 8 regs, AB 8, AU 8
ACB = [162, 154, 146, 138]; ACU = [194, 186, 178, 170]
TOK = [dict(W=[2, 3], AB=[4, 5], AU=[6, 7]), dict(W=[8, 9], AB=[10, 11], AU=[12, 13])]
RB = [14, 16]; RU = [15, 17]
WP, BP, UP, P2, P, CNT, TMP = 72, [73, 74], [75, 76], 77, 78, 79, 80
out = []
def e(s): out.append('        ' + s)
def load(dstreg, ptr, off, tok):
    out.append('        send.ugm (1|M0)          r%d      r%d  null:0  0x%X            0x0240F580           {I@1,$%d}' % (dstreg, ptr, off << 12 if off else 0, tok))
def dpas(acc, a, w, ty, flags):
    e('dpas.8x8 (16|M0)         r%d:d        r%d:d            r%d:%s            r%d.0:s4         {%s}' % (acc, acc, a, ty, w, flags))
def half(j, steady, last):
    s = j; ns = 1 - j
    loads = steady or (last and j == 0)
    e('sync.allrd                           ($%d,$%d)' % (RB[(j - 1) % 2], RU[(j - 1) % 2]))
    if loads:
        for h in range(2): load(S[ns]['W'] + 4 * h, WP, 0x100 * (j + 1 + ((-h if last else h) if DIST else 0)), TOK[ns]['W'][h])     # 2nd send: next tile's line (distinct line, timing only)
        for h in range(2): load(S[ns]['AB'] + 4 * h, BP[j], 0x100 * h, TOK[ns]['AB'][h])
        for h in range(2): load(S[ns]['AU'] + 4 * h, UP[j], 0x100 * h, TOK[ns]['AU'][h])
    e('sync.allwr                           (%s)' % ','.join('$%d' % t for t in TOK[s]['W'] + TOK[s]['AB']))
    for rg in range(4): dpas(ACB[rg], S[s]['AB'], S[s]['W'] + 2 * rg, 'b', 'Atomic' if rg < 3 else '$%d' % RB[s])
    e('sync.allwr                           (%s)' % ','.join('$%d' % t for t in TOK[s]['AU']))
    for rg in range(4): dpas(ACU[rg], S[s]['AU'], S[s]['W'] + 2 * rg, 'ub', 'Atomic' if rg < 3 else '$%d' % RU[s])
    if steady:
        e('sync.allrd                           (%s)' % ','.join('$%d' % t for t in TOK[ns]['W'] + TOK[ns]['AB'] + TOK[ns]['AU']))
        e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (BP[j], BP[j], P2))
        e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (UP[j], UP[j], P2))
        if j == 1: e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    0x200:uw   {I@1}' % (WP, WP))
e('and (1|M0)               r%d.0<1>:ud   r4.10<0;1,0>:ud   1:ud' % TMP)
e('cmp (1|M0)    (ne)f1.0   null<1>:ud    r%d.0<0;1,0>:ud   0:ud  {I@1}' % TMP)
e('(W&f1.0) jmpi                                L1728')
e('mov (1|M0)               r%d.0<1>:q    r18.0<0;1,0>:q' % WP)
e('add (1|M0)               r%d.0<1>:q    r19.0<0;1,0>:q    -r9.0<0;1,0>:q' % P)
e('shl (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    1:w   {I@1}' % (P2, P))
e('mov (1|M0)               r%d.0<1>:q    r19.0<0;1,0>:q' % BP[0])
e('mov (1|M0)               r%d.0<1>:q    r20.0<0;1,0>:q' % UP[0])
e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (BP[1], BP[0], P))
e('add (1|M0)               r%d.0<1>:q    r%d.0<0;1,0>:q    r%d.0<0;1,0>:q   {I@1}' % (UP[1], UP[0], P))
# own tile-0 loads into set 0 (the compiler's prologue loads land in r85..r136, untouched)
for h in range(2): load(S[0]['W'] + 4 * h, WP, 0x100 * (h if DIST else 0), TOK[0]['W'][h])
for h in range(2): load(S[0]['AB'] + 4 * h, r9 if False else 9, 0x100 * h, TOK[0]['AB'][h])
for h in range(2): load(S[0]['AU'] + 4 * h, 10, 0x100 * h, TOK[0]['AU'][h])
for r in range(138, 202, 2): e('mov (32|M0)              r%d.0<1>:d   0:w' % r)
e('shr (1|M0)               r%d.0<1>:ud   r4.10<0;1,0>:ud   1:w' % CNT)
e('add (1|M0)               r%d.0<1>:d    r%d.0<0;1,0>:d    -1:w   {I@1}' % (CNT, CNT))
e('cmp (1|M0)    (le)f0.1   null<1>:d     r%d.0<0;1,0>:d    0:w   {I@1}' % CNT)
e('(W&f0.1) jmpi                                LN_final')
out.append('LN_loop:')
for j in range(2): half(j, True, False)
e('add (1|M0)               r%d.0<1>:d    r%d.0<0;1,0>:d    -1:w' % (CNT, CNT))
e('cmp (1|M0)    (gt)f0.1   null<1>:d     r%d.0<0;1,0>:d    0:w   {I@1}' % CNT)
e('(W&f0.1) jmpi                                LN_loop')
out.append('LN_final:')
for j in range(2): half(j, False, True)
e('sync.allrd                           null')
e('sync.allwr                           null')
e('(W)     jmpi                                 L3616')
i = next(k for k, l in enumerate(L) if re.match(r'\(W&f1\.0\) jmpi\s+L3360', l))
open(dst, 'w').write('\n'.join(L[:i + 1] + out + L[i + 1:]))
print('inserted', len(out))
