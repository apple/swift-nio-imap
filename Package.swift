// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
// 6.2 is the floor so that the package always builds with `nonisolated(nonsending)` available.

import PackageDescription

let package = Package(
    name: "swift-nio-imap",
    // Pinned so that the package can use the stdlib's newer memory-safety types. `Span` itself
    // back-deploys to macOS 10.14.4, but the accessors that produce one from an existing value do not:
    // `String.utf8Span`, `Array.span` and `InlineArray` are all `anyAppleOS 26.0`, because a bridged
    // or otherwise non-contiguous value has no buffer to lend and the getter cannot back-deploy.
    // Declaring the floor is what makes those usable in the parser and the encoder.
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: "NIOIMAP", targets: ["NIOIMAP"]),
        .library(name: "IMAPCommands", targets: ["IMAPCommands"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", "1.4.0"..<"2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.24.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.64.0"),
        // 1.14.0 introduced the task-local `withLogger` / `Logger.current` APIs.
        .package(url: "https://github.com/apple/swift-log", from: "1.14.0"),
    ],
    targets: [
        .target(
            name: "NIOIMAP",
            dependencies: [
                .target(name: "NIOIMAPCore")
            ],
            // The documentation is built out-of-band, not by SwiftPM: excluding the catalog
            // keeps it out of the build product instead of being copied in as a resource.
            exclude: ["NIOIMAP.docc"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        ),
        .testTarget(
            name: "NIOIMAPTests",
            dependencies: [
                .target(name: "NIOIMAP"),
                .target(name: "NIOIMAPCore"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        ),

        .target(
            name: "NIOIMAPCore",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "DequeModule", package: "swift-collections"),
            ],
            // The documentation is built out-of-band, not by SwiftPM: excluding the catalog
            // keeps it out of the build product instead of being copied in as a resource.
            exclude: ["NIOIMAPCore.docc"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                // For `@_lifetime` and non-escapable parse cursors. `Lifetimes` is the only feature
                // needed and the only one to enable: the older `LifetimeDependence` spelling does not
                // enable `@_lifetime` (verified — "'@_lifetime' attribute is only valid when
                // experimental feature Lifetimes is enabled"), so adding it would be misleading noise.
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
        .testTarget(
            name: "NIOIMAPCoreTests",
            dependencies: [
                .target(name: "NIOIMAPCore"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),

        .target(
            name: "IMAPCommands",
            dependencies: [
                .target(name: "NIOIMAP"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "Logging", package: "swift-log"),
            ],
            exclude: ["IMAPCommands.docc"],
            swiftSettings: [
                // The closure-taking APIs are caller-isolated: their closures need to be able to
                // capture, mutate and return non-`Sendable` state belonging to whatever actor
                // called them. That requires both the methods and the closure types to be
                // `nonisolated(nonsending)`, which is what this makes the default.
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        ),
        .testTarget(
            name: "IMAPCommandsTests",
            dependencies: [
                .target(name: "IMAPCommands"),
                .target(name: "NIOIMAP"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        ),
    ]
)
