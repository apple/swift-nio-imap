// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-nio-imap",
    products: [
        .library(name: "NIOIMAP", targets: ["NIOIMAP"]),
    ], dependencies: [
        .package(url: "https://github.com/apple/swift-nio", from: "2.34.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.16.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.49.4"),
        .package(url: "https://github.com/apple/swift-standard-library-preview.git", .exact("0.0.3")),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .executableTarget(
            name: "NIOIMAPPerformanceTester",
            dependencies: [
                "NIOIMAP",
            ]
        ),
        .target(
            name: "NIOIMAP",
            dependencies: [
                "NIOIMAPCore",
            ]
        ),
        .testTarget(
            name: "NIOIMAPTests",
            dependencies: [
                "NIOIMAP",
                "NIOIMAPCore",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ]
        ),

        .target(
            name: "NIOIMAPCore",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "StandardLibraryPreview", package: "swift-standard-library-preview"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "NIOIMAPCoreTests",
            dependencies: [
                "NIOIMAPCore",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ]
        ),

        .executableTarget(
            name: "CLI",
            dependencies: [
                "CLILib",
            ]
        ),
        .target(
            name: "CLILib",
            dependencies: [
                "NIOIMAP",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "CLILibTests",
            dependencies: [
                "CLILib",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ]
        ),

        .executableTarget(
            name: "Proxy",
            dependencies: [
                "NIOIMAP",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ]
        ),

        .executableTarget(
            name: "NIOIMAPFormatter",
            dependencies: [
                .product(name: "swiftformat", package: "SwiftFormat"),
            ]
        ),

        .executableTarget(
            name: "NIOIMAPFuzzer",
            dependencies: [
                "NIOIMAP",
                .product(name: "NIO", package: "swift-nio"),
            ]
        ),
    ]
)
