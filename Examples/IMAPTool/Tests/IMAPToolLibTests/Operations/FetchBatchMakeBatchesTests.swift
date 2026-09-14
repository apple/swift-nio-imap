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
private enum `FetchBatch makeBatches Tests` {
    struct MakeBatchesFixture: Sendable, CustomTestStringConvertible {
        var name: String
        var query: FetchQuery
        var mailboxMessageCount: Int
        var capabilities: [Capability]
        var expectedCommands: [TestConnection.CommandAndResponses]
        var expectedBatches: [FetchBatch]

        var testDescription: String { name }
    }

    @Test(arguments: [
        MakeBatchesFixture(
            name: "plain, RFC 3501, low count, low mailbox count",
            query: .last(count: 100),
            mailboxMessageCount: 400,
            capabilities: [.imap4rev1],
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .sequenceNumbers(.set(.init(set: [301...])!)),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search(
                                    [512, 4_096],
                                    nil
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ],
            expectedBatches: [
                .uidRange(512...4_096)
            ]
        ),
        MakeBatchesFixture(
            name: "plain, RFC 3501, low count",
            query: .last(count: 100),
            mailboxMessageCount: 10_000,
            capabilities: [.imap4rev1],
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .sequenceNumbers(.set(.init(set: [9_901...])!)),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search(
                                    [
                                        1_079, 1_283, 2_322, 5_182, 6_006, 7_819, 7_883, 8_070, 8_474, 8_528,
                                        8_620, 9_807, 10_005, 12_082, 12_597, 12_691, 14_703, 15_888, 16_782, 16_872,
                                        17_454, 17_555, 19_137, 19_828, 20_042, 20_086, 20_377, 20_431, 21_962, 26_433,
                                        26_812, 29_345, 30_321, 30_489, 30_888, 31_770, 32_312, 34_426, 34_729, 36_694,
                                        40_553, 42_606, 45_058, 47_190, 48_397, 49_179, 49_180, 49_465, 49_870, 50_844,
                                        54_726, 54_832, 57_006, 57_560, 58_010, 58_370, 60_014, 60_205, 60_658, 61_121,
                                        63_208, 64_805, 65_387, 66_388, 68_296, 69_005, 69_826, 71_466, 72_523, 73_406,
                                        74_642, 75_624, 76_758, 76_852, 77_549, 77_758, 77_999, 79_296, 80_852, 83_383,
                                        83_793, 84_020, 85_746, 86_013, 86_383, 87_165, 87_551, 88_094, 88_206, 88_709,
                                        91_139, 91_531, 92_567, 92_941, 93_030, 93_158, 94_107, 94_577, 94_882, 98_793,
                                    ],
                                    nil
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ],
            expectedBatches: [
                .uidRange(1_079...98_793)
            ]
        ),
        MakeBatchesFixture(
            name: "plain, RFC 3501, larger count",
            query: .last(count: 900),
            mailboxMessageCount: 100_000,
            capabilities: [.imap4rev1],
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .sequenceNumbers(.set(.init(set: [99_101, 100_000])!)),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search(
                                    [
                                        6_987_831,
                                        9_879_779,
                                    ],
                                    nil
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ],
            expectedBatches: [
                .uidRange(6_987_831...9_879_779)
            ]
        ),
        MakeBatchesFixture(
            name: "plain, RFC 3501, count spanning multiple batches",
            query: .last(count: 2_300),
            mailboxMessageCount: 100_000,
            capabilities: [.imap4rev1],
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .sequenceNumbers(
                            .set(
                                .init(set: [
                                    97_701,
                                    98_000,
                                    99_000,
                                    100_000,
                                ])!
                            )
                        ),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search(
                                    [
                                        1_132_068,
                                        3_842_087,
                                        7_706_447,
                                        9_155_708,
                                    ],
                                    nil
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ],
            expectedBatches: [
                .uidRange(7_706_448...9_155_708),
                .uidRange(3_842_088...7_706_447),
                .uidRange(1_132_068...3_842_087),
            ]
        ),
        MakeBatchesFixture(
            name: "plain, RFC 3501, count spanning multiple batches, message limit, extended search",
            query: .last(count: 2_300),
            mailboxMessageCount: 100_000,
            capabilities: [
                .imap4rev1,
                .messageLimit(2_000),
                .extendedSearch,
            ],
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .sequenceNumbers(
                            .set(
                                .init(set: [
                                    97_701,
                                    98_000,
                                    100_000,
                                ])!
                            )
                        ),
                        charset: nil,
                        returnOptions: [.all]
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .extendedSearch(
                                    ExtendedSearchResponse(
                                        correlator: SearchCorrelator(tag: "A1"),
                                        kind: .uid,
                                        returnData: [
                                            .all(
                                                .set([
                                                    3_344_364,
                                                    5_503_918,
                                                    9_920_245,
                                                ])
                                            )
                                        ]
                                    )
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ],
            expectedBatches: [
                .uidRange(5_503_919...9_920_245),
                .uidRange(3_344_364...5_503_918),
            ]
        ),
        MakeBatchesFixture(
            name: "partial, RFC 9394, low count",
            query: .last(count: 100),
            mailboxMessageCount: 10_000,
            capabilities: [.imap4rev1, .partial, .messageLimit(1_200)],
            expectedCommands: [],
            expectedBatches: [
                .partialLast(.last(1...100))
            ]
        ),
        MakeBatchesFixture(
            name: "partial, RFC 9394",
            query: .last(count: 3_000),
            mailboxMessageCount: 10_000,
            capabilities: [.imap4rev1, .partial, .messageLimit(1_200)],
            expectedCommands: [],
            expectedBatches: [
                .partialLast(.last(1...1_200)),
                .partialLast(.last(1_201...2_400)),
                .partialLast(.last(2_401...3_000)),
            ]
        ),
        MakeBatchesFixture(
            name: ".uids with Partial, sparse UIDs",
            query: .uids([100, 5_000, 10_000]),
            mailboxMessageCount: 10_000,
            capabilities: [.imap4rev1, .partial, .messageLimit(1_200)],
            expectedCommands: [],
            expectedBatches: [
                .partialLast(.last(1...3))
            ]
        ),
        MakeBatchesFixture(
            name: ".uids without Partial, sparse UIDs spanning multiple batches",
            query: .uids([100, 200, 5_000, 10_000]),
            mailboxMessageCount: 20_000,
            capabilities: [.imap4rev1],
            expectedCommands: [],
            expectedBatches: [
                .uidRange(100...10_000)
            ]
        ),
        MakeBatchesFixture(
            name: ".all without Partial, multiple batches",
            query: .all,
            mailboxMessageCount: 2_300,
            capabilities: [.imap4rev1],
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .sequenceNumbers(
                            .set(
                                .init(set: [
                                    1,
                                    300,
                                    1_300,
                                    2_300,
                                ])!
                            )
                        ),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search(
                                    [
                                        100,
                                        5_000,
                                        8_000,
                                        15_000,
                                    ],
                                    nil
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ],
            expectedBatches: [
                .uidRange(8_001...15_000),
                .uidRange(5_001...8_000),
                .uidRange(100...5_000),
            ]
        ),
        MakeBatchesFixture(
            name: ".all with Partial, multiple batches",
            query: .all,
            mailboxMessageCount: 2_300,
            capabilities: [.imap4rev1, .partial, .messageLimit(1_000)],
            expectedCommands: [],
            expectedBatches: [
                .partialLast(.last(1...1_000)),
                .partialLast(.last(1_001...2_000)),
                .partialLast(.last(2_001...2_300)),
            ]
        ),
        MakeBatchesFixture(
            name: ".uids with Partial, large UID set needing multiple batches",
            query: .uids(UIDSet(1...3_000)),
            mailboxMessageCount: 10_000,
            capabilities: [.imap4rev1, .partial, .messageLimit(1_000)],
            expectedCommands: [],
            expectedBatches: [
                .partialLast(.last(1...1_000)),
                .partialLast(.last(1_001...2_000)),
                .partialLast(.last(2_001...3_000)),
            ]
        ),
        MakeBatchesFixture(
            name: ".all without Partial, empty mailbox",
            query: .all,
            mailboxMessageCount: 0,
            capabilities: [.imap4rev1],
            expectedCommands: [],
            expectedBatches: [
                .uidRange(.all)
            ]
        ),
        MakeBatchesFixture(
            name: ".all without Partial, mailbox with few messages",
            query: .all,
            mailboxMessageCount: 400,
            capabilities: [.imap4rev1],
            expectedCommands: [],
            expectedBatches: [
                .uidRange(.all)
            ]
        ),
        MakeBatchesFixture(
            name: ".uids without Partial, empty UID set",
            query: .uids([]),
            mailboxMessageCount: 1_000,
            capabilities: [.imap4rev1],
            expectedCommands: [],
            expectedBatches: []
        ),
        MakeBatchesFixture(
            name: ".uids without Partial, large UID set forcing batching",
            query: .uids(UIDSet(1_000...2_500)),
            mailboxMessageCount: 10_000,
            capabilities: [.imap4rev1, .messageLimit(1_000)],
            expectedCommands: [],
            expectedBatches: [
                .uidRange(1_501...2_500),
                .uidRange(1_000...1_500),
            ]
        ),
        MakeBatchesFixture(
            name: ".uids without Partial, contiguous UIDs split into batches",
            query: .uids(UIDSet(5_000...7_000)),
            mailboxMessageCount: 10_000,
            capabilities: [.imap4rev1, .messageLimit(1_000)],
            expectedCommands: [],
            expectedBatches: [
                .uidRange(6_001...7_000),
                .uidRange(5_001...6_000),
                .uidRange(5_000...5_000),
            ]
        ),
        MakeBatchesFixture(
            name: ".all with message limit, multiple batches",
            query: .all,
            mailboxMessageCount: 2_300,
            capabilities: [.imap4rev1, .messageLimit(1_000)],
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .sequenceNumbers(
                            .set(
                                .init(set: [
                                    1,
                                    300,
                                    1_300,
                                    2_300,
                                ])!
                            )
                        ),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search(
                                    [
                                        100,
                                        5_000,
                                        8_000,
                                        15_000,
                                    ],
                                    nil
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ],
            expectedBatches: [
                .uidRange(8_001...15_000),
                .uidRange(5_001...8_000),
                .uidRange(100...5_000),
            ]
        ),
    ])
    static func `test makeBatches`(
        _ fixture: MakeBatchesFixture
    ) async throws {
        let connection = TestConnection(expectedCommands: fixture.expectedCommands)
        let batches = try await makeBatches(
            connection: connection,
            query: fixture.query,
            mailboxMessageCount: fixture.mailboxMessageCount,
            capabilities: fixture.capabilities
        )
        #expect(Array(batches) == fixture.expectedBatches)
        #expect(await connection.expectedCommands == [], "Should not have any commands remaining.")
    }
}
