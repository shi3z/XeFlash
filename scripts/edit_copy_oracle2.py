#!/usr/bin/env python3
"""Oracle replay of proposer variants at 16 rows (K=15) on the m23 greedy outputs: tokens/pass of the copy candidate alone.
variants: latest5 = latest occurrence of the last 5 tokens; longest = candidate with the longest verified backward match among all
occurrences of the last 3 tokens (cap 64); sticky = continue the previous alignment (source pointer) if it was accepted, else longest."""
import json, collections, sys
meta = json.load(open("benchmarks/edit/meta.json")); R = "benchmarks/results/m23"
def load(name):
    ids = json.load(open(f"{R}/tok_{name}_r1/edit_{name}__greedy.json"))[:meta[name]["expected_tokens"]]
    return json.load(open(f"benchmarks/prompts/edit_{name}.json")), ids
def run(prompt, out, variant, K=15, minhit=4, maxocc=64):
    seq = list(prompt); occ = collections.defaultdict(list); L = len(out)
    for p in range(2, len(seq)): occ[tuple(seq[p-2:p+1])].append(p)   # key: 3-gram ending at p
    i = passes = copied = 0; ptr = None; lens = []
    while i < L:
        cand = []; src = None
        if variant == "sticky" and ptr is not None and ptr < len(seq) and seq[ptr-1] == seq[-1]:
            src = ptr
        if src is None and len(seq) >= 3:
            ps = occ.get(tuple(seq[-3:]), [])[-maxocc:]
            if variant == "latest5":
                ps = [p for p in ps if seq[p-4:p+1] == seq[-5:]][-1:]
                best = ps[0] if ps else None
            else:
                best, bl = None, 0
                for p in ps:
                    if p == len(seq) - 1: continue
                    l = 0
                    while l < 64 and p - l >= 0 and seq[p - l] == seq[-1 - l]: l += 1
                    if l >= bl: best, bl = p, l   # ties -> latest
            if best is not None: src = best + 1
        if src is not None: cand = seq[src:src + K]
        acc = 0
        while acc < len(cand) and i + acc < L and cand[acc] == out[i + acc]: acc += 1
        use = len(cand) >= minhit
        take = min((acc + 1) if use else 1, L - i)
        if use: copied += 1; lens.append(acc)
        passes += 1
        if use and src is not None: ptr = src + take      # next aligned source position
        else: ptr = None
        for t in out[i:i + take]:
            seq.append(t)
            if len(seq) >= 3: occ[tuple(seq[-3:])].append(len(seq) - 1)
        i += take
    return passes, copied, L / passes
for name in meta:
    prompt, o = load(name)
    for v in ("latest5", "longest", "sticky"):
        p, c, tpp = run(prompt, o, v)
        print(f"{name}|{v}|passes {p}|copy passes {c}|tok/pass {tpp:.2f}")
