task|config|tok/s mean (min-max)|tokens/pass|accept1|Main ms/pass|Draft ms/pass|answer = expected|same tokens+state as greedy
edit_code|greedy|24.8 (24.8-24.8)|1.00|-|40.34|-|0/5|-
edit_code|bd2:fixed8|100.4 (100.0-100.6)|5.17|0.977|43.34|6.16|0/5|5/5
edit_code|bd2:fixed16|96.2 (96.2-96.3)|5.65|0.976|49.32|7.34|0/5|5/5
edit_code|bd2:adapt-cost|101.4 (101.4-101.5)|5.42|0.976|45.00|6.44|0/5|5/5
edit_jsonl|greedy|25.1 (25.1-25.1)|1.00|-|39.88|-|5/5|-
edit_jsonl|bd2:fixed8|157.0 (156.4-157.1)|7.95|1.000|42.28|6.15|5/5|5/5
edit_jsonl|bd2:fixed16|261.4 (260.8-261.6)|15.26|1.000|48.11|7.41|5/5|5/5
edit_jsonl|bd2:adapt-cost|262.0 (261.9-262.1)|15.26|1.000|48.02|7.36|5/5|5/5
edit_jsonl_long|greedy|24.5 (24.5-24.5)|1.00|-|40.83|-|5/5|-
edit_jsonl_long|bd2:fixed8|151.2 (151.1-151.3)|7.96|1.000|44.26|6.12|5/5|5/5
edit_jsonl_long|bd2:fixed16|247.1 (247.0-247.1)|15.06|1.000|50.70|7.40|5/5|5/5
edit_jsonl_long|bd2:adapt-cost|248.0 (247.9-248.1)|15.10|1.000|50.63|7.38|5/5|5/5
