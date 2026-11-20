#!/usr/bin/env python3
"""Build token-id prompt files for the YASAKANI v0.1.6 `bench --edit` tasks (benchmarks/edit/edit_tasks.json, unchanged copy).
Prompt = Qwen3.8 chat template, thinking off. Also writes expected token counts (expected answer + <|im_end|>) -> n_new."""
import json, hashlib, sys
from transformers import AutoTokenizer
tk = AutoTokenizer.from_pretrained("/data/B60special/models/Qwen3.8-27B")
d = json.load(open("benchmarks/edit/edit_tasks.json"))
meta = {}
for t in d["tasks"]:
    assert hashlib.sha256(t["expected"].encode()).hexdigest() == t["expected_sha256"]
    ids = tk.apply_chat_template(t["messages"], add_generation_prompt=True, enable_thinking=False, tokenize=True)
    ids = ids["input_ids"] if isinstance(ids, dict) or hasattr(ids, "keys") else ids
    exp = tk(t["expected"].strip() , add_special_tokens=False)["input_ids"]
    im_end = tk.convert_tokens_to_ids("<|im_end|>")
    json.dump(list(map(int, ids)), open(f"benchmarks/prompts/edit_{t['name']}.json", "w"))
    meta[t["name"]] = dict(prompt_tokens=len(ids), expected_tokens=len(exp) + 1, max_tokens=t["max_tokens"], expected_sha256=t["expected_sha256"])
    print(t["name"], meta[t["name"]], tk.decode(ids[-12:]).replace("\n", "\\n"))
json.dump(meta, open("benchmarks/edit/meta.json", "w"), indent=1)
