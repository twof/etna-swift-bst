import BST
import BSTGen
import Foundation

// ETNA solve runner (product name `bst`).
//   bst <strategy> <property> [duration_seconds]
// The mutant under test is selected via the BST_MUTANT env var (default: clean),
// since PropertyTestingKit's coverage instrumentation covers all variants in a
// single build (see Mutants.swift / README).
//
// Prints one line of ETNA result JSON to stdout.

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: bst <strategy> <property> [duration_seconds]\n".utf8))
    FileHandle.standardError.write(Data("properties: \(bstProperties.joined(separator: ", "))\n".utf8))
    exit(2)
}

let strategy = args[1]   // e.g. "ptk" / "TypeBasedFuzzer"; accepted and ignored (one strategy)
let property = args[2]
let durationSecs = args.count >= 4 ? (Int(args[3]) ?? 10) : 10
let mutantName = ProcessInfo.processInfo.environment["BST_MUTANT"] ?? "none"
let mutant = Mutant(rawValue: mutantName) ?? .none

_ = strategy

do {
    let outcome = try await solve(property: property, mutant: mutant, duration: .seconds(durationSecs))
    print(outcome.json)
} catch {
    let aborted = SolveOutcome(status: "aborted", tests: 0, discards: 0,
                               counterexample: nil, error: "\(error)", timeNs: 0)
    print(aborted.json)
}
