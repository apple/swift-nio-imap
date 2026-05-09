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
import System

struct MessageFlagCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "flag",
        abstract: "Set / unset IMAP flags on messages.",
        aliases: ["flags"]
    )

    @OptionGroup()
    var connectionInfo: ConnectionInfo

    @Option(help: "The mailbox containing the message(s).")
    var mailbox: MailboxName = .inbox

    @Option(help: "How to format the result.")
    var outputFormat: ResultFormat = .text

    @Option(
        name: [.customLong("flag"), .customLong("set")],
        help: .init(
            "IMAP flag to set on the message(s).",
            discussion: #"""
                Allows specifying flags to be set on messages.

                This can be repeated multiple times to set multiple flags.

                Valid values: \#(MessageFlag.allCases.map { $0.rawValue }.joined(separator: ", "))
                """#
        )
    )
    var setFlags: [MessageFlag] = []

    @Option(
        name: [.customLong("unset"), .customLong("remove")],
        help: .init(
            "IMAP flag to unset on the message(s).",
            discussion: #"""
                Allows specifying flags to be unset on messages.

                This can be repeated multiple times to unset multiple flags.

                Valid values: \#(MessageFlag.allCases.map { $0.rawValue }.joined(separator: ", "))
                """#
        )
    )
    var unsetFlags: [MessageFlag] = []

    @Option(
        name: .customLong("uid"),
        help: "UIDs of messages to modify (can be specified multiple times)"
    )
    var uids: [UID] = []
    @Option(
        name: .customLong("message-id"),
        help: "Message-ID of message to modify (can be specified multiple times)"
    )
    var messageIDs: [MessageID] = []

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

    func validate() throws {
        guard
            !uids.isEmpty || !messageIDs.isEmpty || (messages != nil)
        else {
            throw ValidationError(
                "Must specify at least one UID (--uid) or a file to read UIDs and/or message-id from (--messages)."
            )
        }
    }

    func run() async throws {
        let ids = try UIDsAndMessageIDs(
            filePath: messages,
            uids: uids,
            messageIDs: messageIDs
        )
        guard
            !ids.isEmpty
        else {
            writeStatus("No messages to update,")
            return
        }

        try await run(
            ids: ids,
            changes: imapFlags
        )
    }

    func run(
        ids: UIDsAndMessageIDs,
        changes: IMAPToolLib.FlagChanges
    ) async throws {
        try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) { id, connection in
            let info = try await select(
                connection: connection,
                createMailbox: .fail,
                mailbox: mailbox
            )

            let allUIDs = try await findMessageIDs(
                connection: connection,
                selectInfo: info,
                capabilities: id.capabilities,
                ids: ids
            )

            guard
                !allUIDs.isEmpty
            else { return }

            try await updateFlags(
                connection: connection,
                uids: allUIDs,
                changes: changes
            )
        }

        struct EmptyResult: Encodable {}

        writeResult(result: EmptyResult(), format: outputFormat)
    }
}

extension MessageFlagCommand {
    var imapFlags: IMAPToolLib.FlagChanges {
        IMAPToolLib.FlagChanges(
            setFlags: setFlags,
            unsetFlags: unsetFlags
        )
    }
}

extension IMAPToolLib.FlagChanges {
    init(
        setFlags: [MessageFlag],
        unsetFlags: [MessageFlag]
    ) {
        let a =
            setFlags
            .reduce(into: Set<NIOIMAP.Flag>()) {
                $0.formUnion($1.flagsToSet)
            }
        let b =
            unsetFlags
            .reduce(into: Set<NIOIMAP.Flag>()) {
                $0.formUnion($1.flagsToUnset)
            }
        self.init(set: [], unset: [])
        self.set = a.subtracting(b)
            .sorted(by: { "\($0)" < "\($1)" })
        self.unset = b.subtracting(a)
            .sorted(by: { "\($0)" < "\($1)" })
    }
}
