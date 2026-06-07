// swift-tools-version: 6.2
import PackageDescription

// PropertyTestingKit requires the patched Swift toolchain (parameter packs) and
// macOS 26. Build via ./scripts/swift-toolchain.sh, not system `swift`.
//
// `-sanitize-coverage=edge,pc-table` instruments the code under test so PTK's
// SanCovHooks can observe edge coverage; `-sanitize=undefined` matches PTK's own
// build. Any product linking the instrumented `BST` module must also link PTK
// (which provides the SanitizerCoverage callbacks).
let sanitize: [SwiftSetting] = [
    .unsafeFlags(["-sanitize=undefined", "-sanitize-coverage=edge,pc-table"])
]

let package = Package(
    name: "etna-swift-bst",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "bst", targets: ["Solve"]),
        .executable(name: "bst-sampler", targets: ["bst-sampler"]),
    ],
    dependencies: [
        .package(path: "../PropertyTestingKit"),
    ],
    targets: [
        // System under test + spec + decoders + mutants. Instrumented for coverage.
        .target(
            name: "BST",
            swiftSettings: sanitize
        ),
        // PTK-backed generators + coverage-guided solve/sample strategy.
        .target(
            name: "BSTGen",
            dependencies: [
                "BST",
                .product(name: "PropertyTestingKit", package: "PropertyTestingKit"),
            ],
            swiftSettings: sanitize
        ),
        // Target dir is `Solve` (not `bst`) to avoid a case-insensitive
        // filesystem clash with the `BST` library; the product is still `bst`.
        .executableTarget(
            name: "Solve",
            dependencies: ["BSTGen"],
            swiftSettings: sanitize
        ),
        .executableTarget(
            name: "bst-sampler",
            dependencies: ["BSTGen"],
            swiftSettings: sanitize
        ),
        .testTarget(
            name: "BSTTests",
            dependencies: [
                "BST",
                // Provides the SanitizerCoverage runtime for the instrumented BST module.
                .product(name: "PropertyTestingKit", package: "PropertyTestingKit"),
            ],
            swiftSettings: sanitize
        ),
    ]
)
