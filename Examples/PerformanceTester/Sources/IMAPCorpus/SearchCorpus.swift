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

/// `SEARCH` and `ESEARCH` results, as wire bytes.
///
/// What matters is the very large result: thousands of UIDs on one line, arriving over many socket
/// reads. Small results (1–32 elements) are here to find the size below which a fast path does not
/// pay for its setup.
///
/// ```
/// * SEARCH 10002 10005 10011 …\r\n
/// * ESEARCH (TAG "A1") UID ALL 10002,10005:10014,10017,…\r\n
/// ```
///
/// `ESEARCH` alternates single UIDs and ranges (50/50), ascending and never adjacent, so no two
/// elements merge. Values are deterministic, so every run parses identical bytes.
public enum SearchCorpus {
    /// Which untagged response carries the result.
    public enum Kind: String, CaseIterable, Sendable {
        /// `* SEARCH n n n …`: space-separated numbers.
        case search
        /// `* ESEARCH … UID ALL sequence-set`: comma-separated numbers and ranges.
        case esearch
    }

    /// How many decimal digits every UID has.
    public enum Digits: Int, CaseIterable, Sendable {
        /// 10000…99999: a young mailbox.
        case five = 5
        /// 100000000…999999999: a server whose UIDs encode more than a counter.
        case nine = 9

        /// The smallest UID with this many digits, i.e. where the corpus starts.
        var firstValue: UInt32 {
            var value: UInt32 = 1
            for _ in 1..<rawValue { value *= 10 }
            return value
        }
    }

    /// Element counts small enough to fit one read. They bracket the fast-path threshold.
    public static let smallCounts = [1, 2, 4, 8, 16, 32]

    /// The element count of a large result.
    public static let largeCount = 5_000

    /// How many copies of a small result one buffer holds, so a sample is not dominated by the
    /// per-iteration overhead of the harness.
    public static let smallRepetitions = 1_000

    /// The tag of the command the results answer.
    static let tag = "A1"

    /// The result elements, ascending. A single UID is a range whose bounds are equal.
    ///
    /// `SEARCH` has only single UIDs; `ESEARCH` alternates single UIDs (even indices) and ranges of
    /// 2…20 UIDs (odd indices). Gaps between elements are 2…7, so elements never touch.
    public static func elements(kind: Kind, count: Int, digits: Digits) -> [ClosedRange<UInt32>] {
        // 64-bit LCG (Knuth's MMIX constants): deterministic, and good enough to vary gaps.
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next(_ bound: UInt32) -> UInt32 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return UInt32(truncatingIfNeeded: state >> 33) % bound
        }

        var result: [ClosedRange<UInt32>] = []
        result.reserveCapacity(count)
        var lower = digits.firstValue
        for index in 0..<count {
            lower += 2 + next(6)
            let isRange = kind == .esearch && index % 2 == 1
            let upper = isRange ? lower + 1 + next(19) : lower
            result.append(lower...upper)
            lower = upper
        }
        precondition(
            String(result.last!.upperBound).count == digits.rawValue,
            "corpus overflowed \(digits.rawValue) digits"
        )
        return result
    }

    /// `repetitions` copies of one result line, then the tagged completion.
    ///
    /// - Parameters:
    ///   - kind: `SEARCH` or `ESEARCH`.
    ///   - count: Elements per result.
    ///   - digits: Digits per UID.
    ///   - repetitions: How many copies of the result line to write.
    /// - Returns: The complete server output, ready to feed to a `ResponseParser`.
    public static func responseBytes(kind: Kind, count: Int, digits: Digits, repetitions: Int = 1) -> ByteBuffer {
        let line = resultLine(kind: kind, elements: elements(kind: kind, count: count, digits: digits))
        var buffer = ByteBuffer()
        buffer.reserveCapacity(line.utf8.count * repetitions + 32)
        for _ in 0..<repetitions {
            buffer.writeString(line)
        }
        buffer.writeString("\(tag) OK Search completed\r\n")
        return buffer
    }

    /// One untagged result line, CRLF included.
    static func resultLine(kind: Kind, elements: [ClosedRange<UInt32>]) -> String {
        switch kind {
        case .search:
            // e.g. `* SEARCH 10002 10005\r\n`
            let numbers = elements.map { String($0.lowerBound) }
            return "* SEARCH \(numbers.joined(separator: " "))\r\n"
        case .esearch:
            // e.g. `* ESEARCH (TAG "A1") UID ALL 10002,10005:10014\r\n`
            let items = elements.map { range in
                range.lowerBound == range.upperBound
                    ? String(range.lowerBound)
                    : "\(range.lowerBound):\(range.upperBound)"
            }
            return "* ESEARCH (TAG \"\(tag)\") UID ALL \(items.joined(separator: ","))\r\n"
        }
    }
}
