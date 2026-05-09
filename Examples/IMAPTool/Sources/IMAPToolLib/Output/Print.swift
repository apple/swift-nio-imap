//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(Glibc)
import Glibc
nonisolated(unsafe) let _exit: (Int32) -> Never = Glibc.exit
#elseif canImport(Darwin)
import Darwin
nonisolated(unsafe) let _exit: (Int32) -> Never = Darwin.exit
#elseif canImport(MSVCRT)
import MSVCRT
nonisolated(unsafe) let _exit: (Int32) -> Never = ucrt._exit
#endif

/// Writes to standard error (`stderr`).
///
/// This is for informational messages. It does not interfere with command output (such as JSON).
public func writeStatus(_ output: Output, terminator: String = "\n") {
    let text = output.text + terminator
    FileHandle.standardError.write(text.data(using: .utf8)!)
}

/// Writes to standard output (`stdout`).
///
/// Used for "clean" terminations such as `--help` and `--version`, whose text
/// belongs on standard output rather than standard error.
func writeStandardOutput(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
    _ = fsync(FileHandle.standardOutput.fileDescriptor)
}

func flushStatus() {
    // We use fsync(2) and intentionally ignore the result. This can fail depending on what kind of output (terminal vs. pipe vs. file) standard output is going to.
    _ = fsync(FileHandle.standardError.fileDescriptor)
}

/// Writes the output message to standard error and terminates the process.
public func exitWithErrorMessage(_ output: Output, code: Int32 = -1) -> Never {
    writeStatus(output)
    flushStatus()
    _exit(code)
}
