import BST
import PropertyTestingKit

// MARK: - Building blocks

/// Small integer mutator — bounded keys/values so random trees are often valid
/// BSTs and keys collide, giving the coverage-guided search a fair chance of
/// reaching the mutant-triggering states. (Range tuning is a legitimate
/// strategy knob; cf. ETNA §4.2 on sized generation.)
let smallInt = Mutator<Int>(
    seeds: [-2, -1, 0, 1, 2, 3],
    mutate: { v, rng in
        let candidates = [v &+ 1, v &- 1, 0, 0 &- v]
        return candidates[Int.random(in: 0..<candidates.count, using: &rng)]
    },
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

func mutateTree(_ t: Tree, _ rng: inout FastRNG) -> Tree {
    let candidates: [Tree]
    switch t {
    case .E:
        candidates = [.T(.E, 0, 0, .E), .T(.E, 1, 0, .E), .T(.E, -1, 0, .E)]
    case let .T(l, k, v, r):
        candidates = [
            .T(l, k &+ 1, v, r),
            .T(l, k &- 1, v, r),
            .T(l, k, v &+ 1, r),
            .T(r, k, v, l),                                   // swap children
            l, r,                                             // drop a side
            .T(.T(.E, k &- 1, 0, .E), k, v, r),               // grow left
            .T(l, k, v, .T(.E, k &+ 1, 0, .E)),               // grow right
        ]
    }
    guard !candidates.isEmpty else { return t }
    return candidates[Int.random(in: 0..<candidates.count, using: &rng)]
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
            mutate: { mutateTree($0, &$1) },
            generate: { genTree(&$0, 4) },
            // Real REDUCE/eviction size metric: wire length.
            size: { $0.description.count }
        )
    }
}

// MARK: - Per-shape argument tuples (single Codable inputs for `fuzz`)

struct ArgT: Codable, Sendable, MutatorProviding {
    var t: Tree
    var wire: String { "\(t)" }
    static var defaultMutator: Mutator<ArgT> {
        Mutator(seeds: [ArgT(t: .E)],
                mutate: { x, rng in ArgT(t: mutateTree(x.t, &rng)) },
                generate: { ArgT(t: genTree(&$0, 4)) },
                size: { $0.wire.count })
    }
}

