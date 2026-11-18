#!/usr/bin/env python3
"""Tokenise the code tasks with the official tokenizer and chat template (thinking off).

    make_code_prompts.py <checkpoint_dir> <out_dir> [--ctx 8000,30000]

Short prompts:  <out_dir>/<task>.json
Long prompts:   <out_dir>/codectx<N>_<task>.json   = real source files of this repository truncated to N tokens as reference
                                                     code, then the same task (so context length and task type are matched).
"""
import json
import sys
from pathlib import Path

from transformers import AutoTokenizer

sys.path.insert(0, str(Path(__file__).parent))
from code_tasks import TASKS  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
tok = AutoTokenizer.from_pretrained(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)


def encode(text):
    s = tok.apply_chat_template([{"role": "user", "content": text}], tokenize=False, add_generation_prompt=True, enable_thinking=False)
    return tok(s, add_special_tokens=False)["input_ids"]


for name, t in TASKS.items():
    ids = encode(t["prompt"])
    (out / f"{name}.json").write_text(json.dumps(ids))
    print(name, len(ids))

if "--ctx" in sys.argv:
    files = ["crates/xeflash-runtime/src/engine.rs", "crates/xeflash-runtime/src/lib.rs", "tools/run/src/main.rs",
             "kernels/model/model.cpp", "kernels/gemm/gemm.cpp", "kernels/runtime.cpp", "crates/xeflash-model/src/container.rs"]
    ref = "".join(f"// ===== file: {f} =====\n" + (REPO / f).read_text() + "\n" for f in files if (REPO / f).exists())
    ref_ids = tok(ref, add_special_tokens=False)["input_ids"]
    print("reference code tokens available:", len(ref_ids))
    for n in map(int, sys.argv[sys.argv.index("--ctx") + 1].split(",")):
        body = tok.decode(ref_ids[:n])
        for name, t in TASKS.items():
            text = f"Here is part of a codebase, for reference:\n\n{body}\n\n---\nNow, in the same coding style, solve this separate task.\n\n{t['prompt']}"
            ids = encode(text)
            (out / f"codectx{n // 1000}k_{name}.json").write_text(json.dumps(ids))
            print(f"codectx{n // 1000}k_{name}", len(ids))
