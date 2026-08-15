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

/// Creates the mailbox and then runs `LIST` and `STATUS` on it.
func createAndList<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    mailbox: NewMailboxAction
) async throws -> MailboxInfoAndStatus {
    switch mailbox {
    case .alreadyExists(let name):
        return try await listAlreadyExisting(
            connection: connection,
            capabilities: capabilities,
            mailbox: name
        )
    case .create(let name, let parameters):
        return try await createAndList(
            connection: connection,
            capabilities: capabilities,
            mailbox: name,
            parameters: parameters
        )
    }
}

/// Creates the mailbox and then runs `LIST` and `STATUS` on it.
func createAndList<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    mailbox: MailboxName,
    parameters _parameters: [CreateParameter]
) async throws -> MailboxInfoAndStatus {
    let parameters: [CreateParameter]
    if capabilities.contains(.createSpecialUse) {
        parameters = _parameters
    } else {
        if !_parameters.isEmpty {
            writeStatus("Server does not support CREATE-SPECIAL-USE")
        }
        parameters = []
    }

    let createText = try await connection.send(.create(mailbox, parameters)) { tag, responses in
        writeStatus("Did send CREATE mailbox '\(mailbox)' with tag \(tag)")
        return try await responses.waitForCompletion()
    }.getOK()
    writeStatus("Did CREATE mailbox '\(mailbox)': \(createText)")

    guard
        let info = try await listMailbox(
            connection: connection,
            capabilities: capabilities,
            mailbox: mailbox
        )
    else { throw NoListResponseAfterCreate(mailbox: mailbox) }
    return info
}

struct NoListResponseAfterCreate: Swift.Error {
    var mailbox: MailboxName
}

private func listAlreadyExisting<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    mailbox: MailboxName,
) async throws -> MailboxInfoAndStatus {
    guard
        let info = try await listMailbox(
            connection: connection,
            capabilities: capabilities,
            mailbox: mailbox
        )
    else { throw NoListResponseForExistingMailbox(mailbox: mailbox) }
    return info
}

struct NoListResponseForExistingMailbox: Swift.Error {
    var mailbox: MailboxName
}
