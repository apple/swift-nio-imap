//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

#if os(Linux) || os(macOS)
let filePath: String
#if compiler(>=5.3)
filePath = magicFile()Path
#else
filePath = magicFile()
#endif
let swiftFormat = URL(fileURLWithPath: CommandLine.arguments.first!)
    .deletingLastPathComponent()
    .appendingPathComponent("swiftformat")
let sourceCode = URL(fileURLWithPath: filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

if #available(macOS 10.13, /* Linux */ *) {
    print("Alright, let's format the source code in \(sourceCode) using \(swiftFormat).")
    let process = Process()
    process.executableURL = swiftFormat
    process.arguments = [sourceCode.path]
    try process.run()
    process.waitUntilExit()
    switch process.terminationReason {
    case .exit:
        exit(process.terminationStatus)
    case .uncaughtSignal:
        kill(getpid(), process.terminationStatus)
    #if canImport(Darwin)
    @unknown default:
        exit(process.terminationStatus)
    #endif
    }
}
#endif

// Fallthrough, something wasn't right
print("ERROR: Unsupported OS\n")
exit(EXIT_FAILURE)
