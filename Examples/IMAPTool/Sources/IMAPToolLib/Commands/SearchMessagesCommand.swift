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

struct SearchMessagesCommand: AsyncParsableCommand, Sendable {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search for messages",
        discussion: #"""
            This command searches for messages in a mailbox based on various criteria such as date ranges, flags, and subjects.
            """#,
        aliases: [
            "search-messages",
            "search-message",
        ]
    )

    @OptionGroup()
    var connectionInfo: ConnectionInfo

    @Option(help: "How to format the result.")
    var outputFormat: ResultFormat = .text

    @Option(
        name: .customLong("mailbox"),
        help: "The mailbox to search in"
    )
    var mailbox: MailboxName = .inbox

    @OptionGroup()
    var predicate: Predicate

    @ArgumentParser.Flag(
        name: .customLong("fetch-message-info"),
        help: "Fetch message info for the found UIDs"
    )
    var shouldFetchMessageInfo: Bool = false

    func run() async throws {
        // Get the search criteria:
        let searchKey = try SearchKey(predicate)
        writeStatus("Searching for messages with \(searchKey)")

        struct Result: Encodable {
            var imapQuery: String
            var uids: [UID]
            var messageInfo: [MessageInfo]?
        }

        let result: Result = try await IMAPConnection.withAuthenticatedConnection(
            info: connectionInfo
        ) { info, connection -> Result in
            let mailboxInfo = try await select(
                connection: connection,
                createMailbox: .fail,
                mailbox: mailbox
            )

            let uids = try await search(
                connection: connection,
                capabilities: info.capabilities,
                key: searchKey
            )

            let messageInfo: [MessageInfo]?
            if shouldFetchMessageInfo {
                messageInfo = try await fetchMessageInfo(
                    connection: connection,
                    mailboxMessageCount: mailboxInfo.messageCount,
                    capabilities: info.capabilities,
                    query: .uids(uids)
                )
            } else {
                messageInfo = nil
            }

            return Result(
                imapQuery: String(reflecting: searchKey),
                uids: uids.map { $0 },
                messageInfo: messageInfo
            )
        }

        writeResult(
            result: result,
            format: outputFormat
        )
    }
}
