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
import AsyncAlgorithms
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO
import NIOIMAP

/// Runs `LIST` and `STATUS` on all mailboxes for the account.
///
/// Uses `LIST-STATUS` (RFC 5819) if available, or falls back to separate `LIST` and `STATUS` commands
/// based on the capabilities of the server.
func listMailboxes<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability]
) async throws -> [MailboxInfoAndStatus] {
    try await list(
        connection: connection,
        capabilities: capabilities,
        target: .allMailboxes
    )
}

func listMailbox<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    mailbox: MailboxName
) async throws -> MailboxInfoAndStatus? {
    let allInfo = try await list(
        connection: connection,
        capabilities: capabilities,
        target: .specific(mailbox)
    )
    return allInfo.first(where: { $0.path.name == mailbox })
}

enum ListTarget: Hashable, Sendable {
    case allMailboxes
    case specific(MailboxName)
}

func list<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    target: ListTarget
) async throws -> [MailboxInfoAndStatus] {
    let strategy = ListStatusStrategy(
        capabilities: capabilities
    )

    switch strategy.kind {
    case .listThenStatus:
        let listInfo = try await list(
            connection: connection,
            target: target,
            listReturnOptions: strategy.listReturnOptions
        )
        let statusInfo = try await status(
            connection: connection,
            mailboxes: listInfo.keys.lazy.map { $0.name },
            statusAttributes: strategy.statusAttributes
        )
        return combineListAndStatus(
            listInfo: listInfo,
            statusInfo: statusInfo
        )
    case .listStatus:
        return try await listStatus(
            connection: connection,
            target: target,
            listReturnOptions: strategy.listReturnOptions,
            statusAttributes: strategy.statusAttributes
        )
    }
}

// MARK: Strategy

struct ListStatusStrategy: Hashable, Sendable {
    var listReturnOptions: [ReturnOption]
    var statusAttributes: [MailboxAttribute]
    var kind: Kind

    enum Kind: Hashable, Sendable {
        /// Run LIST followed by STATUS for each mailbox
        case listThenStatus
        /// Run LIST-STATUS
        case listStatus
    }
}

extension ListStatusStrategy {
    init(
        capabilities: [Capability]
    ) {
        self.init(
            listReturnOptions: [],
            statusAttributes: [
                .messageCount,
                .uidNext,
                .uidValidity,
                .unseenCount,
            ],
            kind: .listThenStatus
        )

        // RFC 5162
        if capabilities.contains(.condStore) {
            statusAttributes.append(.highestModificationSequence)
        }
        // RFC 6154
        if capabilities.contains(.specialUse) {
            listReturnOptions.append(.specialUse)
        }
        // RFC 7889
        // Disabled for now. Many servers fail on this.
        if false && capabilities.contains(where: { $0.name == "APPENDLIMIT" }) {
            statusAttributes.append(.appendLimit)
        }
        // RFC 8438 "STATUS=SIZE"
        if capabilities.contains(Capability("STATUS=SIZE")) {
            statusAttributes.append(.size)
        }
        // RFC 5819 “LIST-STATUS”
        kind = capabilities.contains(.listStatus) ? .listStatus : .listThenStatus
    }
}

// MARK: - List then Status

private func combineListAndStatus(
    listInfo: [MailboxPath: [MailboxInfo.Attribute]],
    statusInfo: [MailboxName: MailboxStatus]
) -> [MailboxInfoAndStatus] {
    return
        listInfo
        .reduce(into: []) { all, list in
            all.append(
                MailboxInfoAndStatus(
                    path: list.key,
                    attributes: Set(list.value),
                    status: statusInfo[list.key.name]
                )
            )
        }
        .sorted {
            stableCompare($0.path.name, $1.path.name)
        }
}

// MARK: -

/// The combined result of `LIST` and `STATUS` for a single mailbox.
struct MailboxInfoAndStatus: Hashable, Sendable {
    /// The mailbox path including its separator.
    var path: MailboxPath
    /// The mailbox attributes from `LIST`.
    var attributes: Set<MailboxInfo.Attribute>
    /// The mailbox status from `STATUS`, if available.
    var status: MailboxStatus?
}

extension MailboxInfoAndStatus {
    /// An encodable representation of mailbox information and status.
    struct EncodableInfo: Encodable, Sendable {
        /// The raw mailbox name as a string.
        var name: String?
        /// The path separator character.
        var pathSeparator: String?
        /// The display name split into path components.
        var displayName: [String]
        /// The mailbox attributes as strings.
        var attributes: [String]

        /// The total number of messages in the mailbox.
        var messageCount: Int?
        /// The predicted next UID value.
        var nextUID: UInt32?
        /// The UID validity value for the mailbox.
        var uidValidity: UInt32?
        /// The number of unseen messages.
        var unseenCount: Int?
        /// The highest modification sequence value.
        var highestModificationSequence: UInt64?
        /// The per-message append size limit, if the server reports one.
        var appendLimit: Int?
    }
}

