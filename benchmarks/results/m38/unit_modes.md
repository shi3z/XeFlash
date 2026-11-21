shape (64 rows)|split ms (exact)|lgrf ms (exact)|rb2 ms (exact)|rb2s ms (exact)|pd2 ms (exact)|pd2l ms (exact)
merged.qkvz|0.2063 (y)|0.1684 (y)|0.2117 (y)|0.1658 (y)|0.2037 (y)|0.1805 (y)
merged.attn_qkv|0.1592 (y)|0.1334 (y)|0.1652 (y)|0.1596 (y)|0.1621 (y)|0.1389 (y)
out_proj|0.0871 (y)|0.0795 (y)|0.0868 (y)|0.0927 (y)|0.0926 (y)|0.0916 (y)
merged.gate_up|0.3692 (y)|0.3101 (y)|0.3810 (y)|0.3520 (y)|0.3737 (y)|0.3301 (y)
mlp.down|0.1997 (y)|0.2330 (y)|0.2123 (y)|0.2331 (y)|0.2222 (y)|0.2626 (y)
lm_head|2.9729 (y)|2.3579 (y)|2.6238 (y)|2.3949 (y)|2.5655 (y)|2.3840 (y)
GEMM sum @64 rows|57.4 ms|52.4 ms|59.0 ms|56.3 ms|59.0 ms|57.1 ms
