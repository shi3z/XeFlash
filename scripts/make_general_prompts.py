#!/usr/bin/env python3
"""Prompts for the general-generation study (Part AI): benchmarks/prompts/gen_*.json (token ids, same ChatML form as the existing prompts)."""
import json
from transformers import AutoTokenizer
tk = AutoTokenizer.from_pretrained("/data/B60special/models/Qwen3.8-27B")
def chat(user): return f"<|im_start|>user\n{user}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
def save(name, text):
    ids = tk(text, add_special_tokens=False)["input_ids"]
    json.dump(ids, open(f"benchmarks/prompts/gen_{name}.json", "w")); print(name, len(ids))
# C++ edit: a function of a real source file, rename a local variable in one function only
src = open("/data/llamacpp/src/common/ngram-cache.cpp").read()
save("cpp_edit", chat("Below is a C++ file. In the function `common_ngram_cache_update` only, rename the local variable `ngram_size` to `n_gram_size` (every occurrence inside that function). Change nothing else.\nReturn the complete file, from the first line to the last, with no Markdown code fences and no explanation.\n\n" + src))
save("ja_chat", chat("最近、仕事で新しいプログラミング言語を覚える必要が出てきました。忙しい社会人が効率よく学ぶためのコツを、具体的な例を交えて教えてください。"))
save("en_chat", chat("I have three days in Kyoto in November and I like quiet places more than crowded sights. Can you suggest a day-by-day plan and explain why you picked each place?"))
save("math", chat("A train leaves city A at 9:00 travelling at 80 km/h towards city B, 420 km away. A second train leaves city B at 10:30 travelling at 100 km/h towards city A. At what time do they meet, and how far from city A? Then solve the same problem if the second train leaves at 10:00 at 90 km/h. Show every step."))
save("ja_write", chat("雨の日の古い書店を舞台にした、静かで少し不思議な短編小説を日本語で書いてください。800字程度でお願いします。"))
