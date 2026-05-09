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

import IMAPCommands
import ArgumentParser
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIOIMAP

struct MessageInfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "message-info",
        abstract: "Get information about messages."
    )

    @OptionGroup()
    var connectionInfo: ConnectionInfo

    @Option(
        name: .customLong("mailbox"),
        help: """
            The mailbox to get messages from.
            """
    )
    var mailbox: MailboxName = .inbox

    @OptionGroup()
    var fetchQueryGroup: FetchQueryGroup

    @Option(help: "How to format the result.")
    var outputFormat: ResultFormat = .text

    func run() async throws {
        let query = try fetchQueryGroup.makeFetchQuery()

        let result: [MessageInfo] = try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) {
            id,
            connection in
            let info = try await select(
                connection: connection,
                createMailbox: .fail,
                mailbox: mailbox
            )
            return try await fetchMessageInfo(
                connection: connection,
                mailboxMessageCount: info.messageCount,
                capabilities: id.capabilities,
                query: query
            )
        }

        writeResult(result: result, format: outputFormat)
    }
}
