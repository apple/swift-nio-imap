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
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO
import NIOIMAP

/// The result of selecting a mailbox, containing its metadata.
struct SelectInfo: Hashable, Sendable {
    /// The name of the selected mailbox.
    var mailbox: MailboxName
    /// The text from the `OK` command completion.
    var responseText: ResponseText
    /// The flags defined for this mailbox.
    var flags: [Flag]
    /// The permanent flags that can be modified in this mailbox.
    var permanentFlags: [PermanentFlag]
    /// The total number of messages from the `EXISTS` response.
    var messageCount: Int
    /// The next UID the server assigns to a new message.
    var uidNext: UID
    /// The UID validity value for this mailbox.
    var uidValidity: UIDValidity

    /// Creates a `SelectInfo` with all required fields.
    init(
        mailbox: MailboxName,
        responseText: ResponseText,
        flags: [Flag],
        permanentFlags: [PermanentFlag],
        messageCount: Int,
        uidNext: UID,
        uidValidity: UIDValidity
    ) {
        self.mailbox = mailbox
        self.responseText = responseText
        self.flags = flags
        self.permanentFlags = permanentFlags
        self.messageCount = messageCount
        self.uidNext = uidNext
        self.uidValidity = uidValidity
    }
}

extension SelectInfo {
    init(
        temp: Temporary,
        response: TaggedResponse
    ) throws {
        let responseText = try response.getOK()
        guard
            let flags = temp.flags
        else { throw Error.missingSelectField("flags") }
        guard
            let permanentFlags = temp.permanentFlags
        else { throw Error.missingSelectField("permanent flags") }
        guard
            let messageCount = temp.messageCount
        else { throw Error.missingSelectField("message count") }
        guard
            let uidNext = temp.uidNext
        else { throw Error.missingSelectField("UIDNEXT") }
        guard
            let uidValidity = temp.uidValidity
        else { throw Error.missingSelectField("UIDVALIDITY") }
        self.init(
            mailbox: temp.mailbox,
            responseText: responseText,
            flags: flags,
            permanentFlags: permanentFlags,
            messageCount: messageCount,
            uidNext: uidNext,
            uidValidity: uidValidity
        )
    }

    /// The in-progress version that gets updated while `SELECT` runs.
    struct Temporary: Hashable, Sendable {
        var mailbox: MailboxName
        var flags: [Flag]?
        var permanentFlags: [PermanentFlag]?
        /// From `<n> EXISTS`
        var messageCount: Int?
        var uidNext: UID?
        var uidValidity: UIDValidity?
    }

    enum Error: Swift.Error {
        /// The `SELECT` response was missing a required untagged field. The associated
        /// value names the field (e.g. `"UIDNEXT"`).
        case missingSelectField(String)
    }
}

/// Selects the given mailbox on the connection.
func select<C: ConnectionProtocol>(
    connection: C,
    createMailbox: SelectCreateOption,
    mailbox: MailboxPath
) async throws -> SelectInfo {
    try await select(
        connection: connection,
        createMailbox: createMailbox,
        mailbox: mailbox.name
    )
}

/// Controls behavior when the mailbox does not exist during selection.
enum SelectCreateOption: Hashable, Sendable {
    /// Fails selection if the mailbox does not exist.
    case fail
    /// Creates the mailbox with the given parameters if it does not exist.
    case create([CreateParameter])
}

/// Selects the given mailbox, optionally creating it first.
func select<C: ConnectionProtocol>(
    connection: C,
    createMailbox: SelectCreateOption,
    mailbox: MailboxName
) async throws -> SelectInfo {
    let info = try await selectOrCreate(
        connection: connection,
        createMailbox: createMailbox,
        mailbox: mailbox
    )
    writeStatus(
        "Did select mailbox '\(mailbox)'. Message count: \(info.messageCount), UIDNEXT: \(info.uidNext), UIDVALIDITY: \(info.uidValidity)"
    )
    return info
}

private enum FirstResult {
    case success(SelectInfo)
    case create([CreateParameter])
}

private func selectOrCreate<C: ConnectionProtocol>(
    connection: C,
    createMailbox: SelectCreateOption,
    mailbox: MailboxName
) async throws -> SelectInfo {
    let parameters: [CreateParameter]
    switch try await trySelect(
        connection: connection,
        createMailbox: createMailbox,
        mailbox: mailbox
    ) {
    case .success(let info):
        return info
    case .create(let p):
        parameters = p
    }

    // Try to create:
    let createText = try await connection.send(.create(mailbox, parameters)) { tag, responses in
        writeStatus("Did send CREATE with tag \(tag)")
        return try await responses.waitForCompletion()
    }.getOK()
    writeStatus("Did CREATE: \(createText)")
    // Re-try SELECT:
    let (info, response) = try await sendSelect(
        connection: connection,
        mailbox: mailbox
    )
    return try SelectInfo(
        temp: info,
        response: response
    )
}

/// Attempts a `SELECT` and either returns the result, or — if the mailbox does not
/// exist and the caller opted in to creation — returns the parameters needed to create it.
private func trySelect<C: ConnectionProtocol>(
    connection: C,
    createMailbox: SelectCreateOption,
    mailbox: MailboxName
) async throws -> FirstResult {
    let (info, response) = try await sendSelect(
        connection: connection,
        mailbox: mailbox
    )
    // The only branch that diverts from the normal "construct SelectInfo" path is
    // a `NO` response when the caller opted in to creating the mailbox.
    // Every other state — `.ok`, `.bad`, or `.no` with `.fail` — goes through
    // `SelectInfo.init`, which surfaces success or throws the underlying error.
    if case .create(let parameters) = createMailbox,
        case .no(let text) = response.state
    {
        writeStatus("Unable to SELECT mailbox — will try to create (\(text))")
        return .create(parameters)
    }
    return try .success(
        SelectInfo(
            temp: info,
            response: response
        )
    )
}

private func sendSelect<C: ConnectionProtocol>(
    connection: C,
    mailbox: MailboxName
) async throws -> (SelectInfo.Temporary, TaggedResponse) {
    try await connection.send(.select(mailbox)) { _, responses in
        var info = SelectInfo.Temporary(mailbox: mailbox)
        let response = try await responses.forEach { response in
            switch response {
            case .untagged(let untagged):
                info.update(untagged)
            default:
                break
            }
        }
        return (info, response)
    }
}

extension SelectInfo.Temporary {
    mutating func update(_ untagged: ResponsePayload) {
        switch untagged {
        case .mailboxData(.flags(let f)):
            flags = f
        case .mailboxData(.exists(let count)):
            messageCount = count
        case .conditionalState(.ok(let text)):
            switch text.code {
            case .permanentFlags(let f):
                permanentFlags = f
            case .uidNext(let uid):
                uidNext = uid
            case .uidValidity(let v):
                uidValidity = v
            default:
                break
            }
        default:
            break
        }
    }
}
