import BST
import PropertyTestingKit

// MARK: - Building blocks

/// Small integer mutator — bounded keys/values so random trees are often valid
/// BSTs and keys collide, giving the coverage-guided search a fair chance of
/// reaching the mutant-triggering states. (Range tuning is a legitimate
/// strategy knob; cf. ETNA §4.2 on sized generation.)
let smallInt = Mutator<Int>(
    seeds: [-2, -1, 0, 1, 2, 3],
    mutate: { v in [v &+ 1, v &- 1, 0, 0 &- v] },
    generate: { rng in Int.random(in: -4...4, using: &rng) }
)

func genTree(_ rng: inout FastRNG, _ depth: Int) -> Tree {
    if depth <= 0 { return .E }
    if Int.random(in: 0...2, using: &rng) == 0 { return .E }
    return .T(
        genTree(&rng, depth - 1),
        Int.random(in: -4...4, using: &rng),
        Int.random(in: 0...3, using: &rng),
        genTree(&rng, depth - 1)
    )
}

func mutateTree(_ t: Tree) -> [Tree] {
    switch t {
    case .E:
        return [.T(.E, 0, 0, .E), .T(.E, 1, 0, .E), .T(.E, -1, 0, .E)]
    case let .T(l, k, v, r):
        return [
            .T(l, k &+ 1, v, r),
            .T(l, k &- 1, v, r),
            .T(l, k, v &+ 1, r),
            .T(r, k, v, l),                                   // swap children
            l, r,                                             // drop a side
            .T(.T(.E, k &- 1, 0, .E), k, v, r),               // grow left
            .T(l, k, v, .T(.E, k &+ 1, 0, .E)),               // grow right
        ]
    }
}

/// A type-based tree generator (arbitrary trees, not valid-by-construction),
/// making PTK's strategy the coverage-guided-fuzzer analog of FuzzChick's
/// `TypeBasedFuzzer` rather than a bespoke valid-BST generator.
extension Tree: MutatorProviding {
    public static var defaultMutator: Mutator<Tree> {
        Mutator(
            seeds: [
                .E,
                .T(.E, 0, 0, .E),
                .T(.T(.E, 0, 0, .E), 1, 0, .T(.E, 2, 0, .E)),
                .T(.E, 1, 0, .T(.E, 2, 0, .E)),
            ],
            mutate: { mutateTree($0) },
            generate: { genTree(&$0, 4) }
        )
    }
}

// MARK: - Per-shape argument tuples (single Codable inputs for `fuzz`)

struct ArgT: Codable, Sendable, MutatorProviding {
    var t: Tree
    var wire: String { "\(t)" }
    static var defaultMutator: Mutator<ArgT> {
        Mutator(seeds: [ArgT(t: .E)],
                mutate: { x in mutateTree(x.t).map { ArgT(t: $0) } },
                generate: { ArgT(t: genTree(&$0, 4)) })
    }
}

struct ArgTI: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int
    var wire: String { "(\(t) \(k))" }
    static var defaultMutator: Mutator<ArgTI> {
        Mutator(seeds: [ArgTI(t: .E, k: 0)],
                mutate: { x in
                    mutateTree(x.t).prefix(2).map { ArgTI(t: $0, k: x.k) }
                    + smallInt.mutate(x.k).prefix(2).map { ArgTI(t: x.t, k: $0) }
                },
                generate: { ArgTI(t: genTree(&$0, 4), k: smallInt.generate(&$0)) })
    }
}

struct ArgTII: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int; var k2: Int
    var wire: String { "(\(t) \(k) \(k2))" }
    static var defaultMutator: Mutator<ArgTII> {
        Mutator(seeds: [ArgTII(t: .E, k: 0, k2: 0)],
                mutate: { x in
                    mutateTree(x.t).prefix(2).map { ArgTII(t: $0, k: x.k, k2: x.k2) }
                    + smallInt.mutate(x.k).prefix(1).map { ArgTII(t: x.t, k: $0, k2: x.k2) }
                    + smallInt.mutate(x.k2).prefix(1).map { ArgTII(t: x.t, k: x.k, k2: $0) }
                },
                generate: { ArgTII(t: genTree(&$0, 4), k: smallInt.generate(&$0), k2: smallInt.generate(&$0)) })
    }
}

struct ArgTIII: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int; var k2: Int; var v: Int
    var wire: String { "(\(t) \(k) \(k2) \(v))" }
    static var defaultMutator: Mutator<ArgTIII> {
        Mutator(seeds: [ArgTIII(t: .E, k: 0, k2: 0, v: 0)],
                mutate: { x in
                    mutateTree(x.t).prefix(2).map { ArgTIII(t: $0, k: x.k, k2: x.k2, v: x.v) }
                    + smallInt.mutate(x.k).prefix(1).map { ArgTIII(t: x.t, k: $0, k2: x.k2, v: x.v) }
                    + smallInt.mutate(x.k2).prefix(1).map { ArgTIII(t: x.t, k: x.k, k2: $0, v: x.v) }
                    + smallInt.mutate(x.v).prefix(1).map { ArgTIII(t: x.t, k: x.k, k2: x.k2, v: $0) }
                },
                generate: { ArgTIII(t: genTree(&$0, 4), k: smallInt.generate(&$0), k2: smallInt.generate(&$0), v: smallInt.generate(&$0)) })
    }
}

