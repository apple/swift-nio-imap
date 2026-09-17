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

import NIOCore
import NIOFileSystem
import SystemPackage
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private let tokenBucket = TokenBucket(tokens: 20)

extension Data {
    /// Reads the contents of the file at the given path asynchronously.
    init(
        asyncContentsOf filePath: FilePath,
        length: Int = .max
    ) async throws {
        let buffer = try await read(
            filePath: filePath,
            length: length
        )
        self.init(buffer.readableBytesView)
    }
}

extension ByteBuffer {
    /// Reads the contents of the file at the given path asynchronously.
    init(
        asyncContentsOf filePath: FilePath,
        length: Int = .max
    ) async throws {
        self = try await read(
            filePath: filePath,
            length: length
        )
    }
}

private func read(
    filePath: FilePath,
    length: Int
) async throws -> ByteBuffer {
    // Use the TokenBucket to limit concurrency.
    try await tokenBucket.withToken {
        try await readWithToken(
            filePath: filePath,
            length: length
        )
    }
}

private func readWithToken(
    filePath: FilePath,
    length: Int
) async throws -> ByteBuffer {
    try await FileSystem.shared.withFileHandle(forReadingAt: filePath) { handle in
        guard length != .max else {
            return try await handle.readToEnd(maximumSizeAllowed: .unlimited)
        }
        // `length` is an upper bound, not the exact size to read: callers use it to
        // look at just the start of a message. Reading in chunks lets us stop early
        // rather than pulling a whole (potentially huge) file into memory.
        var result = ByteBuffer()
        for try await var chunk in handle.readChunks() {
            let remaining = length - result.readableBytes
            guard chunk.readableBytes < remaining else {
                result.writeImmutableBuffer(chunk.readSlice(length: remaining)!)
                break
            }
            result.writeImmutableBuffer(chunk)
        }
        return result
    }
}
