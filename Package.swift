// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-nio-imap",
    products: [
        .library(name: "NIOIMAP", targets: ["NIOIMAP"]),
    ], dependencies: [
        .package(url: "https://github.com/apple/swift-nio", from: "2.27.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.10.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", .exact("0.47.13")),
        .package(url: "https://github.com/apple/swift-standard-library-preview.git", .exact("0.0.1")),
    ],
    targets: [
        .target(
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

        .target(
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

        .target(
            name: "Proxy",
            dependencies: [
                "NIOIMAP",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ]
        ),

        .target(
            name: "NIOIMAPFormatter",
            dependencies: [
                .product(name: "swiftformat", package: "SwiftFormat"),
            ]
        ),
    ]
)
