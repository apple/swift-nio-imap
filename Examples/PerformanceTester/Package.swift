// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
// 6.2 to match the root package, which this example depends on by path.

import PackageDescription

let package = Package(
    name: "imap-performance-tester-example",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(name: "swift-nio-imap", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "NIOIMAPPerformanceTester",
            dependencies: [
                .product(name: "NIOIMAP", package: "swift-nio-imap")
            ]
        )
    ]
)
