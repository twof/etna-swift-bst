# etna-swift-bst

A **binary search tree workload for [ETNA](https://github.com/alpaylan/etna-cli)**,
implemented in **Swift** with **[PropertyTestingKit](https://github.com/doordash-oss/PropertyTestingKit)**
(PTK) as a **coverage-guided** testing strategy.

It is a faithful port of ETNA's reference BST workload
([etna-python-bst](https://github.com/alpaylan/etna-python-bst), itself mirroring
the Rust/Rocq ports): the same `Tree`, the same 18 properties, and the same 8
mutants with the same ground-truth witnesses. The novelty is the **strategy**:
where ETNA's existing BST strategies are bespoke/type-based *generators*, here
PTK drives the search with **edge-coverage feedback** — the Swift analog of
QuickChick's `FuzzChick` `TypeBasedFuzzer` (the only coverage-guided strategy in
ETNA's current matrix; see the project research notes).

## Layout

| Path | Role |
|---|---|
| `Sources/BST/` | System under test (`Tree`, `insert`/`delete`/`union`/…), spec (18 properties), S-expr decoder, and the 8 mutants. No PTK dependency; `-sanitize-coverage` instrumented. |
| `Sources/BSTGen/` | PTK-backed type-based `Tree` generator + per-shape `Codable` argument structs; the coverage-guided `solve(...)` and `sample(...)` strategy. |
| `Sources/Solve/` | The `bst` executable (ETNA `solve`). Target dir is `Solve`, not `bst`, to avoid a case-insensitive-filesystem clash with `BST`. |
| `Sources/bst-sampler/` | The `bst-sampler` executable (ETNA `sample`). |
| `Tests/BSTTests/` | Differential oracle (vs the reference) + mutant-detectability tests. |
| `etna.toml`, `steps.json` | ETNA workload manifest + capability protocol. |
| `scripts/` | Toolchain build wrapper + run wrappers + `detect.sh` repro. |

## Building & running

PTK requires the **patched Swift toolchain** (parameter packs) and **macOS 26**,
so build via the wrapper rather than system `swift`:

```bash
# Point at your local toolchain build (default shown); Xcode-beta SDK is used.
export BUILD_ROOT=/path/to/OpenSourceDev/build/Ninja-RelWithDebInfoAssert
./scripts/swift-toolchain.sh build      # builds bst + bst-sampler
./scripts/swift-toolchain.sh test       # runs the oracle + mutant tests
```

Run the solver (the run wrappers put the toolchain runtime on the dylib path):

```bash
# bst <strategy> <property> [duration_seconds]   (strategy: "ptk")
./scripts/run-bst.sh ptk InsertPost 10
# -> {"status":"passed","tests":...,"discards":...,"counterexample":null,...}

BST_MUTANT=insert_1 ./scripts/run-bst.sh ptk InsertPost 10
# -> {"status":"failed",...,"counterexample":"((T E 0 0 E) 1 0 0)",...}

./scripts/run-sampler.sh InsertPost 100   # cross-language `sample`: [{time,value},...]
./scripts/detect.sh 8                      # reproduce the detection sweep
```

`solve` prints one line of ETNA result JSON (`status` ∈ passed | failed | aborted).

## Mutants

The 8 mutants (`insert_1..3`, `delete_4..5`, `union_6..8`) are a single-source,
faithful translation of `etna.toml`'s mutants (`Sources/BST/Mutants.swift`),
selected at **runtime** via the `BST_MUTANT` env var and a `@TaskLocal` that the
clean impl consults at each mutation point.

This **diverges from ETNA's marauder source-swap + recompile** model, by design:
PTK builds through a patched toolchain where per-mutant rebuilds are slow, and
runtime selection keeps coverage instrumentation over every variant in a single
build (and propagates into PTK's `TaskGroup` fuzz engines). `union_8` is
byte-identical to the clean body — an *equivalent* mutant — so it is
behaviourally undetectable, as in the reference.

## Validation

- **Faithful port (oracle).** Our Swift verdict matches the reference Python
  clean impl on all **52** `etna.toml` witnesses (36 `true` / 16 `false`). The 16
  `false` are not bugs: several properties precondition `isBST` on only *some*
  arguments, so a witness carrying an invalid-BST argument fails on the correct
  impl too. (`Tests/BSTTests/OracleTests.swift`.)
- **Mutant fidelity.** Under-mutant verdicts match the reference (each mutant
  applied to the Python impl with correct recursion) on all 52 witnesses, and
  every non-equivalent mutant is caught by some witness.
  (`Tests/BSTTests/MutantTests.swift`.)
- **Coverage-guided detection (PTK).** With short (~6–10s) budgets and a
  type-based generator (small key range), PTK's `solve` finds counterexamples
  for `insert_1/2/3` (via `InsertPost`) and `delete_4/5` (via `DeletePost`) —
  *genuine* detections, since clean **passes** those properties.

### Caveat: the base `union` is imperfect

Clean `union` itself **fails** `UnionValid`/`UnionPost`/`UnionModel` on some
inputs (e.g. `UnionValid` only preconditions `isBST(t1)`, and the fuel-bounded
`union` does not preserve all model laws). This is faithful to the reference
(those are exactly the union witnesses that are `false`-on-clean). Consequently
the union properties do **not** cleanly isolate the union mutants — a `failed`
result there can reflect the base bug rather than the mutant. A mutant is only
*genuinely detected* by property `P` when clean `P` passes; `detect.sh` prints
the clean baselines alongside so the distinction is visible.

## Relation to ETNA

ETNA evaluates strategies by **mutation testing**: a *task* is a (mutant,
property) pair, scored by whether a strategy finds the injected bug within a
budget over N trials, visualised as task-bucket charts. This repo contributes a
**Swift + coverage-guided** point on that map. The cross-language `sample`
capability is open-loop (matches ETNA's serialized-input runners); the
coverage-guided `solve` is necessarily intra-process (the coverage feedback loop
cannot cross the serialization boundary).
