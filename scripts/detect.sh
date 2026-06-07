#!/bin/bash
# Reproduce the mutant-detection result using ETNA's source-swap model: for each
# mutant, activate the marauder variant, rebuild, and run the property that
# should catch it. Prints (mutant/property -> status, counterexample).
#   ./scripts/detect.sh [duration_seconds]   (default 8)
#
# Requires the `etna` CLI (wraps marauder) and the patched toolchain. The
# workload's marauder.toml registers Swift as a custom language so `etna
# mutation set` can find the variants.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUR="${1:-8}"

reset() { etna mutation reset -p "$ROOT" >/dev/null 2>&1 || true; }
build() { "$ROOT/scripts/swift-toolchain.sh" build >/dev/null 2>&1; }
run()   { "$ROOT/scripts/run-bst.sh" ptk "$1" "$DUR" 2>/dev/null | tail -1; }
field() { echo "$1" | sed -E "s/.*\"$2\":(\"?[^\",]*\"?).*/\1/"; }

trap reset EXIT

echo "# clean baselines (a mutant is only *genuinely* detected where clean passes)"
reset; build
for prop in InsertPost DeletePost UnionModel; do
  echo "clean / $prop -> $(field "$(run "$prop")" status)"
done

echo "# mutants (each: reset -> set -> rebuild -> solve)"
for c in "insert_1 InsertPost" "insert_2 InsertPost" "insert_3 InsertPost" \
         "delete_4 DeletePost" "delete_5 DeletePost" \
         "union_6 UnionModel" "union_7 UnionModel" "union_8 UnionModel"; do
  mut="${c%% *}"; prop="${c##* }"
  reset; etna mutation set "$mut" -p "$ROOT" >/dev/null 2>&1; build
  line=$(run "$prop")
  echo "$mut / $prop -> $(field "$line" status)   cex=$(field "$line" counterexample)"
done
