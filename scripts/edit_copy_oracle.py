#!/usr/bin/env python3
"""Offline headroom analysis of a copy/edit speculative drafter (prompt lookup, "PLD") on the measured edit outputs.
No GPU. For every task it replays the greedy output (verified identical to all spec configs) and, pass by pass, proposes up to K tokens
copied from the context after the latest earlier occurrence of the last n tokens (searching prompt + already generated text);
the verifier accepts the longest prefix equal to the true greedy continuation (exactly what greedy verification accepts). Result =
tokens/pass of a pure copy drafter (no draft model; a miss still yields 1 token), and of a hybrid that falls back to bdraft2 when
there is no usable copy proposal. Timing is an ESTIMATE from measured per-pass costs (m=1/8/16 measured; m=32/64 extrapolated)."""
import json, sys, collections
tasks = json.load(open("benchmarks/edit/meta.json"))
R = "benchmarks/results/m23"
def tokens(name):
    ids = json.load(open(f"{R}/tok_{name}_r1/edit_{name}__greedy.json")); n = tasks[name]["expected_tokens"]
    return json.load(open(f"benchmarks/prompts/edit_{name}.json")), ids[:n]
def simulate(prompt, out, n, K, minhit):
    ctx = list(prompt); idx = collections.defaultdict(list)
    def add(upto):
        for p in range(max(0, len(done_idx) and done_idx[0]), upto): pass
    # n-gram index over ctx: key = tuple(ctx[p-n:p]) -> positions p (next token index)
    pos = {}
    for p in range(n, len(ctx)): pos[tuple(ctx[p-n:p])] = p   # the suffix itself (p == len) is added only after the lookup
    i, passes, hits, copied, useful = 0, 0, 0, 0, 0
    sizes = collections.Counter(); emit_list = []
    L = len(out)
    while i < L:
        key = tuple(ctx[-n:]); p = pos.get(key)
        acc = 0; prop = 0
        if p is not None and p < len(ctx):
            prop = min(K, len(ctx) - p)
            while acc < prop and i + acc < L and ctx[p + acc] == out[i + acc]: acc += 1
        passes += 1
        take = acc + 1 if i + acc < L else acc  # bonus token from the verifier
        take = min(take, L - i)
        if prop >= minhit: hits += 1
        pos[key] = len(ctx)
        for t in out[i:i + take]:
            ctx.append(t)
            q = len(ctx)
            if q - 1 >= n and q < len(ctx) + 1 and i + take > 0: pass
        for q in range(len(ctx) - take + 1, len(ctx)):
            if q >= n: pos[tuple(ctx[q-n:q])] = q
        sizes[min(prop, K)] += 1
        emit_list.append((prop, take))
        i += take
    return passes, emit_list
# per-pass cost (ms), from measurements m23 (fixed8 m=8: 43.3 main, fixed16 m=16: 49.3 main, greedy m=1: 40.3, bdraft2 draft 6.2-7.4 ms)
# beyond 16 rows: linear extrapolation 0.75 ms per extra row (assumption: measured 8->16 slope), optimistic
# Measured GEMM sums (benchmarks/results/m24, s4 unit benchmark x layer counts: 48 qkvz, 16 attn_qkv, 64 out_proj, 64 gate_up, 64 down, 1 lm_head):
#   a16: m=1 28.25, m=8 29.48, m=16 32.86 ms; 8-bit activations only above 16 rows: m=32 46.65, m=64 71.54 ms.
# Non-GEMM part of the Main pass = measured Main (37.7/46.2 ms at m=1/16, m20) - GEMM = 9.5 -> 13.3 ms; extrapolated 0.25 ms/row.
# Model A (optimistic): 8-bit-activation GEMM times as measured, non-GEMM extrapolated.  Model B (a16 proxy): a 16-bit-activation GEMM of m rows
# costs about the 8-bit one of 2m rows (two planes): m=32 -> 71.5, m=64 -> 143 ms (extrapolated x2).
import bisect
_PTS_A = [(1,40.3),(8,43.3),(16,49.3),(32,64.0),(64,96.9)]      # Main ms incl. ~6 ms bdraft2-free offset of the m23 measurements (m23 main values)
_PTS_B = [(1,40.3),(8,43.3),(16,49.3),(32,88.9),(64,168.3)]
def _interp(pts, m):
    xs=[p[0] for p in pts]
    if m>=xs[-1]: return pts[-1][1]
    i=bisect.bisect_right(xs,m)-1; (x0,y0),(x1,y1)=pts[i],pts[i+1]
    return y0+(y1-y0)*(m-x0)/(x1-x0)
def main_ms(m, model="A"): return _interp(_PTS_A if model=="A" else _PTS_B, m)
def rows_for(prop): return 1 + prop
out = {}
print("task|n|K|passes|tok/pass (copy only)|est tok/s model A / model B (copy only)|hybrid est A / B")
for name in tasks:
    prompt, o = tokens(name)
    for n in (5,):
        for K in (15, 31, 63):
            passes, em = simulate(prompt, o, n, K, 4)
            L = len(o); res=[]
            for mod in ("A","B"):
                t_c = sum(main_ms(rows_for(p if p >= 4 else 0), mod) for p, _ in em)
                nc = sum(tk_ for p, tk_ in em if p < 4)
                hy = sum(main_ms(rows_for(p), mod) for p, _ in em if p >= 4) + nc/3.5*(49.3+7.4)
                res.append((L/t_c*1e3, L/hy*1e3))
            print(f"{name}|{n}|{K}|{passes}|{L/passes:.2f}|{res[0][0]:.0f} / {res[1][0]:.0f}|{res[0][1]:.0f} / {res[1][1]:.0f}")
