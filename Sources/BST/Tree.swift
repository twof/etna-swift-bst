// Binary search tree implementation, ported from ETNA's reference workload
// (alpaylan/etna-python-bst `impl.py`, which mirrors the Rust/Rocq ports).
//
// Milestone 1 ships only the *correct* bodies. The mutant variants (insert_1..3,
// delete_4..5, union_6..8) arrive in milestone 2 via marauder comment-mutants.
//
// Field order matches the reference `repr`: `(T left k v right)` and `(E)`.

public indirect enum Tree: Equatable {
    case E
    case T(Tree, Int, Int, Tree)
}

extension Tree: CustomStringConvertible {
    public var description: String {
        switch self {
        case .E:
            return "(E)"
        case let .T(l, k, v, r):
            return "(T \(l) \(k) \(v) \(r))"
        }
    }
}

public let FUEL = 10_000

// MARK: - Insert

public func insert(_ k: Int, _ v: Int, _ t: Tree) -> Tree {
    switch t {
    case .E:
        return .T(.E, k, v, .E)
    case let .T(l, k2, v2, r):
        if let mutated = insertMutant(k, v, l, k2, v2, r) { return mutated }
        if k < k2 {
            return .T(insert(k, v, l), k2, v2, r)
        } else if k2 < k {
            return .T(l, k2, v2, insert(k, v, r))
        } else {
            return .T(l, k2, v, r)
        }
    }
}

// MARK: - Join

public func join(_ l: Tree, _ r: Tree) -> Tree {
    switch (l, r) {
    case (.E, _):
        return r
    case (_, .E):
        return l
    case let (.T(l1, k1, v1, r1), .T(l2, k2, v2, r2)):
        return .T(l1, k1, v1, .T(join(r1, l2), k2, v2, r2))
    }
}

// MARK: - Delete

public func delete(_ k: Int, _ t: Tree) -> Tree {
    switch t {
    case .E:
        return .E
    case let .T(l, k2, v2, r):
        if let mutated = deleteMutant(k, l, k2, v2, r) { return mutated }
        if k < k2 {
            return .T(delete(k, l), k2, v2, r)
        } else if k2 < k {
            return .T(l, k2, v2, delete(k, r))
        } else {
            return join(l, r)
        }
    }
}

// MARK: - Below / Above

public func below(_ k: Int, _ t: Tree) -> Tree {
    switch t {
    case .E:
        return .E
    case let .T(l, k2, v2, r):
        if k <= k2 {
            return below(k, l)
        } else {
            return .T(l, k2, v2, below(k, r))
        }
    }
}

public func above(_ k: Int, _ t: Tree) -> Tree {
    switch t {
    case .E:
        return .E
    case let .T(l, k2, v2, r):
        if k2 <= k {
            return above(k, r)
        } else {
            return .T(above(k, l), k2, v2, r)
        }
    }
}

// MARK: - Union (fuel-bounded, mirrors the reference `union_8` shape)

public func unionF(_ l: Tree, _ r: Tree, _ f: Int) -> Tree {
    if f == 0 { return .E }
    let f1 = f - 1
    switch (l, r) {
    case (.E, _):
        return r
    case (_, .E):
        return l
    case let (.T(l1, k1, v1, r1), .T(l2, k2, v2, r2)):
        if let mutated = unionMutant(l1, k1, v1, r1, l2, k2, v2, r2, f1) { return mutated }
        if k1 == k2 {
            return .T(unionF(l1, l2, f1), k1, v1, unionF(r1, r2, f1))
        } else if k1 < k2 {
            return .T(
                unionF(l1, below(k1, l2), f1),
                k1,
                v1,
                unionF(r1, .T(above(k1, l2), k2, v2, r2), f1)
            )
        } else {
            return unionF(.T(l2, k2, v2, r2), .T(l1, k1, v1, r1), f1)
        }
    }
}

public func union(_ l: Tree, _ r: Tree) -> Tree {
    unionF(l, r, FUEL)
}

// MARK: - Find / Size / toList

public func find(_ k: Int, _ t: Tree) -> Int? {
    switch t {
    case .E:
        return nil
    case let .T(l, k2, v2, r):
        if k < k2 {
            return find(k, l)
        } else if k2 < k {
            return find(k, r)
        } else {
            return v2
        }
    }
}

public func size(_ t: Tree) -> Int {
    switch t {
    case .E:
        return 0
    case let .T(l, _, _, r):
        return 1 + size(l) + size(r)
    }
}

public func toList(_ t: Tree) -> [(Int, Int)] {
    switch t {
    case .E:
        return []
    case let .T(l, k, v, r):
        return toList(l) + [(k, v)] + toList(r)
    }
}
