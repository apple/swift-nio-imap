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
enum ListStatusTests {
    struct StrategyFixture: Hashable, CustomTestStringConvertible {
        var capabilities: [Capability]
        var expected: ListStatusStrategy

        var testDescription: String {
            capabilities.map { String($0) }.joined(separator: " ")
        }
    }

    @Test(arguments: [
        StrategyFixture(
            capabilities: [],
            expected: ListStatusStrategy(
                listReturnOptions: [],
                statusAttributes: [
                    .messageCount,
                    .uidNext,
                    .uidValidity,
                    .unseenCount,
                ],
                kind: .listThenStatus
            )
        ),
        StrategyFixture(
            capabilities: [.listStatus],
            expected: ListStatusStrategy(
                listReturnOptions: [],
                statusAttributes: [
                    .messageCount,
                    .uidNext,
                    .uidValidity,
                    .unseenCount,
                ],
                kind: .listStatus
            )
        ),
        StrategyFixture(
            capabilities: [.condStore],
            expected: ListStatusStrategy(
                listReturnOptions: [],
                statusAttributes: [
                    .messageCount,
                    .uidNext,
                    .uidValidity,
                    .unseenCount,
                    .highestModificationSequence,
                ],
                kind: .listThenStatus
            )
        ),
        StrategyFixture(
            capabilities: [.specialUse],
            expected: ListStatusStrategy(
                listReturnOptions: [
                    .specialUse
                ],
                statusAttributes: [
                    .messageCount,
                    .uidNext,
                    .uidValidity,
                    .unseenCount,
                ],
                kind: .listThenStatus
            )
        ),
        StrategyFixture(
            capabilities: [.appendLimit(1234)],
            expected: ListStatusStrategy(
                listReturnOptions: [],
                statusAttributes: [
                    .messageCount,
                    .uidNext,
                    .uidValidity,
                    .unseenCount,
                ],
                kind: .listThenStatus
            )
        ),
        StrategyFixture(
            capabilities: [Capability("STATUS=SIZE")],
            expected: ListStatusStrategy(
                listReturnOptions: [],
                statusAttributes: [
                    .messageCount,
                    .uidNext,
                    .uidValidity,
                    .unseenCount,
                    .size,
                ],
                kind: .listThenStatus
            )
        ),
        StrategyFixture(
            capabilities: [
                .listStatus,
                .condStore,
                .specialUse,
                .appendLimit(1234),
                Capability("STATUS=SIZE"),
            ],
            expected: ListStatusStrategy(
                listReturnOptions: [
                    .specialUse
                ],
                statusAttributes: [
                    .messageCount,
                    .uidNext,
                    .uidValidity,
                    .unseenCount,
                    .highestModificationSequence,
                    .size,
                ],
                kind: .listStatus
            )
        ),
    ])
    static func strategy(
        fixture: StrategyFixture
    ) throws {
        #expect(ListStatusStrategy(capabilities: fixture.capabilities) == fixture.expected)
    }

