shape|tok|ms|TOPS (both planes)|% of 196.5 peak|weight GB/s
merged.qkvz|16|0.1041|51.6|26%|403
merged.qkvz|64|0.2052|104.7|53%|204
merged.qkvz|128|0.3313|129.6|66%|127
merged.attn_qkv|16|0.0923|50.9|26%|398
merged.attn_qkv|64|0.1594|117.9|60%|230
merged.attn_qkv|128|0.2851|131.8|67%|129
out_proj|16|0.0588|34.2|17%|268
out_proj|64|0.0903|89.2|45%|174
out_proj|128|0.1243|129.6|66%|127
merged.gate_up|16|0.2287|49.9|25%|390
merged.gate_up|64|0.3690|123.7|63%|242
merged.gate_up|128|0.6711|136.0|69%|133
mlp.down|16|0.1308|43.6|22%|341
mlp.down|64|0.1983|115.1|59%|225
mlp.down|128|0.3710|123.0|63%|120
lm_head|16|1.5602|52.2|27%|407
lm_head|64|2.9849|109.0|55%|213
lm_head|128|6.3406|102.7|52%|100
GEMM sum per pass (ms): {16: 34.81, 64: 57.47, 128: 101.45}
weights per pass: 25.60 G; a16 ops per pass at 64 rows: 6.55 TOP -> 33.3 ms at 196.5 TOPS peak; at 128 rows 66.7 ms
