| kernel | loop | calls measured | send / call (M) | DPAS / call (M) (XMX instr / 8) | ALU1 / call (M) | ALU0 / call (M) | INT64 / call (M) | INT16 / call (M) | control / call (M) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| gate+up m=8 | old | 7372 | 1.04 | 0.66 | 13.17 | 0.62 | 3.65 | 1.47 | 0.50 |
| gate+up m=8 | new | 8152 | 1.03 | 0.66 | 1.55 | 0.14 | 1.06 | 0.02 | 0.09 |
| out proj m=8 | old | 10002 | 0.16 | 0.10 | 1.85 | 0.08 | 0.51 | 0.20 | 0.07 |
| out proj m=8 | new | 10002 | 0.16 | 0.10 | 0.22 | 0.02 | 0.16 | 0.00 | 0.01 |
