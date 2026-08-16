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

struct MailboxCommand: AsyncParsableCommand, Sendable {
    static let configuration = CommandConfiguration(
        commandName: "mailbox",
        abstract: "Operations on mailboxes / maildirs",
        subcommands: [
            List.self,
            Create.self,
            Delete.self,
            Rename.self,
        ],
        defaultSubcommand: List.self,
        aliases: ["maildir", "mailboxes", "maildirs"]
    )
}

// MARK: List

extension MailboxCommand {
    struct List: AsyncParsableCommand, Sendable {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all mailboxes / maildirs"
        )

        @OptionGroup()
        var connectionInfo: ConnectionInfo

        @Option(help: "How to format the result.")
        var outputFormat: ResultFormat = .text

        func run() async throws {
            let result = try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) {
                info,
                connection in
                try await listMailboxes(
                    connection: connection,
                    capabilities: info.capabilities
                )
            }

            writeResult(
                result: result.map { MailboxInfoAndStatus.EncodableInfo($0) },
                format: outputFormat
            )
        }
    }
}

// MARK: Create

extension MailboxCommand {
    struct Create: AsyncParsableCommand, Sendable {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create mailbox(es)",
            discussion: #"""
                This creates one or multiple mailboxes.

                Note that servers that support CREATE-SPECIAL-USE will let the user specify the so-called “special-use” attributes on the mailbox upon creation.
                """#
        )

        @OptionGroup()
        var connectionInfo: ConnectionInfo

        @Option(help: "How to format the result.")
        var outputFormat: ResultFormat = .text

        @Option(
            name: .customLong("name")
        )
        var names: [String] = []

        @Option(
            name: .customLong("name-json"),
            help: .init(
                "Mailbox path as a JSON",
                discussion: #"""
                    Specify the mailbox with JSON. Using the 'path' key allows specifying a nested mailbox. Using the 'name' key, allow specifying a top-level mailbox. The 'specialUse' key can be used for CREATE-SPECIAL-USE. For example: `{path: ["foo", "bar"], specialUse: "trash"}`.
                    """#,
            )
        )
        var paths: [MailboxNameWithSpecialUse] = []

        func run() async throws {
            let result = try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) {
                info,
                connection in
                let list = try await listMailboxes(
                    connection: connection,
                    capabilities: info.capabilities
                )

                let existing = ExistingMailboxHierarchy(mailboxPaths: list.map { $0.path })
                let mailboxes = try existing.makeMailboxNamesForCreation(mailboxDisplayNamesWithSpecialUse)

                var result: [MailboxInfoAndStatus] = []
                for m in mailboxes {
                    result.append(
                        try await createAndList(
                            connection: connection,
                            capabilities: info.capabilities,
                            mailbox: m
                        )
                    )
                }
                return result
            }

            writeResult(
                result: result.map { MailboxInfoAndStatus.EncodableInfo($0) },
                format: outputFormat
            )
        }
    }
}

// MARK: -

extension MailboxCommand.Create {
    var mailboxDisplayNamesWithSpecialUse: [MailboxDisplayNameWithSpecialUse] {
        names.map {
            MailboxDisplayNameWithSpecialUse(namePath: [$0], parameters: [])
        }
            + paths.map {
                MailboxDisplayNameWithSpecialUse($0)
            }
    }
}

extension MailboxCommand.Create {
    struct MailboxNameWithSpecialUse: Hashable, Sendable {
        var namePath: [String]
        var specialUse: SpecialUse?

        enum SpecialUse: String, Hashable, Sendable {
            case archive
            case drafts
            case junk
            case sent
            case trash
        }
    }
}

extension MailboxDisplayNameWithSpecialUse {
    init(
        _ other: MailboxCommand.Create.MailboxNameWithSpecialUse
    ) {
        self.init(
            namePath: other.namePath,
            parameters: other.specialUse.map { [CreateParameter($0)] } ?? []
        )
    }
}

extension CreateParameter {
    init(
        _ other: MailboxCommand.Create.MailboxNameWithSpecialUse.SpecialUse
    ) {
        let attr: UseAttribute
        switch other {
        case .archive: attr = .archive
        case .drafts: attr = .drafts
        case .junk: attr = .junk
        case .sent: attr = .sent
        case .trash: attr = .trash
        }
        self = .attributes([attr])
    }
}

// MARK: -

extension MailboxCommand.Create.MailboxNameWithSpecialUse: ExpressibleByArgument {
    fileprivate struct Raw: Decodable {
        var name: String?
        var path: [String]?
        var specialUse: String?
    }

    init?(argument: String) {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        decoder.assumesTopLevelDictionary = true
        guard
            let raw = try? decoder.decode(Raw.self, from: Data(argument.utf8))
        else { return nil }
        // Path
        let namePath: [String]
        switch (raw.name, raw.path) {
        case (let name?, nil):
            namePath = [name]
        case (nil, let path?):
            namePath = path
        case (.some, .some), (nil, nil):
            return nil
        }
        // Special Use:
        let specialUse: SpecialUse?
        if let s = raw.specialUse {
            guard
                let ss = SpecialUse(rawValue: s)
            else { return nil }
            specialUse = ss
        } else {
            specialUse = nil
        }
        self.init(
            namePath: namePath,
            specialUse: specialUse
        )
    }
}

// MARK: Delete

extension MailboxCommand {
    struct Delete: AsyncParsableCommand, Sendable {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete mailbox(es)",
            discussion: #"""
                This deletes one or multiple mailboxes and all their contents.

