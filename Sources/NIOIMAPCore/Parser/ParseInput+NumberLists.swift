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
//
// Numbers are read 8 bytes at a time (SWAR, see `DecimalSWAR`), and results go to the caller's array
// in batches, so it pays one uniqueness check per batch rather than per element. 5,000 UIDs: ~1.5 ns
// each with 5 digits, ~2.4 ns with 9, against ~3.7 ns and ~5 ns a byte at a time.

/// The most decimal digits a `UInt32` can have (4294967295).
private let maximumUInt32Digits = 10

/// How many results are collected on the stack before they are appended to the caller's array.
private let batchCapacity = 64

extension ParseInput {
    /// Consumes as many `SP nz-number` elements as the current chunk holds, appending each to `output`.
    ///
    /// Reads e.g. `" 2 10 300"`. Stops before the first element that is not exactly one space followed
    /// by a number with no leading zero that fits in a `UInt32` and ends inside the chunk.
    ///
    /// - Returns: How many elements it consumed.
    @_lifetime(self: copy self)
    @discardableResult
    mutating func parseSpaceSeparatedNZNumbers<T>(
        appendingTo output: inout [T],
        _ transform: (UInt32) -> T
    ) -> Int {
        var elements = 0
        let consumed = withCurrentChunk { chunk in
            chunk.withUnsafeBufferPointer { bytes -> Int in
                withAppendBatch(of: T.self) { batch -> Int in
                    var consumed = 0
                    while let (value, end) = Self.nzNumber(in: bytes, after: UInt8(ascii: " "), at: consumed) {
                        batch.append(transform(value), flushingTo: &output)
                        elements += 1
                        consumed = end
                    }
                    batch.flush(to: &output)
                    return consumed
                }
            }
        }
        advance(by: consumed)
        return elements
    }

