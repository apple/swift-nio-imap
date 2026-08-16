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
@testable import IMAPToolLib
import Testing

@Suite("ThroughputEstimator — degenerate durations")
enum ThroughputEstimatorInfinityTests {

    /// Bug #7: `didComplete` allows a batch through on the `60 < count` branch even when
    /// the elapsed duration is zero, then divides by it — producing an infinite rate.
    @Test
    static func manyCompletionsAtSameInstantStayFinite() {
        let t0 = Date(timeIntervalSinceReferenceDate: 10_000)
        var estimator = ThroughputEstimator(now: t0)

        var emitted: [Double] = []
        for _ in 0..<100 {
            if let throughput = estimator.didComplete(now: t0) {
                emitted.append(throughput.tasksPerSecond)
            }
        }

        #expect(
            emitted.allSatisfy { $0.isFinite && $0 >= 0 },
            "60+ completions within a zero-length interval produced a non-finite throughput: \(emitted)."
        )
    }

    /// Bug #7 (cont.): A backward clock adjustment yields a negative duration, so the
    /// same branch produces a negative throughput.
    @Test
    static func backwardClockDoesNotProduceNegativeRate() {
        let t0 = Date(timeIntervalSinceReferenceDate: 10_000)
        let earlier = t0.addingTimeInterval(-1)
        var estimator = ThroughputEstimator(now: t0)

        var emitted: [Double] = []
        for _ in 0..<100 {
            if let throughput = estimator.didComplete(now: earlier) {
                emitted.append(throughput.tasksPerSecond)
            }
        }

        #expect(
            emitted.allSatisfy { $0.isFinite && $0 >= 0 },
            "A backward clock adjustment produced a negative/non-finite throughput: \(emitted)."
        )
    }
}
