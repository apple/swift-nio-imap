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

import ArgumentParser
// `FileHandle` is not part of `FoundationEssentials`.
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// The output format for command results.
public enum ResultFormat: String, Sendable {
    /// Plain text output.
    case text
    /// JSON output.
    case json
}

extension ResultFormat: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(rawValue: argument)
    }
}

// MARK: -

/// Write the execution result to standard output.
///
/// This uses the given `format` and writes either plain text or JSON.
/// Note that all other output should use `writeStatus()` and go to standard error to allow
/// piping the result to another tool.
public func writeResult<R>(
    result: R,
    format: ResultFormat,
    terminator: Data? = nil
) where R: Encodable {
    let data: Data
    do {
        data = try makeResultData(
            result: result,
            format: format
        )
    } catch {
        exitWithErrorMessage("Failed to encode result '\(String(describing: result))'.")
    }

    // Flush the status -- if we’re running in the terminal, both will
    // go to the tty.
    flushStatus()
    // Write to stdout:
    FileHandle.standardOutput.write(data)
    if let terminator {
        FileHandle.standardOutput.write(terminator)
    }
    // We use fsync(2) and intentionally ignore the result. This can fail depending on what kind of output (terminal vs. pipe vs. file) standard output is going to.
    _ = fsync(FileHandle.standardOutput.fileDescriptor)
}

private func makeResultData<R>(
    result: R,
    format: ResultFormat
) throws -> Data where R: Encodable {
    try makeResultData(result, format: format)
}

func makeResultData<R>(_ result: R, format: ResultFormat) throws -> Data where R: Encodable {
    switch format {
    case .text:
        let encoder = TextEncoder()
        return try encoder.encode(result).data(using: .utf8)!
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(result)
    }
}