    /// Consumes as many `"," nz-number [":" nz-number]` elements as the current chunk holds, appending
    /// each to `output`.
    ///
    /// Reads the tail of a sequence set, e.g. `",5,7:9,20:12"`, as `5...5`, `7...9`, `12...20`: a range
    /// is ordered, as the generic grammar does. Stops before the first element it cannot read whole,
    /// e.g. one containing `*`.
    ///
    /// - Returns: How many elements it consumed.
    @_lifetime(self: copy self)
    @discardableResult
    mutating func parseCommaSeparatedNZRanges<T>(
        appendingTo output: inout [T],
        _ transform: (ClosedRange<UInt32>) -> T
    ) -> Int {
        var elements = 0
        let consumed = withCurrentChunk { chunk in
            chunk.withUnsafeBufferPointer { bytes -> Int in
                withAppendBatch(of: T.self) { batch -> Int in
                    var consumed = 0
                    while let (first, firstEnd) = Self.nzNumber(in: bytes, after: UInt8(ascii: ","), at: consumed) {
                        var end = firstEnd
                        var range = first...first
                        if bytes[firstEnd] == UInt8(ascii: ":") {
                            guard
                                let (second, secondEnd) = Self.nzNumber(
                                    in: bytes,
                                    after: UInt8(ascii: ":"),
                                    at: firstEnd
                                )
                            else { break }
                            range = min(first, second)...max(first, second)
                            end = secondEnd
                        }
                        batch.append(transform(range), flushingTo: &output)
                        elements += 1
                        consumed = end
                    }
                    batch.flush(to: &output)
                    return consumed
                }
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
        // Two words hold the longest number and its terminator; near the end of the chunk, go byte by byte.
        guard first + DecimalSWAR.windowSize <= bytes.count else {
            return nzNumberByteByByte(in: bytes, first: first)
        }
        return DecimalSWAR.number(at: UnsafeRawPointer(bytes.baseAddress! + first), first: first)
    }

    /// The digits at `first` onwards, one byte at a time. `bytes[first]` is a digit other than `0`.
    private static func nzNumberByteByByte(
        in bytes: UnsafeBufferPointer<UInt8>,
        first: Int
    ) -> (value: UInt32, end: Int)? {
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

/// Results collected on the stack and appended to an array a batch at a time: one uniqueness check
/// and one copy per batch, rather than a uniqueness check per element.
private struct AppendBatch<Element> {
    private let storage: UnsafeMutableBufferPointer<Element>
    private var count = 0

    fileprivate init(storage: UnsafeMutableBufferPointer<Element>) {
        self.storage = storage
    }

    @inline(__always)
    mutating func append(_ element: Element, flushingTo output: inout [Element]) {
        storage.initializeElement(at: count, to: element)
        count += 1
        if count == storage.count { flush(to: &output) }
    }

    mutating func flush(to output: inout [Element]) {
        let filled = UnsafeMutableBufferPointer(rebasing: storage[..<count])
        output.append(contentsOf: filled)
        filled.deinitialize()
        count = 0
    }
}

/// Runs `body` with an empty batch on the stack. `body` must flush the batch before it returns.
@inline(__always)
private func withAppendBatch<Element, Result>(
    of _: Element.Type,
    _ body: (inout AppendBatch<Element>) -> Result
) -> Result {
    withUnsafeTemporaryAllocation(of: Element.self, capacity: batchCapacity) { storage in
        var batch = AppendBatch(storage: storage)
        return body(&batch)
    }
}

/// Decimal digits read 8 at a time from a `UInt64` ("SIMD within a register").
///
/// Byte `i` of a little-endian load is the `i`-th character, so for `"12345 67"`:
///
///     word − 0x3030…   [1, 2, 3, 4, 5, 0xF0, 6, 7]    digit values; a space wraps to 0xF0
///     digit run        5                             bytes before the first non-digit
///     shifted left     [0, 0, 0, 1, 2, 3, 4, 5]       digits right-aligned in the top bytes
///     pairs, quads…    12345                         three multiply-adds, 2→4→8 digits
private enum DecimalSWAR {
    /// Bytes read per number: two words, enough for 10 digits and the terminator.
    static let windowSize = 16

    /// `'0'` in every byte.
    private static let zeros: UInt64 = 0x3030_3030_3030_3030

    /// Added to a byte's digit value, sets its high bit if the value is above 9.
    private static let aboveNine: UInt64 = 0x7676_7676_7676_7676

    /// The high bit of every byte.
    private static let highBits: UInt64 = 0x8080_8080_8080_8080

    /// Reads the number whose first digit, not `0`, is at `pointer`, `first` being its index.
    ///
    /// - Precondition: `windowSize` bytes are readable at `pointer`.
    /// - Returns: The number and the index just past it, or `nil` if it has more than 10 digits or
    ///   does not fit in a `UInt32`.
    @inline(__always)
    static func number(at pointer: UnsafeRawPointer, first: Int) -> (value: UInt32, end: Int)? {
        let low = digitValues(UInt64(littleEndian: pointer.loadUnaligned(as: UInt64.self)))
        let lowCount = digitRun(low)
        guard lowCount == 8 else {
            return (UInt32(truncatingIfNeeded: value(of: low, count: lowCount)), first + lowCount)
        }
        let high = digitValues(UInt64(littleEndian: pointer.loadUnaligned(fromByteOffset: 8, as: UInt64.self)))
        let highCount = digitRun(high)
        guard highCount <= maximumUInt32Digits - 8 else { return nil }
        let scale: UInt64 = highCount == 0 ? 1 : (highCount == 1 ? 10 : 100)
        let total = value(of: low, count: 8) * scale + value(of: high, count: highCount)
        guard let total = UInt32(exactly: total) else { return nil }
        return (total, first + 8 + highCount)
    }

    /// Each byte minus `'0'`. Exact for every byte up to the first non-digit; a borrow only reaches
    /// bytes after it.
    @inline(__always)
    private static func digitValues(_ word: UInt64) -> UInt64 {
        word &- zeros
    }

    /// How many leading bytes of `values` are digits, 0…8.
    @inline(__always)
    private static func digitRun(_ values: UInt64) -> Int {
        // A byte is not a digit if its value wrapped (high bit set) or is above 9.
        let nonDigits = (values | (values &+ aboveNine)) & highBits
        return nonDigits == 0 ? 8 : nonDigits.trailingZeroBitCount / 8
    }

    /// The number formed by the first `count` digit values of `values`, 0…8 of them.
    @inline(__always)
    private static func value(of values: UInt64, count: Int) -> UInt64 {
        guard count > 0 else { return 0 }
        var x = values << UInt64((8 - count) * 8)
        x = (x &* 10 &+ (x >> 8)) & 0x00FF_00FF_00FF_00FF
        x = (x &* 100 &+ (x >> 16)) & 0x0000_FFFF_0000_FFFF
        x = (x &* 10_000 &+ (x >> 32)) & 0x0000_0000_FFFF_FFFF
        return x
    }
}
