#!/usr/bin/env python3
import sys,collections,statistics as s
d=collections.defaultdict(list); ex=collections.defaultdict(set)
for l in open(sys.argv[1]):
    p=l.split()
    if len(p)>=6 and p[0]!='done':
        try: d[(p[0],p[1],p[2])].append(float(p[4])); ex[(p[0],p[1],p[2])].add(p[5])
        except: pass
shapes=sorted({k[0] for k in d}); ms=sorted({k[1] for k in d}); pads=sorted({k[2] for k in d},key=lambda x:int(x[3:]))
print('median ms (min..max), n, results; delta vs pad0')
for m in ms:
  for sh in shapes:
    b=s.median(d[(sh,m,'pad0')]) if (sh,m,'pad0') in d else None
    cells=[]
    for pd in pads:
        v=d.get((sh,m,pd))
        if not v: continue
        md=s.median(v); cells.append('%s %.4f (%.4f..%.4f) n=%d %s%s'%(pd,md,min(v),max(v),len(v),','.join(sorted(ex[(sh,m,pd)])),'' if pd=='pad0' or not b else ' %+.1f%%'%((md/b-1)*100)))
    print('%-16s %-4s | '%(sh,m)+' | '.join(cells))
