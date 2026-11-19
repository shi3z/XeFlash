| shape | m | prod. time us | eff. read GB/s | threads (thr/EU, waves of 1280) | trips x dpas/trip = DPAS per thread | DPAS per call (dynamic) | loads per call (dyn.), load-pipe MB | int ALU+mul+mov+cmp per call (M) | sync waits / trip | weights-only us | DPAS-only us (XMX busy %) | full / weights-only | dominant bottleneck |
|---|---:|---:|---:|---|---|---:|---|---:|---:|---:|---|---:|---|
| gate+up | 1 | 207.8 | 429 | 2176 (8.0, 1.70) | 40 x 8 | 0.70 M | 1.04 M, 134 | 1.2 | 12 | 210.2 | 18.9 (9%) | 0.99 | weight stream (DRAM); XMX waits for data |
| gate+up | 8 | 217.0 | 411 | 2176 (8.0, 1.70) | 40 x 8 | 0.70 M | 1.04 M, 267 | 1.2 | 4 | 218.1 | 40.2 (19%) | 1.00 | weight stream (DRAM); XMX waits for data |
| gate+up | 16 | 226.9 | 393 | 2176 (8.0, 1.70) | 80 x 8 | 1.39 M | 1.74 M, 446 | 1.9 | 4 | 227.0 | 75.8 (33%) | 1.01 | weight stream (DRAM); XMX waits for data |
| down | 1 | 105.6 | 422 | 320 (2.0, 0.25) | 136 x 8 | 0.35 M | 0.52 M, 67 | 0.6 | 12 | 103.1 | 15.7 (15%) | 1.02 | weight stream (DRAM); XMX waits for data |
| down | 8 | 121.2 | 368 | 640 (4.0, 0.50) | 68 x 8 | 0.35 M | 0.52 M, 134 | 0.6 | 4 | 116.2 | 18.0 (17%) | 0.92 | weight stream; segmented K-split (extra loads in flight help) + combine kernel / 2-way split |
| down | 16 | 148.9 | 299 | 640 (4.0, 0.50) | 136 x 8 | 0.70 M | 0.87 M, 223 | 1.0 | 4 | 115.4 | 32.9 (27%) | 1.06 | weight stream + activation-load traffic (X/XL loads add 6% over weights alone; 640 threads) + combine kernel / 2-way split |
| out proj | 1 | 50.4 | 312 | 320 (2.0, 0.25) | 48 x 8 | 0.12 M | 0.18 M, 24 | 0.2 | 12 | 49.9 | 6.5 (13%) | 1.01 | weight stream (DRAM); XMX waits for data |
| out proj | 8 | 55.8 | 282 | 320 (2.0, 0.25) | 48 x 8 | 0.12 M | 0.18 M, 47 | 0.2 | 4 | 50.5 | 12.6 (22%) | 1.12 | weight stream + activation-load traffic (X/XL loads add 12% over weights alone; 320 threads) |
| out proj | 16 | 65.2 | 241 | 320 (2.0, 0.25) | 96 x 8 | 0.25 M | 0.31 M, 79 | 0.3 | 4 | 55.4 | 23.7 (36%) | 1.18 | weight stream + activation-load traffic (X/XL loads add 18% over weights alone; 320 threads) |
| attn qkv | 1 | 92.7 | 396 | 896 (5.6, 0.70) | 40 x 8 | 0.29 M | 0.43 M, 55 | 0.5 | 12 | 89.6 | 9.7 (10%) | 1.03 | weight stream (DRAM); XMX waits for data |
| attn qkv | 8 | 95.1 | 386 | 896 (5.6, 0.70) | 40 x 8 | 0.29 M | 0.43 M, 110 | 0.5 | 4 | 92.8 | 18.7 (20%) | 1.02 | weight stream (DRAM); XMX waits for data |
| attn qkv | 16 | 97.0 | 378 | 896 (5.6, 0.70) | 80 x 8 | 0.57 M | 0.72 M, 184 | 0.8 | 4 | 94.9 | 36.1 (37%) | 1.02 | weight stream (DRAM); XMX waits for data |
| GDN in-proj | 1 | 101.2 | 414 | 1024 (6.4, 0.80) | 40 x 8 | 0.33 M | 0.49 M, 63 | 0.6 | 12 | 99.1 | 9.7 (10%) | 1.02 | weight stream (DRAM); XMX waits for data |
| GDN in-proj | 8 | 103.7 | 404 | 1024 (6.4, 0.80) | 40 x 8 | 0.33 M | 0.49 M, 126 | 0.6 | 4 | 103.3 | 18.7 (18%) | 1.00 | weight stream (DRAM); XMX waits for data |
| GDN in-proj | 16 | 105.9 | 396 | 1024 (6.4, 0.80) | 80 x 8 | 0.66 M | 0.82 M, 210 | 0.9 | 4 | 107.0 | 36.1 (34%) | 0.99 | weight stream (DRAM); XMX waits for data |