struct ArgTI: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int
    var wire: String { "(\(t) \(k))" }
    static var defaultMutator: Mutator<ArgTI> {
        Mutator(seeds: [ArgTI(t: .E, k: 0)],
                mutate: { x, rng in
                    // Pick ONE field to mutate (weights match the old candidate counts).
                    switch Int.random(in: 0..<4, using: &rng) {
                    case 0, 1: return ArgTI(t: mutateTree(x.t, &rng), k: x.k)
                    default: return ArgTI(t: x.t, k: smallInt.mutate(x.k, &rng))
                    }
                },
                generate: { ArgTI(t: genTree(&$0, 4), k: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}

struct ArgTII: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int; var k2: Int
    var wire: String { "(\(t) \(k) \(k2))" }
    static var defaultMutator: Mutator<ArgTII> {
        Mutator(seeds: [ArgTII(t: .E, k: 0, k2: 0)],
                mutate: { x, rng in
                    switch Int.random(in: 0..<4, using: &rng) {
                    case 0, 1: return ArgTII(t: mutateTree(x.t, &rng), k: x.k, k2: x.k2)
                    case 2: return ArgTII(t: x.t, k: smallInt.mutate(x.k, &rng), k2: x.k2)
                    default: return ArgTII(t: x.t, k: x.k, k2: smallInt.mutate(x.k2, &rng))
                    }
                },
                generate: { ArgTII(t: genTree(&$0, 4), k: smallInt.generate(&$0), k2: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}

struct ArgTIII: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int; var k2: Int; var v: Int
    var wire: String { "(\(t) \(k) \(k2) \(v))" }
    static var defaultMutator: Mutator<ArgTIII> {
        Mutator(seeds: [ArgTIII(t: .E, k: 0, k2: 0, v: 0)],
                mutate: { x, rng in
                    switch Int.random(in: 0..<5, using: &rng) {
                    case 0, 1: return ArgTIII(t: mutateTree(x.t, &rng), k: x.k, k2: x.k2, v: x.v)
                    case 2: return ArgTIII(t: x.t, k: smallInt.mutate(x.k, &rng), k2: x.k2, v: x.v)
                    case 3: return ArgTIII(t: x.t, k: x.k, k2: smallInt.mutate(x.k2, &rng), v: x.v)
                    default: return ArgTIII(t: x.t, k: x.k, k2: x.k2, v: smallInt.mutate(x.v, &rng))
                    }
                },
                generate: { ArgTIII(t: genTree(&$0, 4), k: smallInt.generate(&$0), k2: smallInt.generate(&$0), v: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}

struct ArgTIIII: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int; var k2: Int; var v: Int; var v2: Int
    var wire: String { "(\(t) \(k) \(k2) \(v) \(v2))" }
    static var defaultMutator: Mutator<ArgTIIII> {
        Mutator(seeds: [ArgTIIII(t: .E, k: 0, k2: 0, v: 0, v2: 0)],
                mutate: { x, rng in
                    switch Int.random(in: 0..<6, using: &rng) {
                    case 0, 1: return ArgTIIII(t: mutateTree(x.t, &rng), k: x.k, k2: x.k2, v: x.v, v2: x.v2)
                    case 2: return ArgTIIII(t: x.t, k: smallInt.mutate(x.k, &rng), k2: x.k2, v: x.v, v2: x.v2)
                    case 3: return ArgTIIII(t: x.t, k: x.k, k2: smallInt.mutate(x.k2, &rng), v: x.v, v2: x.v2)
                    case 4: return ArgTIIII(t: x.t, k: x.k, k2: x.k2, v: smallInt.mutate(x.v, &rng), v2: x.v2)
                    default: return ArgTIIII(t: x.t, k: x.k, k2: x.k2, v: x.v, v2: smallInt.mutate(x.v2, &rng))
                    }
                },
                generate: { ArgTIIII(t: genTree(&$0, 4), k: smallInt.generate(&$0), k2: smallInt.generate(&$0), v: smallInt.generate(&$0), v2: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}

struct ArgTT: Codable, Sendable, MutatorProviding {
    var t1: Tree; var t2: Tree
    var wire: String { "(\(t1) \(t2))" }
    static var defaultMutator: Mutator<ArgTT> {
        Mutator(seeds: [ArgTT(t1: .E, t2: .E)],
                mutate: { x, rng in
                    if Bool.random(using: &rng) {
                        return ArgTT(t1: mutateTree(x.t1, &rng), t2: x.t2)
                    } else {
                        return ArgTT(t1: x.t1, t2: mutateTree(x.t2, &rng))
                    }
                },
                generate: { ArgTT(t1: genTree(&$0, 4), t2: genTree(&$0, 4)) },
                size: { $0.wire.count })
    }
}

struct ArgTTI: Codable, Sendable, MutatorProviding {
    var t1: Tree; var t2: Tree; var k: Int
    var wire: String { "(\(t1) \(t2) \(k))" }
    static var defaultMutator: Mutator<ArgTTI> {
        Mutator(seeds: [ArgTTI(t1: .E, t2: .E, k: 0)],
                mutate: { x, rng in
                    switch Int.random(in: 0..<4, using: &rng) {
                    case 0, 1: return ArgTTI(t1: mutateTree(x.t1, &rng), t2: x.t2, k: x.k)
                    case 2: return ArgTTI(t1: x.t1, t2: mutateTree(x.t2, &rng), k: x.k)
                    default: return ArgTTI(t1: x.t1, t2: x.t2, k: smallInt.mutate(x.k, &rng))
                    }
                },
                generate: { ArgTTI(t1: genTree(&$0, 4), t2: genTree(&$0, 4), k: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}

struct ArgTTII: Codable, Sendable, MutatorProviding {
    var t1: Tree; var t2: Tree; var k: Int; var v: Int
    var wire: String { "(\(t1) \(t2) \(k) \(v))" }
    static var defaultMutator: Mutator<ArgTTII> {
        Mutator(seeds: [ArgTTII(t1: .E, t2: .E, k: 0, v: 0)],
                mutate: { x, rng in
                    switch Int.random(in: 0..<5, using: &rng) {
                    case 0, 1: return ArgTTII(t1: mutateTree(x.t1, &rng), t2: x.t2, k: x.k, v: x.v)
                    case 2: return ArgTTII(t1: x.t1, t2: mutateTree(x.t2, &rng), k: x.k, v: x.v)
                    case 3: return ArgTTII(t1: x.t1, t2: x.t2, k: smallInt.mutate(x.k, &rng), v: x.v)
                    default: return ArgTTII(t1: x.t1, t2: x.t2, k: x.k, v: smallInt.mutate(x.v, &rng))
                    }
                },
                generate: { ArgTTII(t1: genTree(&$0, 4), t2: genTree(&$0, 4), k: smallInt.generate(&$0), v: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}

struct ArgTTT: Codable, Sendable, MutatorProviding {
    var t1: Tree; var t2: Tree; var t3: Tree
    var wire: String { "(\(t1) \(t2) \(t3))" }
    static var defaultMutator: Mutator<ArgTTT> {
        Mutator(seeds: [ArgTTT(t1: .E, t2: .E, t3: .E)],
                mutate: { x, rng in
                    switch Int.random(in: 0..<3, using: &rng) {
                    case 0: return ArgTTT(t1: mutateTree(x.t1, &rng), t2: x.t2, t3: x.t3)
                    case 1: return ArgTTT(t1: x.t1, t2: mutateTree(x.t2, &rng), t3: x.t3)
                    default: return ArgTTT(t1: x.t1, t2: x.t2, t3: mutateTree(x.t3, &rng))
                    }
                },
                generate: { ArgTTT(t1: genTree(&$0, 4), t2: genTree(&$0, 4), t3: genTree(&$0, 4)) },
                size: { $0.wire.count })
    }
}
