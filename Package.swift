// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-nio-imap",
    products: [
        .library(name: "NIOIMAP", targets: ["NIOIMAP"])
    ], dependencies: [
        .package(url: "https://github.com/apple/swift-nio", from: "2.13.0"),
        .package(url: "https://github.com/apple/swift-nio-extras", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "NIOIMAP",
            dependencies: ["NIO"]
        ),
        .target(
            name: "CLI",
            dependencies: ["CLILib"]
        ),
        .target(
            name: "CLILib",
            dependencies: ["NIO", "NIOSSL", "NIOIMAP", "Logging"]
        ),
        .target(
            name: "Proxy",
            dependencies: ["NIOIMAP", "NIO", "NIOSSL"]
        ),
        .testTarget(
            name: "NIOIMAPTests",
            dependencies: ["NIOIMAP", "NIO", "NIOTestUtils"]
        ),
        .testTarget(
            name: "CLILibTests",
            dependencies: ["CLILib", "NIO", "NIOTestUtils"]
        ),
    ]
)
