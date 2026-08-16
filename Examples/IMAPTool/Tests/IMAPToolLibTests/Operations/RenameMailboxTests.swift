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
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite("Rename Mailbox")
struct RenameMailboxTests {

    // MARK: - Happy Path Tests

    @Test
    static func renameMailbox_success() async throws {
        let connection = try TestConnection(
            expectedOrdering: .inOrder,
            expectedCommands: [
                .init(
                    command: .rename(from: "OldFolder", to: "NewFolder", parameters: [:]),
                    untagged: [],
                    completion: .ok(.init(text: "RENAME completed"))
                )
            ]
        )

        try await renameMailbox(
            connection: connection,
            capabilities: [.imap4rev1],
            old: "OldFolder",
            new: "NewFolder"
        )

        await #expect(connection.expectedCommands == [])
    }

    @Test
    static func renameMailbox_successWithCustomMessage() async throws {
        let connection = try TestConnection(
            expectedOrdering: .inOrder,
            expectedCommands: [
                .init(
                    command: .rename(from: "INBOX.Drafts", to: "INBOX.MyDrafts", parameters: [:]),
                    untagged: [],
                    completion: .ok(.init(text: "Mailbox renamed successfully"))
                )
            ]
        )

        try await renameMailbox(
            connection: connection,
            capabilities: [.imap4rev1],
            old: "INBOX.Drafts",
            new: "INBOX.MyDrafts"
        )

        await #expect(connection.expectedCommands == [])
    }

    @Test
    static func renameMailbox_nestedMailbox() async throws {
        let connection = try TestConnection(
            expectedOrdering: .inOrder,
            expectedCommands: [
                .init(
                    command: .rename(from: "INBOX.Work.2023", to: "INBOX.Archives.2023", parameters: [:]),
                    untagged: [],
                    completion: .ok(.init(text: "RENAME completed"))
                )
            ]
        )

        try await renameMailbox(
            connection: connection,
            capabilities: [.imap4rev1],
            old: "INBOX.Work.2023",
            new: "INBOX.Archives.2023"
        )

        await #expect(connection.expectedCommands == [])
    }

    @Test
    static func renameMailbox_moveToTopLevel() async throws {
        let connection = try TestConnection(
            expectedOrdering: .inOrder,
            expectedCommands: [
                .init(
                    command: .rename(from: "INBOX.Work.ImportantProject", to: "ImportantProject", parameters: [:]),
                    untagged: [],
                    completion: .ok(.init(text: "RENAME completed"))
                )
            ]
        )

        try await renameMailbox(
            connection: connection,
            capabilities: [.imap4rev1],
            old: "INBOX.Work.ImportantProject",
            new: "ImportantProject"
        )

        await #expect(connection.expectedCommands == [])
    }

    @Test
    static func renameMailbox_moveToNestedLevel() async throws {
        let connection = try TestConnection(
            expectedOrdering: .inOrder,
            expectedCommands: [
                .init(
                    command: .rename(from: "TempFolder", to: "INBOX.Archives.TempFolder", parameters: [:]),
                    untagged: [],
                    completion: .ok(.init(text: "RENAME completed"))
                )
            ]
        )

        try await renameMailbox(
            connection: connection,
            capabilities: [.imap4rev1],
            old: "TempFolder",
            new: "INBOX.Archives.TempFolder"
        )

        await #expect(connection.expectedCommands == [])
    }

    // MARK: - Error Handling Tests

    @Test
    static func renameMailbox_sourceNotFound() async throws {
        let connection = try TestConnection(
            expectedOrdering: .inOrder,
            expectedCommands: [
                .init(
                    command: .rename(from: "NonExistentFolder", to: "NewFolder", parameters: [:]),
                    untagged: [],
                    completion: .no(.init(text: "Source mailbox does not exist"))
                )
            ]
        )

        await #expect(throws: TaggedResponse.StateNotOK.self) {
            _ = try await renameMailbox(
                connection: connection,
                capabilities: [.imap4rev1],
                old: "NonExistentFolder",
                new: "NewFolder"
            )
        }

        await #expect(connection.expectedCommands == [])
    }

    @Test
    static func renameMailbox_badResponse() async throws {
        let connection = try TestConnection(
            expectedOrdering: .inOrder,
            expectedCommands: [
                .init(
                    command: .rename(from: "SourceFolder", to: "TargetFolder", parameters: [:]),
                    untagged: [],
                    completion: .bad(.init(text: "Invalid command syntax"))
                )
            ]
        )

        await #expect(throws: TaggedResponse.StateNotOK.self) {
            _ = try await renameMailbox(
                connection: connection,
                capabilities: [.imap4rev1],
                old: "SourceFolder",
                new: "TargetFolder"
            )
        }

        await #expect(connection.expectedCommands == [])
    }
}
