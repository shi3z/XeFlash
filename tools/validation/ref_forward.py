#!/usr/bin/env python3
"""Reference forward pass on the CPU with the official transformers layer code.

    ref_forward.py <checkpoint_dir> <ids.json> <out_dir> [--xfm model.xfm] [--layers N]

Layers are instantiated one at a time (`Qwen3_5DecoderLayer` from transformers),
loaded from the checkpoint, and run in FP32 over the whole sequence, so the
54 GB model never has to be in memory at once. Writes the same files as
`xf-run dump`: h00.bin (embeddings), h01..h64.bin (after each layer),
logits.bin, greedy.json.

With --xfm, every matrix the XeFlash container stores quantised is replaced by
its reconstruction, giving the exact function the engine is supposed to
compute. Without it, the original BF16 weights are used.
"""
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open
from transformers import AutoConfig
from transformers.models.qwen3_5 import modeling_qwen3_5 as M

sys.path.insert(0, str(Path(__file__).parent))
from xfm import Xfm  # noqa: E402

torch.set_grad_enabled(False)


class Ckpt:
    def __init__(self, folder, xfm=None):
        self.folder = Path(folder)
        self.where = json.loads((self.folder / "model.safetensors.index.json").read_text())["weight_map"]
        self.xfm = Xfm(xfm) if xfm else None
        self.files = {}

    def get(self, name):
        if self.xfm is not None and self.xfm.is_matrix(name):
            return torch.from_numpy(self.xfm.matrix(name))
        f = self.where[name]
        if f not in self.files:
            self.files[f] = safe_open(str(self.folder / f), "pt")
        return self.files[f].get_tensor(name).float()


def main():
    ckpt_dir, ids_path, out_dir = sys.argv[1:4]
    xfm = sys.argv[sys.argv.index("--xfm") + 1] if "--xfm" in sys.argv else None
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    ids = json.loads(Path(ids_path).read_text())
    T = len(ids)
    cfg = AutoConfig.from_pretrained(ckpt_dir).text_config
    cfg._attn_implementation = "eager"
    ck = Ckpt(ckpt_dir, xfm)
    pre = "model.language_model."

    emb = ck.get(pre + "embed_tokens.weight")
    h = emb[torch.tensor(ids)].unsqueeze(0).clone()
    del emb
    h.numpy().astype("<f4").tofile(out / "h00.bin")

    rot = M.Qwen3_5TextRotaryEmbedding(cfg)
    pos = torch.arange(T).view(1, 1, -1).expand(3, 1, -1)
    position_embeddings = rot(h, pos)
    causal = torch.full((T, T), float("-inf")).triu(1)[None, None]

    n_layers = int(sys.argv[sys.argv.index("--layers") + 1]) if "--layers" in sys.argv else cfg.num_hidden_layers
    for l in range(n_layers):
        layer = M.Qwen3_5DecoderLayer(cfg, l).float().eval()
        sd = {k: ck.get(f"{pre}layers.{l}.{k}") .reshape(v.shape) for k, v in layer.state_dict().items()}
        layer.load_state_dict(sd, strict=True)
        if ck.xfm is not None:
            # Bias correction stored with quantised matrices.
            for mname, mod in layer.named_modules():
                if isinstance(mod, torch.nn.Linear):
                    b = ck.xfm.bias(f"{pre}layers.{l}.{mname}.weight")
                    if b is not None:
                        mod.bias = torch.nn.Parameter(torch.from_numpy(b))
        full = cfg.layer_types[l] == "full_attention"
        res = layer(h, position_embeddings=position_embeddings, attention_mask=causal if full else None,
                    position_ids=None, past_key_values=None)
        h = res[0] if isinstance(res, tuple) else res
        h.numpy().astype("<f4").tofile(out / f"h{l + 1:02d}.bin")
        print(f"layer {l:2d} {cfg.layer_types[l]:16s} |h| rms {h.pow(2).mean().sqrt().item():.4f}", flush=True)
        del layer, sd

    if n_layers < cfg.num_hidden_layers:
        return  # partial run: hidden states only
    norm = M.Qwen3_5RMSNorm(cfg.hidden_size, eps=cfg.rms_norm_eps)
    norm.weight.copy_(ck.get(pre + "norm.weight"))
    hn = norm(h)[0]
    hn.numpy().astype("<f4").tofile(out / "final_norm.bin")
    head = ck.get("lm_head.weight")
    logits = hn @ head.T
    logits.numpy().astype("<f4").tofile(out / "logits.bin")
    (out / "greedy.json").write_text(json.dumps(logits.argmax(-1).tolist()))
    print("greedy:", logits.argmax(-1).tolist())


if __name__ == "__main__":
    main()
