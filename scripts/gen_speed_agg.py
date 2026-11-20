import json,glob,statistics as S,sys
R=sys.argv[1]
def rows(f):
    return json.load(open(f))
print("## A: 5 repeats (one process each, warm-up prompt discarded; measured = last 3 rows)")
print("ctx|config|tok/s mean (min-max)|main ms|draft ms|tok/pass|accept1|same tok/state")
for c in ("8k","30k","60k"):
    per={}
    for f in sorted(glob.glob(f"{R}/A_{c}_r*.json")):
        for r in rows(f)[-3:]:
            per.setdefault(r["drafter"],[]).append(r)
    for d,v in per.items():
        g=lambda k:[x[k] for x in v]
        m=lambda k:S.mean(g(k))
        print(f"{c}|{d}|{m('tok_per_s'):.1f} ({min(g('tok_per_s')):.1f}-{max(g('tok_per_s')):.1f})|{m('main_ms'):.2f}|{m('draft_ms'):.2f}|{m('tokens_per_pass'):.2f}|{m('accept1'):.3f}|{all(x['same_tokens'] and x['same_state'] for x in v)} n={len(v)}")
for n in ("B_sustained_8k","C_code"):
    print("##",n)
    for r in rows(f"{R}/{n}.json"):
        print(r["prompt"],r["drafter"],f"{r['tok_per_s']:.1f}",f"main {r['main_ms']:.1f} draft {r['draft_ms']:.1f} tpp {r['tokens_per_pass']:.2f} acc {r['accept1']:.3f}",r["new_tokens"],r["same_tokens"],r["same_state"])
