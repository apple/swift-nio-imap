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

struct ThroughputEstimator {
    var start: Date
    var count = 0

    init(
        now: Date = Date()
    ) {
        self.start = now
    }

    mutating func didComplete(
        now: Date = Date()
    ) -> Throughput? {
        count += 1
        let duration = now.timeIntervalSince(start)
        guard
            2 <= count,
            0 < duration,
            (30 < duration) || (60 < count)
        else { return nil }
        let throughput = Double(count) / Double(duration)
        count = 0
        start = now
        return Throughput(tasksPerSecond: throughput)
    }
}

extension ThroughputEstimator {
    struct Throughput {
        var tasksPerSecond: Double
    }
}

extension ThroughputEstimator.Throughput {
    func formattedTasksPerSecond(
        fractionLength: Int = 1
    ) -> String {
        tasksPerSecond.formatted(
            .number.precision(.fractionLength(fractionLength))
                .locale(Locale(identifier: "en_US.posix"))
        )
    }

    func formattedTimeRemaining(
        remainingCount: Int,
        remainingCountCutOff: Int = 0
    ) -> String? {
        // Don’t create this when things are super slow.
        guard
            remainingCountCutOff < remainingCount,
            0.001 < tasksPerSecond
        else { return nil }

        let secondsRemaining = Double(remainingCount) / tasksPerSecond
        return formatCondensedDuration(seconds: secondsRemaining)
    }
}

/// Formats a duration as `1hr 2min 3s`, omitting zero components.
///
/// `Date`’s `.components(style:fields:)` format style is Darwin-only, and this is
/// user-visible output, so it is spelled out by hand.
func formatCondensedDuration(seconds: Double) -> String {
    // Anything non-finite (or negative) has no sensible representation.
    guard seconds.isFinite, 0 < seconds else { return "0sec" }
    // Clamp rather than trap when converting to an integer.
    guard seconds < Double(Int.max) else { return "0sec" }
    // Truncate towards zero, matching the format style this replaces.
    let total = Int(seconds)
    let components = [
        (total / 3600, "hr"),
        ((total % 3600) / 60, "min"),
        (total % 60, "sec"),
    ]
    let parts =
        components
        .filter { value, _ in value != 0 }
        .map { value, unit in "\(value)\(unit)" }
    guard !parts.isEmpty else { return "0sec" }
    return parts.joined(separator: " ")
}