extension MailboxInfoAndStatus.EncodableInfo {
    /// Creates an encodable representation from a `MailboxInfoAndStatus`.
    init(_ other: MailboxInfoAndStatus) {
        self.init(
            name: String(validating: other.path.name.bytes, as: UTF8.self),
            pathSeparator: other.path.pathSeparator.map { String($0) },
            displayName: other.path.displayStringComponents(omittingEmptySubsequences: false),
            attributes: other.attributes.map { String($0) }.sorted(),
            messageCount: other.status?.messageCount,
            nextUID: (other.status?.nextUID).map { UInt32($0) },
            uidValidity: (other.status?.uidValidity).map { UInt32($0) },
            unseenCount: other.status?.unseenCount,
            highestModificationSequence: (other.status?.highestModificationSequence).map { UInt64($0) },
            appendLimit: other.status?.appendLimit
        )
    }
}

// MARK: -

extension Command {
    fileprivate static func list(
        target: ListTarget,
        returnOptions: [ReturnOption]
    ) -> Command {
        switch target {
        case .allMailboxes: .listAllMailboxes(returnOptions: returnOptions)
        case .specific(let name): .listMailbox(mailbox: name, returnOptions: returnOptions)
        }
    }

    fileprivate static func listAllMailboxes(
        returnOptions: [ReturnOption]
    ) -> Command {
        Command.listIndependent(
            [],
            reference: MailboxName([]),
            .mailbox(ByteBuffer(string: "*")),
            returnOptions
        )
    }

    fileprivate static func listMailbox(
        mailbox: MailboxName,
        returnOptions: [ReturnOption]
    ) -> Command {
        Command.listIndependent(
            [],
            reference: MailboxName([]),
            .mailbox(ByteBuffer(bytes: mailbox.bytes)),
            returnOptions
        )
    }
}

private func list<C: ConnectionProtocol>(
    connection: C,
    target: ListTarget,
    listReturnOptions: [ReturnOption]
) async throws -> [MailboxPath: [MailboxInfo.Attribute]] {
    let command = Command.list(
        target: target,
        returnOptions: listReturnOptions
    )
    return try await connection.send(command, isolation: #isolation) { tag, responses in
        var all: [MailboxPath: [MailboxInfo.Attribute]] = [:]
        for try await response in responses {
            switch response {
            case .untagged(.mailboxData(.list(let info))):
                all[info.path] = info.attributes
            case .tagged(let r):
                try r.checkOK()
            default:
                break
            }
        }
        return all
    }
}

private func status<C: ConnectionProtocol>(
    connection: C,
    mailboxes: some Sequence<MailboxName>,
    statusAttributes: [MailboxAttribute]
) async throws -> [MailboxName: MailboxStatus] {
    // Loop over all mailboxes
    // Pipeline a few STATUS at the time:
    let concurrencyLimit = 5

    return try await withThrowingTaskGroup { group in
        var remaining = mailboxes.makeIterator()
        var submittedCount = 0

        func popNextMailbox() -> MailboxName? {
            guard
                submittedCount < concurrencyLimit,
                let result = remaining.next()
            else { return nil }
            submittedCount += 1
            return result
        }

        while let mailbox = popNextMailbox() {
            group.addTask {
                let s = try await status(
                    connection: connection,
                    mailbox: mailbox,
                    statusAttributes: statusAttributes
                )
                return (mailbox, s)
            }
        }

        var all: [MailboxName: MailboxStatus] = [:]
        for try await result in group {
            if let s = result.1 {
                all[result.0] = s
            }

            submittedCount -= 1
            // Every time we get a result back, check if there's more work we should submit and do so
            if let mailbox = popNextMailbox() {
                group.addTask {
                    let s = try await status(
                        connection: connection,
                        mailbox: mailbox,
                        statusAttributes: statusAttributes
                    )
                    return (mailbox, s)
                }
            }
        }
        return all
    }
}

private func status<C: ConnectionProtocol>(
    connection: C,
    mailbox: MailboxName,
    statusAttributes: [MailboxAttribute]
) async throws -> MailboxStatus? {
    try await connection.send(.status(mailbox, statusAttributes), isolation: #isolation) { tag, responses in
        var result: MailboxStatus?
        for try await response in responses {
            switch response {
            case .untagged(.mailboxData(.status(mailbox, let status))):
                result = status
            case .tagged(let r):
                try r.checkOK()
            default:
                break
            }
        }
        return result
    }
}

// MARK: - List-Status

/// Use RFC 5819 “LIST-STATUS” to get LIST and STATUS with a single command.
private func listStatus<C: ConnectionProtocol>(
    connection: C,
    target: ListTarget,
    listReturnOptions: [ReturnOption],
    statusAttributes: [MailboxAttribute]
) async throws -> [MailboxInfoAndStatus] {
    let command = Command.list(
        target: target,
        returnOptions: listReturnOptions + [.statusOption(statusAttributes)]
    )
    return try await connection.send(command, isolation: #isolation) { tag, responses in
        var list: [MailboxPath: [MailboxInfo.Attribute]] = [:]
        var status: [MailboxName: MailboxStatus] = [:]
        for try await response in responses {
            switch response {
            case .untagged(.mailboxData(.list(let info))):
                list[info.path] = info.attributes
            case .untagged(.mailboxData(.status(let mailbox, let s))):
                status[mailbox] = s
            case .tagged(let r):
                try r.checkOK()
            default:
                break
            }
        }
        return combineListAndStatus(
            listInfo: list,
            statusInfo: status
        )
    }
}
