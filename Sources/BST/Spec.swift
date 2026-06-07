// BST properties + reference "model" list operations, ported from ETNA's
// reference workload (etna-python-bst `spec.py`).
//
// Properties return `Bool?` (mirroring the Rust port's `Option<bool>`):
//   - `true`  → property held
//   - `false` → property violated (a real counterexample)
//   - `nil`   → precondition failed → the input is *discarded*, not a pass
// This distinction matters: ETNA counts discards separately from passes.

// MARK: - Validity predicate

public func keys(_ t: Tree) -> [Int] {
    switch t {
    case .E:
        return []
    case let .T(l, k, _, r):
        return [k] + keys(l) + keys(r)
    }
}

public func isBST(_ t: Tree) -> Bool {
    switch t {
    case .E:
        return true
    case let .T(l, k, _, r):
        return isBST(l)
            && isBST(r)
            && keys(l).allSatisfy { $0 < k }
            && keys(r).allSatisfy { $0 > k }
    }
}

// MARK: - Model (sorted-association-list) operations

func deleteKey(_ k: Int, _ xs: [(Int, Int)]) -> [(Int, Int)] {
    xs.filter { $0.0 != k }
}

// Ported verbatim from `spec.py` `l_insert`, including its quirky control flow
// (the `else` binds to the second `if`), so the model agrees with ETNA's oracle.
func lInsert(_ pair: (Int, Int), _ xs: [(Int, Int)]) -> [(Int, Int)] {
    let (k, v) = pair
    var inserted = false
    var result: [(Int, Int)] = []
    for (k2, v2) in xs {
        if !inserted && k < k2 {
            result.append((k, v))
            inserted = true
        }
        if k == k2 && !inserted {
            result.append((k, v))
            inserted = true
        } else {
            result.append((k2, v2))
        }
    }
    if !inserted {
        result.append((k, v))
    }
    return result
}

func lSort(_ xs: [(Int, Int)]) -> [(Int, Int)] {
    var result: [(Int, Int)] = []
    for kv in xs {
        result = lInsert(kv, result)
    }
    return result
}

func lFind(_ k: Int, _ xs: [(Int, Int)]) -> Int? {
    for (k2, v) in xs where k2 == k {
        return v
    }
    return nil
}

func lUnionBy(_ f: (Int, Int) -> Int, _ l1: [(Int, Int)], _ l2: [(Int, Int)]) -> [(Int, Int)] {
    var result = l2
    for (k, v) in l1 {
        result = result.filter { $0.0 != k }
        let v2 = lFind(k, l2)
        let vNew = v2 != nil ? f(v, v2!) : v
        result = lInsert((k, vNew), result)
    }
    return result
}

func listsEqual(_ a: [(Int, Int)], _ b: [(Int, Int)]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { $0 == $1 }
}

// MARK: - Properties

public func prop_insert_valid(_ t: Tree, _ k: Int, _ v: Int) -> Bool? {
    guard isBST(t) else { return nil }
    return isBST(insert(k, v, t))
}

public func prop_delete_valid(_ t: Tree, _ k: Int) -> Bool? {
    guard isBST(t) else { return nil }
    return isBST(delete(k, t))
}

public func prop_union_valid(_ t1: Tree, _ t2: Tree) -> Bool? {
    guard isBST(t1), isBST(t2) else { return nil }   // hand-written Coq: precondition on both
    return isBST(union(t1, t2))
}

public func prop_insert_post(_ t: Tree, _ k: Int, _ k2: Int, _ v: Int) -> Bool? {
    guard isBST(t) else { return nil }
    return find(k2, insert(k, v, t)) == (k == k2 ? v : find(k2, t))
}

public func prop_delete_post(_ t: Tree, _ k: Int, _ k2: Int) -> Bool? {
    guard isBST(t) else { return nil }
    return find(k2, delete(k, t)) == (k == k2 ? nil : find(k2, t))
}

public func prop_union_post(_ t1: Tree, _ t2: Tree, _ k: Int) -> Bool? {
    guard isBST(t1) else { return nil }   // hand-written Coq: precondition on t1 only
    let expected = find(k, t1) != nil ? find(k, t1) : find(k, t2)
    return find(k, union(t1, t2)) == expected
}

public func prop_insert_model(_ t: Tree, _ k: Int, _ v: Int) -> Bool? {
    guard isBST(t) else { return nil }
    return listsEqual(toList(insert(k, v, t)), lInsert((k, v), deleteKey(k, toList(t))))
}

public func prop_delete_model(_ t: Tree, _ k: Int) -> Bool? {
    guard isBST(t) else { return nil }
    return listsEqual(toList(delete(k, t)), deleteKey(k, toList(t)))
}

public func prop_union_model(_ t1: Tree, _ t2: Tree) -> Bool? {
    guard isBST(t1), isBST(t2) else { return nil }
    return listsEqual(toList(union(t1, t2)), lSort(lUnionBy({ x, _ in x }, toList(t1), toList(t2))))
}

public func prop_insert_insert(_ t: Tree, _ k: Int, _ k2: Int, _ v: Int, _ v2: Int) -> Bool? {
    guard isBST(t) else { return nil }
    let lhs = insert(k, v, insert(k2, v2, t))
    let rhs = k == k2 ? insert(k, v, t) : insert(k2, v2, insert(k, v, t))
    return lhs == rhs
}

public func prop_insert_delete(_ t: Tree, _ k: Int, _ k2: Int, _ v: Int) -> Bool? {
    guard isBST(t) else { return nil }
    let lhs = insert(k, v, delete(k2, t))
    let rhs = k == k2 ? insert(k, v, t) : delete(k2, insert(k, v, t))
    return lhs == rhs
}

public func prop_insert_union(_ t: Tree, _ t2: Tree, _ k: Int, _ v: Int) -> Bool? {
    guard isBST(t), isBST(t2) else { return nil }
    return insert(k, v, union(t, t2)) == union(insert(k, v, t), t2)
}

public func prop_delete_insert(_ t: Tree, _ k: Int, _ k2: Int, _ v: Int) -> Bool? {
    guard isBST(t) else { return nil }
    let lhs = delete(k, insert(k2, v, t))
    let rhs = k == k2 ? delete(k, t) : insert(k2, v, delete(k, t))
    return lhs == rhs
}

public func prop_delete_delete(_ t: Tree, _ k: Int, _ k2: Int) -> Bool? {
    guard isBST(t) else { return nil }
    return delete(k, delete(k2, t)) == delete(k2, delete(k, t))
}

public func prop_delete_union(_ t1: Tree, _ t2: Tree, _ k: Int) -> Bool? {
    guard isBST(t1), isBST(t2) else { return nil }
    return delete(k, union(t1, t2)) == union(delete(k, t1), delete(k, t2))
}

public func prop_union_delete_insert(_ t1: Tree, _ t2: Tree, _ k: Int, _ v: Int) -> Bool? {
    guard isBST(t1), isBST(t2) else { return nil }
    return union(delete(k, t1), insert(k, v, t2)) == insert(k, v, union(t1, t2))
}

public func prop_union_union_idempotent(_ t: Tree) -> Bool? {
    guard isBST(t) else { return nil }
    return union(t, t) == t
}

public func prop_union_union_assoc(_ t1: Tree, _ t2: Tree, _ t3: Tree) -> Bool? {
    guard isBST(t1), isBST(t2), isBST(t3) else { return nil }
    return union(t1, union(t2, t3)) == union(union(t1, t2), t3)
}
