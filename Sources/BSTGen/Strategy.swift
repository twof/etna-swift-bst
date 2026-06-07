import BST
import PropertyTestingKit
import Foundation
import os

/// Thrown by the fuzz closure when a property is violated; carries the failing
/// input in ETNA wire form so `solve` can report it as the counterexample.
struct PropertyViolation: Error { let wire: String }

/// Outcome of one solve run, shaped for ETNA's (legacy) result JSON.
public struct SolveOutcome: Sendable {
    public let status: String          // "passed" | "failed" | "aborted"
    public let tests: Int
    public let discards: Int
    public let counterexample: String?
    public let error: String?
    public let timeNs: UInt64

    public init(status: String, tests: Int, discards: Int, counterexample: String?, error: String?, timeNs: UInt64) {
        self.status = status
        self.tests = tests
        self.discards = discards
        self.counterexample = counterexample
        self.error = error
        self.timeNs = timeNs
    }
}

private func jsonEscape(_ s: String) -> String {
    var out = ""
    for c in s {
        switch c {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        case "\t": out += "\\t"
        case "\r": out += "\\r"
        default: out.append(c)
        }
    }
    return out
}

extension SolveOutcome {
    /// ETNA result JSON (matching the shape emitted by the Rust/Python workloads).
    public var json: String {
        let cex = counterexample.map { "\"\(jsonEscape($0))\"" } ?? "null"
        let err = error.map { "\"\(jsonEscape($0))\"" } ?? "null"
        return """
        {"status":"\(status)","tests":\(tests),"discards":\(discards),"counterexample":\(cex),"error":\(err),"time":"\(timeNs)ns","execution_time":null,"generation_time":null,"shrinking_time":null}
        """
    }
}

/// Run the coverage-guided fuzzer over inputs of type `I`, checking `check`.
/// `check` returns the property verdict: `false` is a counterexample, `nil` a
/// precondition discard, `true` a pass.
private func runFuzz<I: MutatorProviding & Codable & Sendable>(
    _ type: I.Type,
    duration: Duration,
    wire: @escaping @Sendable (I) -> String,
    check: @escaping @Sendable (I) -> Bool?
) async -> SolveOutcome {
    let discards = OSAllocatedUnfairLock(initialState: 0)
    let start = DispatchTime.now()
    func elapsed() -> UInt64 { DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds }

    do {
        // ETNA semantics: stop at the *first* counterexample so the recorded
        // time is time-to-find, and the run returns well within ETNA's hard
        // process-kill at `timeout`. A single engine keeps that exit prompt
        // (sibling engines would otherwise run the full budget after a halt).
        let stopAtFirstCounterexample = FuzzPlugin<I>(
            id: "stop_at_first_counterexample",
            handleSync: { _ in [] },
            handleAsync: { event in
                if case .failureFound = event {
                    return [.stop(FuzzPluginAction<I>.StopAction(reason: .custom("counterexample_found")))]
                }
                return []
            }
        )
        let result = try await fuzz(
            duration: duration,
            persistence: .ephemeral,
            parallelism: 1,
            plugins: { [.corpusMutation(), stopAtFirstCounterexample] }
        ) { (input: I) in
            switch check(input) {
            case .some(false): throw PropertyViolation(wire: wire(input))
            case .none: discards.withLock { $0 += 1 }
            case .some(true): break
            }
        }
        return SolveOutcome(status: "passed", tests: result.stats.totalInputs,
                            discards: discards.withLock { $0 }, counterexample: nil, error: nil, timeNs: elapsed())
    } catch let e as FuzzError {
        guard case let .testFailed(_, underlying, _, stats) = e else {
            return SolveOutcome(status: "aborted", tests: 0, discards: discards.withLock { $0 },
                                counterexample: nil, error: "\(e)", timeNs: elapsed())
        }
        return SolveOutcome(status: "failed", tests: stats.totalInputs,
                            discards: discards.withLock { $0 },
                            counterexample: (underlying as? PropertyViolation)?.wire, error: nil, timeNs: elapsed())
    } catch {
        return SolveOutcome(status: "aborted", tests: 0, discards: discards.withLock { $0 },
                            counterexample: nil, error: "\(error)", timeNs: elapsed())
    }
}

/// All property names this workload understands (matches `etna.toml`).
public let bstProperties = [
    "InsertValid", "DeleteValid", "UnionValid", "InsertPost", "DeletePost", "UnionPost",
    "InsertModel", "DeleteModel", "UnionModel", "InsertInsert", "InsertDelete", "InsertUnion",
    "DeleteInsert", "DeleteDelete", "DeleteUnion", "UnionDeleteInsert", "UnionUnionIdem", "UnionUnionAssoc",
]

public enum SolveError: Error { case unknownProperty(String) }

