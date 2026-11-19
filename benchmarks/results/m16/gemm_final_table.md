| shape | m | before (XF_GEMM_WG=0) us | after (default) us | change | exact vs CPU (before/after) |
|---|---:|---:|---:|---:|---|
| out_proj | 1 | 50.7 (segs 1) | 50.4 (segs 1) | -0.6% | exact/exact |
| out_proj | 8 | 55.8 (segs 1) | 50.9 (segs 1) | -8.8% | exact/exact |
| out_proj | 16 | 63.5 (segs 1) | 57.1 (segs 1) | -10.1% | exact/exact |
| mlp.down | 1 | 105.4 (segs 1) | 105.4 (segs 1) | +0.0% | exact/exact |
| mlp.down | 8 | 120.8 (segs 2) | 111.3 (segs 1) | -7.9% | exact/exact |
| mlp.down | 16 | 142.9 (segs 2) | 132.0 (segs 1) | -7.6% | exact/exact |
| merged.gate_up | 1 | 207.4 (segs 1) | 207.5 (segs 1) | +0.0% | exact/exact |
| merged.gate_up | 8 | 216.4 (segs 1) | 216.6 (segs 1) | +0.1% | exact/exact |
| merged.gate_up | 16 | 228.1 (segs 1) | 227.7 (segs 1) | -0.2% | exact/exact |
| merged.qkvz | 1 | 102.4 (segs 1) | 102.4 (segs 1) | +0.0% | exact/exact |
| merged.qkvz | 8 | 103.3 (segs 1) | 101.9 (segs 1) | -1.4% | exact/exact |
| merged.qkvz | 16 | 106.5 (segs 1) | 104.5 (segs 1) | -1.9% | exact/exact |
| merged.attn_qkv | 1 | 92.5 (segs 1) | 92.5 (segs 1) | +0.0% | exact/exact |
| merged.attn_qkv | 8 | 94.8 (segs 1) | 91.6 (segs 1) | -3.4% | exact/exact |
| merged.attn_qkv | 16 | 96.9 (segs 1) | 91.9 (segs 1) | -5.2% | exact/exact |
| lm_head | 1 | 1442.7 (segs 1) | 1442.6 (segs 1) | -0.0% | exact/exact |
| lm_head | 8 | 1508.5 (segs 1) | 1500.5 (segs 1) | -0.5% | exact/exact |
| lm_head | 16 | 1567.9 (segs 1) | 1560.7 (segs 1) | -0.5% | exact/exact |
