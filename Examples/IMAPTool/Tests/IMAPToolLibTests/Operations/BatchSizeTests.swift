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

@testable import IMAPToolLib
import NIOIMAP
import Testing

@Suite
private enum BatchSizeTests {
    @Test(arguments: [0, -1])
    static func rejectsNonPositive(_ count: Int) {
        #expect(BatchSize(count) == nil)
    }

    struct MessageLimitFixture: Sendable, CustomTestStringConvertible {
        var capabilities: [Capability]
        var expected: BatchSize

        var testDescription: String { "\(capabilities)" }
    }

    @Test(arguments: [
        MessageLimitFixture(capabilities: [], expected: 1_000),
        MessageLimitFixture(capabilities: [.messageLimit(999)], expected: 1_000),
        MessageLimitFixture(capabilities: [.messageLimit(1_000)], expected: 1_000),
        MessageLimitFixture(capabilities: [.messageLimit(10_000)], expected: 10_000),
        MessageLimitFixture(capabilities: [Capability("MESSAGELIMIT=4294967295")], expected: 4_294_967_295),
    ])
    static func messageLimit(_ fixture: MessageLimitFixture) {
        #expect(BatchSize(capabilities: fixture.capabilities) == fixture.expected)
    }

    /// Missing, unparsable, or out-of-range `MESSAGELIMIT` falls back to `minimum`.
    @Test(arguments: [
        Capability("MESSAGELIMIT"),
        Capability("MESSAGELIMIT=abc"),
        Capability("MESSAGELIMIT=0"),
        Capability("MESSAGELIMIT=-5000"),
        Capability("MESSAGELIMIT=4294967296"),
        Capability("MESSAGELIMIT=99999999999"),
    ])
    static func invalidMessageLimit(_ capability: Capability) {
        #expect(BatchSize(capabilities: [capability]) == .minimum)
    }

    struct PartialRangeFixture: Sendable, CustomTestStringConvertible {
        var size: BatchSize
        var batch: Int
        var expected: ClosedRange<SequenceNumber>

        var testDescription: String { "\(size) #\(batch)" }
    }

    @Test(arguments: [
        PartialRangeFixture(size: 1_000, batch: 0, expected: 1...1_000),
        PartialRangeFixture(size: 1_000, batch: 1, expected: 1_001...2_000),
        PartialRangeFixture(size: 1_200, batch: 2, expected: 2_401...3_600),
        PartialRangeFixture(size: 1, batch: 0, expected: 1...1),
        PartialRangeFixture(size: 1, batch: 4, expected: 5...5),
        // End clamped to `SequenceNumber.max`:
        PartialRangeFixture(size: 3_000_000_000, batch: 1, expected: 3_000_000_001...4_294_967_295),
    ])
    static func partialRange(_ fixture: PartialRangeFixture) {
        #expect(fixture.size.partialRange(batch: fixture.batch) == fixture.expected)
    }

    /// A batch size above `UInt32.max / 2` must not overflow past the last batch.
    @Test
    static func partialFetchBatches_hugeBatchSize() {
        let batches = PartialFetchBatches(last: 5, batchSize: 3_000_000_000)
        #expect(Array(batches) == [.partialLast(.last(1...5))])
    }
}
