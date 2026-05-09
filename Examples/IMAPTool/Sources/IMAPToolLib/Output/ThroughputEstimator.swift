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

        let now = Date()
        let secondsRemaining = Double(remainingCount) / tasksPerSecond
        let interval = now..<(now.addingTimeInterval(secondsRemaining))
        return
            interval
            .formatted(
                .components(style: .condensedAbbreviated, fields: [.hour, .minute, .second])
                    .locale(Locale(identifier: "en_US.posix"))
            )
    }
}
