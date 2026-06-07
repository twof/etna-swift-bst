import sys

def tokenize(s):
    out, cur = [], ""
    for ch in s:
        if ch in "()":
            if cur: out.append(cur); cur=""
            out.append(ch)
        elif ch.isspace():
            if cur: out.append(cur); cur=""
        else: cur += ch
    if cur: out.append(cur)
    return out

def parse(toks):
    t = toks.pop(0)
    if t == "(":
        lst=[]
        while toks[0] != ")":
            lst.append(parse(toks))
        toks.pop(0); return lst
    return t

def tree(e):
    if e == "E": return "E"
    if isinstance(e, list) and e == ["E"]: return "E"
    assert isinstance(e, list) and e[0] == "T", e
    return f"(T {tree(e[1])} {e[2]} {e[3]} {tree(e[4])})"

def arg(e):
    return tree(e) if (e == "E" or isinstance(e, list)) else e  # nat literal plain

lines = [l for l in open("/tmp/bst-inputs.tsv").read().splitlines() if l.strip()]
print("Require Import String.")
print("From BST Require Import QcEtna Spec Impl.")
print("Open Scope nat_scope.")
print("")
for idx, line in enumerate(lines):
    prop, inp = line.split("\t")
    parsed = parse(tokenize(inp))
    elems = parsed if isinstance(parsed, list) else [parsed]
    coq_args = " ".join(arg(e) for e in elems)
    print(f"Compute ({idx}, prop_{prop} {coq_args}).")
