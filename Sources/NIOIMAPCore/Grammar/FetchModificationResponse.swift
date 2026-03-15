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

/// The modification sequence value of a message returned as part of a `FETCH` response (RFC 7162 `CONDSTORE` extension).
///
/// When a client uses the ``FetchAttribute/modificationSequenceValue(_:)`` fetch attribute or uses conditional
/// `FETCH` modifiers like ``FetchModifier/changedSince(_:)``, the server returns the current modification sequence
/// (mod-sequence) value of each message. This value indicates when the message's metadata was last changed.
///
/// **Requires server capability:** ``Capability/condStore``
///
/// The mod-sequence value is used for client-server synchronization. Clients can track which messages have changed
/// since a known point in time by comparing mod-sequence values, allowing efficient resynchronization of mailbox state
/// without re-downloading unchanged messages.
///
/// ### Example
///
/// ```
/// C: A001 FETCH 1 (FLAGS MODSEQ)
/// S: * 1 FETCH (FLAGS (\Seen) MODSEQ (12352))
/// S: A001 OK FETCH completed
/// ```
///
/// The `MODSEQ (12352)` portion in the response represents a ``FetchModificationResponse`` with
/// `modificationSequenceValue: 12352`. The mod-sequence is the unique identifier for this version
/// of the message's metadata.
///
/// - SeeAlso: [RFC 7162 Section 3.1.4](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.4)
/// - SeeAlso: ``FetchAttribute/modificationSequenceValue(_:)``
/// - SeeAlso: ``SearchModificationSequence``
public struct FetchModificationResponse: Hashable, Sendable {
    /// The modification sequence value indicating when this message's metadata was last changed.
    ///
    /// This value is assigned by the server and increments whenever any metadata property (flags, custom keywords, etc.)
    /// of the message is modified. Clients use this to track state changes across sessions.
    public var modificationSequenceValue: ModificationSequenceValue

    /// Creates a new `FetchModificationResponse`.
    /// - parameter modifierSequenceValue: The modification sequence value of the message
    public init(modifierSequenceValue: ModificationSequenceValue) {
        self.modificationSequenceValue = modifierSequenceValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFetchModificationResponse(_ resp: FetchModificationResponse) -> Int {
        self.writeString("MODSEQ (") + self.writeModificationSequenceValue(resp.modificationSequenceValue)
            + self.writeString(")")
    }
}
