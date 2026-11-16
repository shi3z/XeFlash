#!/usr/bin/env python3
"""CPU reference of the official MTP block, teacher-forced over a sequence.

    ref_mtp.py <checkpoint_dir> <ids.json> <ref_dir> [--pre-norm] [--hidden-first]

`ref_dir` is the output of ref_forward.py for the same ids (it provides the
trunk hidden states). Graph, as implemented by vLLM (qwen3_5_mtp.py) and
llama.cpp (graph_mtp):

    x_t   = fc( cat[ norm_e(emb(tok_t)) , norm_h(h_{t-1}) ] )      t >= 1
    x_0   = fc( cat[ norm_e(emb(tok_0)) , 0 ] )                    (llama.cpp convention)
    y     = full-attention decoder layer over x_0..x_{T-1} (causal, RoPE position t)
    logits_t = lm_head( mtp.norm(y_t) )         -> prediction of tok_{t+1}

h is the trunk output AFTER the final norm. --pre-norm feeds the hidden state
before the final norm instead, --hidden-first swaps the concatenation order;
both exist only to test the reading of the graph against measured accuracy.
Writes mtp_pred.json (greedy prediction per position) and prints the
teacher-forced accuracy of predicting tok_{t+1} at position t.
"""
import json
import sys
from pathlib import Path

import numpy as np
import torch
from transformers import AutoConfig
from transformers.models.qwen3_5 import modeling_qwen3_5 as M

sys.path.insert(0, str(Path(__file__).parent))
from ref_forward import Ckpt  # noqa: E402

torch.set_grad_enabled(False)
ckpt_dir, ids_path, ref_dir = sys.argv[1:4]
pre_norm = "--pre-norm" in sys.argv
hidden_first = "--hidden-first" in sys.argv
ids = json.loads(Path(ids_path).read_text())
T = len(ids)
cfg = AutoConfig.from_pretrained(ckpt_dir).text_config
cfg._attn_implementation = "eager"
cfg.layer_types = ["full_attention"]
ck = Ckpt(ckpt_dir)
D = cfg.hidden_size

hname = "h64.bin" if pre_norm else "final_norm.bin"
h = torch.from_numpy(np.fromfile(Path(ref_dir) / hname, "<f4").reshape(T, D).copy())
emb = ck.get("model.language_model.embed_tokens.weight")[torch.tensor(ids)]


def norm(name, x):
    n = M.Qwen3_5RMSNorm(D, eps=cfg.rms_norm_eps)
    n.weight.copy_(ck.get(name))
    return n(x)


e = norm("mtp.pre_fc_norm_embedding.weight", emb)
hn = norm("mtp.pre_fc_norm_hidden.weight", h)
hn = torch.cat([torch.zeros(1, D), hn[:-1]], 0)          # pair tok_t with h_{t-1}; zero for t = 0
cat = torch.cat([hn, e], -1) if hidden_first else torch.cat([e, hn], -1)
x = (cat @ ck.get("mtp.fc.weight").T).unsqueeze(0)

layer = M.Qwen3_5DecoderLayer(cfg, 0).float().eval()
layer.load_state_dict({k: ck.get(f"mtp.layers.0.{k}").reshape(v.shape) for k, v in layer.state_dict().items()}, strict=True)
rot = M.Qwen3_5TextRotaryEmbedding(cfg)
pe = rot(x, torch.arange(T).view(1, 1, -1).expand(3, 1, -1))
causal = torch.full((T, T), float("-inf")).triu(1)[None, None]
res = layer(x, position_embeddings=pe, attention_mask=causal, position_ids=None, past_key_values=None)
y = (res[0] if isinstance(res, tuple) else res)[0]
yn = norm("mtp.norm.weight", y)
yn.numpy().astype("<f4").tofile(Path(ref_dir) / "mtp_hidden.bin")
logits = yn @ ck.get("lm_head.weight").T
pred = logits.argmax(-1).tolist()
Path(ref_dir, "mtp_pred.json").write_text(json.dumps(pred))
hit = sum(int(pred[t] == ids[t + 1]) for t in range(1, T - 1))
print(f"variant pre_norm={pre_norm} hidden_first={hidden_first}: "
      f"MTP teacher-forced top-1 accuracy {hit}/{T - 2} = {100 * hit / (T - 2):.1f}%")
