#!/usr/bin/env python3
"""Run YASAKANI (RTX 5060 Ti port, read-only use of its tree) on exactly the token-id prompts used for XeFlash.

  PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=/data/yasakani/5060/yasakani/python python3 run_yasakani.py \\
      --max-ctx 10240 --item benchmarks/prompts/long8000.json:256 --item ... --json out.json [--modes on,off]

Greedy (temperature 0), same ids, same number of generated tokens. Engine settings: the defaults of the tuned build
(`RuntimeProfile.default`), speculation `on` = YASAKANI's look-ahead with bdraft2 (default `spec`), `off` = plain decoding.
tok/s as YASAKANI's own benchmarks define it: (generated tokens - 1) / generation time (prefill excluded).
Peak GPU memory: nvidia-smi sampled every 0.2 s from before the engine is created until the last run ends.
"""
import argparse
import hashlib
import json
import subprocess
import sys
import threading
import time
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("--model-dir", default="/data/yasakani/model-speed")
ap.add_argument("--dll", default="/data/yasakani/5060/yasakani/build/libyskn.so")
ap.add_argument("--max-ctx", type=int, required=True)
ap.add_argument("--item", action="append", required=True, help="ids.json:new_tokens")
ap.add_argument("--modes", default="on,off")
ap.add_argument("--json", required=True)
ap.add_argument("--save-ids", default="")
ap.add_argument("--env", action="append", default=[], help="YSKN_X=V engine setting (e.g. YSKN_PROF=1 for the per-kernel profile)")
ap.add_argument("--spec", action="append", default=[], help="k=v speculation setting (e.g. use_graph=0)")
a = ap.parse_args()

from yasakani import Engine, ModelPack  # noqa: E402
from yasakani import runtime as _rt  # noqa: E402
from yasakani.engine import Sampling  # noqa: E402
from yasakani.runtime import RuntimeProfile  # noqa: E402
from yasakani.textio import ChatFormatter  # noqa: E402

_rt.STAT_INDEX.update(ms_verify=25, ms_draft=26, ms_total=27, ms_commit=28, ms_record=29, ms_ctx=40, **{"rows%d" % m: 6 + m for m in range(1, 17)})
peak = [0]
stop = [False]


def watch():
    while not stop[0]:
        try:
            v = int(subprocess.run(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"], capture_output=True, text=True).stdout.split()[0])
            peak[0] = max(peak[0], v)
        except Exception:  # noqa: BLE001
            pass
        time.sleep(0.2)


threading.Thread(target=watch, daemon=True).start()
pack = ModelPack.load(a.model_dir)
fmt = ChatFormatter(pack.root)
t0 = time.time()
eng = Engine(pack, max_ctx=a.max_ctx, dll=a.dll, profile=RuntimeProfile.default(pack, dict(kv.split("=", 1) for kv in a.env)))
eng.warmup([fmt.encode("warm-up"), fmt.prompt([{"role": "user", "content": "warm-up"}])[0]], n_gen=32)
print(f"# max_ctx {eng.max_ctx}, load {time.time() - t0:.1f}s, GPU memory now {peak[0]} MiB", flush=True)
greedy = Sampling(0.0, 0.95, 20, 0.0, 0)
rows = []
for item in a.item:
    path, n = item.rsplit(":", 1)
    ids = json.loads(Path(path).read_text())
    for mode in a.modes.split(","):
        from_spec = {} if mode == "on" else None
        spec = {k: int(v) for k, v in (kv.split("=", 1) for kv in a.spec)} if mode == "on" else None
        if mode == "off":
            # YASAKANI's own "look-ahead off" setting (quickstart/lookahead_check.py NO_LOOKAHEAD)
            import importlib.util
            sp = importlib.util.spec_from_file_location("lookahead_check", "/data/yasakani/5060/yasakani/quickstart/lookahead_check.py")
            m = importlib.util.module_from_spec(sp)
            sp.loader.exec_module(m)
            spec = dict(m.NO_LOOKAHEAD)
            spec.update({k: int(v) for k, v in (kv.split("=", 1) for kv in a.spec)})
        eng.reset()
        eng.set_sampling(greedy)
        r = eng.generate(ids, int(n), spec=spec)
        k = len(r.ids)
        p = max(1, r.passes)
        row = dict(prompt=Path(path).stem, mode=mode, prompt_tokens=len(ids), tokens=k, passes=r.passes, prefill_ms=r.prefill_ms, gen_ms=r.gen_ms,
                   tok_s=(k - 1) / (r.gen_ms / 1000.0), tok_per_pass=(k - 1) / p, prefill_tok_s=len(ids) / (r.prefill_ms / 1000.0),
                   per_pass_ms={q[3:]: r.stats[q] / p for q in ("ms_verify", "ms_draft", "ms_commit", "ms_record", "ms_ctx", "ms_total")},
                   rows_hist={m_: int(r.stats["rows%d" % m_]) for m_ in range(1, 17) if r.stats["rows%d" % m_]},
                   sha=hashlib.sha256(str(list(r.ids)).encode()).hexdigest()[:12], peak_mib_so_far=peak[0])
        rows.append(row)
        if a.save_ids:
            Path(a.save_ids).mkdir(parents=True, exist_ok=True)
            Path(a.save_ids, f"{row['prompt']}__{mode}.json").write_text(json.dumps([int(x) for x in r.ids]))
        print(f"{row['prompt']:24s} {mode:3s} {row['tok_s']:7.1f} tok/s | {row['tok_per_pass']:.2f} tok/pass | {row['gen_ms'] / p:.2f} ms/pass "
              f"(verify {row['per_pass_ms']['verify']:.2f} draft {row['per_pass_ms']['draft']:.2f}) | prefill {row['prefill_tok_s']:.0f} tok/s | peak {peak[0]} MiB", flush=True)
stop[0] = True
eng.close()
Path(a.json).write_text(json.dumps(dict(max_ctx=a.max_ctx, peak_mib=peak[0], rows=rows), indent=1))
