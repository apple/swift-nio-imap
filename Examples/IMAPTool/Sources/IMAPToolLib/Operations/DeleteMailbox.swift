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

/// Deletes a mailbox from the server.
func deleteMailbox<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    mailbox: MailboxName
) async throws {
    let text = try await connection.send(.delete(mailbox)) { tag, responses in
        writeStatus("Did send DELETE mailbox '\(mailbox)' with tag \(tag)")
        return try await responses.waitForCompletion()
    }.getOK()
    writeStatus("Did DELETE mailbox '\(mailbox)': \(text)")
}
