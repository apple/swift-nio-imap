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

import NIO

/// The read sizes the parser benchmarks feed input at.
///
/// Why these sizes:
///
/// - `1` is the pathological case: a byte-at-a-time feed measures the per-read overhead (an append
///   plus a parse attempt) in isolation.
/// - `1448` is an Ethernet MTU minus TCP/IP headers, i.e. the smallest realistic size a socket
///   read delivers. The `copyThreshold` of 1024 is deliberately below it.
/// - the rest bracket the sizes at which pinning a whole received buffer to extract a few bytes
///   from it starts to waste footprint.
public enum ReadSize {
    /// One byte at a time. See ``ReadSize``.
    public static let single = 1
    /// An Ethernet MTU minus TCP/IP headers.
    public static let mtu = 1_448
    /// Every read size the parser benchmarks sweep, smallest first.
    public static let sweep = [1_448, 4_096, 16_384, 65_536]
}

extension ByteBuffer {
    /// Splits the readable bytes into chunks of at most `size` bytes, in order.
    ///
    /// The chunks share storage with `self`; they are slices, not copies. Splitting up front
    /// means the benchmark's measured region contains only the parse work, not the slicing.
    ///
    /// - Parameter size: The maximum size of each chunk. Must be greater than zero.
    /// - Returns: The chunks, in order. Only the last one may be shorter than `size`.
    public func chunks(ofSize size: Int) -> [ByteBuffer] {
        precondition(size > 0, "chunk size must be positive")
        var result: [ByteBuffer] = []
        result.reserveCapacity((self.readableBytes / size) + 1)
        var offset = self.readerIndex
        let end = self.writerIndex
        while offset < end {
            let length = min(size, end - offset)
            result.append(self.getSlice(at: offset, length: length)!)
            offset += length
        }
        return result
    }
}
