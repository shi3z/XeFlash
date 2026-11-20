#!/usr/bin/env python3
"""Static analysis of the IGC-generated Xe2 (BMG) assembly of the xf_gemm kernels.

  isa_analyze.py DUMPDIR_OR_SPV... --out OUTDIR

For every `submit<WF,R,G,U,A16,PIPE>` kernel found (IGC_ShaderDumpEnable dumps of SPIR-V): ocloc compile + disasm, GRF count / scratch, the hot loop (the backward-jump
region that contains the DPAS), instruction classes, send (UGM) list with message type and immediates, DPAS accumulator chains, the SBID scoreboard
(how many loads are outstanding at every wait), 64-bit integer ops, calls (division / modulo emulation), flag-register moves.
Writes <out>/<label>.loop.asm (the loop body) and prints one JSON line per kernel on stdout.
"""
import argparse, collections, glob, json, os, re, shutil, subprocess, sys


def sh(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def kernel_label(spv):
    txt = sh(['strings', '-n', '6', spv])
    m = re.search(r'_ZTS[A-Za-z0-9_]*submit[A-Za-z0-9_]*', txt)
    if not m:
        return None
    dem = sh(['c++filt', m.group(0)]).strip()
    mm = re.search(r'(submit_exp|submit)<([^>]*)>', dem)
    return (mm.group(1) + '<' + mm.group(2).replace(' ', '') + '>') if mm else None


def disasm(spv, tag):
    od = '/tmp/claude-1000/isa_an_' + tag
    shutil.rmtree(od, ignore_errors=True)
    subprocess.run(['ocloc', 'compile', '-spirv_input', '-file', spv, '-device', 'bmg', '-out_dir', od], capture_output=True)
    b = glob.glob(od + '/*.bin')
    if not b:  # some modules (e.g. the 3-bit kernels) only build with the ESIMD front end
        subprocess.run(['ocloc', 'compile', '-spirv_input', '-file', spv, '-device', 'bmg', '-out_dir', od, '-options', '-vc-codegen'], capture_output=True)
        b = glob.glob(od + '/*.bin')
    if not b:
        return None
    st = sh(['strings', '-n', '3', b[0]])
    dd = od + '/dis'
    os.makedirs(dd, exist_ok=True)
    subprocess.run(['ocloc', 'disasm', '-file', b[0], '-device', 'bmg', '-dump', dd], capture_output=True)
    t = glob.glob(dd + '/.text*')
    if not t:
        return None
    grf = re.search(r'grf_count:\s+(\d+)', st)
    return dict(lines=open(t[0], errors='ignore').read().split('\n'), grf=int(grf[1]) if grf else -1,
                scratch=('per_thread_memory_buffers' in st and 'type:            scratch' in st), strings=st)


OPC = re.compile(r'^\s*(?:\((?P<pred>[^)]*)\)\s*)?(?P<op>[a-z][a-z0-9_]*(?:\.[A-Za-z0-9_]+)*)\s')
SBID = re.compile(r'\$(\d+)')


def parse(lines):
    ins = []
    for i, l in enumerate(lines):
        s = l.rstrip()
        if not s.strip():
            continue
        m = re.match(r'^(L\d+):', s)
        if m:
            ins.append(dict(i=i, kind='label', name=m[1], text=s))
            continue
        m = OPC.match(s)
        if not m:
            continue
        op = m['op']
        base = op.split('.')[0]
        d = dict(i=i, kind='ins', op=op, base=base, text=s, pred=m['pred'] or '')
        sw = re.search(r'\{([^}]*)\}', s)
        d['swsb'] = sw[1] if sw else ''
        d['q64'] = bool(re.search(r':u?q\b', s)) and base not in ('send', 'sendc', 'dpas', 'jmpi')
        if base in ('send', 'sendc'):
            c = s.split('//')[-1].strip() if '//' in s else ''
            d['desc'] = c
            mm = re.search(r'\{[^}]*\$(\d+)[^}]*\}', s)
            d['sbid'] = int(mm[1]) if mm and '.dst' not in mm[0] and '.src' not in mm[0] else None
            ms = re.search(r'\$(\d+)(?![.\d])', d['swsb'])
            d['sbid'] = int(ms[1]) if ms else None
            imm = re.search(r'flat\[A\+(0x[0-9a-f]+|\d+)\]', c)
            d['imm'] = int(imm[1], 0) if imm else 0
            d['msg'] = re.search(r'(load|store|atomic|fence)[a-z0-9_.]*', c)[0] if re.search(r'(load|store|atomic|fence)', c) else ''
            mr = re.search(r'wr:(\d+)\+?(\d*), rd:(\d+)', c)
            d['rd'] = int(mr[3]) if mr else 0
        if base == 'dpas':
            r = re.findall(r'(r\d+(?:\.\d+)?|null):(\w+)', s)
            d['dst'] = r[0][0] if r else ''
            d['acc'] = r[1][0] if len(r) > 1 else ''
            d['atomic'] = 'Atomic' in d['swsb']
        ins.append(d)
    return ins


def find_loop(ins):
    pos = {x['name']: k for k, x in enumerate(ins) if x['kind'] == 'label'}
    best = None
    for k, x in enumerate(ins):
        if x['kind'] != 'ins' or x['base'] not in ('jmpi', 'goto', 'while'):
            continue
        m = re.search(r'\b(L\d+)\b', x['text'])
        if m and m[1] in pos and pos[m[1]] < k:
            a, b = pos[m[1]], k
            nd = sum(1 for y in ins[a:b + 1] if y['kind'] == 'ins' and y['base'] == 'dpas')
            if nd and (best is None or nd > best[2]):
                best = (a, b, nd)
    return best


def classify(x):
    b = x['base']
    if b in ('send', 'sendc'):
        return 'load' if x.get('msg','').startswith('load') else 'store' if x.get('msg','').startswith('store') else 'send-other'
    if b == 'dpas':
        return 'dpas'
    if b == 'sync':
        return 'sync'
    if b in ('jmpi', 'goto', 'while', 'call', 'ret', 'join', 'halt', 'brc', 'brd', 'break', 'cont'):
        return 'branch'
    if b == 'cmp' or b == 'cmpn':
        return 'cmp'
    if b == 'mov' or b == 'movi':
        return 'mov'
    if b in ('mul', 'mach', 'macl', 'mad', 'mac'):
        return 'mul64' if x['q64'] or b in ('mach', 'macl') else 'mul32'
    if b in ('add', 'add3', 'addc', 'subb', 'sub', 'shl', 'shr', 'asr', 'and', 'or', 'xor', 'not', 'sel', 'bfn', 'bfe', 'bfi1', 'bfi2', 'rol', 'ror', 'lzd', 'cbit', 'avg'):
        return 'int-alu'
    if b in ('math', 'fbl', 'frc', 'rndd', 'rnde', 'rndu', 'rndz'):
        return 'math'
    return 'other:' + b


def analyse(label, ins, grf, scratch):
    lp = find_loop(ins)
    if not lp:
        return None
    a, b, _ = lp
    body = [x for x in ins[a:b + 1] if x['kind'] == 'ins']
    pre = [x for x in ins[:a] if x['kind'] == 'ins']
    post = [x for x in ins[b + 1:] if x['kind'] == 'ins']
    cls = collections.Counter(classify(x) for x in body)
    sends = [x for x in body if x['base'] in ('send', 'sendc') and x.get('msg','').startswith('load')]
    bytes_per_load = [x['rd'] * 64 for x in sends]  # GRF = 64 B on Xe2
    dp = [x for x in body if x['base'] == 'dpas']
    # accumulator chains
    accs = collections.OrderedDict()
    mindist_dp, mindist_ins = 10 ** 9, 10 ** 9
    last_dp, last_ins = {}, {}
    for k, x in enumerate(body):
        if x['base'] != 'dpas':
            continue
        d = x['dst']
        n = sum(1 for y in body[:k] if y['base'] == 'dpas')
        accs[d] = accs.get(d, 0) + 1
        if d in last_dp:
            mindist_dp = min(mindist_dp, n - last_dp[d] - 1)
            mindist_ins = min(mindist_ins, k - last_ins[d] - 1)
        last_dp[d], last_ins[d] = n, k
    # scoreboard simulation over one trip: outstanding SBIDs at each wait
    out = set()
    waits = []
    send_pos = []
    first_wait_after_send = None
    for k, x in enumerate(body):
        sw = x['swsb']
        if x['base'] == 'sync':
            toks = set(int(t) for t in SBID.findall(x['text'].split('//')[0]))
            hit = len(toks & out) if toks else len(out)
            waits.append((k, x['op'], sorted(toks), len(out), hit))
            out -= toks if toks else set()
            if not toks:
                out.clear()
        else:
            for t in re.findall(r'\$(\d+)\.dst', sw):
                if int(t) in out:
                    waits.append((k, 'dst-wait', [int(t)], len(out), 1))
                    out.discard(int(t))
        if x['base'] in ('send', 'sendc') and x.get('sbid') is not None:
            out.add(x['sbid'])
            send_pos.append(k)
    nload = len(sends)
    spread = (send_pos[-1] - send_pos[0] + 1) if send_pos else 0
    firstwait = next((w[0] for w in waits if w[3] > 0), None)
    loads_before_first_wait = sum(1 for p in send_pos if firstwait is None or p < firstwait)
    calls = [x['text'].strip()[:90] for x in pre + body + post if x['base'] == 'call']
    flagmov = [x for x in body if x['base'] == 'mov' and re.search(r'\bf\d\.\d', x['text'])]
    spill_ops = [x for x in pre + body + post if x['base'] in ('send', 'sendc') and re.search(r'scratch|spill|\.ss\b', x.get('desc', ''))]
    return dict(label=label, grf=grf, scratch=scratch, static_body=len(body), pre=len(pre), post=len(post), classes=dict(cls),
                loads=nload, load_bytes_each=sorted(set(bytes_per_load)), load_bytes_total=sum(bytes_per_load),
                load_descs=sorted(set(x['desc'].split(';')[-1].strip().split('.flat')[0] for x in sends)),
                load_imms=sorted(set(x['imm'] for x in sends)), dpas=len(dp), acc_regs=len(accs), acc_updates=list(accs.values()),
                dpas_min_gap_dpas=None if mindist_dp == 10 ** 9 else mindist_dp, dpas_min_gap_ins=None if mindist_ins == 10 ** 9 else mindist_ins,
                dpas_atomic=sum(1 for x in dp if x['atomic']), dpas_src=sorted(set(re.findall(r':(\w+)\s', ' '.join(x['text'].split('//')[0] for x in dp)))),
                q64_ops=sum(1 for x in body if x['q64']), mul64=cls.get('mul64', 0), calls_in_kernel=calls, flag_movs=len(flagmov),
                spill_sends=len(spill_ops), sync_ops=cls.get('sync', 0), waits=len(waits), send_spread_instr=spread,
                loads_before_first_wait=loads_before_first_wait, wait_list=[(w[0], w[1], w[2], w[3]) for w in waits][:24], body=[x['text'] for x in body])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('inputs', nargs='+')
    ap.add_argument('--out', required=True)
    ap.add_argument('--wf', default='0')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    spvs = []
    for p in a.inputs:
        spvs += sorted(glob.glob(p + '/**/*.spv', recursive=True)) if os.path.isdir(p) else [p]
    seen = {}
    for spv in spvs:
        lab = kernel_label(spv)
        if not lab or not lab.startswith('submit<' + a.wf + ','):
            continue
        tag = re.sub(r'\W', '_', os.path.dirname(spv).split('/')[-1] + '_' + lab)
        if lab in seen and seen[lab] == tag.split('_submit')[0]:
            continue
        d = disasm(spv, tag)
        if not d:
            continue
        r = analyse(lab, parse(d['lines']), d['grf'], d['scratch'])
        if not r:
            continue
        r['run'] = os.path.dirname(spv).split('/')[-1]
        open(os.path.join(a.out, tag + '.loop.asm'), 'w').write('\n'.join(r['body']) + '\n')
        r2 = {k: v for k, v in r.items() if k != 'body'}
        print(json.dumps(r2))


if __name__ == '__main__':
    main()
