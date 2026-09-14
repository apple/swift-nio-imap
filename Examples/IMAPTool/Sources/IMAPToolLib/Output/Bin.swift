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

// `round`/`floor`/`log10`/`pow` are not part of `FoundationEssentials`.
import Foundation

struct Histogram: Equatable, Encodable {
    var bins: [Bin]
    var totalCount: Int

    struct Bin: Equatable, Encodable {
        var range: Range<Double>
        var count: Int
    }
}

extension Histogram {
    init?(data: [Double]) {
        guard let h = Histogram.withEmptyBins(data: data) else { return nil }
        self = h
        data.forEach { value in
            guard let index = bins.firstIndex(where: { $0.range.contains(value) }) else { return }
            bins[index].count += 1
        }
    }

    static func withEmptyBins(data: [Double]) -> Histogram? {
        guard let ranges = binRanges(data: data) else { return nil }
        return Histogram(
            bins: ranges.map {
                Histogram.Bin(range: $0, count: 0)
            },
            totalCount: data.count
        )
    }
}

// MARK: -

func binRanges(data: [Double]) -> [Range<Double>]? {
    guard
        let mean = data.mean(),
        let standardDeviation = data.standardDeviation()
    else { return nil }
    // We want to span approx. ±2σ
    // -- but less if the data doesn’t span that interval:
    let lower = max(
        data.reduce(into: Double.infinity) {
            $0 = min($0, $1)
        },
        mean - 2 * standardDeviation
    )
    let upper = min(
        data.reduce(into: -Double.infinity) {
            $0 = max($0, $1)
        },
        mean + 2 * standardDeviation
    )
    guard lower < upper else { return nil }
    // Calculate the bins with “rounded” sizes:
    let bins = -3..<3
    let binSpan = roundedBinSpan((upper - lower) / Double(bins.count))
    let middle = roundedBinSpan(lower + 0.5 * (upper - lower))
    return bins.map {
        let lower = middle + Double($0) * binSpan
        let upper = lower + binSpan
        return lower..<upper
    }
}

/// Finds a “nice” value that’s relatively close to `input`.
func roundedBinSpan(_ input: Double) -> Double {
    // `log10`/`pow` are only meaningful for a positive magnitude. Guard against zero
    // and non-finite input (which would otherwise yield NaN), and round the magnitude
    // for negative input so the result keeps `input`’s sign.
    guard input.isFinite, input != 0 else { return 0 }
    let magnitude = abs(input)
    let scale = pow(10, floor(log10(magnitude)))
    let a = magnitude / scale
    let x: Double = 5
    let b = round(a * x) / x
    let rounded = b * scale
    return input < 0 ? -rounded : rounded
}
