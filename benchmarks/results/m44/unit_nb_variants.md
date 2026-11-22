variant|gate_up|qkvz|attn_qkv|out_proj|down|lm_head|GEMM sum @64 rows (ms)|exact
split (128 GRF, old default)|0.3692|0.2063|0.1592|0.0871|0.1997|2.9729|57.4|True
lgrf (256 GRF, 32 tokens: adopted)|0.3107|0.1709|0.1364|0.0791|0.1998|2.3439|50.5|True
SLM + full barrier, 2 tiles/stage|0.4335|0.2336|0.1828|0.0958|0.2101|3.0752|64.5|True
nb: 1 producer, 2 tiles x 4 buffers|0.3981|0.1978|0.1868|0.1230|0.3036|2.8178|68.1|True
nb4: 4 tiles x 3 buffers|0.4015|0.1971|0.1849|0.1156|0.2795|2.8679|66.3|True
nb1: 2 tiles x 2 buffers|0.4030|0.2001|0.1894|0.1247|0.3023|2.8750|68.6|True
nb2p: 2 producers (plane split)|0.4368|0.2159|0.1783|0.1154|0.2799|2.9586|69.4|True
nb2p4: 2 producers, 4 tiles|0.4120|0.2048|0.1741|0.1106|0.2181|2.7914|62.8|True
nb, local fences only|0.3945|0.1962|0.1857|0.1219|0.3037|2.7841|67.7|True
nb, producer loads one stage ahead|0.3966|0.1976|0.1867|0.1223|0.3030|2.7993|67.9|True
nbl: 8 consumers x 32 tokens, 256 GRF|0.4879|0.2448|0.2320|0.1242|0.4569|3.2712|87.2|True
nbl4: same, 4 tiles x 3 buffers|0.5119|0.2574|0.2283|0.1426|0.4962|3.4718|93.1|True
