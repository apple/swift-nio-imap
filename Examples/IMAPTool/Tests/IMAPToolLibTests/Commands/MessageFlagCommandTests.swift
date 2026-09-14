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
@testable import IMAPToolLib
@testable import IMAPCommands
import Foundation
import NIO
import NIOIMAP
import Testing

private enum MessageFlagCommandTests {
    static func parse(
        _ arguments: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> MessageFlagCommand {
        try ArgumentParsingTests.parse(
            MessageFlagCommand.self,
            arguments,
            sourceLocation: sourceLocation
        )
    }

    @Test
    static func parseFlagsCommand_withUID() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "bar.example.com",
            "--mailbox", "INBOX",
            "--uid", "123",
            "--flag", "seen",
            "--flag", "flagged",
        ])
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.mailbox == .inbox)
        #expect(sut.uids == [123])
        #expect(sut.messages == nil)
        #expect(sut.setFlags == [.seen, .flagged])
    }

    @Test
    static func parseFlagsCommand_withMessages() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "bar.example.com",
            "--mailbox", "INBOX",
            "--flag", "seen",
            "--flag", "flagged",
            "--messages", "messages.json",
        ])
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.mailbox == .inbox)
        #expect(sut.uids == [])
        #expect(sut.messages == "messages.json")
        #expect(sut.setFlags == [.seen, .flagged])
    }

    @Test
    static func parseFlagsCommand_validation_noFlags() throws {
        // This should actually be valid - you can specify UIDs without flags
        // if you want to just select the messages (though not very useful)
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "bar.example.com",
            "--uid", "123",
            // No flags specified - this is technically valid
        ])
        #expect(sut.setFlags == [])
        #expect(sut.unsetFlags == [])
        #expect(sut.uids == [123])
        #expect(sut.messageIDs == [])
    }

    @Test
    static func parseFlagsCommand_multipleUIDs() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--uid", "456",
            "--uid", "789",
            "--flag", "seen",
        ])
        #expect(sut.uids == [123, 456, 789])
        #expect(sut.messageIDs == [])
        #expect(sut.setFlags == [.seen])
        #expect(sut.unsetFlags == [])
    }

    @Test
    static func parseFlagsCommand_singleMessageID() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--message-id", "foo@mail.example.com",
            "--flag", "seen",
        ])
        #expect(sut.uids == [])
        #expect(sut.messageIDs == ["<foo@mail.example.com>"])
        #expect(sut.setFlags == [.seen])
        #expect(sut.unsetFlags == [])
    }

    @Test
    static func parseFlagsCommand_messageIDsAndUID() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--message-id", "foo@mail.example.com",
            "--uid", "123",
            "--flag", "seen",
        ])
        #expect(sut.uids == [123])
        #expect(sut.messageIDs == ["<foo@mail.example.com>"])
        #expect(sut.setFlags == [.seen])
        #expect(sut.unsetFlags == [])
    }

    @Test
    static func parseFlagsCommand_multipleMessageIDs() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--message-id", "foo@mail.example.com",
            "--message-id", "<bar@mail.example.com>",
            "--flag", "seen",
        ])
        #expect(sut.uids == [])
        #expect(sut.messageIDs == ["<foo@mail.example.com>", "<bar@mail.example.com>"])
        #expect(sut.setFlags == [.seen])
        #expect(sut.unsetFlags == [])
    }

    @Test
    static func parseFlagsCommand_unsetFlags() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--unset", "seen",
            "--unset", "flagged",
        ])
        #expect(sut.setFlags == [])
        #expect(sut.unsetFlags == [.seen, .flagged])
    }

    @Test
    static func parseFlagsCommand_setBothSetAndUnset() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--set", "seen",
            "--set", "draft",
            "--remove", "flagged",
            "--remove", "deleted",
        ])
        #expect(sut.setFlags == [.seen, .draft])
        #expect(sut.unsetFlags == [.flagged, .deleted])
    }

    @Test
    static func parseFlagsCommand_allStandardFlags() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--flag", "answered",
            "--flag", "flagged",
            "--flag", "deleted",
            "--flag", "seen",
            "--flag", "draft",
        ])
        #expect(sut.setFlags == [.answered, .flagged, .deleted, .seen, .draft])
    }

    @Test
    static func parseFlagsCommand_colorFlags() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--flag", "red",
            "--flag", "orange",
            "--flag", "yellow",
            "--flag", "green",
            "--flag", "blue",
            "--flag", "purple",
            "--flag", "gray",
        ])
        #expect(sut.setFlags == [.red, .orange, .yellow, .green, .blue, .purple, .gray])
    }

    @Test
    static func parseFlagsCommand_customMailbox() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--mailbox", "Sent",
            "--uid", "123",
            "--flag", "seen",
        ])
        #expect(sut.mailbox == "Sent")
        #expect(sut.uids == [123])
        #expect(sut.setFlags == [.seen])
    }

    @Test
    static func parseFlagsCommand_outputFormat() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--flag", "seen",
            "--output-format", "json",
        ])
        #expect(sut.outputFormat == .json)
    }

    @Test
    static func parseFlagsCommand_aliasCommand() throws {
        let sut = try parse([
            "flag",  // Using the alias instead of "flags"
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--flag", "seen",
        ])
        #expect(sut.uids == [123])
        #expect(sut.setFlags == [.seen])
    }

    @Test
    static func parseFlagsCommand_longFormOptions() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--set", "seen",  // Using --set instead of --flag
            "--remove", "flagged",  // Using --remove instead of --unset
        ])
        #expect(sut.setFlags == [.seen])
        #expect(sut.unsetFlags == [.flagged])
    }

    @Test
    static func parseFlagsCommand_validation_bothUIDsAndMessages() throws {
        // This should be valid - having both UIDs and messages file is allowed
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--messages", "messages.json",
            "--flag", "seen",
        ])
        #expect(sut.uids == [123])
        #expect(sut.messages == "messages.json")
        #expect(sut.setFlags == [.seen])
    }

    @Test
    static func parseFlagsCommand_flagChangesConversion() throws {
        let sut = try parse([
            "flags",
            "--sasl", "plain:foo bar",
            "--server", "example.com",
            "--uid", "123",
            "--set", "seen",
            "--set", "flagged",
            "--unset", "deleted",
            "--unset", "draft",
        ])

        let flagChanges = sut.imapFlags

        // Test that the conversion works correctly
        #expect(flagChanges.set == [.flagged, .seen])
        #expect(flagChanges.unset == [.deleted, .draft])
    }
}
