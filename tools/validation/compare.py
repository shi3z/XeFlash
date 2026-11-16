#!/usr/bin/env python3
"""Compare two dumps written by `xf-run dump` / `ref_forward.py`.

    compare.py <reference_dir> <test_dir> [--md]

Per stage (embedding, each layer): max abs error, RMS error, relative error
(|a-b| / |a|) and cosine similarity over all tokens. For the logits: KL
divergence KL(ref || test) per token (mean / max) and top-1 agreement.
"""
import json
import sys
from pathlib import Path

import numpy as np

ref, test = Path(sys.argv[1]), Path(sys.argv[2])
md = "--md" in sys.argv
rows = []
for l in range(65):
    a = np.fromfile(ref / f"h{l:02d}.bin", "<f4").astype(np.float64)
    b = np.fromfile(test / f"h{l:02d}.bin", "<f4").astype(np.float64)
    assert a.shape == b.shape, f"h{l:02d}: {a.shape} vs {b.shape}"
    d = a - b
    rows.append((("emb" if l == 0 else f"L{l - 1:02d}"), np.abs(d).max(), np.sqrt((d * d).mean()),
                 np.linalg.norm(d) / np.linalg.norm(a), (a @ b) / (np.linalg.norm(a) * np.linalg.norm(b))))
sep = " | " if md else "  "
print(sep.join(["stage", "max abs", "rms err", "rel err", "cosine"]))
if md:
    print("---|---|---|---|---")
show = rows if "--all" in sys.argv else [r for i, r in enumerate(rows) if i < 5 or i % 8 == 0 or i >= 63]
for name, mx, rms, rel, cos in show:
    print(sep.join([name, f"{mx:.3e}", f"{rms:.3e}", f"{rel:.3e}", f"{cos:.6f}"]))

V = 248320
la = np.fromfile(ref / "logits.bin", "<f4").reshape(-1, V).astype(np.float64)
lb = np.fromfile(test / "logits.bin", "<f4").reshape(-1, V).astype(np.float64)


def logsm(x):
    x = x - x.max(-1, keepdims=True)
    return x - np.log(np.exp(x).sum(-1, keepdims=True))


pa, pb = logsm(la), logsm(lb)
kl = (np.exp(pa) * (pa - pb)).sum(-1)
top = (la.argmax(-1) == lb.argmax(-1))
d = la - lb
print(f"logits: rms err {np.sqrt((d * d).mean()):.4e}  max abs {np.abs(d).max():.4e}  "
      f"KL mean {kl.mean():.3e} max {kl.max():.3e}  top-1 agreement {top.sum()}/{top.size} = {top.mean() * 100:.2f}%")
ga, gb = json.loads((ref / "greedy.json").read_text()), json.loads((test / "greedy.json").read_text())
print("greedy ids identical:", ga == gb)
