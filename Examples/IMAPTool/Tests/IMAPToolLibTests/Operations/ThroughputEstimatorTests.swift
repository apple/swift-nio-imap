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

import Foundation
@testable import IMAPToolLib
import Testing

@Suite
enum ThroughputEstimatorTests {
    struct ThroughputFormatFixture: CustomTestStringConvertible {
        var throughput: ThroughputEstimator.Throughput
        var fractionLength: Int
        var expectedFormattedTasksPerSecond: String

        var testDescription: String {
            "\(throughput.tasksPerSecond)-\(fractionLength)"
        }
    }

    @Test(arguments: [
        // Zero throughput
        ThroughputFormatFixture(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 0
            ),
            fractionLength: 1,
            expectedFormattedTasksPerSecond: "0.0"
        ),
        // Basic decimal with 1 fraction digit
        ThroughputFormatFixture(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 1.2
            ),
            fractionLength: 1,
            expectedFormattedTasksPerSecond: "1.2"
        ),
        // No fraction digits
        ThroughputFormatFixture(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 3.7
            ),
            fractionLength: 0,
            expectedFormattedTasksPerSecond: "4"
        ),
        // Multiple fraction digits
        ThroughputFormatFixture(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 2.3456
            ),
            fractionLength: 3,
            expectedFormattedTasksPerSecond: "2.346"
        ),
        // Very small number
        ThroughputFormatFixture(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 0.001
            ),
            fractionLength: 3,
            expectedFormattedTasksPerSecond: "0.001"
        ),
        // Large number
        ThroughputFormatFixture(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 1234.5678
            ),
            fractionLength: 2,
            expectedFormattedTasksPerSecond: "1,234.57"
        ),
        // Integer value with fraction length
        ThroughputFormatFixture(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 5.0
            ),
            fractionLength: 2,
            expectedFormattedTasksPerSecond: "5.00"
        ),
        // Very high precision
        ThroughputFormatFixture(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 1.0
            ),
            fractionLength: 5,
            expectedFormattedTasksPerSecond: "1.00000"
        ),
    ])
    static func formattedTasksPerSecond(
        fixture: ThroughputFormatFixture
    ) async throws {
        #expect(
            fixture.throughput.formattedTasksPerSecond(
                fractionLength: fixture.fractionLength
            ) == fixture.expectedFormattedTasksPerSecond
        )
    }

    struct ThroughputFormatTimeRemaining: CustomTestStringConvertible {
        var throughput: ThroughputEstimator.Throughput
        var remainingCount: Int
        var remainingCountCutOff: Int
        var expected: String?

        var testDescription: String {
            "\(throughput.tasksPerSecond)-\(remainingCount)/\(remainingCountCutOff)"
        }
    }

    @Test(arguments: [
        // Zero throughput - no time estimate
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 0
            ),
            remainingCount: 200,
            remainingCountCutOff: 10,
            expected: nil
        ),
        // Basic time calculation
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 1.2
            ),
            remainingCount: 200,
            remainingCountCutOff: 10,
            expected: "2min 46sec"
        ),
        // Very low throughput (just above threshold)
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 0.002
            ),
            remainingCount: 100,
            remainingCountCutOff: 10,
            expected: "13hr 53min 20sec"
        ),
        // Below threshold throughput - no estimate
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 0.0001
            ),
            remainingCount: 100,
            remainingCountCutOff: 10,
            expected: nil
        ),
        // Remaining count at cutoff - no estimate
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 2.0
            ),
            remainingCount: 10,
            remainingCountCutOff: 10,
            expected: nil
        ),
        // Remaining count below cutoff - no estimate
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 2.0
            ),
            remainingCount: 5,
            remainingCountCutOff: 10,
            expected: nil
        ),
        // Fast throughput - seconds only
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 10.0
            ),
            remainingCount: 45,
            remainingCountCutOff: 5,
            expected: "4sec"
        ),
        // Medium throughput - minutes and seconds
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 0.5
            ),
            remainingCount: 150,
            remainingCountCutOff: 20,
            expected: "5min"
        ),
        // Slow throughput - hours and minutes
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 0.1
            ),
            remainingCount: 1000,
            remainingCountCutOff: 50,
            expected: "2hr 46min 40sec"
        ),
        // Very fast throughput - sub-second
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 100.0
            ),
            remainingCount: 50,
            remainingCountCutOff: 10,
            expected: "0sec"
        ),
        // Zero remaining count cutoff
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 1.0
            ),
            remainingCount: 30,
            remainingCountCutOff: 0,
            expected: "30sec"
        ),
        // Exactly 1 hour
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 1.0
            ),
            remainingCount: 3600,
            remainingCountCutOff: 10,
            expected: "1hr"
        ),
        // Exactly 1 minute
        ThroughputFormatTimeRemaining(
            throughput: ThroughputEstimator.Throughput(
                tasksPerSecond: 1.0
            ),
            remainingCount: 60,
            remainingCountCutOff: 10,
            expected: "1min"
        ),
    ])
    static func formattedTimeRemaining(
        fixture: ThroughputFormatTimeRemaining
    ) async throws {
        #expect(
            fixture.throughput.formattedTimeRemaining(
                remainingCount: fixture.remainingCount,
                remainingCountCutOff: fixture.remainingCountCutOff
            ) == fixture.expected
        )
    }

    // MARK: - didComplete() Tests

    @Test("didComplete returns nil on first call")
    static func didCompleteFirstCall() async throws {
        var estimator = ThroughputEstimator(now: Date())
        let result = estimator.didComplete(now: Date())
        #expect(result == nil)
        #expect(estimator.count == 1)
    }

    @Test("didComplete returns nil when count is less than 2")
    static func didCompleteCountLessThanTwo() async throws {
        let startTime = Date()
        var estimator = ThroughputEstimator(now: startTime)

        // First call should return nil
        let result1 = estimator.didComplete(now: startTime.addingTimeInterval(60))
        #expect(result1 == nil)
        #expect(estimator.count == 1)
    }

    @Test("didComplete returns nil when duration <= 30 and count <= 60")
    static func didCompleteWithinThresholds() async throws {
        let startTime = Date()
        var estimator = ThroughputEstimator(now: startTime)

        // Complete tasks within 30 seconds and under 60 count
        for i in 1...10 {
            let result = estimator.didComplete(now: startTime.addingTimeInterval(Double(i) * 2))  // 2 seconds apart
            #expect(result == nil)
        }
        #expect(estimator.count == 10)
    }

    @Test("didComplete returns throughput when duration > 30 seconds")
    static func didCompleteAfterDurationThreshold() async throws {
        let startTime = Date()
        var estimator = ThroughputEstimator(now: startTime)

        // First call increments count to 1
        let result1 = estimator.didComplete(now: startTime.addingTimeInterval(10))
        #expect(result1 == nil)
        #expect(estimator.count == 1)

        // Second call after 31 seconds should return throughput
        let result2 = estimator.didComplete(now: startTime.addingTimeInterval(31))
        #expect(result2 != nil)

        let throughput = try #require(result2)
        // 2 tasks in 31 seconds = 2/31 ≈ 0.0645 tasks/second
        #expect(abs(throughput.tasksPerSecond - (2.0 / 31.0)) < 0.0001)

        // Estimator should be reset
        #expect(estimator.count == 0)
    }

    @Test("didComplete returns throughput when count > 60")
    static func didCompleteAfterCountThreshold() async throws {
        let startTime = Date()
        var estimator = ThroughputEstimator(now: startTime)

        // Complete 61 tasks within 30 seconds (very fast)
        for i in 1...60 {
            let result = estimator.didComplete(now: startTime.addingTimeInterval(Double(i) * 0.1))  // 0.1 seconds apart
            #expect(result == nil)
        }

        // 61st task should trigger throughput calculation
        let result = estimator.didComplete(now: startTime.addingTimeInterval(6.1))
        #expect(result != nil)

        let throughput = try #require(result)
        // 61 tasks in 6.1 seconds = 61/6.1 ≈ 10.0 tasks/second
        #expect(abs(throughput.tasksPerSecond - (61.0 / 6.1)) < 0.0001)

        // Estimator should be reset
        #expect(estimator.count == 0)
    }

    @Test("didComplete resets estimator after returning throughput")
    static func didCompleteResetsEstimator() async throws {
        let startTime = Date()
        var estimator = ThroughputEstimator(now: startTime)

        // Get to threshold
        let _ = estimator.didComplete(now: startTime.addingTimeInterval(10))
        let throughputResult = estimator.didComplete(now: startTime.addingTimeInterval(35))

        #expect(throughputResult != nil)
        #expect(estimator.count == 0)

        // The start time should be updated to the time of the last didComplete call
        // We can verify this by checking that the next call starts counting from 0 again
        let nextResult = estimator.didComplete(now: startTime.addingTimeInterval(40))
        #expect(nextResult == nil)
        #expect(estimator.count == 1)
    }

    @Test("didComplete calculates correct throughput")
    static func didCompleteCalculatesCorrectThroughput() async throws {
        let startTime = Date()
        var estimator = ThroughputEstimator(now: startTime)

        // Complete 5 tasks over 10 seconds
        for i in 1...4 {
            let result = estimator.didComplete(now: startTime.addingTimeInterval(Double(i) * 2))
            #expect(result == nil)
        }

        // 5th task at 50 seconds (duration > 30, so should return throughput)
        let result = estimator.didComplete(now: startTime.addingTimeInterval(50))
        #expect(result != nil)

        let throughput = try #require(result)
        // 5 tasks in 50 seconds = 0.1 tasks/second
        #expect(abs(throughput.tasksPerSecond - 0.1) < 0.0001)
    }

    @Test("didComplete with custom now parameter")
    static func didCompleteWithCustomNow() async throws {
        let startTime = Date()
        let customNow = startTime.addingTimeInterval(100)

        var estimator = ThroughputEstimator(now: startTime)

        // First call
        let result1 = estimator.didComplete(now: customNow)
        #expect(result1 == nil)
        #expect(estimator.count == 1)

        // Second call should return throughput (duration = 100 seconds > 30)
        let result2 = estimator.didComplete(now: customNow.addingTimeInterval(1))
        #expect(result2 != nil)

        let throughput = try #require(result2)
        // 2 tasks in 101 seconds ≈ 0.0198 tasks/second
        #expect(abs(throughput.tasksPerSecond - (2.0 / 101.0)) < 0.0001)
    }

    @Test("didComplete edge case: exactly 30 seconds duration")
    static func didCompleteExactly30Seconds() async throws {
        let startTime = Date()
        var estimator = ThroughputEstimator(now: startTime)

        // First call
        let result1 = estimator.didComplete(now: startTime.addingTimeInterval(10))
        #expect(result1 == nil)

        // Second call at exactly 30 seconds - should return nil (condition is 30 < duration)
        let result2 = estimator.didComplete(now: startTime.addingTimeInterval(30))
        #expect(result2 == nil)
        #expect(estimator.count == 2)
    }

    @Test("didComplete edge case: exactly 60 tasks")
    static func didCompleteExactly60Tasks() async throws {
        let startTime = Date()
        var estimator = ThroughputEstimator(now: startTime)

        // Complete exactly 60 tasks in 10 seconds
        for i in 1...60 {
            let result = estimator.didComplete(now: startTime.addingTimeInterval(Double(i) * 0.1))
            if i == 60 {
                // At exactly 60 tasks with duration < 30, should return nil
                #expect(result == nil)
            } else {
                #expect(result == nil)
            }
        }
        #expect(estimator.count == 60)
    }
}
