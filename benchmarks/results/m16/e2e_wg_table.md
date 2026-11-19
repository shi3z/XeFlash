| context | config | WG=0 (before) tok/s | default (after) tok/s | gain | Main pass ms before→after | tok/cycle | same tokens & state |
|---|---|---:|---:|---:|---|---:|---|
| code | fixed8 | 123.7 | 125.4 | +1.4% | 42.1→41.4 | 6.17 | True |
| code | fixed16 | 142.4 | 147.2 | +3.4% | 48.1→46.2 | 8.08 | True |
| code | adapt-cost | 139.9 | 145.7 | +4.2% | 47.5→46.0 | 7.95 | True |
| 8k | fixed8 | 67.1 | 68.2 | +1.5% | 44.7→43.9 | 3.53 | True |
| 8k | fixed16 | 59.5 | 61.4 | +3.1% | 51.8→50.0 | 3.62 | True |
| 8k | adapt-cost | 65.6 | 65.8 | +0.3% | 45.7→45.4 | 3.53 | True |
| 30k | fixed8 | 55.3 | 56.1 | +1.3% | 51.9→51.0 | 3.31 | True |
| 30k | fixed16 | 50.0 | 51.3 | +2.6% | 62.0→60.2 | 3.55 | True |
| 30k | adapt-cost | 55.1 | 55.7 | +1.1% | 52.1→51.4 | 3.31 | True |