/// Coverage-guided solve: fuzz `property` for `duration`. The mutant under test
/// is whichever marauder variant is active in the compiled `BST` module.
public func solve(property: String, duration: Duration) async throws -> SolveOutcome {
    switch property {
    case "InsertValid":
        return await runFuzz(ArgTII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_insert_valid($0.t, $0.k, $0.k2) })
    case "DeleteValid":
        return await runFuzz(ArgTI.self, duration: duration,
                             wire: { $0.wire }, check: { prop_delete_valid($0.t, $0.k) })
    case "UnionValid":
        return await runFuzz(ArgTT.self, duration: duration,
                             wire: { $0.wire }, check: { prop_union_valid($0.t1, $0.t2) })
    case "InsertPost":
        return await runFuzz(ArgTIII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_insert_post($0.t, $0.k, $0.k2, $0.v) })
    case "DeletePost":
        return await runFuzz(ArgTII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_delete_post($0.t, $0.k, $0.k2) })
    case "UnionPost":
        return await runFuzz(ArgTTI.self, duration: duration,
                             wire: { $0.wire }, check: { prop_union_post($0.t1, $0.t2, $0.k) })
    case "InsertModel":
        return await runFuzz(ArgTII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_insert_model($0.t, $0.k, $0.k2) })
    case "DeleteModel":
        return await runFuzz(ArgTI.self, duration: duration,
                             wire: { $0.wire }, check: { prop_delete_model($0.t, $0.k) })
    case "UnionModel":
        return await runFuzz(ArgTT.self, duration: duration,
                             wire: { $0.wire }, check: { prop_union_model($0.t1, $0.t2) })
    case "InsertInsert":
        return await runFuzz(ArgTIIII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_insert_insert($0.t, $0.k, $0.k2, $0.v, $0.v2) })
    case "InsertDelete":
        return await runFuzz(ArgTIII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_insert_delete($0.t, $0.k, $0.k2, $0.v) })
    case "InsertUnion":
        return await runFuzz(ArgTTII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_insert_union($0.t1, $0.t2, $0.k, $0.v) })
    case "DeleteInsert":
        return await runFuzz(ArgTIII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_delete_insert($0.t, $0.k, $0.k2, $0.v) })
    case "DeleteDelete":
        return await runFuzz(ArgTII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_delete_delete($0.t, $0.k, $0.k2) })
    case "DeleteUnion":
        return await runFuzz(ArgTTI.self, duration: duration,
                             wire: { $0.wire }, check: { prop_delete_union($0.t1, $0.t2, $0.k) })
    case "UnionDeleteInsert":
        return await runFuzz(ArgTTII.self, duration: duration,
                             wire: { $0.wire }, check: { prop_union_delete_insert($0.t1, $0.t2, $0.k, $0.v) })
    case "UnionUnionIdem", "UnionUnionIdempotent":
        return await runFuzz(ArgT.self, duration: duration,
                             wire: { $0.wire }, check: { prop_union_union_idempotent($0.t) })
    case "UnionUnionAssoc":
        return await runFuzz(ArgTTT.self, duration: duration,
                             wire: { $0.wire }, check: { prop_union_union_assoc($0.t1, $0.t2, $0.t3) })
    default:
        throw SolveError.unknownProperty(property)
    }
}

// MARK: - Sampling (cross-language `sample` capability)

/// Generate `count` inputs for `property`, each with its generation time (ns)
/// and ETNA wire serialization. Open-loop (no coverage feedback).
public func sample(property: String, count: Int) throws -> [(timeNs: UInt64, wire: String)] {
    func gen<I: MutatorProviding>(_ type: I.Type, _ wire: @escaping (I) -> String) -> [(UInt64, String)] {
        var rng = FastRNG()
        var out: [(UInt64, String)] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            let start = DispatchTime.now()
            let value = I.defaultMutator.generate(&rng)
            let ns = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            out.append((ns, wire(value)))
        }
        return out
    }
    switch property {
    case "InsertValid", "DeletePost", "InsertModel", "DeleteDelete":
        return gen(ArgTII.self) { $0.wire }
    case "DeleteValid", "DeleteModel":
        return gen(ArgTI.self) { $0.wire }
    case "UnionValid", "UnionModel":
        return gen(ArgTT.self) { $0.wire }
    case "InsertPost", "InsertDelete", "DeleteInsert":
        return gen(ArgTIII.self) { $0.wire }
    case "UnionPost", "DeleteUnion":
        return gen(ArgTTI.self) { $0.wire }
    case "InsertInsert":
        return gen(ArgTIIII.self) { $0.wire }
    case "InsertUnion", "UnionDeleteInsert":
        return gen(ArgTTII.self) { $0.wire }
    case "UnionUnionIdem", "UnionUnionIdempotent":
        return gen(ArgT.self) { $0.wire }
    case "UnionUnionAssoc":
        return gen(ArgTTT.self) { $0.wire }
    default:
        throw SolveError.unknownProperty(property)
    }
}
