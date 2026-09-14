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
import IMAPCommands
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO
import NIOIMAP
import SystemPackage

struct DeleteMessagesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete-messages",
        abstract: "Delete messages."
    )

    @OptionGroup()
    var connectionInfo: ConnectionInfo

    @Option(help: "How to format the result.")
    var outputFormat: ResultFormat = .text

    @Option(
        name: .customLong("mailbox"),
        help: """
            The mailbox to delete messages from.
            """
    )
    var mailboxName: MailboxName = .inbox

    @ArgumentParser.Flag(
        name: .customLong("all"),
        help: ArgumentHelp(
            "Delete all messages in the mailbox",
            discussion: #"""
                This will (permanently) delete all messages in the given mailbox.
                Since this can lead to permanent data loss, this will either (a)
                query the user to confirm this choice (if running in an interactive
                shell), or (b) check for the existence of a file named
                .imap-tool-allow-delete-all
                in the current user’s home directory.
                """#
        )
    )
    var deleteAllMessages = false

    @Option(
        help: #"""
            A file to read message info from. This should be JSON as output by the \
            'append' command. The JSON needs to be an array where each element has a \
            'uid' value or an 'id' value, the latter being the message-id header of \
            the messages to be deleted.
            """#,
        completion: .file(extensions: ["json"])
    )
    var messages: String?

    func run() async throws {
        switch action {
        case .deleteSpecific(filePath: let path):
            let ids = try UIDsAndMessageIDs.parse(filePath: path)
            guard !ids.isEmpty else {
                writeStatus("No UIDs / Message-IDs found.")
                return
            }
            try await deleteSpecificMessages(ids: ids)
        case .deleteAll:
            try await deleteAllMessages()
        case .fail(let text):
            exitWithErrorMessage(text)
        }
    }
}

extension DeleteMessagesCommand {
    enum Action: Equatable {
        case deleteAll
        case deleteSpecific(filePath: String)
        case fail(Output)
    }

    var action: Action {
        switch (deleteAllMessages, messages) {
        case (false, let messages?):
            return .deleteSpecific(filePath: messages)
        case (true, nil):
            return .deleteAll
        case (true, .some):
            return .fail("Can not specify both --all and a file to read message info from.")
        case (false, nil):
            return .fail("Need to specify a file to read message info from.")
        }
    }
}

// MARK: - Delete All Messages

extension DeleteMessagesCommand {
    func deleteAllMessages() async throws {
        struct Result: Encodable {
            var count: Int
        }

        let result: Result = try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) {
            id,
            connection in
            let info = try await select(
                connection: connection,
                createMailbox: .fail,
                mailbox: mailboxName
            )

            writeStatus("Mailbox has \(info.messageCount) messages.")

            guard
                0 < info.messageCount
            else { return Result(count: 0) }

            await checkDeleteAllSafeguards(
                mailbox: mailboxName,
                messageCount: info.messageCount
            )

            try await IMAPToolLib.deleteAllMessages(
                connection: connection
            )

            return Result(
                count: info.messageCount
            )
        }

        writeResult(
            result: result,
            format: outputFormat
        )

    }

    func checkDeleteAllSafeguards(
        mailbox: MailboxName,
        messageCount: Int
    ) async {
        if standardInputIsTTY {
            writeStatus(
                "You are about to delete \(messageCount) messages in mailbox '\(mailbox)'. Please type the exact message count to confirm.",
                terminator: ""
            )
            guard
                let input = readLine()
            else { exitWithErrorMessage("EOF") }
            guard
                input == "\(messageCount)"
            else { exitWithErrorMessage("'\(input)' != '\(messageCount)'") }
        } else {
            guard
                let home = ProcessInfo.processInfo.environment["HOME"]
            else { exitWithErrorMessage("HOME not set") }
            let path = FilePath(home).appending(".imap-tool-allow-delete-all")
            do {
                _ = try await Data(
                    asyncContentsOf: path,
                    length: 1
                )
            } catch {
                exitWithErrorMessage("Safeguard file '\(path)' does not exist.")
            }
        }
    }
}

// MARK: - Delete Specific Messages

extension DeleteMessagesCommand {
    func deleteSpecificMessages(
        ids: UIDsAndMessageIDs
    ) async throws {
        struct Result: Encodable {
            var uids: [UID]
        }

        let result: Result = try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) {
            id,
            connection in

            let info = try await select(
                connection: connection,
                createMailbox: .fail,
                mailbox: mailboxName
            )

            let allUIDs = try await findMessageIDs(
                connection: connection,
                selectInfo: info,
                capabilities: id.capabilities,
                ids: ids
            )

            try await deleteMessages(
                connection: connection,
                uids: allUIDs
            )

            return Result(
                uids: Array(allUIDs)
            )
        }

        writeResult(
            result: result,
            format: outputFormat
        )
    }
}
