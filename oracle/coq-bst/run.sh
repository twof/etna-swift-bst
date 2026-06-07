#!/bin/bash
# Compile the hand-written 2023 Coq BST (jwshii/etna) and Compute each input's
# verdict. Requires the etna-coq opam switch (see oracle/coq-rbt/README.md).
#   python3 gen_bst_inputs.py        # -> bst-inputs.tsv (non-negative; Coq BST uses nat)
#   python3 gen_bst_oracle.py > Oracle.v
#   ./run.sh                          # prints  = (idx, Some true|false|None)
set -e
export PATH=/opt/homebrew/bin:$PATH
eval "$(opam env --switch=etna-coq)"
cd "$(dirname "$0")"
python3 gen_bst_oracle.py > Oracle.v
for f in QcEtna Impl Spec Oracle; do coqc -Q . BST "$f.v"; done
