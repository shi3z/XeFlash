task|config|tok/s mean (min-max)|tokens/pass|accept1|Main ms/pass|Draft ms/pass|answer = expected|same tokens+state as greedy
edit_code|greedy|26.6 (26.6-26.6)|1.00|-|37.58|-|0/5|-
edit_code|bd2:adapt-cost|109.1 (108.9-109.2)|5.48|0.973|42.70|6.63|0/5|5/5
edit_code|hv4+bd2:fixed16|428.5 (428.5-428.5)|29.07|0.806|63.48|3.54|0/5|5/5
edit_jsonl|greedy|26.9 (26.9-26.9)|1.00|-|37.12|-|5/5|-
edit_jsonl|bd2:adapt-cost|291.4 (291.2-291.5)|15.26|1.000|44.34|7.41|5/5|5/5
edit_jsonl|hv4+bd2:fixed16|811.6 (811.5-811.7)|59.48|1.000|70.85|1.87|5/5|5/5
edit_jsonl_long|greedy|26.3 (26.3-26.3)|1.00|-|38.06|-|5/5|-
edit_jsonl_long|bd2:adapt-cost|275.0 (274.8-275.1)|15.10|1.000|46.83|7.39|5/5|5/5
edit_jsonl_long|hv4+bd2:fixed16|731.2 (731.1-731.2)|59.58|1.000|79.20|1.71|5/5|5/5
