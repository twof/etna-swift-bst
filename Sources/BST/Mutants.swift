// The eight BST mutants from ETNA's reference workload (etna-python-bst
// `impl.py`). Each mutant replaces the body of one function's recursive case
// with a subtly-wrong variant; the clean impl in `Tree.swift` consults the
// currently-selected mutant at each mutation point and falls back to the
// correct body when none applies.
//
// Why a runtime-selected mutant instead of ETNA's marauder source-swap +
// recompile: PropertyTestingKit builds through a patched toolchain (slow), and
// a campaign runs (8 mutants × ~6 properties × N trials). Selecting the mutant
// at runtime keeps coverage instrumentation over every variant in a single
// build, turning 8 rebuilds into one. The mutant bodies below are a faithful,
// single-source translation of the same eight mutants `etna.toml` names.

public enum Mutant: String, Sendable, CaseIterable {
    case none
    case insert_1, insert_2, insert_3
    case delete_4, delete_5
    case union_6, union_7, union_8
}

enum MutantContext {
    /// The mutant active for the current task. `insert`/`delete`/`unionF` read
    /// this at their mutation point. Task-local so it is concurrency-safe and
    /// propagates through recursion without a global.
    @TaskLocal static var current: Mutant = .none
}

/// Run `body` with `mutant` selected.
public func withMutant<T>(_ mutant: Mutant, _ body: () throws -> T) rethrows -> T {
    try MutantContext.$current.withValue(mutant, operation: body)
}

/// Async variant — the selected mutant propagates to child tasks (PTK's fuzz
/// engines run as TaskGroup children), so the whole fuzz run sees the mutant.
public func withMutant<T>(_ mutant: Mutant, _ body: () async throws -> T) async rethrows -> T {
    try await MutantContext.$current.withValue(mutant, operation: body)
}

// MARK: - Mutant bodies
//
// Each returns the mutant's result for the `T(l, k2, v2, r)` recursive case, or
// `nil` when the active mutant does not affect this function (clean fallback).

func insertMutant(_ k: Int, _ v: Int, _ l: Tree, _ k2: Int, _ v2: Int, _ r: Tree) -> Tree? {
    switch MutantContext.current {
    case .insert_1:
        // Ignores the existing tree entirely.
        return .T(.E, k, v, .E)
    case .insert_2:
        // Collapses the `k2 < k` case into the equal case (overwrites value).
        if k < k2 {
            return .T(insert(k, v, l), k2, v2, r)
        } else {
            return .T(l, k2, v, r)
        }
    case .insert_3:
        // Equal-key case keeps the old value `v2` instead of updating to `v`.
        if k < k2 {
            return .T(insert(k, v, l), k2, v2, r)
        } else if k2 < k {
            return .T(l, k2, v2, insert(k, v, r))
        } else {
            return .T(l, k2, v2, r)
        }
    default:
        return nil
    }
}

func deleteMutant(_ k: Int, _ l: Tree, _ k2: Int, _ v2: Int, _ r: Tree) -> Tree? {
    switch MutantContext.current {
    case .delete_4:
        // Drops the surrounding node, returning only the recursive subtree.
        if k < k2 {
            return delete(k, l)
        } else if k2 < k {
            return delete(k, r)
        } else {
            return join(l, r)
        }
    case .delete_5:
        // Swaps the comparison directions.
        if k2 < k {
            return .T(delete(k, l), k2, v2, r)
        } else if k < k2 {
            return .T(l, k2, v2, delete(k, r))
        } else {
            return join(l, r)
        }
    default:
        return nil
    }
}

func unionMutant(
    _ l1: Tree, _ k1: Int, _ v1: Int, _ r1: Tree,
    _ l2: Tree, _ k2: Int, _ v2: Int, _ r2: Tree,
    _ f1: Int
) -> Tree? {
    switch MutantContext.current {
    case .union_6:
        // Ignores key ordering: blindly nests the right operand.
        return .T(l1, k1, v1, .T(unionF(r1, l2, f1), k2, v2, r2))
    case .union_7:
        // `k1 < k2` case mis-merges (no below/above split).
        if k1 == k2 {
            return .T(unionF(l1, l2, f1), k1, v1, unionF(r1, r2, f1))
        } else if k1 < k2 {
            return .T(l1, k1, v1, .T(unionF(r1, l2, f1), k2, v2, r2))
        } else {
            return unionF(.T(l2, k2, v2, r2), .T(l1, k1, v1, r1), f1)
        }
    case .union_8:
        // Identical to the clean body — an equivalent mutant (undetectable).
        return nil
    default:
        return nil
    }
}

// MARK: - Mutant-parameterised evaluation

/// Evaluate a named property against a decoded argument tuple, with `mutant`
/// selected. Returns `nil` when the precondition discards the input.
public func evaluate(property: String, args: [SExpr], mutant: Mutant) throws -> Bool? {
    try withMutant(mutant) {
        try evaluate(property: property, args: args)
    }
}
