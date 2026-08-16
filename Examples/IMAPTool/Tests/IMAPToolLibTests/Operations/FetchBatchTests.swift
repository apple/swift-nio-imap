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

@testable import IMAPCommands
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite
private enum FetchBatchTests {
    struct FetchBatchesIteratorFixture: Sendable, CustomTestStringConvertible {
        var batches: FetchBatches
        var expected: [FetchBatch]

        var testDescription: String { "\(batches)" }
    }

    @Test(arguments: [
        FetchBatchesIteratorFixture(
            batches: .fixed([
                1...1_000,
                1_001...2_000,
            ]),
            expected: [
                .uidRange(1...1_000),
                .uidRange(1_001...2_000),
            ]
        ),
        FetchBatchesIteratorFixture(
            batches: .fixed([]),
            expected: []
        ),
        FetchBatchesIteratorFixture(
            batches: .fixed([100...200]),
            expected: [.uidRange(100...200)]
        ),
        FetchBatchesIteratorFixture(
            batches: .partial(
                PartialFetchBatches(
                    last: 2_000,
                    batchSize: 1_000
                )
            ),
            expected: [
                .partialLast(.last(1...1_000)),
                .partialLast(.last(1_001...2_000)),
            ]
        ),
        FetchBatchesIteratorFixture(
            batches: .partial(
                PartialFetchBatches(
                    last: 100,
                    batchSize: 1_000
                )
            ),
            expected: [
                .partialLast(.last(1...100))
            ]
        ),
        FetchBatchesIteratorFixture(
            batches: .fromBoundaries(
                UIDBatchFromBoundaries(boundaries: [100, 5_000, 10_000, 15_000])
            ),
            expected: [
                .uidRange(10_001...15_000),
                .uidRange(5_001...10_000),
                .uidRange(100...5_000),
            ]
        ),
        FetchBatchesIteratorFixture(
            batches: .fromBoundaries(
                UIDBatchFromBoundaries(boundaries: [100, 200])
            ),
            expected: [
                .uidRange(100...200)
            ]
        ),
        FetchBatchesIteratorFixture(
            batches: .fromBoundaries(
                UIDBatchFromBoundaries(boundaries: [])
            ),
            expected: []
        ),
    ])
    static func fetchBatchesIterator(
        _ fixture: FetchBatchesIteratorFixture
    ) {
        var iterator = fixture.batches.makeIterator()
        var actual: [FetchBatch] = []
        while let batch = iterator.next() {
            actual.append(batch)
            guard actual.count < 50 else {
                Issue.record("Too many iterations.")
                break
            }
        }
        #expect(actual == fixture.expected)
    }

    struct SplitUIDsIntoRangesFixture: Sendable, CustomTestStringConvertible {
        var uids: UIDSet
        var maximumCount: Int
        var expected: [UIDRange]

        var testDescription: String { "uids: \(uids), max: \(maximumCount)" }
    }

    @Test(arguments: [
        SplitUIDsIntoRangesFixture(
            uids: [],
            maximumCount: 1_000,
            expected: []
        ),
        SplitUIDsIntoRangesFixture(
            uids: [100, 200, 300],
            maximumCount: 5,
            expected: [100...300]
        ),
        SplitUIDsIntoRangesFixture(
            uids: [100, 200, 1_500, 2_000],
            maximumCount: 2,
            expected: [
                1_500...2_000,
                100...200,
            ]
        ),
        SplitUIDsIntoRangesFixture(
            uids: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            maximumCount: 3,
            expected: [
                8...10,
                5...7,
                2...4,
                1...1,
            ]
        ),
        SplitUIDsIntoRangesFixture(
            uids: [100],
            maximumCount: 1,
            expected: [100...100]
        ),
        SplitUIDsIntoRangesFixture(
            uids: [100, 200, 300, 400, 500],
            maximumCount: 1,
            expected: [
                500...500,
                400...400,
                300...300,
                200...200,
                100...100,
            ]
        ),
        SplitUIDsIntoRangesFixture(
            uids: [1, 2, 3, 100, 200, 300, 1_000, 2_000, 3_000],
            maximumCount: 4,
            expected: [
                300...3_000,
                2...200,
                1...1,
            ]
        ),
    ])
    static func splitUIDsIntoRanges_test(
        _ fixture: SplitUIDsIntoRangesFixture
    ) {
        let result = splitUIDsIntoRanges(
            uids: fixture.uids,
            maximumCount: fixture.maximumCount
        )
        #expect(result == fixture.expected)
    }

