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

// Fast paths for long lists of numbers, i.e. large `SEARCH` and `ESEARCH` results.
//
// They read straight out of the current chunk, with no allocation and no combinator per number, and
// accept only the well-formed shape. On anything else they stop *before* the element they could not
// read, having consumed only complete elements, so the generic grammar picks up exactly where they
// left off:
//
//     " 12 345 6789 (MODSEQ 5)\r\n"
//      └──── fast ────┘└ generic ┘
//
// A number that runs to the end of the chunk is left to the generic grammar too, since it may
// continue in the next region.

/// The most decimal digits a `UInt32` can have (4294967295).
private let maximumUInt32Digits = 10

extension ParseInput {
    /// Consumes as many `SP nz-number` elements as the current chunk holds, calling `body` with each.
    ///
    /// Reads e.g. `" 2 10 300"`. Stops before the first element that is not exactly one space followed
    /// by a number with no leading zero that fits in a `UInt32` and ends inside the chunk.
    ///
    /// - Returns: How many elements it consumed.
    @_lifetime(self: copy self)
    @discardableResult
    mutating func parseSpaceSeparatedNZNumbers(_ body: (UInt32) -> Void) -> Int {
        var elements = 0
        let consumed = withCurrentChunk { chunk in
            chunk.withUnsafeBufferPointer { bytes -> Int in
                var consumed = 0
                while let (value, end) = Self.nzNumber(in: bytes, after: UInt8(ascii: " "), at: consumed) {
                    body(value)
                    elements += 1
                    consumed = end
                }
                return consumed
            }
        }
        advance(by: consumed)
        return elements
    }

    /// Reads `separator nz-number` at `start`, e.g. `" 300"`.
    ///
    /// - Returns: The number and the index just past it, or `nil` if `bytes` does not hold exactly that
    ///   shape followed by a non-digit.
    @inline(__always)
    private static func nzNumber(
        in bytes: UnsafeBufferPointer<UInt8>,
        after separator: UInt8,
        at start: Int
    ) -> (value: UInt32, end: Int)? {
        guard start < bytes.count, bytes[start] == separator else { return nil }
        let first = start + 1
        guard first < bytes.count, bytes[first] &- UInt8(ascii: "1") < 9 else { return nil }
        var value = UInt64(bytes[first] &- UInt8(ascii: "0"))
        var index = first + 1
        while index < bytes.count {
            let digit = bytes[index] &- UInt8(ascii: "0")
            guard digit < 10 else { break }
            guard index - first < maximumUInt32Digits else { return nil }
            value = value * 10 + UInt64(digit)
            index += 1
        }
        // The terminator must be visible: a number at the end of the chunk may continue past it.
        guard index < bytes.count, let value = UInt32(exactly: value) else { return nil }
        return (value, index)
    }
}
