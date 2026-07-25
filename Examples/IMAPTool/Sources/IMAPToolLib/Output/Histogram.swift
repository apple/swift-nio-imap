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

// `NumberFormatter` is not part of `FoundationEssentials`.
import Foundation

/// A text-based histogram suitable for terminal output.
struct TextHistogram: Equatable, Encodable, TextOutputEncodable {
    let underlying: Histogram
    let lines: [String]

    /// Encodes the underlying histogram data.
    func encode(to encoder: Encoder) throws {
        try self.underlying.encode(to: encoder)
    }

    /// The single-line text representation.
    var textOutput: String { "" }
    /// The multi-line text representation.
    var textOutputLines: [String] { self.lines }
}

extension TextHistogram {
    /// Creates a histogram from duration values, or returns `nil` if the data is insufficient.
    init?(durations: [TimeInterval], width: Int = 78) {
        guard let histogram = Histogram(data: durations) else { return nil }
        let lines = histogram.makeDurationLines(width: width)
        self.init(underlying: histogram, lines: lines)
    }
}

// MARK: -

extension Histogram {
    func makeDurationLines(width: Int) -> [String] {
        let binsAndLabels: [(Histogram.Bin, String)] = bins.map { bin -> (Histogram.Bin, String) in
            let label = formatDuration(bin.range.lowerBound) + "-" + formatDuration(bin.range.upperBound)
            return (bin, label)
        }
        let maxLabelWidth = binsAndLabels.reduce(into: 0) { $0 = max($0, $1.1.count) }

        let lines: [String] = binsAndLabels.map { bin, label -> String in
            let fraction = Double(bin.count) / Double(totalCount)
            // Guard against very long labels driving the bar width non-positive.
            let barWidth = max(1, width - maxLabelWidth - 2)
            let bar = String.barWithLabel(fraction: fraction, width: barWidth)
            return label + String(repeating: " ", count: maxLabelWidth - label.count) + ": " + bar
        }
        return lines
    }
}

// MARK: -

func formatDuration(_ value: TimeInterval) -> String {
    guard value >= 10 else {
        return numberFormatter.string(for: value * 1000)! + "ms"
    }
    return numberFormatter.string(for: value)! + "s"
}

private let numberFormatter: NumberFormatter = {
    var f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumSignificantDigits = 1
    f.maximumSignificantDigits = 3
    f.usesGroupingSeparator = true
    f.groupingSeparator = ","
    f.groupingSize = 3
    f.locale = .posix
    return f
}()

private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.locale = .posix
    return c
}()