    struct PartialSequenceFixture: Sendable, CustomTestStringConvertible {
        var batches: PartialFetchBatches
        var expected: [FetchBatch]

        var testDescription: String { "\(batches)" }
    }

    @Test(arguments: [
        PartialSequenceFixture(
            batches: PartialFetchBatches(
                last: 200,
                batchSize: 1_000
            ),
            expected: [
                .partialLast(.last(1...200))
            ]
        ),
        PartialSequenceFixture(
            batches: PartialFetchBatches(
                last: 1,
                batchSize: 1_000
            ),
            expected: [
                .partialLast(.last(1...1))
            ]
        ),
        PartialSequenceFixture(
            batches: PartialFetchBatches(
                last: 1_000,
                batchSize: 1_000
            ),
            expected: [
                .partialLast(.last(1...1_000))
            ]
        ),
        PartialSequenceFixture(
            batches: PartialFetchBatches(
                last: 2_000,
                batchSize: 1_000
            ),
            expected: [
                .partialLast(.last(1...1_000)),
                .partialLast(.last(1_001...2_000)),
            ]
        ),
        PartialSequenceFixture(
            batches: PartialFetchBatches(
                last: 2_100,
                batchSize: 1_000
            ),
            expected: [
                .partialLast(.last(1...1_000)),
                .partialLast(.last(1_001...2_000)),
                .partialLast(.last(2_001...2_100)),
            ]
        ),
        PartialSequenceFixture(
            batches: PartialFetchBatches(
                last: 2_999,
                batchSize: 1_000
            ),
            expected: [
                .partialLast(.last(1...1_000)),
                .partialLast(.last(1_001...2_000)),
                .partialLast(.last(2_001...2_999)),
            ]
        ),
    ])
    static func partialSequence(
        _ fixture: PartialSequenceFixture
    ) {
        #expect(Array(fixture.batches) == fixture.expected)
    }

    @Test
    static func partialSequence_all() {
        #expect(
            PartialFetchBatches(
                query: .all,
                mailboxMessageCount: 765,
                batchSize: 1_000
            )
                == PartialFetchBatches(
                    last: 765,
                    batchSize: 1_000
                )
        )
        #expect(
            PartialFetchBatches(
                query: .all,
                mailboxMessageCount: 0,
                batchSize: 1_000
            ) == nil
        )
        #expect(
            PartialFetchBatches(
                query: .all,
                mailboxMessageCount: 1,
                batchSize: 1_000
            )
                == PartialFetchBatches(
                    last: 1,
                    batchSize: 1_000
                )
        )
    }

    @Test
    static func partialSequence_last() {
        #expect(
            PartialFetchBatches(
                query: .last(count: 2_000),
                mailboxMessageCount: 765,
                batchSize: 1_000
            )
                == PartialFetchBatches(
                    last: 765,
                    batchSize: 1_000
                )
        )
        #expect(
            PartialFetchBatches(
                query: .last(count: 2_000),
                mailboxMessageCount: 0,
                batchSize: 1_000
            ) == nil
        )
        #expect(
            PartialFetchBatches(
                query: .last(count: 2_000),
                mailboxMessageCount: 2_001,
                batchSize: 1_000
            )
                == PartialFetchBatches(
                    last: 2_000,
                    batchSize: 1_000
                )
        )
        #expect(
            PartialFetchBatches(
                query: .last(count: 2_000),
                mailboxMessageCount: 77_777,
                batchSize: 1_000
            )
                == PartialFetchBatches(
                    last: 2_000,
                    batchSize: 1_000
                )
        )
    }
}
