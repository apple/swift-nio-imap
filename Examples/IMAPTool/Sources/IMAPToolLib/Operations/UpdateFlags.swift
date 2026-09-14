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
import NIOIMAP

/// Describes flags to add and remove from messages.
struct FlagChanges: Hashable, Sendable {
    /// The flags to add to the messages.
    var set: [NIOIMAP.Flag]
    /// The flags to remove from the messages.
    var unset: [NIOIMAP.Flag]

    /// Creates a new flag change set with the given flags to add and remove.
    init(
        set: [NIOIMAP.Flag],
        unset: [NIOIMAP.Flag]
    ) {
        self.set = set
        self.unset = unset
    }

    var isEmpty: Bool {
        self.set.isEmpty && self.unset.isEmpty
    }
}

/// Updates flags on the messages specified by UIDs.
func updateFlags<C: ConnectionProtocol>(
    connection: C,
    uids: UIDSet,
    changes: FlagChanges
) async throws {
    try await sendStore(
        connection: connection,
        uids: uids,
        flags: changes.set,
        operatorLabel: "+FLAGS",
        makeStoreFlags: { StoreFlags.add(silent: false, list: $0) }
    )
    try await sendStore(
        connection: connection,
        uids: uids,
        flags: changes.unset,
        operatorLabel: "-FLAGS",
        makeStoreFlags: { StoreFlags.remove(silent: false, list: $0) }
    )
}

private func sendStore<C: ConnectionProtocol>(
    connection: C,
    uids: UIDSet,
    flags: [NIOIMAP.Flag],
    operatorLabel: String,
    makeStoreFlags: ([NIOIMAP.Flag]) -> StoreFlags
) async throws {
    guard
        !flags.isEmpty,
        let command = Command.uidStore(
            messages: uids,
            modifiers: [],
            data: StoreData.flags(makeStoreFlags(flags))
        )
    else { return }
    try await connection.send(command) { tag, responses in
        writeStatus(
            "Did send UID STORE \(operatorLabel) \(flags.map { String($0) }.joined(separator: ", ")) with tag \(tag)"
        )
        return try await responses.waitForCompletion()
    }.checkOK()
    writeStatus("Did UID STORE \(operatorLabel) on \(uids.count) UID(s)")
}