struct ArgTIIII: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int; var k2: Int; var v: Int; var v2: Int
    var wire: String { "(\(t) \(k) \(k2) \(v) \(v2))" }
    static var defaultMutator: Mutator<ArgTIIII> {
        Mutator(seeds: [ArgTIIII(t: .E, k: 0, k2: 0, v: 0, v2: 0)],
                mutate: { x in
                    mutateTree(x.t).prefix(2).map { ArgTIIII(t: $0, k: x.k, k2: x.k2, v: x.v, v2: x.v2) }
                    + smallInt.mutate(x.k).prefix(1).map { ArgTIIII(t: x.t, k: $0, k2: x.k2, v: x.v, v2: x.v2) }
                    + smallInt.mutate(x.k2).prefix(1).map { ArgTIIII(t: x.t, k: x.k, k2: $0, v: x.v, v2: x.v2) }
                    + smallInt.mutate(x.v).prefix(1).map { ArgTIIII(t: x.t, k: x.k, k2: x.k2, v: $0, v2: x.v2) }
                    + smallInt.mutate(x.v2).prefix(1).map { ArgTIIII(t: x.t, k: x.k, k2: x.k2, v: x.v, v2: $0) }
                },
                generate: { ArgTIIII(t: genTree(&$0, 4), k: smallInt.generate(&$0), k2: smallInt.generate(&$0), v: smallInt.generate(&$0), v2: smallInt.generate(&$0)) })
    }
}

struct ArgTT: Codable, Sendable, MutatorProviding {
    var t1: Tree; var t2: Tree
    var wire: String { "(\(t1) \(t2))" }
    static var defaultMutator: Mutator<ArgTT> {
        Mutator(seeds: [ArgTT(t1: .E, t2: .E)],
                mutate: { x in
                    mutateTree(x.t1).prefix(2).map { ArgTT(t1: $0, t2: x.t2) }
                    + mutateTree(x.t2).prefix(2).map { ArgTT(t1: x.t1, t2: $0) }
                },
                generate: { ArgTT(t1: genTree(&$0, 4), t2: genTree(&$0, 4)) })
    }
}

struct ArgTTI: Codable, Sendable, MutatorProviding {
    var t1: Tree; var t2: Tree; var k: Int
    var wire: String { "(\(t1) \(t2) \(k))" }
    static var defaultMutator: Mutator<ArgTTI> {
        Mutator(seeds: [ArgTTI(t1: .E, t2: .E, k: 0)],
                mutate: { x in
                    mutateTree(x.t1).prefix(2).map { ArgTTI(t1: $0, t2: x.t2, k: x.k) }
                    + mutateTree(x.t2).prefix(1).map { ArgTTI(t1: x.t1, t2: $0, k: x.k) }
                    + smallInt.mutate(x.k).prefix(1).map { ArgTTI(t1: x.t1, t2: x.t2, k: $0) }
                },
                generate: { ArgTTI(t1: genTree(&$0, 4), t2: genTree(&$0, 4), k: smallInt.generate(&$0)) })
    }
}

struct ArgTTII: Codable, Sendable, MutatorProviding {
    var t1: Tree; var t2: Tree; var k: Int; var v: Int
    var wire: String { "(\(t1) \(t2) \(k) \(v))" }
    static var defaultMutator: Mutator<ArgTTII> {
        Mutator(seeds: [ArgTTII(t1: .E, t2: .E, k: 0, v: 0)],
                mutate: { x in
                    mutateTree(x.t1).prefix(2).map { ArgTTII(t1: $0, t2: x.t2, k: x.k, v: x.v) }
                    + mutateTree(x.t2).prefix(1).map { ArgTTII(t1: x.t1, t2: $0, k: x.k, v: x.v) }
                    + smallInt.mutate(x.k).prefix(1).map { ArgTTII(t1: x.t1, t2: x.t2, k: $0, v: x.v) }
                    + smallInt.mutate(x.v).prefix(1).map { ArgTTII(t1: x.t1, t2: x.t2, k: x.k, v: $0) }
                },
                generate: { ArgTTII(t1: genTree(&$0, 4), t2: genTree(&$0, 4), k: smallInt.generate(&$0), v: smallInt.generate(&$0)) })
    }
}

struct ArgTTT: Codable, Sendable, MutatorProviding {
    var t1: Tree; var t2: Tree; var t3: Tree
    var wire: String { "(\(t1) \(t2) \(t3))" }
    static var defaultMutator: Mutator<ArgTTT> {
        Mutator(seeds: [ArgTTT(t1: .E, t2: .E, t3: .E)],
                mutate: { x in
                    mutateTree(x.t1).prefix(1).map { ArgTTT(t1: $0, t2: x.t2, t3: x.t3) }
                    + mutateTree(x.t2).prefix(1).map { ArgTTT(t1: x.t1, t2: $0, t3: x.t3) }
                    + mutateTree(x.t3).prefix(1).map { ArgTTT(t1: x.t1, t2: x.t2, t3: $0) }
                },
                generate: { ArgTTT(t1: genTree(&$0, 4), t2: genTree(&$0, 4), t3: genTree(&$0, 4)) })
    }
}
