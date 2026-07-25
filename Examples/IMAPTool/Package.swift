// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "imap-tool-example",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "IMAPToolLib", targets: ["IMAPToolLib"]),
        .executable(name: "imap-tool", targets: ["IMAPTool"]),
    ],
    dependencies: [
        .package(name: "swift-nio-imap", path: "../.."),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.7.0")),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-collections", "1.4.0"..<"2.0.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.64.0"),
        .package(url: "https://github.com/apple/swift-system", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "IMAPToolLib",
            dependencies: [
                .product(name: "NIOIMAP", package: "swift-nio-imap"),
                .product(name: "IMAPCommands", package: "swift-nio-imap"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "DequeModule", package: "swift-collections"),
            ]
        ),
        .executableTarget(
            name: "IMAPTool",
            dependencies: [
                .target(name: "IMAPToolLib"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "IMAPToolLibTests",
            dependencies: [
                .target(name: "IMAPToolLib"),
                .product(name: "IMAPCommands", package: "swift-nio-imap"),
                .product(name: "NIOIMAP", package: "swift-nio-imap"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "SystemPackage", package: "swift-system"),
            ]
        ),
    ]
)
