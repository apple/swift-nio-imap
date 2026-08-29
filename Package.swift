// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
// 6.2 is the floor so that the package always builds with `nonisolated(nonsending)` available.

import PackageDescription

let package = Package(
    name: "swift-nio-imap",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .watchOS(.v11),
        .tvOS(.v18),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "NIOIMAP", targets: ["NIOIMAP"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", from: "2.64.0"),
        .package(url: "https://github.com/apple/swift-collections.git", "1.1.0"..<"2.0.0"),
    ],
    targets: [
        .target(
            name: "NIOIMAP",
            dependencies: [
                "NIOIMAPCore"
            ],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        ),
        .testTarget(
            name: "NIOIMAPTests",
            dependencies: [
                "NIOIMAP",
                "NIOIMAPCore",
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
            ],
            // The documentation is built out-of-band, not by SwiftPM: excluding the catalog
            // keeps it out of the build product instead of being copied in as a resource.
            exclude: ["NIOIMAPCore.docc"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        ),
        .testTarget(
            name: "NIOIMAPCoreTests",
            dependencies: [
                "NIOIMAPCore",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility")
            ]
        ),
    ]
)
