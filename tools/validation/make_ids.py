#!/usr/bin/env python3
"""Tokenise the benchmark prompts with the official tokenizer and chat template
(thinking off), one JSON array of ids per prompt.

    make_ids.py <checkpoint_dir> <out_dir>

The four prompts are the ones `yasakani bench` uses, so both engines see the
same token sequences.
"""
import json
import sys
from pathlib import Path

from transformers import AutoTokenizer

PROMPTS = {
    "explain": "Explain how a hash table works, including collisions and resizing, with a short example.",
    "code": "Write a Python function that merges overlapping intervals and add a few tests for it.",
    "story": "Write a short story about a lighthouse keeper who finds a message in a bottle.",
    "proof": "Prove that the square root of 2 is irrational.",
}

tok = AutoTokenizer.from_pretrained(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
if "--chats" in sys.argv:
    # Whole conversations (with assistant turns) for teacher-forced evaluation.
    chats = json.loads(Path(sys.argv[sys.argv.index("--chats") + 1]).read_text())
    for i, chat in enumerate(chats):
        s = tok.apply_chat_template(chat, tokenize=False, add_generation_prompt=False, enable_thinking=False)
        ids = tok(s, add_special_tokens=False)["input_ids"]
        (out / f"chat{i}.json").write_text(json.dumps(ids))
        print(f"chat{i}", len(ids))
    sys.exit(0)
for name, text in PROMPTS.items():
    s = tok.apply_chat_template([{"role": "user", "content": text}], tokenize=False,
                                add_generation_prompt=True, enable_thinking=False)
    ids = tok(s, add_special_tokens=False)["input_ids"]
    (out / f"{name}.json").write_text(json.dumps(ids))
    (out / f"{name}.txt").write_text(s)
    print(name, len(ids), repr(s[-60:]))
