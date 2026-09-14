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

import ArgumentParser
@testable import IMAPCommands
@testable import IMAPToolLib
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite("Create Mailbox")
struct CreateMailboxTests {
    @Test
    static func endToEnd() async throws {
        let connection = try TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .create("foo", []),
                    untagged: []
                ),
                .init(
                    command: .listIndependent(
                        [],
                        reference: MailboxName([]),
                        .mailbox(ByteBuffer(string: "foo")),
                        []
                    ),
                    untagged: [
                        .mailboxData(
                            .list(
                                MailboxInfo(
                                    attributes: [
                                        .hasNoChildren
                                    ],
                                    path: MailboxPath(
                                        name: "foo",
                                        pathSeparator: "."
                                    ),
                                    extensions: [:]
                                )
                            )
                        )
                    ]
                ),
                .init(
                    command: .status(
                        "foo",
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
                                "foo",
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
            ]
        )

        let info = try await createAndList(
            connection: connection,
            capabilities: [.imap4rev1, .condStore],
            mailbox: .create("foo", [])
        )

        #expect(
            try info
                == MailboxInfoAndStatus(
                    path: MailboxPath(
                        name: "foo",
                        pathSeparator: "."
                    ),
                    attributes: [
                        .hasNoChildren
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
                )
        )
    }

    @Test
    static func endToEnd_alreadyExists() async throws {
        let connection = try TestConnection(
            expectedOrdering: .anyOrder,
            expectedCommands: [
                .init(
                    command: .listIndependent(
                        [],
                        reference: MailboxName([]),
                        .mailbox(ByteBuffer(string: "foo")),
                        []
                    ),
                    untagged: [
                        .mailboxData(
                            .list(
                                MailboxInfo(
                                    attributes: [
                                        .hasNoChildren
                                    ],
                                    path: MailboxPath(
                                        name: "foo",
                                        pathSeparator: "."
                                    ),
                                    extensions: [:]
                                )
                            )
                        )
                    ]
                ),
                .init(
                    command: .status(
                        "foo",
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
                                "foo",
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
            ]
        )

        let info = try await createAndList(
            connection: connection,
            capabilities: [.imap4rev1, .condStore],
            mailbox: .alreadyExists("foo")
        )

        #expect(
            try info
                == MailboxInfoAndStatus(
                    path: MailboxPath(
                        name: "foo",
                        pathSeparator: "."
                    ),
                    attributes: [
                        .hasNoChildren
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
                )
        )
    }
}
