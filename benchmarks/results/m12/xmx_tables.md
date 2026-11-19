### Production kernels, cold weights, 1 segment: time, bandwidth of the stored weights, F = 2MNK (logical), and the XMX work actually issued

| shape | weights | m | time us | stored MB | GB/s | F = 2MNK TFLOPS | DPAS ops issued (G) | XMX TOPS (physical) | share of the format's XMX peak | dpas per thread (dynamic) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| out_proj 5120x6144 | s4 + 16-bit act (2 planes) | 1 | 61.1 | 15.7 | 257 | 1.03 | 0.13 | 2.1 | 1% | 384 |
| out_proj 5120x6144 | s4 + 16-bit act (2 planes) | 8 | 65.9 | 15.7 | 239 | 7.64 | 1.01 | 15.3 | 8% | 384 |
| out_proj 5120x6144 | s4 + 16-bit act (2 planes) | 16 | 77.5 | 15.7 | 203 | 12.99 | 2.01 | 26.0 | 13% | 768 |
| out_proj 5120x6144 | s4>s8 + 8-bit act | 1 | 81.2 | 15.7 | 194 | 0.77 | 0.06 | 0.8 | 0% | 192 |
| out_proj 5120x6144 | s4>s8 + 8-bit act | 8 | 83.1 | 15.7 | 189 | 6.06 | 0.50 | 6.1 | 3% | 192 |
| out_proj 5120x6144 | s4>s8 + 8-bit act | 16 | 96.6 | 15.7 | 163 | 10.42 | 1.01 | 10.4 | 5% | 384 |
| out_proj 5120x6144 | s3 + 16-bit act (2 planes) | 1 | 70.2 | 11.8 | 168 | 0.90 | 0.13 | 1.8 | 1% | 384 |
| out_proj 5120x6144 | s3 + 16-bit act (2 planes) | 8 | 74.8 | 11.8 | 158 | 6.73 | 1.01 | 13.5 | 7% | 384 |
| out_proj 5120x6144 | s3 + 16-bit act (2 planes) | 16 | 73.8 | 11.8 | 160 | 13.64 | 2.01 | 27.3 | 14% | 768 |
| out_proj 5120x6144 | bf16 + bf16 act | 1 | 167.3 | 62.9 | 376 | 0.38 | 0.06 | 0.4 | 0% | 384 |
| out_proj 5120x6144 | bf16 + bf16 act | 8 | 170.5 | 62.9 | 369 | 2.95 | 0.50 | 3.0 | 3% | 384 |
| out_proj 5120x6144 | bf16 + bf16 act | 16 | 196.5 | 62.9 | 320 | 5.12 | 1.01 | 5.1 | 5% | 768 |
| merged.gate_up 34816x5120 | s4 + 16-bit act (2 planes) | 1 | 230.1 | 89.1 | 387 | 1.55 | 0.71 | 3.1 | 2% | 320 |
| merged.gate_up 34816x5120 | s4 + 16-bit act (2 planes) | 8 | 242.5 | 89.1 | 368 | 11.76 | 5.70 | 23.5 | 12% | 320 |
| merged.gate_up 34816x5120 | s4 + 16-bit act (2 planes) | 16 | 253.6 | 89.1 | 351 | 22.49 | 11.41 | 45.0 | 23% | 640 |
| merged.gate_up 34816x5120 | s4>s8 + 8-bit act | 1 | 256.8 | 89.1 | 347 | 1.39 | 0.36 | 1.4 | 1% | 160 |
| merged.gate_up 34816x5120 | s4>s8 + 8-bit act | 8 | 263.0 | 89.1 | 339 | 10.84 | 2.85 | 10.8 | 6% | 160 |
| merged.gate_up 34816x5120 | s4>s8 + 8-bit act | 16 | 270.7 | 89.1 | 329 | 21.07 | 5.70 | 21.1 | 11% | 320 |
| merged.gate_up 34816x5120 | s3 + 16-bit act (2 planes) | 1 | 194.3 | 66.8 | 344 | 1.83 | 0.71 | 3.7 | 2% | 320 |
| merged.gate_up 34816x5120 | s3 + 16-bit act (2 planes) | 8 | 221.8 | 66.8 | 301 | 12.86 | 5.70 | 25.7 | 13% | 320 |
| merged.gate_up 34816x5120 | s3 + 16-bit act (2 planes) | 16 | 242.1 | 66.8 | 276 | 23.56 | 11.41 | 47.1 | 24% | 640 |
| merged.gate_up 34816x5120 | bf16 + bf16 act | 1 | 837.9 | 356.5 | 425 | 0.43 | 0.36 | 0.4 | 0% | 320 |
| merged.gate_up 34816x5120 | bf16 + bf16 act | 8 | 854.9 | 356.5 | 417 | 3.34 | 2.85 | 3.3 | 3% | 320 |
| merged.gate_up 34816x5120 | bf16 + bf16 act | 16 | 873.8 | 356.5 | 408 | 6.53 | 5.70 | 6.5 | 7% | 640 |

### A-H (same thread layout, tile loop and epilogue), 8 tokens, 1 segment, cold; us and overlap


out_proj 5120x6144, s4: A 66.1 | B 66.0 | C 40.8 | D 98.7 | E 65.9 | F 67.4 | G 74.4 | H 24.3
  load time (A) 66.1 us, XMX time (H) 24.3 us (25% of D); D - A = 32.6 us; overlap factor of D = (A+H-D)/min(A,H) = -0.34, of E = 1.01

out_proj 5120x6144, s3: A 62.9 | B 68.5 | C 41.5 | D 80.3 | E 71.9 | F 73.7 | G 65.7 | H 24.4
  load time (A) 62.9 us, XMX time (H) 24.4 us (30% of D); D - A = 17.4 us; overlap factor of D = (A+H-D)/min(A,H) = 0.29, of E = 0.63

merged.gate_up 34816x5120, s4: A 237.1 | B 237.1 | C 72.0 | D 245.1 | E 241.9 | F 237.4 | G 239.9 | H 62.3
  load time (A) 237.1 us, XMX time (H) 62.3 us (25% of D); D - A = 8.0 us; overlap factor of D = (A+H-D)/min(A,H) = 0.87, of E = 0.92

merged.gate_up 34816x5120, s3: A 193.7 | B 199.7 | C 74.5 | D 254.3 | E 223.9 | F 206.5 | G 204.1 | H 61.9
  load time (A) 193.7 us, XMX time (H) 61.9 us (24% of D); D - A = 60.6 us; overlap factor of D = (A+H-D)/min(A,H) = 0.02, of E = 0.51

out_proj 5120x6144, s4exp8: A 66.1 | B 114.7 | C 41.4 | D 123.0 | E 89.2 | F 123.0 | G 74.5 | H 24.5
  load time (A) 66.1 us, XMX time (H) 24.5 us (20% of D); D - A = 56.9 us; overlap factor of D = (A+H-D)/min(A,H) = -1.32, of E = 0.06

merged.gate_up 34816x5120, s4exp8: A 237.2 | B 262.8 | C 75.0 | D 273.5 | E 265.4 | F 268.7 | G 239.9 | H 64.2
  load time (A) 237.2 us, XMX time (H) 64.2 us (23% of D); D - A = 36.3 us; overlap factor of D = (A+H-D)/min(A,H) = 0.43, of E = 0.56
