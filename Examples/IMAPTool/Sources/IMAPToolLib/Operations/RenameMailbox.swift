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

/// Renames a mailbox on the server.
func renameMailbox<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    old oldName: MailboxName,
    new newName: MailboxName
) async throws {
    let text = try await connection.send(
        .rename(from: oldName, to: newName, parameters: [:])
    ) { tag, responses in
        writeStatus("Did send RENAME mailbox '\(oldName)' to '\(newName)' with tag \(tag)")
        return try await responses.waitForCompletion()
    }.getOK()
    writeStatus("Did RENAME mailbox '\(oldName)' to '\(newName)': \(text)")
}
