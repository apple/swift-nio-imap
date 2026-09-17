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

import Testing
import ArgumentParser
@testable import IMAPToolLib
import NIOIMAP

@Suite
enum MoveMessageCommandTests {
    static func parse(_ arguments: [String]) throws -> MoveMessageCommand {
        try ArgumentParsingTests.parse(MoveMessageCommand.self, arguments)
    }

    @Test
    static func parseBasicMoveCommand_withUID() throws {
        let sut = try parse([
            "move-message",
            "--server", "imap.example.com",
            "--username", "testuser:testpass",
            "--source", "INBOX",
            "--destination", "Sent",
            "--uid", "123",
        ])

        #expect(sut.connectionInfo.server == "imap.example.com")
        #expect(sut.connectionInfo.username == "testuser:testpass")
        #expect(sut.sourceMailbox == "INBOX")
        #expect(sut.destinationMailbox == "Sent")
        #expect(sut.uids == [123])
        #expect(sut.messageIDs == [])
        #expect(sut.outputFormat == .text)
    }

    @Test
    static func parseMultipleUIDs() throws {
        let sut = try parse([
            "move-message",
            "--server", "imap.example.com",
            "--username", "user:pass",
            "--source", "INBOX",
            "--destination", "Archive",
            "--uid", "1",
            "--uid", "2",
            "--uid", "100",
        ])

        #expect(sut.uids == [1, 2, 100])
        #expect(sut.messageIDs == [])
    }

    @Test
    static func parseWithMessageID() throws {
        let sut = try parse([
            "move-message",
            "--server", "imap.example.com",
            "--username", "user:pass",
            "--source", "INBOX",
            "--destination", "Trash",
            "--message-id", "<msg123@example.com>",
        ])

        #expect(sut.uids == [])
        #expect(sut.messageIDs == [MessageID("<msg123@example.com>")])
    }

    @Test
    static func parseMultipleMessageIDs() throws {
        let sut = try parse([
            "move-message",
            "--server", "imap.example.com",
            "--username", "user:pass",
            "--source", "INBOX",
            "--destination", "Archive",
            "--message-id", "<msg1@example.com>",
            "--message-id", "<msg2@example.com>",
            "--message-id", "<msg3@example.com>",
        ])

        #expect(sut.uids == [])
        #expect(
            sut.messageIDs == [
                MessageID("<msg1@example.com>"),
                MessageID("<msg2@example.com>"),
                MessageID("<msg3@example.com>"),
            ]
        )
    }

    @Test
    static func parseMixedUIDsAndMessageIDs() throws {
        let sut = try parse([
            "move-message",
            "--server", "imap.example.com",
            "--username", "user:pass",
            "--source", "INBOX",
            "--destination", "Spam",
            "--uid", "42",
            "--message-id", "<msg@example.com>",
            "--uid", "99",
        ])

        #expect(sut.uids == [42, 99])
        #expect(sut.messageIDs == [MessageID("<msg@example.com>")])
    }

    @Test
    static func parseAlternativeMailboxNames() throws {
        let sut = try parse([
            "move-message",
            "--server", "imap.example.com",
            "--username", "user:pass",
            "--from", "INBOX",
            "--to", "Sent",
            "--uid", "1",
        ])

        #expect(sut.sourceMailbox == "INBOX")
        #expect(sut.destinationMailbox == "Sent")
    }

    @Test
    static func parseWithJSONOutputFormat() throws {
        let sut = try parse([
            "move-message",
            "--server", "imap.example.com",
            "--username", "user:pass",
            "--source", "INBOX",
            "--destination", "Archive",
            "--uid", "1",
            "--output-format", "json",
        ])

        #expect(sut.outputFormat == .json)
    }

    @Test
    static func parseWithMessagesFile() throws {
        let sut = try parse([
            "move-message",
            "--server", "imap.example.com",
            "--username", "user:pass",
            "--source", "INBOX",
            "--destination", "Archive",
            "--messages", "/path/to/messages.json",
        ])

        #expect(sut.messages == "/path/to/messages.json")
        #expect(sut.uids == [])
        #expect(sut.messageIDs == [])
    }

    @Test
    static func parseWithMessagesFileAndUIDs() throws {
        let sut = try parse([
            "move-message",
            "--server", "imap.example.com",
            "--username", "user:pass",
            "--source", "INBOX",
            "--destination", "Archive",
            "--messages", "/path/to/messages.json",
            "--uid", "123",
        ])

        #expect(sut.messages == "/path/to/messages.json")
        #expect(sut.uids == [123])
    }

    @Test
    static func validationFailsWithNoMessageIdentifiers() throws {
        #expect(
            performing: {
                _ = try parse([
                    "move-message",
                    "--server", "imap.example.com",
                    "--username", "user:pass",
                    "--source", "INBOX",
                    "--destination", "Archive",
                ])
            },
            throws: {
                #expect(
                    firstLineOfErrorMessage(for: $0)
                        == "Error: Must specify at least one UID (--uid), Message-ID (--message-id), or a file to read from (--messages)."
                )
                return true
            }
        )
    }
}
