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

extension String {
    /// Creates a Unicode bar that’s `width` wide, and `fraction` of it filled in.
    static func barWithLabel(fraction: Double, width: Int) -> String {
        let basic = self.bar(fraction: fraction, width: width)
        let label = formatFraction(fraction)
        // We need room for the label plus at least one bar character. If the
        // bar is too narrow (or empty), fall back to the plain bar.
        guard 11 <= width, label.count + 1 <= basic.count else { return basic }
        guard fraction < 0.5 else {
            return String(basic.prefix(1)) + label
                + String(basic.suffix(from: basic.index(basic.startIndex, offsetBy: 1 + label.count)))
        }
        return basic.prefix(basic.count - label.count) + label
    }

    /// Creates a Unicode bar that’s `width` wide, and `fraction` of it filled in.
    static func bar(fraction: Double, width: Int) -> String {
        // Clamp so a non-positive width (e.g. from a very long label) yields an
        // empty bar rather than trapping on an invalid `Range`.
        let width = Swift.max(0, width)
        let chars = (0..<width).map { index -> Character in
            let lower = Double(index) / Double(width)
            let blockWidth = 1.0 / Double(width)
            let fill = (fraction - lower) / blockWidth
            let index = Swift.max(0, Swift.min(8, Int(round(fill * 8))))
            return blocks[index]
        }
        return String(chars)
    }
}

private let blocks: [Character] = [
    " ",
    "▏",
    "▎",
    "▍",
    "▌",
    "▋",
    "▊",
    "▉",
    "█",
]

// MARK: -

extension Locale {
    static let posix = Locale(identifier: "en_US_POSIX")
}

private func formatFraction(_ fraction: Double) -> String {
    formatter.string(for: fraction)!
}

private let formatter: NumberFormatter = {
    var f = NumberFormatter()
    f.numberStyle = .percent
    f.minimumSignificantDigits = 1
    f.maximumSignificantDigits = 3
    f.locale = .posix
    return f
}()
