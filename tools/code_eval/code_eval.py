#!/usr/bin/env python3
"""Grade generated code: decode token files, extract the code block, compile / run hidden tests in a bubblewrap sandbox.

    code_eval.py <checkpoint_dir> <tokens_dir> <out.json>

Token files are named <prompt>__<label>.json (written by `xf-run cmp --save-tokens`); the task is the prompt name without a
`codectx<N>k_` prefix. Sandbox: no network (--unshare-all), read-only system directories, empty tmpfs home/work dir, CPU/memory/
process/file-size limits via prlimit, wall-clock timeout; the generated program only ever sees its own scratch directory.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from transformers import AutoTokenizer

sys.path.insert(0, str(Path(__file__).parent))
from code_tasks import TASKS, fib_mod_ref  # noqa: E402

import glob
RUSTC = (glob.glob("/data/B60special/toolchain/rustup/toolchains/*/bin/rustc") or ["rustc"])[0]  # the real rustc, not the rustup shim


def sandbox(cmd, workdir, timeout=60, rw_extra=()):
    base = ["bwrap", "--unshare-all", "--die-with-parent", "--new-session", "--ro-bind", "/usr", "/usr", "--symlink", "usr/bin", "/bin",
            "--symlink", "usr/lib", "/lib", "--symlink", "usr/lib64", "/lib64", "--ro-bind", "/etc/alternatives", "/etc/alternatives", "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp",
            "--bind", workdir, "/work", "--chdir", "/work", "--setenv", "HOME", "/work", "--setenv", "PATH", "/usr/bin:/bin"]
    for p in rw_extra:
        base += ["--ro-bind", p, p]
    lim = ["prlimit", "--cpu=40", "--as=4294967296", "--nproc=256", "--fsize=67108864"]
    try:
        r = subprocess.run(base + lim + cmd, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
        return r.returncode, (r.stdout + r.stderr)[-1500:]
    except subprocess.TimeoutExpired:
        return 124, "timeout"


def extract(text, lang, name):
    """Code of the first fenced block that mentions the wanted name (closed fence required unless it is the last block)."""
    tags = {"python": ("python", "py"), "rust": ("rust", "rs"), "cpp": ("cpp", "c++", "cc")}[lang]
    blocks = [(m.group(1).lower(), m.group(2), True) for m in re.finditer(r"```([A-Za-z+]*)\n(.*?)```", text, re.S)]
    m = re.search(r"```([A-Za-z+]*)\n((?:(?!```).)*)$", text, re.S)
    closed = len(blocks)
    if m and text.count("```") % 2 == 1:
        blocks.append((m.group(1).lower(), m.group(2), False))
    for tag, code, ok in blocks:
        if (tag in tags or tag == "") and name in code:
            return code, ok
    return None, False


def strip_tests(code, lang):
    """Keep only the solution: drop the model's own tests / main / examples, so that a typo in test code does not hide a correct function."""
    import ast
    if lang == "python":
        out, chunk = [], []
        def flush():
            if not chunk:
                return
            src = "\n".join(chunk)
            try:
                tree = ast.parse(src)
            except SyntaxError:
                chunk.clear()
                return
            keep = all(isinstance(n, (ast.Import, ast.ImportFrom, ast.FunctionDef, ast.ClassDef, ast.Assign)) for n in tree.body) and \
                not any(isinstance(n, (ast.FunctionDef, ast.ClassDef)) and (n.name.startswith("test") or n.name in ("main", "run_tests")) for n in tree.body)
            if keep:
                out.append(src)
            chunk.clear()
        for line in code.split("\n"):
            if line and not line[0].isspace() and not line.startswith(("#", ")", "]", "}")) and chunk and not chunk[-1].startswith("@"):
                flush()
            chunk.append(line)
        flush()
        return "\n\n".join(out)
    # rust / c++: split into top-level items at brace depth 0
    items, cur, depth = [], [], 0
    for line in code.split("\n"):
        cur.append(line)
        depth += line.count("{") - line.count("}")
        if depth <= 0 and (line.rstrip().endswith("}") or line.rstrip().endswith(";") or line.startswith("#")):
            items.append("\n".join(cur)); cur = []; depth = 0
    if cur:
        items.append("\n".join(cur))
    keep = []
    for it in items:
        head = it.strip()
        if lang == "rust" and ("#[cfg(test)]" in head or re.search(r"\bfn\s+main\b", head) or "mod tests" in head or "#[test]" in head):
            continue
        if lang == "cpp" and (re.search(r"\bint\s+main\s*\(", head) or re.search(r"\bvoid\s+(test|run_tests)\w*\s*\(", head)):
            continue
        keep.append(it)
    return "\n".join(keep)


