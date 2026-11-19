| shape | weights | m | old loop, best segs (us) | new loop, best segs (us) | change | exact vs CPU reference (old / new) |
|---|---|---:|---:|---:|---:|---|
| out projection 5120x6144 | s4+16-bit act | 1 | 61.1 (segs 1) | 50.5 (segs 1) | -17.3% | exact / exact |
| out projection 5120x6144 | s4+16-bit act | 8 | 65.9 (segs 1) | 55.6 (segs 1) | -15.6% | exact / exact |
| out projection 5120x6144 | s4+16-bit act | 16 | 77.5 (segs 1) | 65.8 (segs 1) | -15.1% | exact / exact |
| down 5120x17408 | s4+16-bit act | 1 | 116.2 (segs 1) | 105.4 (segs 1) | -9.3% | exact / exact |
| down 5120x17408 | s4+16-bit act | 8 | 131.4 (segs 2) | 120.8 (segs 2) | -8.1% | exact / exact |
| down 5120x17408 | s4+16-bit act | 16 | 160.0 (segs 2) | 147.7 (segs 4) | -7.7% | exact / exact |
| gate+up 34816x5120 | s4+16-bit act | 1 | 230.2 (segs 1) | 207.5 (segs 1) | -9.9% | exact / exact |
| gate+up 34816x5120 | s4+16-bit act | 8 | 242.5 (segs 1) | 216.5 (segs 1) | -10.7% | exact / exact |
| gate+up 34816x5120 | s4+16-bit act | 16 | 253.6 (segs 1) | 226.8 (segs 1) | -10.6% | exact / exact |
| GDN in-proj 16384x5120 | s4+16-bit act | 1 | 111.3 (segs 1) | 102.3 (segs 1) | -8.1% | exact / exact |
| GDN in-proj 16384x5120 | s4+16-bit act | 8 | 115.3 (segs 1) | 103.2 (segs 1) | -10.5% | exact / exact |
| GDN in-proj 16384x5120 | s4+16-bit act | 16 | 118.7 (segs 1) | 105.9 (segs 1) | -10.8% | exact / exact |
| attention qkv 14336x5120 | s4+16-bit act | 1 | 103.4 (segs 1) | 92.3 (segs 1) | -10.7% | exact / exact |
| attention qkv 14336x5120 | s4+16-bit act | 8 | 106.7 (segs 1) | 94.7 (segs 1) | -11.2% | exact / exact |
| attention qkv 14336x5120 | s4+16-bit act | 16 | 109.0 (segs 1) | 96.6 (segs 1) | -11.4% | exact / exact |
| lm_head 248320x5120 | s4+16-bit act | 1 | 1472.7 (segs 1) | 1442.8 (segs 1) | -2.0% | exact / exact |
| lm_head 248320x5120 | s4+16-bit act | 8 | 1571.0 (segs 1) | 1508.7 (segs 1) | -4.0% | exact / exact |
| lm_head 248320x5120 | s4+16-bit act | 16 | 1770.8 (segs 1) | 1567.2 (segs 1) | -11.5% | exact / exact |
| out projection 5120x6144 | s3+16-bit act | 1 | 70.3 (segs 1) | 54.4 (segs 1) | -22.6% | exact / exact |
| out projection 5120x6144 | s3+16-bit act | 8 | 59.9 (segs 4) | 46.0 (segs 4) | -23.2% | exact / exact |
| out projection 5120x6144 | s3+16-bit act | 16 | 73.6 (segs 2) | 56.1 (segs 1) | -23.8% | exact / exact |
| down 5120x17408 | s3+16-bit act | 1 | 144.3 (segs 1) | 115.3 (segs 1) | -20.1% | exact / exact |
| down 5120x17408 | s3+16-bit act | 8 | 117.7 (segs 4) | 100.8 (segs 4) | -14.4% | exact / exact |
| down 5120x17408 | s3+16-bit act | 16 | 139.8 (segs 4) | 140.5 (segs 4) | +0.5% | exact / exact |
| gate+up 34816x5120 | s3+16-bit act | 1 | 194.4 (segs 1) | 176.5 (segs 1) | -9.2% | exact / exact |
| gate+up 34816x5120 | s3+16-bit act | 8 | 221.8 (segs 1) | 183.0 (segs 1) | -17.5% | exact / exact |
| gate+up 34816x5120 | s3+16-bit act | 16 | 242.1 (segs 1) | 239.3 (segs 1) | -1.2% | exact / exact |
| GDN in-proj 16384x5120 | s3+16-bit act | 1 | 96.8 (segs 1) | 81.8 (segs 1) | -15.5% | exact / exact |
| GDN in-proj 16384x5120 | s3+16-bit act | 8 | 106.3 (segs 1) | 87.9 (segs 1) | -17.3% | exact / exact |
| GDN in-proj 16384x5120 | s3+16-bit act | 16 | 118.7 (segs 1) | 112.0 (segs 1) | -5.6% | exact / exact |
| attention qkv 14336x5120 | s3+16-bit act | 1 | 83.8 (segs 1) | 73.3 (segs 1) | -12.5% | exact / exact |
| attention qkv 14336x5120 | s3+16-bit act | 8 | 97.8 (segs 1) | 79.0 (segs 1) | -19.2% | exact / exact |
| attention qkv 14336x5120 | s3+16-bit act | 16 | 106.4 (segs 1) | 98.9 (segs 1) | -7.0% | exact / exact |
