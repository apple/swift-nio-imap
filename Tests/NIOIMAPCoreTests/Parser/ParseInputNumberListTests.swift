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

@testable import NIOIMAPCore
import Testing

// The fast path must consume exactly the elements the generic grammar would accept as well-formed, and
// stop before anything else, so the generic grammar resumes at the right byte.
extension ParseInputTests {
    @Test(
        "space-separated numbers: reads well-formed elements, stops before the rest",
        arguments: [
            (" 2 10 300\r\n", [2, 10, 300], 9),
            (" 4294967295 1\r\n", [4_294_967_295, 1], 13),
            // Two spaces, a leading zero, zero itself: left to the generic grammar.
            (" 2  10\r\n", [2], 2),
            (" 2 010\r\n", [2], 2),
            (" 2 0\r\n", [2], 2),
            // Too large for a UInt32, by value and by digit count.
            (" 4294967296\r\n", [], 0),
            (" 12345678901\r\n", [], 0),
            // No visible terminator: the number may continue.
            (" 2 10", [2], 2),
            // What may follow a SEARCH result.
            (" 2 (MODSEQ 5)\r\n", [2], 2),
            (" 2 \r\n", [2], 2),
            ("2 3\r\n", [], 0),
            ("", [], 0),
        ] as [(String, [UInt32], Int)]
    )
    func spaceSeparatedNumbers(_ input: String, _ expected: [UInt32], _ consumed: Int) {
        ParseInputHarness.withSpan(input) { buffer in
            var numbers: [UInt32] = []
            let count = buffer.parseSpaceSeparatedNZNumbers(appendingTo: &numbers) { $0 }
            #expect(numbers == expected)
            #expect(count == expected.count)
            #expect(buffer.consumed == consumed)
        }
    }

    @Test("space-separated numbers: stops before a number that crosses a region boundary")
    func spaceSeparatedNumbersAcrossRegions() {
        ParseInputHarness.withInput([TestRegion(" 2 1"), TestRegion("0 300\r\n")]) { buffer in
            var numbers: [UInt32] = []
            buffer.parseSpaceSeparatedNZNumbers(appendingTo: &numbers) { $0 }
            #expect(numbers == [2])
            #expect(buffer.consumed == 2)
        }
    }

    @Test(
        "comma-separated ranges: reads well-formed elements, stops before the rest",
        arguments: [
            (",5,7:9,12\r\n", [5...5, 7...9, 12...12], 9),
            // A reversed range is ordered, as the generic grammar does.
            (",20:12 ", [12...20], 6),
            (",1:4294967295)", [1...4_294_967_295], 13),
            // `*` and anything malformed are left to the generic grammar.
            (",5,7:*\r\n", [5...5], 2),
            (",5,*:7\r\n", [5...5], 2),
            (",5,7:\r\n", [5...5], 2),
            (",5,7:0\r\n", [5...5], 2),
            (",5,07\r\n", [5...5], 2),
            (",5,,7\r\n", [5...5], 2),
            (",5,4294967296\r\n", [5...5], 2),
            // No visible terminator, after either bound.
            (",5,7", [5...5], 2),
            (",5,7:9", [5...5], 2),
            (",5,7:", [5...5], 2),
            // What may follow a sequence set.
            (",5 COUNT 2\r\n", [5...5], 2),
            ("5,7\r\n", [], 0),
            ("", [], 0),
        ] as [(String, [ClosedRange<UInt32>], Int)]
    )
    func commaSeparatedRanges(_ input: String, _ expected: [ClosedRange<UInt32>], _ consumed: Int) {
        ParseInputHarness.withSpan(input) { buffer in
            var ranges: [ClosedRange<UInt32>] = []
            let count = buffer.parseCommaSeparatedNZRanges(appendingTo: &ranges) { $0 }
            #expect(ranges == expected)
            #expect(count == expected.count)
            #expect(buffer.consumed == consumed)
        }
    }

    @Test("comma-separated ranges: stops before an element that crosses a region boundary")
    func commaSeparatedRangesAcrossRegions() {
        ParseInputHarness.withInput([TestRegion(",5,7:"), TestRegion("9,12\r\n")]) { buffer in
            var ranges: [ClosedRange<UInt32>] = []
            buffer.parseCommaSeparatedNZRanges(appendingTo: &ranges) { $0 }
            #expect(ranges == [5...5])
            #expect(buffer.consumed == 2)
        }
    }