    @Test
    static func endToEnd_listThenStatus() async throws {
        let connection = try TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .listIndependent(
                        [],
                        reference: MailboxName([]),
                        .mailbox(ByteBuffer(string: "*")),
                        []
                    ),
                    untagged: [
                        .mailboxData(
                            .list(
                                MailboxInfo(
                                    attributes: [
                                        .noInferiors
                                    ],
                                    path: MailboxPath(
                                        name: .inbox,
                                        pathSeparator: "/"
                                    ),
                                    extensions: [:]
                                )
                            )
                        ),
                        .mailboxData(
                            .list(
                                MailboxInfo(
                                    attributes: [
                                        .hasNoChildren
                                    ],
                                    path: MailboxPath(
                                        name: "Trash",
                                        pathSeparator: "."
                                    ),
                                    extensions: [:]
                                )
                            )
                        ),
                    ]
                ),
                .init(
                    command: .status(
                        .inbox,
                        [
                            .messageCount,
                            .uidNext,
                            .uidValidity,
                            .unseenCount,
                            .highestModificationSequence,
                        ]
                    ),
                    untagged: [
                        .mailboxData(
                            .status(
                                .inbox,
                                MailboxStatus(
                                    messageCount: 8_640_873,
                                    recentCount: nil,
                                    nextUID: 25_922_595,
                                    uidValidity: 34_563_456,
                                    unseenCount: 17_234,
                                    size: nil,
                                    highestModificationSequence: 9_604_355,
                                    appendLimit: nil
                                )
                            )
                        )
                    ]
                ),
                .init(
                    command: .status(
                        "Trash",
                        [
                            .messageCount,
                            .uidNext,
                            .uidValidity,
                            .unseenCount,
                            .highestModificationSequence,
                        ]
                    ),
                    untagged: [
                        .mailboxData(
                            .status(
                                "Trash",
                                MailboxStatus(
                                    messageCount: 345,
                                    recentCount: nil,
                                    nextUID: 5_262,
                                    uidValidity: 75_386_78,
                                    unseenCount: 12,
                                    size: nil,
                                    highestModificationSequence: 364_949,
                                    appendLimit: nil
                                )
                            )
                        )
                    ]
                ),
            ]
        )

        let info = try await listMailboxes(
            connection: connection,
            capabilities: [.imap4rev1, .condStore]
        )

        #expect(info.count == 2)
        #expect(
            info == [
                try MailboxInfoAndStatus(
                    path: MailboxPath(
                        name: .inbox,
                        pathSeparator: "/"
                    ),
                    attributes: [
                        .noInferiors
                    ],
                    status: MailboxStatus(
                        messageCount: 8_640_873,
                        recentCount: nil,
                        nextUID: 25_922_595,
                        uidValidity: 34_563_456,
                        unseenCount: 17_234,
                        size: nil,
                        highestModificationSequence: 9_604_355,
                        appendLimit: nil
                    )
                ),
                try MailboxInfoAndStatus(
                    path: MailboxPath(
                        name: "Trash",
                        pathSeparator: "."
                    ),
                    attributes: [
                        .hasNoChildren
                    ],
                    status: MailboxStatus(
                        messageCount: 345,
                        recentCount: nil,
                        nextUID: 5_262,
                        uidValidity: 75_386_78,
                        unseenCount: 12,
                        size: nil,
                        highestModificationSequence: 364_949,
                        appendLimit: nil
                    )
                ),
            ]
        )
    }

    @Test
    static func endToEnd_listStatus() async throws {
        let connection = try TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .listIndependent(
                        [],
                        reference: MailboxName([]),
                        .mailbox(ByteBuffer(string: "*")),
                        [
                            .statusOption([
                                .messageCount,
                                .uidNext,
                                .uidValidity,
                                .unseenCount,
                                .highestModificationSequence,
                            ])
                        ]
                    ),
                    untagged: [
                        .mailboxData(
                            .list(
                                MailboxInfo(
                                    attributes: [
                                        .noInferiors
                                    ],
                                    path: MailboxPath(
                                        name: .inbox,
                                        pathSeparator: "/"
                                    ),
                                    extensions: [:]
                                )
                            )
                        ),
                        .mailboxData(
                            .status(
                                .inbox,
                                MailboxStatus(
                                    messageCount: 8_640_873,
                                    recentCount: nil,
                                    nextUID: 25_922_595,
                                    uidValidity: 34_563_456,
                                    unseenCount: 17_234,
                                    size: nil,
                                    highestModificationSequence: 9_604_355,
                                    appendLimit: nil
                                )
                            )
                        ),
                        .mailboxData(
                            .list(
                                MailboxInfo(
                                    attributes: [
                                        .hasNoChildren
                                    ],
                                    path: MailboxPath(
                                        name: "Trash",
                                        pathSeparator: "."
                                    ),
                                    extensions: [:]
                                )
                            )
                        ),
                        .mailboxData(
                            .status(
                                "Trash",
                                MailboxStatus(
                                    messageCount: 345,
                                    recentCount: nil,
                                    nextUID: 5_262,
                                    uidValidity: 75_386_78,
                                    unseenCount: 12,
                                    size: nil,
                                    highestModificationSequence: 364_949,
                                    appendLimit: nil
                                )
                            )
                        ),
                    ]
                )
            ]
        )

        let info = try await listMailboxes(
            connection: connection,
            capabilities: [.imap4rev1, .condStore, .listStatus]
        )

        #expect(info.count == 2)
        #expect(
            info == [
                try MailboxInfoAndStatus(
                    path: MailboxPath(
                        name: .inbox,
                        pathSeparator: "/"
                    ),
                    attributes: [
                        .noInferiors
                    ],
                    status: MailboxStatus(
                        messageCount: 8_640_873,
                        recentCount: nil,
                        nextUID: 25_922_595,
                        uidValidity: 34_563_456,
                        unseenCount: 17_234,
                        size: nil,
                        highestModificationSequence: 9_604_355,
                        appendLimit: nil
                    )
                ),
                try MailboxInfoAndStatus(
                    path: MailboxPath(
                        name: "Trash",
                        pathSeparator: "."
                    ),
                    attributes: [
                        .hasNoChildren
                    ],
                    status: MailboxStatus(
                        messageCount: 345,
                        recentCount: nil,
                        nextUID: 5_262,
                        uidValidity: 75_386_78,
                        unseenCount: 12,
                        size: nil,
                        highestModificationSequence: 364_949,
                        appendLimit: nil
                    )
                ),
            ]
        )
    }
}
