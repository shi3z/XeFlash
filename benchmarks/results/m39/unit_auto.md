shape|16 rows ms|32 rows ms|64 rows ms (TOPS, % of peak)
merged.qkvz|0.1041|0.1287|0.1709 (126, 64%)
merged.attn_qkv|0.0924|0.1230|0.1364 (138, 70%)
out_proj|0.0571|0.0665|0.0791 (102, 52%)
merged.gate_up|0.2286|0.2566|0.3107 (147, 75%)
mlp.down|0.1349|0.1785|0.1998 (114, 58%)
lm_head|1.5602|1.7064|2.3439 (139, 71%)
GEMM sum|35.0 ms|42.0 ms|50.5 ms
