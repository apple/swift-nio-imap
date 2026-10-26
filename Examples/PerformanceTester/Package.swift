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

// Which checkout of the library the benchmarks measure.
//
// The default is this working tree. Setting `IMAP_IMPL=main` points the path dependency at a worktree
// of the pre-migration library instead and defines `IMAP_LEGACY_BUFFERS`, which selects the
// `ByteBuffer`-based half of the `IMAPDispatchClient` drivers. That is how one set of benchmark cases
// produces before-and-after numbers for the same client: same case names, same corpora, two
// libraries.
//
// Only `IMAPCorpus` and `IMAPDispatchClient` are declared in that configuration. The rest of the
// suite names `IMAPOutputBuffer`, `IMAPBufferList` and the post-migration model, none of which exist
// on `main`, so it cannot compile there and there is nothing to gain by trying.
let legacyImplementation = Context.environment["IMAP_IMPL"] == "main"
let libraryPath =
    legacyImplementation
    ? (Context.environment["IMAP_MAIN_PATH"] ?? "../../.worktrees/pre-migration")
    : "../.."

// Corpora, as wire bytes and wire text. Portable across both library versions on purpose: it names
// no type the migration changed, so the two configurations are fed byte-identical input.
var targets: [Target] = [
    .target(
        name: "IMAPCorpus",
        dependencies: [
            .product(name: "NIO", package: "swift-nio")
        ]
    ),
    // The before/after comparison for a client whose transport is `DispatchData` throughout. Its
    // drivers exist twice, selected by `IMAP_LEGACY_BUFFERS`.
    .executableTarget(
        name: "IMAPDispatchClient",
        dependencies: [
            "IMAPCorpus",
            .product(name: "NIOIMAP", package: "swift-nio-imap"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "Benchmark", package: "benchmark"),
        ],
        path: "Benchmarks/IMAPDispatchClient",
        swiftSettings: legacyImplementation ? [.define("IMAP_LEGACY_BUFFERS")] : [],
        plugins: [
            .plugin(name: "BenchmarkPlugin", package: "benchmark")
        ]
    ),
]

if !legacyImplementation {
    targets += [
        // Corpora and drivers shared by the benchmark targets. Deliberately has no dependency
        // on `Benchmark`, so the same code can be driven from a plain executable or a test.
        .target(
            name: "IMAPBenchmarkSupport",
            dependencies: [
                "IMAPCorpus",
                .product(name: "NIOIMAP", package: "swift-nio-imap"),
                .product(name: "NIO", package: "swift-nio"),
            ]
        ),
        .executableTarget(
            name: "IMAPParsing",
            dependencies: [
                "IMAPBenchmarkSupport",
                .product(name: "NIOIMAP", package: "swift-nio-imap"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Benchmark", package: "benchmark"),
            ],
            path: "Benchmarks/IMAPParsing",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        ),
        .executableTarget(
            name: "IMAPEncoding",
            dependencies: [
                "IMAPBenchmarkSupport",
                .product(name: "NIOIMAP", package: "swift-nio-imap"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Benchmark", package: "benchmark"),
            ],
            path: "Benchmarks/IMAPEncoding",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        ),
    ]
}

let package = Package(
    name: "imap-performance-tester-example",
    platforms: [
        // Matches the library, which pins macOS 26 for the stdlib accessors that produce a `Span`.
        .macOS(.v26)
    ],
    dependencies: [
        .package(name: "swift-nio-imap", path: libraryPath),
        .package(url: "https://github.com/apple/swift-nio", from: "2.64.0"),
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.36.2"),
    ],
    targets: targets
)
