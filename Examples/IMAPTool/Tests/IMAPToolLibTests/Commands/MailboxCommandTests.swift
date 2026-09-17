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

private enum MailboxCommandTests {
    static func parseDelete(
        _ arguments: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> MailboxCommand.Delete {
        try ArgumentParsingTests.parse(
            MailboxCommand.Delete.self,
            arguments,
            sourceLocation: sourceLocation
        )
    }

    static func parseRename(
        _ arguments: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> MailboxCommand.Rename {
        try ArgumentParsingTests.parse(
            MailboxCommand.Rename.self,
            arguments,
            sourceLocation: sourceLocation
        )
    }

    // MARK: - Delete Command Argument Parsing Tests

    @Test
    static func parseDeleteCommand_singleMailbox() throws {
        let sut = try parseDelete([
            "mailbox",
            "delete",
            "--sasl", "plain:foo bar",
            "--server", "imap.example.com",
            "TestFolder",
        ])

        #expect(sut.connectionInfo.server == "imap.example.com")
        #expect(sut.connectionInfo.sasl == "plain:foo bar")
        #expect(sut.names == ["TestFolder"])
        #expect(sut.outputFormat == .text)
    }

    @Test
    static func parseDeleteCommand_multipleMailboxes() throws {
        let sut = try parseDelete([
            "mailbox",
            "delete",
            "--username", "user:pass",
            "--server", "mail.example.com",
            "OldFolder1",
            "OldFolder2",
            "TempFolder",
        ])

        #expect(sut.connectionInfo.server == "mail.example.com")
        #expect(sut.connectionInfo.username == "user:pass")
        #expect(
            sut.names == [
                "OldFolder1",
                "OldFolder2",
                "TempFolder",
            ]
        )
        #expect(sut.outputFormat == .text)
    }

    @Test
    static func parseDeleteCommand_withOutputFormat() throws {
        let sut = try parseDelete([
            "mailbox",
            "delete",
            "--sasl", "plain:foo bar",
            "--server", "imap.example.com",
            "TestFolder",
            "--output-format", "json",
        ])

        #expect(sut.connectionInfo.server == "imap.example.com")
        #expect(sut.names == ["TestFolder"])
        #expect(sut.outputFormat == .json)
    }

    @Test
    static func parseDeleteCommand_nestedMailboxNames() throws {
        let sut = try parseDelete([
            "mailbox",
            "delete",
            "--sasl", "plain:foo bar",
            "--server", "imap.example.com",
            "INBOX.Work.OldProject",
            "INBOX.Archives.2023",
        ])

        #expect(sut.connectionInfo.server == "imap.example.com")
        #expect(
            sut.names == [
                "INBOX.Work.OldProject",
                "INBOX.Archives.2023",
            ]
        )
    }

    @Test
    static func parseDeleteCommand_validation_noNames() throws {
        #expect(
            performing: {
                _ = try parseDelete([
                    "mailbox",
                    "delete",
                    "--sasl", "plain:foo bar",
                    "--server", "imap.example.com",
                ])
            },
            throws: {
                #expect(
                    RootCommand.fullMessage(for: $0).prefix(while: { !$0.isNewline })
                        == "Error: Must specify at least one mailbox"
                )
                return true
            }
        )
    }

    // MARK: - Rename Command Argument Parsing Tests

    @Test
    static func parseRenameCommand_basic() throws {
        let sut = try parseRename([
            "mailbox",
            "rename",
            "--sasl", "plain:foo bar",
            "--server", "imap.example.com",
            "--old-name", "OldFolder",
            "--new-name", "NewFolder",
        ])

        #expect(sut.connectionInfo.server == "imap.example.com")
        #expect(sut.connectionInfo.sasl == "plain:foo bar")
        #expect(sut.oldName == "OldFolder")
        #expect(sut.newName == "NewFolder")
        #expect(sut.outputFormat == .text)
    }

    @Test
    static func parseRenameCommand_withOutputFormat() throws {
        let sut = try parseRename([
            "mailbox",
            "rename",
            "--username", "user:pass",
            "--server", "mail.example.com",
            "--old-name", "OldName",
            "--new-name", "NewName",
            "--output-format", "json",
        ])

        #expect(sut.connectionInfo.server == "mail.example.com")
        #expect(sut.connectionInfo.username == "user:pass")
        #expect(sut.oldName == "OldName")
        #expect(sut.newName == "NewName")
        #expect(sut.outputFormat == .json)
    }

    @Test
    static func parseRenameCommand_nestedMailboxNames() throws {
        let sut = try parseRename([
            "mailbox",
            "rename",
            "--sasl", "plain:foo bar",
            "--server", "imap.example.com",
            "--old-name", "INBOX.Work.Project1",
            "--new-name", "INBOX.Archives.CompletedProject1",
        ])

        #expect(sut.connectionInfo.server == "imap.example.com")
        #expect(sut.oldName == "INBOX.Work.Project1")
        #expect(sut.newName == "INBOX.Archives.CompletedProject1")
    }

    @Test
    static func parseRenameCommand_allConnectionOptions() throws {
        let sut = try parseRename([
            "mailbox",
            "rename",
            "--username", "testuser:testpass",
            "--server", "imap.example.com:143",
            "--old-name", "OldFolder",
            "--new-name", "NewFolder",
        ])

        #expect(sut.connectionInfo.username == "testuser:testpass")
        #expect(sut.connectionInfo.server == "imap.example.com:143")
        #expect(sut.oldName == "OldFolder")
        #expect(sut.newName == "NewFolder")
    }

    // MARK: - Command Alias Tests

    @Test
    static func parseDeleteCommand_usingMailboxAlias() throws {
        let sut = try parseDelete([
            "mailboxes",  // Using alias instead of "mailbox"
            "delete",
            "--sasl", "plain:foo bar",
            "--server", "imap.example.com",
            "TestFolder",
        ])

        #expect(sut.connectionInfo.server == "imap.example.com")
        #expect(sut.names == ["TestFolder"])
    }

    @Test
    static func parseRenameCommand_usingMaildirAlias() throws {
        let sut = try parseRename([
            "maildir",  // Using alias instead of "mailbox"
            "rename",
            "--sasl", "plain:foo bar",
            "--server", "imap.example.com",
            "--old-name", "OldFolder",
            "--new-name", "NewFolder",
        ])

        #expect(sut.connectionInfo.server == "imap.example.com")
        #expect(sut.oldName == "OldFolder")
        #expect(sut.newName == "NewFolder")
    }

    // MARK: - Validation Tests

    @Test
    static func parseDeleteCommand_duplicateNames() throws {
        #expect(
            performing: {
                _ = try parseDelete([
                    "mailbox",
                    "delete",
                    "--sasl", "plain:foo bar",
                    "--server", "imap.example.com",
                    "TestFolder",
                    "TestFolder",
                    "OtherFolder",
                ])
            },
            throws: {
                #expect(
                    RootCommand.fullMessage(for: $0).prefix(while: { !$0.isNewline })
                        == "Error: Duplicate mailbox name 'TestFolder'"
                )
                return true
            }
        )
    }

    @Test
    static func parseRenameCommand_sameSourceAndTarget() throws {
        // This shouldn’t throw. Server might return an error
        // at run-time, though.
        _ = try parseRename([
            "mailbox",
            "rename",
            "--sasl", "plain:foo bar",
            "--server", "imap.example.com",
            "--old-name", "SameFolder",
            "--new-name", "SameFolder",
        ])
    }
}
