#!/bin/bash
# Fast quantiser experiment: convert the first N layers with the given
# converter options, run the CPU reference over them (all other weights
# original), and report the hidden-state error after each layer against the
# original model on a held-out chat.
#   quick_eval.sh <tag> <N layers> [xf-convert options...]
set -euo pipefail
tag=$1; n=$2; shift 2
root=$(cd "$(dirname "$0")/../.." && pwd)
PY=${PY:-/data/minimaxh3/ComfyUI/.venv/bin/python}
CK=${CK:-/data/B60special/models/Qwen3.8-27B}
W=${W:-/data/B60special/work/quick}
IDS=${IDS:-$root/benchmarks/prompts/chat0.json}
REF=${REF:-/data/B60special/work/m3/ref_bf16_chat0}
mkdir -p "$W"
rm -f "$W/$tag".*.xfm
for l in $(seq 0 $((n - 1))); do
  "$root/target/release/xf-convert" convert "$CK" "$W/$tag.$l.xfm" --only "language_model.layers.$l." "$@" > "$W/$tag.$l.log"
done
# ref_forward takes one container: evaluate cumulatively by chaining is not
# needed -- layers are independent files, so merge via a tiny loader shim.
"$PY" - "$CK" "$IDS" "$W/$tag.out" "$n" "$W/$tag" "$REF" <<'PYEOF'
import sys, json, numpy as np, torch
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[0]).parent))
root = Path("/data/B60special/xeflash/tools/validation"); sys.path.insert(0, str(root))
import ref_forward as RF
from xfm import Xfm
ck_dir, ids, out, n, prefix, ref = sys.argv[1:7]; n = int(n)
class Multi:
    def __init__(self, paths): self.x = [Xfm(p) for p in paths]
    def is_matrix(self, name): return any(x.is_matrix(name) for x in self.x)
    def matrix(self, name): return next(x for x in self.x if x.is_matrix(name)).matrix(name)
    def bias(self, name):
        for x in self.x:
            if x.is_matrix(name): return x.bias(name)
        return None
orig = RF.Ckpt.__init__
def init(self, folder, xfm=None):
    orig(self, folder, None); self.xfm = Multi([f"{prefix}.{l}.xfm" for l in range(n)])
RF.Ckpt.__init__ = init
sys.argv = ["ref_forward.py", ck_dir, ids, out, "--layers", str(n)]
import io, contextlib
with contextlib.redirect_stdout(io.StringIO()): RF.main()
T = len(json.loads(Path(ids).read_text()))
res = []
for l in range(1, n + 1):
    a = np.fromfile(f"{ref}/h{l:02d}.bin", "<f4").reshape(T, -1)[1:].astype(np.float64)
    b = np.fromfile(f"{out}/h{l:02d}.bin", "<f4").reshape(T, -1)[1:].astype(np.float64)
    pt = np.linalg.norm(a - b, axis=-1) / np.linalg.norm(a, axis=-1)
    res.append(f"L{l-1}: {np.median(pt):.4f}/{pt.max():.3f}")
print("per-token relative error of h after each layer, median/max over tokens >= 1:", "  ".join(res))
PYEOF
