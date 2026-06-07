#!/bin/bash
# Reproduce the milestone-3 detection result: clean baseline + each mutant
# against a property that should catch it. Prints (mutant/property -> status).
#   ./scripts/detect.sh [duration_seconds]   (default 8)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUR="${1:-8}"

run() { BST_MUTANT="$1" "$ROOT/scripts/run-bst.sh" ptk "$2" "$DUR" 2>/dev/null | tail -1; }
field() { echo "$1" | sed -E "s/.*\"$2\":(\"?[^\",]*\"?).*/\1/"; }

echo "# clean baselines (a mutant is only *genuinely* detected where clean passes)"
for prop in InsertPost DeletePost UnionModel; do
  line=$(run none "$prop"); echo "clean / $prop -> $(field "$line" status)"
done
echo "# mutants"
for c in "insert_1 InsertPost" "insert_2 InsertPost" "insert_3 InsertPost" \
         "delete_4 DeletePost" "delete_5 DeletePost" \
         "union_6 UnionModel" "union_7 UnionModel" "union_8 UnionModel"; do
  mut="${c%% *}"; prop="${c##* }"
  line=$(run "$mut" "$prop")
  echo "$mut / $prop -> $(field "$line" status)   cex=$(field "$line" counterexample)"
done
