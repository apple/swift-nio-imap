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

/// Marks the specified messages as deleted and expunges them.
func deleteMessages<C: ConnectionProtocol>(
    connection: C,
    uids: UIDSet
) async throws {
    guard !uids.isEmpty else { return }
    guard
        let command = Command.uidStore(
            messages: uids,
            modifiers: [],
            data: StoreData.flags(StoreFlags.add(silent: true, list: [.deleted]))
        )
    else { return }
    try await connection.send(command) { tag, responses in
        return try await responses.waitForCompletion()
    }.checkOK()
    writeStatus("Did mark \(uids.count) UIDs as \\Deleted")
    try await connection.send(.expunge) { tag, responses in
        return try await responses.waitForCompletion()
    }.checkOK()
    writeStatus("Did EXPUNGE")
}

/// Marks all messages in the selected mailbox as deleted and expunges them.
func deleteAllMessages<C: ConnectionProtocol>(
    connection: C
) async throws {
    guard
        let command = Command.uidStore(
            messages: .all,
            modifiers: [],
            data: StoreData.flags(StoreFlags.add(silent: true, list: [.deleted]))
        )
    else { return }
    try await connection.send(command) { tag, responses in
        return try await responses.waitForCompletion()
    }.checkOK()
    writeStatus("Did mark as \\Deleted")
    try await connection.send(.expunge) { tag, responses in
        return try await responses.waitForCompletion()
    }.checkOK()
    writeStatus("Did EXPUNGE")
}
