| shape | m | before: best (segs) us | after: best (segs) us | change | segs 1 / 2 / 4 before | segs 1 / 2 / 4 after | exact (before/after) |
|---|---:|---|---|---:|---|---|---|
| out projection 5120x6144 | 1 | 50.4 (1) | 56.0 (1) | +11.1% | 50.4 / nan / nan | 56.0 / nan / nan | exact / exact |
| out projection 5120x6144 | 8 | 55.8 (1) | 51.4 (1) | -7.9% | 55.8 / 73.9 / 95.5 | 51.4 / 73.8 / 95.4 | exact / exact |
| out projection 5120x6144 | 16 | 63.8 (1) | 57.1 (1) | -10.5% | 63.8 / 88.5 / 114.4 | 57.1 / 93.5 / 120.8 | exact / exact |
| down 5120x17408 | 1 | 105.4 (1) | 115.5 (1) | +9.6% | 105.4 / nan / nan | 115.5 / nan / nan | exact / exact |
| down 5120x17408 | 8 | 120.8 (2) | 111.3 (1) | -7.9% | 128.5 / 120.8 / 125.6 | 111.3 / 120.9 / 125.6 | exact / exact |
| down 5120x17408 | 16 | 142.8 (2) | 132.1 (1) | -7.5% | 156.7 / 142.8 / 149.0 | 132.1 / 143.7 / 149.2 | exact / exact |
| gate+up 34816x5120 | 1 | 207.4 (1) | 206.5 (1) | -0.4% | 207.4 / nan / nan | 206.5 / nan / nan | exact / exact |
| gate+up 34816x5120 | 8 | 216.4 (1) | 216.6 (1) | +0.1% | 216.4 / nan / nan | 216.6 / nan / nan | exact / exact |
| gate+up 34816x5120 | 16 | 228.0 (1) | 227.6 (1) | -0.2% | 228.0 / nan / nan | 227.6 / nan / nan | exact / exact |
| GDN in-proj 16384x5120 | 1 | 102.4 (1) | 103.3 (1) | +0.9% | 102.4 / nan / nan | 103.3 / nan / nan | exact / exact |
| GDN in-proj 16384x5120 | 8 | 103.3 (1) | 101.9 (1) | -1.4% | 103.3 / nan / nan | 101.9 / nan / nan | exact / exact |
| GDN in-proj 16384x5120 | 16 | 106.5 (1) | 104.5 (1) | -1.9% | 106.5 / nan / nan | 104.5 / nan / nan | exact / exact |
| attention qkv 14336x5120 | 1 | 92.4 (1) | 92.7 (1) | +0.3% | 92.4 / nan / nan | 92.7 / nan / nan | exact / exact |
| attention qkv 14336x5120 | 8 | 94.8 (1) | 91.8 (1) | -3.2% | 94.8 / nan / nan | 91.8 / nan / nan | exact / exact |
| attention qkv 14336x5120 | 16 | 96.8 (1) | 91.9 (1) | -5.1% | 96.8 / nan / nan | 91.9 / nan / nan | exact / exact |
| lm_head 248320x5120 | 1 | 1442.5 (1) | 1438.5 (1) | -0.3% | 1442.5 / nan / nan | 1438.5 / nan / nan | exact / exact |
| lm_head 248320x5120 | 8 | 1508.5 (1) | 1500.8 (1) | -0.5% | 1508.5 / nan / nan | 1500.8 / nan / nan | exact / exact |
| lm_head 248320x5120 | 16 | 1568.1 (1) | 1560.8 (1) | -0.5% | 1568.1 / nan / nan | 1560.8 / nan / nan | exact / exact |
