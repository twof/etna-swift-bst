import Testing
@testable import BST

/// Mutant detectability, re-based on the hand-written Coq BST. All 8 mutant
/// bodies are verbatim transcriptions of the Coq `Impl.v` mutant blocks
/// (insert_1..3, delete_4..5, union_6..8), and the clean impl is oracle-proven
/// to match the Coq (see OracleTests), so Swift-under-mutant == Coq-under-mutant.
///
/// Note: after re-basing `union` on the hand-written Coq clean algorithm,
/// `union_8` is NO LONGER equivalent (it is the algorithm the etna-python port
/// used as its "clean" union) — so every mutant, including union_8, is now a
/// genuine, detectable bug.
@Suite("Mutants (hand-written Coq BST)")
struct MutantTests {

    @Test("every mutant is caught: clean passes but the mutant fails some input")
    func everyMutantIsCaught() throws {
        var caught: Set<String> = []
        for c in coqClean where c.verdict == true {        // clean passes (Coq-validated)
            let args = try witnessArgs(c.input)
            for m in Mutant.allCases where m != .none {
                let mutated = try evaluate(property: c.property, args: args, mutant: m)
                if mutated == false { caught.insert(m.rawValue) }
            }
        }
        let expected = Set(Mutant.allCases.map(\.rawValue)).subtracting(["none"])
        #expect(caught == expected, "caught \(caught.sorted()), expected \(expected.sorted())")
    }
}
