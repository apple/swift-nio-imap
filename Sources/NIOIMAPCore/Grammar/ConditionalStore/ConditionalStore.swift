//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

/// Helper type for the `CONDSTORE` parameter in RFC 7162 Conditional Store extension.
///
/// **Requires server capability:** ``Capability/condStore``
///
/// The `CONDSTORE` parameter is used with the `SELECT` and `EXAMINE` commands to enable conditional
/// store operations and modification sequence tracking on the selected mailbox. This allows clients to
/// perform conditional flag changes that only succeed if the message's modification sequence matches
/// the specified value. See [RFC 7162 Section 3.1](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1).
///
/// ### Example
///
/// ```
/// C: A001 SELECT INBOX (CONDSTORE)
/// S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
/// S: * OK [PERMANENTFLAGS (\Answered \Flagged \Deleted \Seen \Draft \*)]
/// S: * 42 EXISTS
/// S: * 0 RECENT
/// S: * OK [UIDVALIDITY 1234567890]
/// S: * OK [MODSEQ 12345]
/// S: A001 OK SELECT completed
/// ```
///
/// The parameter `CONDSTORE` in the command `SELECT INBOX (CONDSTORE)` indicates that modification
/// sequence tracking is enabled for this mailbox. The server responds with `* OK [MODSEQ 12345]`
/// indicating the current modification sequence value.
///
/// ## Related types
///
/// - See ``SearchModificationSequence`` for conditional search operations
/// - See ``StoreModifier`` for conditional store modifiers in STORE commands
/// - See ``SelectParameter`` for other SELECT command parameters
///
/// - SeeAlso: [RFC 7162 Section 3.1](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1)
enum ConditionalStore {
    static let param = "CONDSTORE"
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeConditionalStoreParameter() -> Int {
        self.writeString(ConditionalStore.param)
    }
}