def grade(task, code):
    t = TASKS[task]
    lang = t["lang"]
    with tempfile.TemporaryDirectory() as d:
        w = Path(d)
        if lang == "python":
            (w / "gen.py").write_text(code)
            (w / "test.py").write_text(t["test"])
            rc, o = sandbox(["python3", "test.py"], str(w))
            return "pass" if rc == 0 and "OK" in o else ("fail" if rc != 124 else "timeout"), o
        if lang == "rust":
            (w / "gen.rs").write_text(code + "\n" + t["test"])
            rc, o = sandbox([RUSTC, "--edition", "2021", "--test", "-A", "warnings", "-o", "gen_test", "gen.rs"], str(w), 120,
                            rw_extra=("/data/B60special/toolchain",))
            if rc != 0:
                return "compile_error", o
            rc, o = sandbox(["./gen_test"], str(w))
            return ("pass" if rc == 0 else "fail"), o
        if lang == "cpp":
            test = t["test"]
            if task == "cpp_fib":
                test = test.replace("@F90@", str(fib_mod_ref(90, 1000000007))).replace("@FBIG@", str(fib_mod_ref(10**18, 1000000007)))
            src = "#include <vector>\n#include <utility>\n#include <algorithm>\n#include <cstdint>\n#define main gen_main\n" + code + "\n" + test
            (w / "gen.cpp").write_text(src)
            rc, o = sandbox(["g++", "-std=c++17", "-O1", "-w", "-o", "gen_test", "gen.cpp"], str(w), 120)
            if rc != 0:
                return "compile_error", o
            rc, o = sandbox(["./gen_test"], str(w))
            return ("pass" if rc == 0 and "OK" in o else "fail"), o
    return "n/a", ""


def main():
    tok = AutoTokenizer.from_pretrained(sys.argv[1])
    res = []
    for f in sorted(Path(sys.argv[2]).glob("*.json")):
        prompt, label = f.stem.split("__", 1)
        task = re.sub(r"^codectx\d+k_", "", prompt)
        ids = json.loads(f.read_text())
        eos = next((i for i, t in enumerate(ids) if t in (248046, 248044)), None)  # <|im_end|>, <|endoftext|>
        finished = eos is not None
        if finished:
            ids = ids[:eos]
        text = tok.decode(ids)
        row = dict(prompt=prompt, label=label, tokens=len(ids), task=task, finished=finished)
        if task in TASKS:
            code, closed = extract(text, TASKS[task]["lang"], TASKS[task]["name"])
            row["complete_block"] = bool(closed)
            if code is None:
                row["result"] = "no_code"
            else:
                row["result"], row["log"] = grade(task, code)
                sol = strip_tests(code, TASKS[task]["lang"])
                row["solution_only"], row["solution_log"] = grade(task, sol) if sol.strip() else ("no_code", "")
        else:
            row["result"] = "not graded (free-form prompt)"
        res.append(row)
        print(prompt, label, row["result"], flush=True)
    Path(sys.argv[3]).write_text(json.dumps(res, indent=1))


if __name__ == "__main__":
    main()
