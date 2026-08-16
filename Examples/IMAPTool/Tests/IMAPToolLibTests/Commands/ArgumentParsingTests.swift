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

@Suite("Argument Parsing")
enum ArgumentParsingTests {
    static func parse<A>(
        _: A.Type,
        _ arguments: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> A where A: ParsableCommand {
        let root = try RootCommand.parseAsRoot(arguments)
        return try #require(root as? A, sourceLocation: sourceLocation)
    }

    @Test
    static func parseIdentifyCommand() throws {
        let id = try parse(
            IdentifyCommand.self,
            [
                "id",
                "--sasl", "plain:foo bar",
                "--server", "bar.example.com",
            ]
        )
        #expect(id.connectionInfo.username == nil)
        #expect(id.connectionInfo.sasl == "plain:foo bar")
        #expect(id.connectionInfo.disableSASLIR == false)
        #expect(id.connectionInfo.server == "bar.example.com")
        #expect(id.outputFormat == .text)
    }

    @Test
    static func parseAppendCommand() throws {
        let sut = try parse(
            AppendCommand.self,
            [
                "append",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "foo.eml",
                "baz/bar.eml",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.sasl == nil)
        #expect(sut.connectionInfo.disableSASLIR == false)
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.input == ["foo.eml", "baz/bar.eml"])
        #expect(sut.outputFormat == .text)
    }

    @Test
    static func parseDeleteMessagesCommand() throws {
        let sut = try parse(
            DeleteMessagesCommand.self,
            [
                "delete-messages",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--messages", "foo.json",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.sasl == nil)
        #expect(sut.connectionInfo.disableSASLIR == false)
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.action == .deleteSpecific(filePath: "foo.json"))
        #expect(sut.mailboxName == .inbox)
        #expect(sut.outputFormat == .text)
    }

    @Test
    static func parseDeleteMessagesCommand_2() throws {
        let sut = try parse(
            DeleteMessagesCommand.self,
            [
                "delete-messages",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--messages", "foo.json",
                "--mailbox", "work",
                "--output-format", "json",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.sasl == nil)
        #expect(sut.connectionInfo.disableSASLIR == false)
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.action == .deleteSpecific(filePath: "foo.json"))
        #expect(sut.mailboxName.debugDescription == "work")
        #expect(sut.outputFormat == .json)
    }

    @Test
    static func parseDeleteMessagesCommand_3() throws {
        let sut = try parse(
            DeleteMessagesCommand.self,
            [
                "delete-messages",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--all",
                "--mailbox", "work",
                "--output-format", "json",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.sasl == nil)
        #expect(sut.connectionInfo.disableSASLIR == false)
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.action == .deleteAll)
        #expect(sut.mailboxName.debugDescription == "work")
        #expect(sut.outputFormat == .json)
    }

    @Test
    static func parseDeleteMessagesCommand_4() throws {
        let sut = try parse(
            DeleteMessagesCommand.self,
            [
                "delete-messages",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--all",
                "--messages", "foo.json",
                "--mailbox", "work",
                "--output-format", "json",
            ]
        )
        #expect(sut.action == .fail("Can not specify both --all and a file to read message info from."))
    }

    @Test
    static func parseDeleteMessagesCommand_5() throws {
        let sut = try parse(
            DeleteMessagesCommand.self,
            [
                "delete-messages",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--mailbox", "work",
                "--output-format", "json",
            ]
        )
        #expect(sut.action == .fail("Need to specify a file to read message info from."))
    }

    @Test
    static func parseAppendCommand_1() throws {
        let sut = try parse(
            AppendCommand.self,
            [
                "append",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "a",
                "b",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.mailbox == .inbox)
        #expect(sut.appendOptions == [.skipErrors, .sort])
        #expect(sut.input == ["a", "b"])
    }

    @Test
    static func parseAppendCommand_2() throws {
        let sut = try parse(
            AppendCommand.self,
            [
                "append",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--sort-by-date",
                "--skip-unreadable",
                "a",
                "b",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.mailbox == .inbox)
        #expect(sut.appendOptions == [.skipErrors, .sort])
        #expect(sut.input == ["a", "b"])
    }

    @Test
    static func parseAppendCommand_3() throws {
        let sut = try parse(
            AppendCommand.self,
            [
                "append",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--no-sort-by-date",
                "--create-mailbox",
                "a",
                "b",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.mailbox == .inbox)
        #expect(sut.appendOptions == [.skipErrors, .createMailbox([])])
        #expect(sut.input == ["a", "b"])
    }

    @Test
    static func parseAppendCommand_4() throws {
        let sut = try parse(
            AppendCommand.self,
            [
                "append",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--no-skip-unreadable",
                "a",
                "b",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.mailbox == .inbox)
        #expect(sut.appendOptions == [.sort])
        #expect(sut.input == ["a", "b"])
    }

    @Test
    static func parseAppendCommand_5() throws {
        let sut = try parse(
            AppendCommand.self,
            [
                "append",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--mailbox", "A",
                "a",
                "b",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.mailbox == MailboxName(ByteBuffer(string: "A")))
        #expect(sut.appendOptions == [.skipErrors, .sort])
        #expect(sut.input == ["a", "b"])
    }

    @Test
    static func parseListMailboxes_1() throws {
        let sut = try parse(
            MailboxCommand.List.self,
            [
                "mailboxes",
                "list",
                "--username", "foo:bar",
                "--server", "bar.example.com",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.server == "bar.example.com")
    }

    @Test
    static func parseListMailboxes_2() throws {
        let sut = try parse(
            MailboxCommand.List.self,
            [
                "mailbox",
                "list",
                "--username", "foo:bar",
                "--server", "bar.example.com",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.server == "bar.example.com")
    }

    @Test
    static func parseCreateMailboxes_1() throws {
        let sut = try parse(
            MailboxCommand.Create.self,
            [
                "mailbox",
                "create",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--name", "foo",
                "--name", "bar",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.names == ["foo", "bar"])
        #expect(sut.paths == [])
    }

    @Test
    static func parseCreateMailboxes_2() throws {
        let sut = try parse(
            MailboxCommand.Create.self,
            [
                "mailbox",
                "create",
                "--username", "foo:bar",
                "--server", "bar.example.com",
                "--name", "a",
                "--name-json", #"path: ["foo"]"#,
                "--name-json", #"{path: ["bar"]}"#,
                "--name-json", #"{path: ["foo", "baz"], specialUse: "trash"}"#,
                "--name-json", #"name: "qux""#,
                "--name", "b",
            ]
        )
        #expect(sut.connectionInfo.username == "foo:bar")
        #expect(sut.connectionInfo.server == "bar.example.com")
        #expect(sut.names == ["a", "b"])
        #expect(
            sut.paths == [
                .init(namePath: ["foo"]),
                .init(namePath: ["bar"]),
                .init(namePath: ["foo", "baz"], specialUse: .trash),
                .init(namePath: ["qux"]),
            ]
        )
        #expect(
            sut.mailboxDisplayNamesWithSpecialUse == [
                .init(namePath: ["a"], parameters: []),
                .init(namePath: ["b"], parameters: []),
                .init(namePath: ["foo"], parameters: []),
                .init(namePath: ["bar"], parameters: []),
                .init(namePath: ["foo", "baz"], parameters: [.attributes([.trash])]),
                .init(namePath: ["qux"], parameters: []),
            ]
        )
    }

    @Test
    static func seedParsing() {
        #expect(
            SeededRandomNumberGenerator.Seed(argument: "hex:3501_404A_0218_5150_F23C_78DA_2C09_7E04")
                == SeededRandomNumberGenerator.Seed(a: 0x3501_404A_0218_5150, b: 0xF23C_78DA_2C09_7E04)
        )
    }

    @Test
    static func parseAppendCommand_withFlags() throws {
        let sut = try parse(
            AppendCommand.self,
            [
                "append",
                "--username", "test:pass",
                "--server", "imap.example.com",
                "--flag", "seen",
                "--flag", "flagged",
                "message.eml",
            ]
        )
        #expect(sut.flags == [.seen, .flagged])
        #expect(sut.input == ["message.eml"])
    }

    @Test
    static func parseAppendCommand_withFlags_2() throws {
        let sut = try parse(
            AppendCommand.self,
            [
                "append",
                "--username", "test:pass",
                "--server", "imap.example.com",
                "--flag", "answered",
                "message.eml",
            ]
        )
        #expect(sut.flags == [.answered])
    }
}
