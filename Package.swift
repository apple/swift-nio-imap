// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-nio-imap",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "NIOIMAP", targets: ["NIOIMAP"]),
        .library(name: "IMAPCommands", targets: ["IMAPCommands"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-collections", "1.4.0"..<"2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.24.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.64.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.4.4"),
        .package(url: "https://github.com/apple/swift-se0270-range-set.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "NIOIMAP",
            dependencies: [
                .target(name: "NIOIMAPCore")
            ]
        ),
        .testTarget(
            name: "NIOIMAPTests",
            dependencies: [
                .target(name: "NIOIMAP"),
                .target(name: "NIOIMAPCore"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ]
        ),

        .target(
            name: "NIOIMAPCore",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "SE0270_RangeSet", package: "swift-se0270-range-set"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "NIOIMAPCoreTests",
            dependencies: [
                .target(name: "NIOIMAPCore"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ]
        ),

        .target(
            name: "IMAPCommands",
            dependencies: [
                .target(name: "NIOIMAP"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "IMAPCommandsTests",
            dependencies: [
                .target(name: "IMAPCommands"),
                .target(name: "NIOIMAP"),
            ]
        ),
    ]
)
