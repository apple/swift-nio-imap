// swift-tools-version:6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// This package is deliberately kept separate from the root package so that the benchmark
// dependencies (ordo-one/benchmark and its transitive dependencies) are not resolved when
// somebody just builds the library.
//
// It requires Swift 6.3, which is newer than the library needs. From 6.3 ordo-one/benchmark counts
// allocations with ordo-one/malloc-interposer; earlier toolchains use jemalloc, which has to be
// installed separately and — more importantly — counts differently, so thresholds recorded on one
// backend are meaningless on the other. Requiring 6.3 keeps a single backend and no system
// dependency.

let package = Package(
    name: "imap-performance-tester-example",
    platforms: [
        // Matches the library, which pins macOS 26 for the stdlib accessors that produce a `Span`.
        .macOS(.v26)
    ],
    dependencies: [
        .package(name: "swift-nio-imap", path: "../.."),
        .package(url: "https://github.com/apple/swift-nio", from: "2.64.0"),
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.38.1"),
    ],
    targets: [
        // Corpora, as wire bytes and wire text.
        .target(
            name: "IMAPCorpus",
            dependencies: [
                .product(name: "NIO", package: "swift-nio")
            ]
        ),
        // A client whose transport is `DispatchData` throughout.
        .executableTarget(
            name: "IMAPDispatchClient",
            dependencies: [
                "IMAPCorpus",
                .product(name: "NIOIMAP", package: "swift-nio-imap"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Benchmark", package: "benchmark"),
            ],
            path: "Benchmarks/IMAPDispatchClient",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        ),
    ]
)
