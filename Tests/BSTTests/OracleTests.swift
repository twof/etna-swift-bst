import Testing
@testable import BST

/// Faithful-port proof, re-based on the TRUSTED hand-written 2023 Coq BST
/// (jwshii/etna) as oracle — see `oracle/coq-bst/`. Our Swift `evaluate` must
/// match the Coq clean implementation on every input. (Earlier this validated
/// against the etna-python port, which diverged from the hand-written Coq on
/// `union`; that's now fixed and the oracle is the hand-written Coq.)
@Suite("Oracle (hand-written Coq BST)")
struct OracleTests {

    @Test("Swift clean verdicts match the hand-written Coq BST on all inputs")
    func matchesCoqOracle() throws {
        for c in coqClean {
            let result = try evaluate(property: c.property, args: witnessArgs(c.input))
            #expect(
                result == c.verdict,
                "\(c.property) on \(c.input): expected \(String(describing: c.verdict)) (Coq), got \(String(describing: result))"
            )
        }
    }

    @Test("S-expr parse + decode round-trips")
    func sExprRoundTrip() throws {
        let tree = try decodeTree(parseSExpr("(T (T E 0 0 E) 2 5 E)"))
        #expect(tree == .T(.T(.E, 0, 0, .E), 2, 5, .E))
        #expect(tree.description == "(T (T E 0 0 E) 2 5 E)")
    }

    @Test("isBST basics")
    func isBSTBasics() {
        #expect(isBST(.E))
        #expect(isBST(.T(.T(.E, 0, 0, .E), 1, 0, .T(.E, 2, 0, .E))))
        #expect(!isBST(.T(.E, 1, 0, .T(.E, 0, 0, .E))))
    }
}
