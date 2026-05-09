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
import IMAPCommands
@testable import IMAPToolLib
import NIOIMAP

@Suite
enum DeleteMailboxTests {

    // MARK: - Happy Path Tests

    @Test
    static func deleteMailbox_success() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .delete("TestMailbox"),
                responses: [],
                completion: .ok(.init(text: "DELETE completed"))
            )
        ])

        try await deleteMailbox(
            connection: connection,
            capabilities: [.imap4rev1],
            mailbox: "TestMailbox"
        )

        await #expect(connection.expectedCommands == [])
    }

    @Test
    static func deleteMailbox_nestedMailbox() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .delete("Projects/Work/Archive"),
                responses: [],
                completion: .ok(.init(text: "DELETE completed"))
            )
        ])

        try await deleteMailbox(
            connection: connection,
            capabilities: [.imap4rev1],
            mailbox: "Projects/Work/Archive"
        )

        await #expect(connection.expectedCommands == [])
    }

    // MARK: - Error Handling Tests

    @Test
    static func deleteMailbox_notFound() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .delete("NonExistentMailbox"),
                responses: [],
                completion: .no(.init(text: "Mailbox does not exist"))
            )
        ])

        await #expect(throws: TaggedResponse.StateNotOK.self) {
            _ = try await deleteMailbox(
                connection: connection,
                capabilities: [.imap4rev1],
                mailbox: "NonExistentMailbox"
            )
        }

        await #expect(connection.expectedCommands == [])
    }

    @Test
    static func deleteMailbox_specialCharacters() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .delete("Special & Characters (Test)"),
                responses: [],
                completion: .ok(.init(text: "DELETE completed"))
            )
        ])

        try await deleteMailbox(
            connection: connection,
            capabilities: [.imap4rev1],
            mailbox: "Special & Characters (Test)"
        )

        await #expect(connection.expectedCommands == [])
    }
}
