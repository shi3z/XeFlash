| shape | calls / pass | MB | floor fit us | read-only probe us | old us | new us | new vs floor | old vs floor |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| gate+up 34816x5120 | 64 | 89.1 | 213.3 | 213.8 | 242.5 | 216.5 | +2% | +14% |
| down 5120x17408 | 64 | 44.6 | 112.2 | 110.0 | 131.4 | 120.8 | +8% | +17% |
| GDN in-proj 16384x5120 | 48 | 41.9 | 106.0 | 102.2 | 115.3 | 103.2 | -3% | +9% |
| attention qkv 14336x5120 | 16 | 36.7 | 94.2 | 90.4 | 106.7 | 94.7 | +1% | +13% |
| out projection 5120x6144 | 64 | 15.7 | 46.5 | 54.9 | 65.9 | 55.6 | +20% | +42% |
| lm_head 248320x5120 | 1 | 635.7 | 1455.6 | 1455.1 | 1571.0 | 1508.7 | +4% | +8% |
| **sum per 8-token pass (ms)** | | | **31.86** | 32.04 | **36.96** | **33.12** | **+4.0%** | +16.0% |

GEMM share of the floor: old 86%, new 96% (fit floor); bytes per pass 12.8 GB at the datasheet 456 GB/s = 28.1 ms: old 76%, new 85%
