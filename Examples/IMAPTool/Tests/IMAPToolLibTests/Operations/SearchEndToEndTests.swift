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

@Suite(.timeLimit(.minutes(1)))
private enum SearchEndToEndTests {
    @Test
    static func extended_RFC_4731() async throws {
        let connection = TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .not(.deleted),
                        charset: nil,
                        returnOptions: [.all]
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .extendedSearch(
                                    ExtendedSearchResponse(
                                        correlator: SearchCorrelator(tag: "A1"),  // <--- we need to hard-code this.
                                        kind: .uid,
                                        returnData: [.all(.set([309_727, 967_986]))]
                                    )
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ]
        )
        let uids = try await search(
            connection: connection,
            capabilities: [.extendedSearch],
            key: .not(.deleted)
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(uids == [309_727, 967_986])
    }

    @Test
    static func partial_RFC_9394() async throws {
        let connection = TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .not(.deleted),
                        charset: nil,
                        returnOptions: [.partial(.last(1...1_200))]
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .extendedSearch(
                                    ExtendedSearchResponse(
                                        correlator: SearchCorrelator(tag: "A1"),  // <--- we need to hard-code this.
                                        kind: .uid,
                                        returnData: [
                                            .partial(
                                                .last(1...1_200),
                                                [309_727, 967_986]
                                            )
                                        ]
                                    )
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
                .init(
                    command: .uidSearch(
                        key: .not(.deleted),
                        charset: nil,
                        returnOptions: [.partial(.last(1_201...2_400))]
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .extendedSearch(
                                    ExtendedSearchResponse(
                                        correlator: SearchCorrelator(tag: "A2"),  // <--- we need to hard-code this.
                                        kind: .uid,
                                        returnData: [
                                            .partial(
                                                .last(1_201...2_400),
                                                []
                                            )
                                        ]
                                    )
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
            ]
        )
        let uids = try await search(
            connection: connection,
            capabilities: [.partial, .messageLimit(1_200)],
            key: .not(.deleted)
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(uids == [309_727, 967_986])
    }

    @Test
    static func allUIDs_rfc3501() async throws {
        let connection = TestConnection(
            expectedOrdering: .anyOrder,
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
                ),
                .init(
                    command: .uidSearch(
                        key: .uid(.set(UIDSetNonEmpty(range: 6_987_831...9_879_779))),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search(
                                    [
                                        6_987_831, 7_125_543, 7_263_255, 7_400_966, 7_538_678,
                                        7_676_390, 7_814_102, 7_951_814, 8_089_525, 8_227_237,
                                        8_364_949, 8_502_661, 8_640_373, 8_778_085, 8_915_796,
                                        9_053_508, 9_191_220, 9_328_932, 9_466_644, 9_604_355,
                                        9_742_067, 9_879_779,
                                    ],
                                    nil
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
            ]
        )
        let result: UIDSet = try await allUIDs(
            connection: connection,
            query: .last(count: 900),
            mailboxMessageCount: 100_000,
            capabilities: [.imap4rev1]
        )
        #expect(
            result == [
                6_987_831, 7_125_543, 7_263_255, 7_400_966, 7_538_678,
                7_676_390, 7_814_102, 7_951_814, 8_089_525, 8_227_237,
                8_364_949, 8_502_661, 8_640_373, 8_778_085, 8_915_796,
                9_053_508, 9_191_220, 9_328_932, 9_466_644, 9_604_355,
                9_742_067, 9_879_779,
            ]
        )
    }

    @Test
    static func seenUIDs_rfc3501() async throws {
        let connection = TestConnection(
            expectedOrdering: .anyOrder,
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
                ),
                .init(
                    command: .uidSearch(
                        key: .and([
                            .uid(.set(UIDSetNonEmpty(range: 6_987_831...9_879_779))),
                            .seen,
                        ]),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search(
                                    [
                                        6_987_831, 7_125_543, 7_263_255, 7_400_966, 7_538_678,
                                        7_676_390, 7_814_102, 7_951_814, 8_089_525, 8_227_237,
                                        8_364_949, 8_502_661, 8_640_373, 8_778_085, 8_915_796,
                                        9_053_508, 9_191_220, 9_328_932, 9_466_644, 9_604_355,
                                        9_742_067, 9_879_779,
                                    ],
                                    nil
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
            ]
        )
        let result: UIDSet = try await batchedSearch(
            connection: connection,
            key: .seen,
            query: .last(count: 900),
            mailboxMessageCount: 100_000,
            capabilities: [.imap4rev1]
        )
        #expect(
            result == [
                6_987_831, 7_125_543, 7_263_255, 7_400_966, 7_538_678,
                7_676_390, 7_814_102, 7_951_814, 8_089_525, 8_227_237,
                8_364_949, 8_502_661, 8_640_373, 8_778_085, 8_915_796,
                9_053_508, 9_191_220, 9_328_932, 9_466_644, 9_604_355,
                9_742_067, 9_879_779,
            ]
        )
    }

    @Test
    static func seenUIDs_partial() async throws {
        let connection = TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .seen,
                        charset: nil,
                        returnOptions: [.partial(.last(1...900))]
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .extendedSearch(
                                    ExtendedSearchResponse(
                                        correlator: SearchCorrelator(tag: "A1"),  // <--- we need to hard-code this.
                                        kind: .uid,
                                        returnData: [
                                            .partial(
                                                .last(1...900),
                                                [
                                                    6_987_831, 7_125_543, 7_263_255, 7_400_966, 7_538_678,
                                                    7_676_390, 7_814_102, 7_951_814, 8_089_525, 8_227_237,
                                                    8_364_949, 8_502_661, 8_640_373, 8_778_085, 8_915_796,
                                                    9_053_508, 9_191_220, 9_328_932, 9_466_644, 9_604_355,
                                                    9_742_067, 9_879_779,
                                                ]
                                            )
                                        ]
                                    )
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ]
        )
        let result: UIDSet = try await batchedSearch(
            connection: connection,
            key: .seen,
            query: .last(count: 900),
            mailboxMessageCount: 100_000,
            capabilities: [.imap4rev1, .partial, .messageLimit(1_200)]
        )
        #expect(
            result == [
                6_987_831, 7_125_543, 7_263_255, 7_400_966, 7_538_678,
                7_676_390, 7_814_102, 7_951_814, 8_089_525, 8_227_237,
                8_364_949, 8_502_661, 8_640_373, 8_778_085, 8_915_796,
                9_053_508, 9_191_220, 9_328_932, 9_466_644, 9_604_355,
                9_742_067, 9_879_779,
            ]
        )
    }

    @Test
    static func uids_rfc3501_multipleBatches() async throws {
        // Tests that batchedSearch correctly intersects requested UIDs with each batch's UID range
        // and combines results across multiple batches when the server doesn't support PARTIAL.
        let connection = TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .uid(.set(UIDSetNonEmpty(range: 2_994...4_000))),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search([3_956, 3_607, 3_358], nil)
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
                .init(
                    command: .uidSearch(
                        key: .uid(.set(UIDSetNonEmpty(range: 2_000...2_993))),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search([2_272, 2_878, 2_850], nil)
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
            ]
        )
        let result: UIDSet = try await batchedSearch(
            connection: connection,
            key: .all,
            query: .uids([2_000...4_000]),
            mailboxMessageCount: 100_000,
            capabilities: [.imap4rev1, .messageLimit(1_007)]
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(result == [2_272, 2_878, 2_850, 3_956, 3_607, 3_358])
    }

    @Test
    static func uids_partial() async throws {
        // Tests that batchedSearch with PARTIAL capability correctly searches for specific UIDs.
        // With PARTIAL, the search is limited to the last N messages in the mailbox.
        let connection = TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .uid(.set(UIDSetNonEmpty(set: [100, 200, 1_500, 2_000])!)),
                        charset: nil,
                        returnOptions: [.partial(.last(1...4))]
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .extendedSearch(
                                    ExtendedSearchResponse(
                                        correlator: SearchCorrelator(tag: "A1"),
                                        kind: .uid,
                                        returnData: [
                                            .partial(
                                                .last(1...4),
                                                [1_500, 2_000]
                                            )
                                        ]
                                    )
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ]
        )
        let result: UIDSet = try await batchedSearch(
            connection: connection,
            key: .all,
            query: .uids([100, 200, 1_500, 2_000]),
            mailboxMessageCount: 100_000,
            capabilities: [.imap4rev1, .partial, .messageLimit(1_200)]
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(result == [1_500, 2_000])
    }

    @Test
    static func all_rfc3501_multipleBatches() async throws {
        // Tests that batchedSearch correctly iterates through all batches when fetching
        // the entire mailbox using UID range batching (without PARTIAL).
        let connection = TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .sequenceNumbers(.set(.init(set: [1, 1_000, 2_000, 3_000])!)),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search([100, 5_000, 10_000, 15_000], nil)
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
                .init(
                    command: .uidSearch(
                        key: .uid(.set(UIDSetNonEmpty(range: 10_001...15_000))),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search([11_000, 12_000, 13_000, 14_000, 15_000], nil)
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
                .init(
                    command: .uidSearch(
                        key: .uid(.set(UIDSetNonEmpty(range: 5_001...10_000))),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search([6_000, 7_000, 8_000, 9_000, 10_000], nil)
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
                .init(
                    command: .uidSearch(
                        key: .uid(.set(UIDSetNonEmpty(range: 100...5_000))),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search([100, 1_000, 2_000, 3_000, 4_000, 5_000], nil)
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
            ]
        )
        let result: UIDSet = try await batchedSearch(
            connection: connection,
            key: .all,
            query: .all,
            mailboxMessageCount: 3_000,
            capabilities: [.imap4rev1, .messageLimit(1_000)]
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(
            result == [
                100, 1_000, 2_000, 3_000, 4_000, 5_000,
                6_000, 7_000, 8_000, 9_000, 10_000,
                11_000, 12_000, 13_000, 14_000, 15_000,
            ]
        )
    }

    @Test
    static func all_partial() async throws {
        // Tests that batchedSearch with PARTIAL capability correctly searches the entire mailbox
        // using PARTIAL ranges. With a small mailbox, this should require only one partial batch.
        let connection = TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .all,
                        charset: nil,
                        returnOptions: [.partial(.last(1...3_000))]
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .extendedSearch(
                                    ExtendedSearchResponse(
                                        correlator: SearchCorrelator(tag: "A1"),
                                        kind: .uid,
                                        returnData: [
                                            .partial(
                                                .last(1...3_000),
                                                [
                                                    100, 1_000, 2_000, 3_000, 4_000, 5_000,
                                                    6_000, 7_000, 8_000, 9_000, 10_000,
                                                    11_000, 12_000, 13_000, 14_000, 15_000,
                                                ]
                                            )
                                        ]
                                    )
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                )
            ]
        )
        let result: UIDSet = try await batchedSearch(
            connection: connection,
            key: .all,
            query: .all,
            mailboxMessageCount: 3_000,
            capabilities: [.imap4rev1, .partial, .messageLimit(5_000)]
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(
            result == [
                100, 1_000, 2_000, 3_000, 4_000, 5_000,
                6_000, 7_000, 8_000, 9_000, 10_000,
                11_000, 12_000, 13_000, 14_000, 15_000,
            ]
        )
    }

}
