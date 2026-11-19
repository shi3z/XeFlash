| shape | m | launch | avg us | LSC read GB/s (load pipe, all threads) | LSC miss % | LSC->L3 read GB/s | L3 read GB/s | L3 miss % | DRAM read GB/s | LSC input avail % | LSC output ready % | SLM GB/s |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| merged.gate_up | 1 | plain | 207 | 510 | 17.1 | 408 | 409 | 99.1 | 407 | 89 | 10 | 0 |
| merged.gate_up | 8 | plain | 216 | 1176 | 9.1 | 408 | 409 | 95.8 | 394 | 89 | 9 | 0 |
| merged.gate_up | 8 | WG 4 | 216 | 1168 | 9.1 | 405 | 405 | 95.7 | 391 | 91 | 9 | 0 |
| mlp.down | 1 | plain | 105 | 474 | 17.2 | 381 | 382 | 99.2 | 379 | 43 | 9 | 0 |
| mlp.down | 1 | WG 4 | 116 | 435 | 17.9 | 354 | 354 | 98.5 | 348 | 20 | 8 | 0 |
| mlp.down | 8 | plain | 128 | 947 | 9.0 | 336 | 336 | 99.5 | 318 | 45 | 7 | 0 |
| mlp.down | 8 | WG 4 | 111 | 1072 | 9.5 | 402 | 402 | 99.3 | 360 | 80 | 8 | 0 |
| out_proj | 1 | plain | 51 | 305 | 17.3 | 245 | 245 | 98.7 | 243 | 36 | 6 | 0 |
| out_proj | 1 | WG 4 | 56 | 285 | 18.0 | 231 | 231 | 97.7 | 227 | 14 | 6 | 0 |
| out_proj | 8 | plain | 56 | 708 | 9.2 | 251 | 251 | 93.3 | 236 | 37 | 5 | 0 |
| out_proj | 8 | WG 4 | 51 | 749 | 9.8 | 284 | 284 | 88.6 | 250 | 40 | 6 | 0 |
