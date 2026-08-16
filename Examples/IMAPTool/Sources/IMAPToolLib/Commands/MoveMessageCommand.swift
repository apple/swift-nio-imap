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
import NIOIMAP

struct MoveMessageCommand: AsyncParsableCommand, Sendable {
    static let configuration = CommandConfiguration(
        commandName: "move-message",
        abstract: "Move messages between mailboxes",
        discussion: #"""
            This command moves messages from one mailbox to another.

            If the server supports the MOVE extension (RFC 6851), it will use the UID MOVE command. Otherwise, it will fall back to UID COPY and then delete the source.
            """#
    )

    @OptionGroup()
    var connectionInfo: ConnectionInfo

    @Option(help: "How to format the result.")
    var outputFormat: ResultFormat = .text

    @Option(
        name: [.customLong("source"), .customLong("from")],
        help: "Source mailbox containing the message(s)"
    )
    var sourceMailbox: MailboxName

    @Option(
        name: [.customLong("destination"), .customLong("to")],
        help: "Destination mailbox for the message(s)"
    )
    var destinationMailbox: MailboxName

    @Option(
        name: .customLong("uid"),
        help: "UID of message to move (can be specified multiple times)"
    )
    var uids: [UID] = []

    @Option(
        name: .customLong("message-id"),
        help: "Message-ID of message to move (can be specified multiple times)"
    )
    var messageIDs: [MessageID] = []

    @Option(
        help: #"""
            A file to read message info from. This should be JSON as output by the \
            'append' command. The JSON needs to be an array where each element has a \
            'uid' value or an 'id' value, the latter being the message-id header of \
            the messages to be moved.
            """#,
        completion: .file(extensions: ["json"])
    )
    var messages: String?

    func validate() throws {
        guard
            !uids.isEmpty || !messageIDs.isEmpty || (messages != nil)
        else {
            throw ValidationError(
                "Must specify at least one UID (--uid), Message-ID (--message-id), or a file to read from (--messages)."
            )
        }
    }

    func run() async throws {
        let ids = try UIDsAndMessageIDs(
            filePath: messages,
            uids: uids,
            messageIDs: messageIDs
        )
        guard !ids.isEmpty else {
            writeStatus("No messages to move.")
            return
        }

        struct Result: Encodable {
            var uids: [UID]
        }

        let result = try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) { info, connection in
            // Select the source mailbox
            let selectInfo = try await select(
                connection: connection,
                createMailbox: .fail,
                mailbox: sourceMailbox
            )

            let allUIDs = try await findMessageIDs(
                connection: connection,
                selectInfo: selectInfo,
                capabilities: info.capabilities,
                ids: ids
            )

            guard !allUIDs.isEmpty else {
                writeStatus("No messages found to move.")
                return Result(uids: [])
            }

            try await moveMessages(
                connection: connection,
                selectInfo: selectInfo,
                capabilities: info.capabilities,
                uids: allUIDs,
                to: destinationMailbox
            )

            return Result(uids: Array(allUIDs))
        }

        writeResult(result: result, format: outputFormat)
    }
}
