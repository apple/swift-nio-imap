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
import System

struct DownloadCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download raw messages.",
        discussion: #"""
            This downloads the raw message data for messages in the specified mailbox on the server into a local directory.

            Previously downloaded messages already in the directory are skipped, allowing downloads to be resumed.

            Passing --delete-unknown deletes any local message files that no longer exist on the server.
            """#
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

    @ArgumentParser.Flag(
        name: .customLong("delete-unknown"),
        inversion: .prefixedNo,
        help: "Delete downloaded messages that do not exist on the server."
    )
    var deleteUnknown: Bool = false

    @Option(
        help: ArgumentHelp(
            #"The directory to download into."#,
            valueName: "directory"
        ),
        completion: .directory
    )
    var destination: FilePath

    @Option(help: "How to format the result.")
    var outputFormat: ResultFormat = .text

    func run() async throws {
        let query = try fetchQueryGroup.makeFetchQuery()

        try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) { id, connection -> Void in
            let info = try await select(
                connection: connection,
                createMailbox: .fail,
                mailbox: mailbox
            )
            _ = try await download(
                connection: connection,
                mailboxMessageCount: info.messageCount,
                capabilities: id.capabilities,
                uidValidity: info.uidValidity,
                query: query,
                into: destination,
                deleteUnknown: deleteUnknown
            )
        }

        // Write an empty result. Allows for future expansion.
        struct Result: Encodable {}
        writeResult(result: Result(), format: outputFormat)
    }
}
