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
def main_ms(m, slope=0.75):
    if m <= 1: return 40.3
    if m <= 8: return 40.3 + (43.3-40.3)*(m-1)/7
    if m <= 16: return 43.3 + (49.3-43.3)*(m-8)/8
    return 49.3 + slope*(m-16)
def rows_for(prop): return 1 + prop
out = {}
print("task|n|K|passes|tok/pass (copy only)|est tok/s copy-only (slope .75 / 1.5)|hybrid est tok/s")
for name in tasks:
    prompt, o = tokens(name)
    for n in (3, 5):
        for K in (15, 31, 63):
            passes, em = simulate(prompt, o, n, K, 4)
            L = len(o)
            t_lo = sum(main_ms(rows_for(p if p >= 4 else 0), .75) for p, _ in em)
            t_hi = sum(main_ms(rows_for(p if p >= 4 else 0), 1.5) for p, _ in em)
            # hybrid: passes without a >=4 proposal use bdraft2 (3.5 tok/pass at 49.3+7.4 ms, an assumption from the measured non-copy rate)
            hy = 0.0; nc_tokens = 0
            for p, tk_ in em:
                if p >= 4: hy += main_ms(rows_for(p), .75)
                else: nc_tokens += tk_
            hy += nc_tokens / 3.5 * (49.3 + 7.4)
            print(f"{name}|{n}|{K}|{passes}|{L/passes:.2f}|{L/t_lo*1e3:.0f} / {L/t_hi*1e3:.0f}|{L/hy*1e3:.0f}")