                WARNING: This operation is irreversible and will permanently delete all messages in the specified mailboxes.
                """#
        )

        @OptionGroup()
        var connectionInfo: ConnectionInfo

        @Option(help: "How to format the result.")
        var outputFormat: ResultFormat = .text

        @Argument(
            help: .init(
                "Mailbox name to be deleted",
                valueName: "mailbox-name"
            )
        )
        var names: [MailboxName] = []

        func run() async throws {
            guard !names.isEmpty else {
                throw ValidationError("At least one mailbox name must be specified")
            }

            let result = try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) {
                info,
                connection in
                // Delete each mailbox:
                for mailboxName in names {
                    try await deleteMailbox(
                        connection: connection,
                        capabilities: info.capabilities,
                        mailbox: mailboxName
                    )
                }
                // List the mailboxes after the deletion:
                return try await listMailboxes(
                    connection: connection,
                    capabilities: info.capabilities
                )
            }

            writeResult(
                result: result.map { MailboxInfoAndStatus.EncodableInfo($0) },
                format: outputFormat
            )
        }

        mutating func validate() throws {
            guard
                !names.isEmpty
            else {
                throw ValidationError("Must specify at least one mailbox")
            }
            var previous = Set<MailboxName>()
            for name in names {
                defer { previous.insert(name) }
                guard
                    !previous.contains(name)
                else {
                    let n = (try? MailboxPath(name: name))?.displayStringComponents().first ?? ""
                    throw ValidationError("Duplicate mailbox name '\(n)'")
                }
            }
        }
    }
}

// MARK: Rename

extension MailboxCommand {
    struct Rename: AsyncParsableCommand, Sendable {
        static let configuration = CommandConfiguration(
            commandName: "rename",
            abstract: "Rename a mailbox",
            discussion: #"""
                This renames a mailbox on the server.
                """#
        )

        @OptionGroup()
        var connectionInfo: ConnectionInfo

        @Option(help: "How to format the result.")
        var outputFormat: ResultFormat = .text

        @Option(
            name: .long,
            help: "Current (old) name of the mailbox"
        )
        var oldName: MailboxName

        @Option(
            name: .long,
            help: "New name for the mailbox"
        )
        var newName: MailboxName

        func run() async throws {
            let result = try await IMAPConnection.withAuthenticatedConnection(info: connectionInfo) {
                info,
                connection in
                try await renameMailbox(
                    connection: connection,
                    capabilities: info.capabilities,
                    old: oldName,
                    new: newName
                )

                return try await listMailboxes(
                    connection: connection,
                    capabilities: info.capabilities
                )
            }

            writeResult(
                result: result.map { MailboxInfoAndStatus.EncodableInfo($0) },
                format: outputFormat
            )
        }
    }
}