    // The cases above are short, so they take the byte-by-byte path. Longer random inputs take the
    // 8-bytes-at-a-time path too, and both must match a plain reference: long numbers, leading zeros,
    // overflow, junk, and numbers ending anywhere relative to the 16-byte window.
    @Test("number lists match a plain reference on random input")
    func numberListsMatchReference() {
        // 64-bit LCG: deterministic, so a failure reproduces.
        var state: UInt64 = 0x1234_5678_9ABC_DEF1
        func next(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int(truncatingIfNeeded: state >> 33) % bound
        }
        let separators = Array(" ,:".utf8)
        let junk = Array("x\r(*".utf8)

        for _ in 0..<20_000 {
            var bytes: [UInt8] = []
            for _ in 0..<(1 + next(12)) {
                bytes.append(separators[next(separators.count)])
                // Mostly 1–10 digits; sometimes 11–12, sometimes a leading zero.
                for position in 0..<(1 + next(12)) {
                    let digit = position == 0 && next(8) != 0 ? 1 + next(9) : next(10)
                    bytes.append(UInt8(ascii: "0") + UInt8(digit))
                }
                if next(10) == 0 { bytes.append(junk[next(junk.count)]) }
            }
            if next(2) == 0 { bytes += Array("\r\n".utf8) }
            let input = String(decoding: bytes, as: UTF8.self)

            ParseInputHarness.withSpan(input) { buffer in
                var numbers: [UInt32] = []
                buffer.parseSpaceSeparatedNZNumbers(appendingTo: &numbers) { $0 }
                let expected = Self.referenceNumbers(bytes)
                #expect(numbers == expected.values, "\(input.debugDescription)")
                #expect(buffer.consumed == expected.consumed, "\(input.debugDescription)")
            }
            ParseInputHarness.withSpan(input) { buffer in
                var ranges: [ClosedRange<UInt32>] = []
                buffer.parseCommaSeparatedNZRanges(appendingTo: &ranges) { $0 }
                let expected = Self.referenceRanges(bytes)
                #expect(ranges == expected.values, "\(input.debugDescription)")
                #expect(buffer.consumed == expected.consumed, "\(input.debugDescription)")
            }
        }
    }

    /// `separator nz-number` at `start`: at most 10 digits, no leading zero, fits a `UInt32`, and
    /// followed by a visible byte.
    private static func referenceNumber(_ bytes: [UInt8], after separator: UInt8, at start: Int) -> (UInt32, Int)? {
        guard start < bytes.count, bytes[start] == separator else { return nil }
        let first = start + 1
        guard first < bytes.count, (UInt8(ascii: "1")...UInt8(ascii: "9")).contains(bytes[first]) else { return nil }
        var end = first
        while end < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[end]) { end += 1 }
        let digits = String(decoding: bytes[first..<end], as: UTF8.self)
        guard end < bytes.count, digits.count <= 10, let value = UInt32(digits) else { return nil }
        return (value, end)
    }

    private static func referenceNumbers(_ bytes: [UInt8]) -> (values: [UInt32], consumed: Int) {
        var values: [UInt32] = []
        var consumed = 0
        while let (value, end) = referenceNumber(bytes, after: UInt8(ascii: " "), at: consumed) {
            values.append(value)
            consumed = end
        }
        return (values, consumed)
    }

    private static func referenceRanges(_ bytes: [UInt8]) -> (values: [ClosedRange<UInt32>], consumed: Int) {
        var values: [ClosedRange<UInt32>] = []
        var consumed = 0
        while let (first, firstEnd) = referenceNumber(bytes, after: UInt8(ascii: ","), at: consumed) {
            guard bytes[firstEnd] == UInt8(ascii: ":") else {
                values.append(first...first)
                consumed = firstEnd
                continue
            }
            guard let (second, secondEnd) = referenceNumber(bytes, after: UInt8(ascii: ":"), at: firstEnd) else { break }
            values.append(min(first, second)...max(first, second))
            consumed = secondEnd
        }
        return (values, consumed)
    }
}
