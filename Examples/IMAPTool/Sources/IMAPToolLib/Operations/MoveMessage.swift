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

/// Moves messages from the currently selected mailbox to another mailbox.
///
/// The source mailbox must already be selected before calling this function.
/// Requiring a ``SelectInfo`` argument makes that prerequisite visible in the
/// type signature, even though the value itself is not read.
func moveMessages<C: ConnectionProtocol>(
    connection: C,
    selectInfo _: SelectInfo,
    capabilities: [Capability],
    uids _uids: UIDSet,
    to destinationMailbox: MailboxName
) async throws {
    guard
        let uids = MessageIdentifierSetNonEmpty(set: _uids)
    else { return }

    // Check if server supports MOVE command (RFC 6851)
    if capabilities.contains(.move) {
        try await moveMessagesUsingMoveCommand(
            connection: connection,
            uids: uids,
            to: destinationMailbox
        )
    } else {
        try await moveMessagesUsingCopyCommand(
            connection: connection,
            uids: uids,
            to: destinationMailbox
        )
    }
}

/// Moves messages using `UID MOVE`.
private func moveMessagesUsingMoveCommand<C: ConnectionProtocol>(
    connection: C,
    uids: MessageIdentifierSetNonEmpty<UID>,
    to destinationMailbox: MailboxName
) async throws {
    let text = try await connection.send(
        .uidMove(.set(uids), destinationMailbox),
        isolation: #isolation
    ) { tag, responses in
        writeStatus("Did send UID MOVE \(uids.set.count) message(s) to '\(destinationMailbox)' with tag \(tag)")
        return try await responses.waitForCompletion()
    }.getOK()

    writeStatus("Did UID MOVE message(s): \(text)")
}

/// Moves messages using `UID COPY` followed by `UID STORE` and `EXPUNGE`.
///
/// Used when the server does not advertise the `MOVE` capability (RFC 6851).
///
/// - Note: The final `EXPUNGE` is a plain, mailbox-wide expunge (RFC 3501): it
///   permanently removes *every* message flagged `\Deleted` in the selected
///   mailbox, not only the ones copied here. This is intentional. A mailbox is
///   commonly accessed from several devices at once, any of which may expunge at
///   any time, so relying on `\Deleted` messages lingering is unsafe — the modern
///   best practice is to expunge right after flagging.
private func moveMessagesUsingCopyCommand<C: ConnectionProtocol>(
    connection: C,
    uids: MessageIdentifierSetNonEmpty<UID>,
    to destinationMailbox: MailboxName
) async throws {
    // UID COPY
    let copyText = try await connection.send(
        .uidCopy(.set(uids), destinationMailbox),
        isolation: #isolation
    ) { tag, responses in
        writeStatus("Did send UID COPY \(uids.set.count) message(s) to '\(destinationMailbox)' with tag \(tag)")
        return try await responses.waitForCompletion()
    }.getOK()
    writeStatus("Did UID COPY message(s): \(copyText)")

    // UID STORE
    let storeText = try await connection.send(
        .uidStore(.set(uids), [], .flags(.add(silent: true, list: [.deleted]))),
        isolation: #isolation
    ) { tag, responses in
        writeStatus("Did send UID STORE \\Deleted with tag \(tag)")
        return try await responses.waitForCompletion()
    }.getOK()
    writeStatus("Did mark message(s) as deleted: \(storeText)")

    // EXPUNGE
    let expungeText = try await connection.send(.expunge, isolation: #isolation) { tag, responses in
        writeStatus("Did send EXPUNGE with tag \(tag)")
        return try await responses.waitForCompletion()
    }.getOK()
    writeStatus("Did EXPUNGE: \(expungeText)")

    writeStatus("Did move \(uids.set.count) message(s) using UID COPY")
}
