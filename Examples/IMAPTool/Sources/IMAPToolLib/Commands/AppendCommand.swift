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
#if canImport(System)
import System
#else
import SystemPackage
#endif

struct AppendCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "append",
        abstract: "Upload messages to the server."
    )

    @OptionGroup()
    var connectionInfo: ConnectionInfo

    @Option(help: "The mailbox to APPEND into.")
    var mailbox: MailboxName = .inbox

    @Option(help: "How to format the result.")
    var outputFormat: ResultFormat = .text

    @ArgumentParser.Flag(
        name: .customLong("skip-unreadable"),
        inversion: .prefixedNo,
        help: "Skip input files that can not be parsed as emails"
    )
    var skipUnreadable = true

    @ArgumentParser.Flag(
        name: .customLong("sort-by-date"),
        inversion: .prefixedNo,
        help: "Sort the input files by message date, upload oldest messages first"
    )
    var sortByDate = true

    @ArgumentParser.Flag(
        inversion: .prefixedNo,
        help: "Create the mailbox if it does not exist"
    )
    var createMailbox = false

    @Option(
        name: .customLong("flag"),
        help: .init(
            "IMAP flag to set on uploaded messages.",
            discussion: #"""
                Allows specifying flags to be set on an appended message.

                This can be repeated multiple times to set multiple flags.

                Valid values: \#(MessageFlag.allCases.map { $0.rawValue }.joined(separator: ", "))
                """#
        )
    )
    var flags: [MessageFlag] = []

    @Argument(
        help: .init(
            "Message file or directory with messages.",
            discussion: #"""
                Specify one or multiple messages to be uploaded.

                Each path can either be a path to an RFC 5288 email message or a path to directory containing RFC 5288 email messages.

                Note: the messages must have a valid 'date' header. 
                """#,
            valueName: "path"
        ),
        completion: .file(extensions: ["eml", "emlx", "message"])
    )
    var input: [String] = []

    func run() async throws {
        guard
            !input.isEmpty
        else {
            throw ValidationError("Need to specify at least one input (file).")
        }

        struct Result: Encodable {
            var id: Identity
            var messages: [Message]

            struct Message: Encodable {
                var filename: String
                var id: String
                var uid: UInt32?
            }
        }

        let result: Result = try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) {
            id,
            connection in
            let uids = try await append(
                connection: connection,
                messages: input.map { FilePath($0) },
                options: appendOptions,
                into: mailbox
            )
            return Result(
                id: id,
                messages: uids.map {
                    Result.Message(
                        filename: $0.filePath.lastComponent.map { String(decoding: $0) } ?? "",
                        id: String($0.messageID),
                        uid: $0.uid.map { UInt32($0) }
                    )
                }
            )
        }

        writeResult(result: result, format: outputFormat)
    }
}

extension AppendCommand {
    var appendOptions: Set<AppendOption> {
        return Set<AppendOption>(
            skipUnreadable: skipUnreadable,
            sortByDate: sortByDate,
            createMailbox: createMailbox,
            flags: imapFlags
        )
    }

    var imapFlags: [NIOIMAP.Flag] {
        flags
            .reduce(into: Set<NIOIMAP.Flag>()) {
                $0.formUnion($1.flagsToSet)
            }
            .sorted(by: { "\($0)" < "\($1)" })
    }
}

extension Set<AppendOption> {
    init(
        skipUnreadable: Bool,
        sortByDate: Bool,
        createMailbox: Bool,
        flags: [NIOIMAP.Flag] = []
    ) {
        self = []
        if skipUnreadable {
            self.insert(.skipErrors)
        }
        if sortByDate {
            self.insert(.sort)
        }
        if createMailbox {
            self.insert(.createMailbox([]))
        }
        if !flags.isEmpty {
            self.insert(.flags(flags))
        }
    }
}
