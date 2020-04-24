// swift-tools-version:5.1
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
        .target(name: "NIOIMAP", dependencies: ["NIOIMAPCore"]),
        .testTarget(
            name: "NIOIMAPTests",
            dependencies: ["NIOIMAP", "NIOIMAPCore", "NIO", "NIOTestUtils"]
        ),

        .target(name: "NIOIMAPCore", dependencies: ["NIO"]),
        .testTarget(
            name: "NIOIMAPCoreTests",
            dependencies: ["NIOIMAPCore", "NIO", "NIOTestUtils"]
        ),

        .target(name: "CLI", dependencies: ["CLILib"]),
        .target(name: "CLILib", dependencies: ["NIO", "NIOSSL", "NIOIMAP", "Logging"]),
        .testTarget(
            name: "CLILibTests",
            dependencies: ["CLILib", "NIO", "NIOTestUtils"]
        ),

        .target(name: "Proxy", dependencies: ["NIOIMAP", "NIO", "NIOSSL"]),
    ]
)
