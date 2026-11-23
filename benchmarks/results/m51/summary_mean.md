task|config|tok/s mean (min-max)|tokens/pass|accept1|Main ms/pass|Draft ms/pass|answer = expected|same tokens+state as greedy
edit_code|greedy|26.5 (26.5-26.5)|1.00|-|37.70|-|0/5|-
edit_code|bd2:adapt-cost|108.3 (108.2-108.7)|5.45|0.974|42.88|6.59|0/5|5/5
edit_code|hv4+bd2:fixed16|424.7 (424.6-424.8)|29.07|0.806|64.08|3.53|0/5|5/5
edit_jsonl|greedy|26.8 (26.8-26.8)|1.00|-|37.28|-|5/5|-
edit_jsonl|bd2:adapt-cost|289.7 (289.6-289.8)|15.26|1.000|44.66|7.40|5/5|5/5
edit_jsonl|hv4+bd2:fixed16|804.1 (803.8-804.2)|59.48|1.000|71.54|1.86|5/5|5/5
edit_jsonl_long|greedy|26.2 (26.1-26.2)|1.00|-|38.24|-|5/5|-
edit_jsonl_long|bd2:adapt-cost|273.5 (273.4-273.6)|15.10|1.000|47.13|7.38|5/5|5/5
edit_jsonl_long|hv4+bd2:fixed16|725.3 (725.3-725.5)|59.58|1.000|79.86|1.70|5/5|5/5
