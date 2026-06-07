// swift-tools-version:5.9
import PackageDescription

// Milestone 1: the workload library + oracle tests only (no PropertyTestingKit
// dependency yet, so this builds fast with the system toolchain). The `bst` /
// `bst-sampler` executables and the PTK dependency arrive in milestone 3, at
// which point the patched toolchain becomes required.
let package = Package(
    name: "etna-swift-bst",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "BST"),
        .testTarget(name: "BSTTests", dependencies: ["BST"]),
    ]
)
