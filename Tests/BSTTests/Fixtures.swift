@testable import BST

/// A `(mutation, property, witness)` row from ETNA's `etna.toml` ground truth,
/// paired with the verdict the reference (etna-python-bst) clean implementation
/// produces (`expected`). See `OracleTests` for how `expected` was derived.
struct Witness {
    let mutation: String
    let property: String
    let input: String
    let expected: Bool
}

/// All 52 ground-truth rows from `etna.toml`. `expected` is the clean-reference
/// verdict; 16 are `false` because several properties precondition `isBST` on
/// only some arguments, so a witness carrying an invalid-BST argument fails on
/// the correct impl too.
let etnaWitnesses: [Witness] = [
    // insert_1
    Witness(mutation: "insert_1", property: "InsertPost", input: "((T E 2 1 E) 0 2 0)", expected: true),
    Witness(mutation: "insert_1", property: "InsertModel", input: "((T E 1 0 E) 0 0)", expected: true),
    Witness(mutation: "insert_1", property: "DeleteInsert", input: "((T E 1 0 E) 0 0 0)", expected: true),
    Witness(mutation: "insert_1", property: "InsertInsert", input: "(E 1 0 0 0)", expected: false),
    Witness(mutation: "insert_1", property: "InsertUnion", input: "(E (T E 1 1 E) 0 0)", expected: false),
    Witness(mutation: "insert_1", property: "UnionDeleteInsert", input: "((T E 2 0 E) E 0 0)", expected: false),
    // insert_2
    Witness(mutation: "insert_2", property: "InsertPost", input: "((T E 0 1 E) 1 0 0)", expected: true),
    Witness(mutation: "insert_2", property: "InsertModel", input: "((T E -2 0 E) 0 0)", expected: true),
    Witness(mutation: "insert_2", property: "InsertDelete", input: "((T E 0 2 (T E 1 0 E)) 0 0 0)", expected: false),
    Witness(mutation: "insert_2", property: "DeleteInsert", input: "((T E 0 0 E) 0 1 0)", expected: true),
    Witness(mutation: "insert_2", property: "InsertInsert", input: "(E 0 1 0 0)", expected: false),
    Witness(mutation: "insert_2", property: "InsertUnion", input: "(E (T E 0 0 E) 1 0)", expected: true),
    Witness(mutation: "insert_2", property: "UnionDeleteInsert", input: "((T E -2 0 E) E 0 0)", expected: true),
    // insert_3
    Witness(mutation: "insert_3", property: "InsertPost", input: "((T E 3 0 E) 3 3 1)", expected: true),
    Witness(mutation: "insert_3", property: "InsertModel", input: "((T E 0 1 E) 0 0)", expected: true),
    Witness(mutation: "insert_3", property: "InsertDelete", input: "((T (T E 0 0 E) 2 0 E) 2 2 0)", expected: false),
    Witness(mutation: "insert_3", property: "InsertInsert", input: "(E 0 0 1 0)", expected: true),
    Witness(mutation: "insert_3", property: "InsertUnion", input: "(E (T E 0 0 E) 1 0)", expected: true),
    Witness(mutation: "insert_3", property: "UnionDeleteInsert", input: "((T E -2 2 E) E -2 0)", expected: true),
    // delete_4
    Witness(mutation: "delete_4", property: "DeleteModel", input: "((T E 0 0 E) 1)", expected: true),
    Witness(mutation: "delete_4", property: "DeletePost", input: "((T E 0 0 E) 1 0)", expected: true),
    Witness(mutation: "delete_4", property: "DeleteDelete", input: "((T (T (T E 0 0 E) 3 5 E) 5 0 E) 5 3)", expected: true),
    Witness(mutation: "delete_4", property: "DeleteInsert", input: "(E 0 1 0)", expected: true),
    Witness(mutation: "delete_4", property: "DeleteUnion", input: "((T E -1 0 E) (T E 0 1 E) -1)", expected: true),
    Witness(mutation: "delete_4", property: "InsertDelete", input: "(E 0 1 0)", expected: true),
    Witness(mutation: "delete_4", property: "UnionDeleteInsert", input: "((T E 0 1 E) (T E 1 0 E) 0 0)", expected: false),
    // delete_5
    Witness(mutation: "delete_5", property: "DeleteModel", input: "((T (T E 1 0 E) 3 0 E) 1)", expected: true),
    Witness(mutation: "delete_5", property: "DeletePost", input: "((T (T E 2 0 E) 4 1 E) 2 2)", expected: true),
    Witness(mutation: "delete_5", property: "DeleteDelete", input: "((T E -4 0 (T E 4 4 E)) 4 -4)", expected: true),
    Witness(mutation: "delete_5", property: "DeleteInsert", input: "((T E 2 0 E) -2 -2 0)", expected: true),
    Witness(mutation: "delete_5", property: "DeleteUnion", input: "((T E -1 0 (T E 0 0 E)) (T E -2 2 E) -1)", expected: true),
    Witness(mutation: "delete_5", property: "UnionDeleteInsert", input: "((T (T E -1 0 E) 0 0 E) E 0 0)", expected: false),
    // union_6
    Witness(mutation: "union_6", property: "UnionValid", input: "((T E 0 0 E) (T E 0 0 E))", expected: true),
    Witness(mutation: "union_6", property: "UnionPost", input: "((T E 0 0 (T E 1 1 E)) (T E 0 0 E) 1)", expected: true),
    Witness(mutation: "union_6", property: "UnionModel", input: "((T E 0 0 E) (T E 0 0 E))", expected: true),
    Witness(mutation: "union_6", property: "DeleteUnion", input: "((T E 2 2 E) (T E -1 0 E) -1)", expected: true),
    Witness(mutation: "union_6", property: "InsertUnion", input: "(E (T E 0 0 E) 1 0)", expected: true),
    Witness(mutation: "union_6", property: "UnionDeleteInsert", input: "((T E 0 0 E) (T E 0 0 E) 0 0)", expected: true),
    Witness(mutation: "union_6", property: "UnionUnionAssoc", input: "((T E 0 1 E) (T E 0 1 E) (T E 0 0 E))", expected: true),
    // union_7
    Witness(mutation: "union_7", property: "UnionValid", input: "(E (T E 0 2 (T E 0 0 E)))", expected: false),
    Witness(mutation: "union_7", property: "UnionPost", input: "((T (T E -2 0 E) 2 0 E) (T E 0 0 E) -2)", expected: true),
    Witness(mutation: "union_7", property: "UnionModel", input: "((T E -1 0 E) (T (T E -2 1 E) 0 0 E))", expected: true),
    Witness(mutation: "union_7", property: "DeleteUnion", input: "((T E 0 0 E) (T (T E 0 0 E) 2 0 E) 2)", expected: true),
    Witness(mutation: "union_7", property: "InsertUnion", input: "((T E 0 0 E) (T E 1 1 E) 1 0)", expected: true),
    Witness(mutation: "union_7", property: "UnionDeleteInsert", input: "((T (T E -1 0 E) 0 0 E) E 0 0)", expected: false),
    Witness(mutation: "union_7", property: "UnionUnionAssoc", input: "((T E 0 0 E) (T E 1 0 E) (T E 1 1 E))", expected: true),
    // union_8 (behaviourally identical to the clean impl — an equivalent mutant)
    Witness(mutation: "union_8", property: "UnionPost", input: "((T (T E 4 4 E) 2147483647 0 E) (T E 4 0 E) 4)", expected: false),
    Witness(mutation: "union_8", property: "UnionModel", input: "((T (T E -2 0 E) 2 0 E) (T E -2 1 E))", expected: false),
    Witness(mutation: "union_8", property: "DeleteUnion", input: "((T (T E -2 0 E) 1 0 E) (T E 0 0 E) 1)", expected: false),
    Witness(mutation: "union_8", property: "InsertUnion", input: "((T E 2 2 E) (T E -1 1 E) -1 0)", expected: false),
    Witness(mutation: "union_8", property: "UnionDeleteInsert", input: "((T E -1 3 E) (T E 3 1 E) -1 0)", expected: false),
    Witness(mutation: "union_8", property: "UnionUnionAssoc", input: "((T E 2 1 E) (T E 2 0 E) (T E 0 0 E))", expected: false),
]
