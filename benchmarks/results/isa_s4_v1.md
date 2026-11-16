| kernel | inst | GRF | DPAS | block loads | block stores | gather/scatter | SLM | spill | barriers |
|---|---|---|---|---|---|---|---|---|---|
| combine_int | 136 | 128 | - | 1x 32B, 4x 64B | 1x 64B | 2 | 0 | 0 B | 0 |
| combine_int+a16 | 166 | 128 | - | 1x 32B, 5x 64B | 1x 64B | 2 | 0 | 0 B | 0 |
| gemm s4 R1 G1 U4 | 344 | 128 | 8x dpas.8x1 s4xb | 1x 128B, 8x 256B, 9x 32B, 2x 64B | 2x 64B | 2 | 0 | 0 B | 0 |
| gemm s4 R8 G1 U2 | 495 | 128 | 2x dpas.8x8 s4xb | 1x 128B, 4x 256B, 3x 32B, 2x 64B | 16x 64B | 0 | 0 | 0 B | 0 |
| gemm s4 R8 G4 U1 | 1299 | 128 | 8x dpas.8x8 s4xb | 3x 128B, 10x 256B, 1x 32B, 2x 64B | 64x 64B | 0 | 0 | 0 B | 0 |
| gemm s4+a16 R1 G1 U4 | 418 | 128 | 8x dpas.8x1 s4xb, 8x dpas.8x1 s4xub | 1x 128B, 8x 256B, 17x 32B, 2x 64B | 3x 64B | 2 | 0 | 0 B | 0 |
| gemm s4+a16 R8 G1 U2 | 685 | 128 | 4x dpas.8x8 s4xb, 4x dpas.8x8 s4xub | 1x 128B, 12x 256B, 3x 32B, 2x 64B | 24x 64B | 0 | 0 | 0 B | 0 |
