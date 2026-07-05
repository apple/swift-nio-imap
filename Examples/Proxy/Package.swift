// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "imap-proxy-example",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(name: "swift-nio-imap", path: "../.."),
        .package(url: "https://github.com/apple/swift-nio", from: "2.64.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.24.0"),
    ],
    targets: [
        .executableTarget(
            name: "Proxy",
            dependencies: [
                .product(name: "NIOIMAP", package: "swift-nio-imap"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ]
        ),
    ]
)
