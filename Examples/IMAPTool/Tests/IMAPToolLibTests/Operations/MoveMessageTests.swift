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
enum MoveMessageTests {
    @Test
    static func testUsingMoveCommand() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidMove(
                    .set([123, 456]),
                    "Archive"
                ),
                responses: [],
                completion: .ok(.init(text: "Moved"))
            )
        ])

        let selectInfo = SelectInfo(
            mailbox: "INBOX",
            responseText: .init(text: "Selected"),
            flags: [],
            permanentFlags: [],
            messageCount: 10,
            uidNext: 500,
            uidValidity: 12345
        )

        try await moveMessages(
            connection: connection,
            selectInfo: selectInfo,
            capabilities: [.move],
            uids: [123, 456],
            to: "Archive"
        )
    }

    @Test
    static func testUsingCopyCommand() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidCopy(
                    .set([789, 101112]),
                    "Sent"
                ),
                responses: [],
                completion: .ok(.init(text: "Copied"))
            ),
            .init(
                command: .uidStore(
                    .set([789, 101112]),
                    [],
                    .flags(
                        StoreFlags.add(
                            silent: true,
                            list: [.deleted]
                        )
                    )
                ),
                responses: [],
                completion: .ok(.init(text: "Updated"))
            ),
            .init(
                command: .expunge,
                responses: [
                    .untagged(.messageData(.expunge(5))),
                    .untagged(.messageData(.expunge(8))),
                ],
                completion: .ok(.init(text: "Done"))
            ),
        ])

        let selectInfo = SelectInfo(
            mailbox: "INBOX",
            responseText: .init(text: "Selected"),
            flags: [],
            permanentFlags: [],
            messageCount: 20,
            uidNext: 150000,
            uidValidity: 67890
        )

        try await moveMessages(
            connection: connection,
            selectInfo: selectInfo,
            capabilities: [],
            uids: [789, 101112],
            to: "Sent"
        )
    }

    @Test
    static func testEmpty() async throws {
        let connection = TestConnection(
            expectedCommands: []
        )

        let selectInfo = SelectInfo(
            mailbox: "INBOX",
            responseText: .init(text: "Selected"),
            flags: [],
            permanentFlags: [],
            messageCount: 0,
            uidNext: 1,
            uidValidity: 11111
        )

        try await moveMessages(
            connection: connection,
            selectInfo: selectInfo,
            capabilities: [.move],
            uids: [],
            to: "Archive"
        )
    }

    @Test
    static func testSingleMessage() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidMove(
                    .set([42]),
                    "Trash"
                ),
                responses: [],
                completion: .ok(.init(text: "Moved"))
            )
        ])

        let selectInfo = SelectInfo(
            mailbox: "INBOX",
            responseText: .init(text: "Selected"),
            flags: [],
            permanentFlags: [],
            messageCount: 5,
            uidNext: 100,
            uidValidity: 99999
        )

        try await moveMessages(
            connection: connection,
            selectInfo: selectInfo,
            capabilities: [.move],
            uids: [42],
            to: "Trash"
        )
    }

    @Test
    static func testMultipleMessagesWithCopyFallback() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidCopy(
                    .set([1, 2, 3, 4, 5]),
                    "Important"
                ),
                responses: [],
                completion: .ok(.init(text: "Copied"))
            ),
            .init(
                command: .uidStore(
                    .set([1, 2, 3, 4, 5]),
                    [],
                    .flags(
                        StoreFlags.add(
                            silent: true,
                            list: [.deleted]
                        )
                    )
                ),
                responses: [],
                completion: .ok(.init(text: "Updated"))
            ),
            .init(
                command: .expunge,
                responses: [
                    .untagged(.messageData(.expunge(1))),
                    .untagged(.messageData(.expunge(2))),
                    .untagged(.messageData(.expunge(3))),
                    .untagged(.messageData(.expunge(4))),
                    .untagged(.messageData(.expunge(5))),
                ],
                completion: .ok(.init(text: "Done"))
            ),
        ])

        let selectInfo = SelectInfo(
            mailbox: "INBOX",
            responseText: .init(text: "Selected"),
            flags: [],
            permanentFlags: [],
            messageCount: 50,
            uidNext: 200,
            uidValidity: 54321
        )

        try await moveMessages(
            connection: connection,
            selectInfo: selectInfo,
            capabilities: [],
            uids: [1, 2, 3, 4, 5],
            to: "Important"
        )
    }
}
