// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-nio-email",
    products: [
        .library(name: "NIOIMAP", targets: ["NIOIMAPCore"]),
    ], dependencies: [
        .package(url: "https://github.com/apple/swift-nio", from: "2.16.0"),
        .package(url: "https://github.com/apple/swift-nio-extras", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.7.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.2.0"),
    ],
    targets: [
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
    ]
)
