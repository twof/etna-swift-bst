import random
random.seed(12345)

# BST insert (matches the clean algorithm) to build VALID BSTs.
def insert(k, v, t):
    if t is None:
        return (None, k, v, None)
    l, k2, v2, r = t
    if k < k2:   return (insert(k, v, l), k2, v2, r)
    elif k2 < k: return (l, k2, v2, insert(k, v, r))
    else:        return (l, k2, v, r)

def to_sexpr(t):
    if t is None: return "E"
    l, k, v, r = t
    return f"(T {to_sexpr(l)} {k} {v} {to_sexpr(r)})"

def rand_valid_tree():
    n = random.randint(0, 5)
    keys = random.sample(range(0, 7), n)
    t = None
    for k in keys:
        t = insert(k, random.randint(0, 3), t)
    return t

def rand_arbitrary_tree(depth=3):
    if depth == 0 or random.random() < 0.45:
        return None
    return (rand_arbitrary_tree(depth-1), random.randint(0, 6),
            random.randint(0, 3), rand_arbitrary_tree(depth-1))

def a_tree(i):
    # mostly valid (exercise the real logic), some arbitrary (exercise isBST/discards)
    return rand_arbitrary_tree() if (i % 4 == 3) else rand_valid_tree()

# (num_trees, num_ints) per property; arg order matches both specs.
specs = {
    "InsertValid": (1, 2), "DeleteValid": (1, 1), "UnionValid": (2, 0),
    "InsertPost": (1, 3), "DeletePost": (1, 2), "UnionPost": (2, 1),
    "InsertModel": (1, 2), "DeleteModel": (1, 1), "UnionModel": (2, 0),
    "InsertInsert": (1, 4), "InsertDelete": (1, 3), "InsertUnion": (2, 2),
    "DeleteInsert": (1, 3), "DeleteDelete": (1, 2), "DeleteUnion": (2, 1),
    "UnionDeleteInsert": (2, 2), "UnionUnionIdem": (1, 0), "UnionUnionAssoc": (3, 0),
}

PER = 22
out = []
for prop, (nt, ni) in specs.items():
    for i in range(PER):
        trees = [to_sexpr(a_tree(i + j)) for j in range(nt)]
        ints = [str(random.randint(0, 6)) for _ in range(ni)]
        args = trees + ints
        out.append(f"{prop}\t({' '.join(args)})")

with open("/tmp/bst-inputs.tsv", "w") as f:
    f.write("\n".join(out) + "\n")
print(f"wrote {len(out)} inputs across {len(specs)} properties")
