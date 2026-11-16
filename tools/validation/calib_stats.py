#!/usr/bin/env python3
"""Collect per-input-channel second moments for every Linear of the text model.

    calib_stats.py <checkpoint_dir> <chats.json> <out_dir> [--ids-out dir]

Runs the original BF16 weights (FP32 math, official transformers layer code,
one layer at a time) over the calibration chats and writes, for every
`...weight` matrix, `<out_dir>/<tensor name>.bin`: mean of x_j^2 over all
calibration tokens, float32 [cols]. The converter uses these as weights for
the quantisation error.

Only diagonal statistics are collected: 5 to 17 thousand numbers per matrix
from about a thousand tokens.
"""
import json
import sys
from pathlib import Path

import torch
from transformers import AutoConfig, AutoTokenizer
from transformers.models.qwen3_5 import modeling_qwen3_5 as M

sys.path.insert(0, str(Path(__file__).parent))
from ref_forward import Ckpt  # noqa: E402

torch.set_grad_enabled(False)


def main():
    ckpt_dir, chats_path, out_dir = sys.argv[1:4]
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    tok = AutoTokenizer.from_pretrained(ckpt_dir)
    seqs = []
    for chat in json.loads(Path(chats_path).read_text()):
        s = tok.apply_chat_template(chat, tokenize=False, add_generation_prompt=False, enable_thinking=False)
        seqs.append(tok(s, add_special_tokens=False)["input_ids"])
    if "--ids-out" in sys.argv:
        d = Path(sys.argv[sys.argv.index("--ids-out") + 1])
        d.mkdir(parents=True, exist_ok=True)
        for i, ids in enumerate(seqs):
            (d / f"seq{i}.json").write_text(json.dumps(ids))
    total = sum(len(s) for s in seqs)
    print(f"{len(seqs)} sequences, {total} tokens", flush=True)

    cfg = AutoConfig.from_pretrained(ckpt_dir).text_config
    cfg._attn_implementation = "eager"
    ck = Ckpt(ckpt_dir)
    pre = "model.language_model."
    emb = ck.get(pre + "embed_tokens.weight")
    hs = [emb[torch.tensor(ids)].unsqueeze(0).clone() for ids in seqs]
    del emb
    rot = M.Qwen3_5TextRotaryEmbedding(cfg)

    acc = {}

    def hook(name):
        def fn(_module, args):
            x = args[0].reshape(-1, args[0].shape[-1]).double()
            acc[name] = acc.get(name, 0) + (x * x).sum(0)
        return fn

    def flush():
        for name, v in acc.items():
            (v / total).float().numpy().astype("<f4").tofile(out / f"{name}.bin")
        acc.clear()

    for l in range(cfg.num_hidden_layers):
        layer = M.Qwen3_5DecoderLayer(cfg, l).float().eval()
        sd = {k: ck.get(f"{pre}layers.{l}.{k}").reshape(v.shape) for k, v in layer.state_dict().items()}
        layer.load_state_dict(sd, strict=True)
        for mname, mod in layer.named_modules():
            if isinstance(mod, torch.nn.Linear):
                mod.register_forward_pre_hook(hook(f"{pre}layers.{l}.{mname}.weight"))
        full = cfg.layer_types[l] == "full_attention"
        for i, h in enumerate(hs):
            T = h.shape[1]
            pe = rot(h, torch.arange(T).view(1, 1, -1).expand(3, 1, -1))
            causal = torch.full((T, T), float("-inf")).triu(1)[None, None]
            res = layer(h, position_embeddings=pe, attention_mask=causal if full else None,
                        position_ids=None, past_key_values=None)
            hs[i] = res[0] if isinstance(res, tuple) else res
        flush()
        print(f"layer {l}", flush=True)
        del layer, sd

    norm = M.Qwen3_5RMSNorm(cfg.hidden_size, eps=cfg.rms_norm_eps)
    norm.weight.copy_(ck.get(pre + "norm.weight"))
    s = 0
    for h in hs:
        x = norm(h).reshape(-1, cfg.hidden_size).double()
        s = s + (x * x).sum(0)
    (s / total).float().numpy().astype("<f4").tofile(out / "lm_head.weight.bin")
    print("done", flush=True)


if __name__ == "__main__":
    main()
