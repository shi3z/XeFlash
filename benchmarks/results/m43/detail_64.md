kernel (64 rows, position ~3K)|calls/pass|net us/call|ms/pass|share
gemm 34816x5120|64|331.7|21.25|27%
gemm  5120x17408|64|194.7|12.48|16%
gemm 16384x5120|48|188.9|9.08|11%
gdn:core|48|138.5|6.66|8%
gemm  5120x6144|64|95.2|6.11|8%
attn:xmx-main|16|272.1|4.36|5%
mlp-act+quant|64|50.5|3.25|4%
addnorm+quant|128|24.6|3.19|4%
gdn:gemv-ab|48|62.8|3.03|4%
gemm 14336x5120|16|151.6|2.43|3%
gemm 248320x5120  (head)|1|2373.5|2.37|3%
gdn:conv|48|23.6|1.15|1%
gdn:post+quant|48|20.6|1.00|1%
attn:combine|16|56.9|0.92|1%
sum (stage-synchronised) ms: 80.1
