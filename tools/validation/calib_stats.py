#!/usr/bin/env python3
"""Collect input statistics for every Linear of the text model.

    calib_stats.py <checkpoint_dir> <chats.json> <out_dir> [--ids-out dir]

Runs the original BF16 weights (FP32 math, official transformers layer code,
one layer at a time) over the calibration chats and writes, per `...weight`
matrix:

  <tensor name>.bin        variance of each input channel over the calibration
                           tokens, every token normalised to unit RMS (f32 [cols])
  <tensor name>.mean.bin   mean input vector, raw (f32 [cols])

Hidden states have a large component shared by all tokens. The quantisation
error against that mean is the same for every token, i.e. a constant per
output row: the converter removes it with a bias (from the mean) and weights
the remaining error by the variance.
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
            # Every token counts equally in the variance: normalise each
            # token's input to unit RMS first, otherwise the few positions
            # whose hidden states are orders of magnitude larger own the
            # statistics of matrices fed by unnormalised activations.
            xt = x / x.pow(2).mean(-1, keepdim=True).sqrt().clamp_min(1e-12)
            s = acc.setdefault(name, [0, 0, 0])
            s[0] = s[0] + xt.sum(0)
            s[1] = s[1] + (xt * xt).sum(0)
            s[2] = s[2] + x.sum(0)
        return fn

    def flush():
        for name, (s1, s2, raw) in acc.items():
            mean_t = s1 / total
            var = (s2 / total - mean_t * mean_t).clamp_min(0)
            var.float().numpy().astype("<f4").tofile(out / f"{name}.bin")          # centred variance (normalised tokens)
            (raw / total).float().numpy().astype("<f4").tofile(out / f"{name}.mean.bin")  # mean input (raw)
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
    fn = hook("lm_head.weight")
    for h in hs:
        fn(None, (norm(h),))
    flush()
    print("done", flush=True)


if __name__ == "__main__":
    main()
