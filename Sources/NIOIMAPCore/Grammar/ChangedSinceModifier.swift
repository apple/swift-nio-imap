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

/// A reference modification sequence value used to filter `FETCH` results (RFC 7162 `CONDSTORE` extension).
///
/// The `CHANGEDSINCE` modifier tells the server to return only messages that have been modified since
/// a known modification sequence value. This allows clients to efficiently synchronize mailbox state by
/// requesting only messages that have changed since the last synchronization point.
///
/// **Requires server capability:** ``Capability/condStore``
///
/// ### Example
///
/// ```
/// C: A001 FETCH 1:* (FLAGS INTERNALDATE) (CHANGEDSINCE 12345)
/// S: * 2 FETCH (FLAGS (\Seen) INTERNALDATE "17-Jul-1996 09:01:33 -0700" MODSEQ (12346))
/// S: * 5 FETCH (FLAGS (\Draft) INTERNALDATE "18-Jul-1996 14:22:10 -0700" MODSEQ (12350))
/// S: A001 OK FETCH completed
/// ```
///
/// The `CHANGEDSINCE 12345` modifier is wrapped as a ``ChangedSinceModifier`` with
/// `modificationSequence: 12345`. Only messages with mod-sequence values greater than 12345
/// are returned.
///
/// - SeeAlso: [RFC 7162 Section 3.1.4](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.4)
/// - SeeAlso: ``FetchModifier/changedSince(_:)``
/// - SeeAlso: ``UnchangedSinceModifier``
public struct ChangedSinceModifier: Hashable, Sendable {
    /// The reference modification sequence value.
    ///
    /// The server returns only messages with modification sequence values greater than this value.
    public var modificationSequence: ModificationSequenceValue

    /// Creates a new `ChangedSinceModifier`.
    /// - parameter modificationSequence: The reference modification sequence value
    public init(modificationSequence: ModificationSequenceValue) {
        self.modificationSequence = modificationSequence
    }
}

/// A reference modification sequence value used to filter STORE operations (RFC 7162 `CONDSTORE` extension).
///
/// The `UNCHANGEDSINCE` modifier tells the server to perform a conditional store operation. The server only
/// applies the requested flag changes if the message's current modification sequence is equal to or less than
/// the specified value. If the message has changed (higher mod-sequence), the operation is rejected, preventing
/// lost updates in multimailbox environments.
///
/// Implements optimistic concurrency control, allowing multiple clients to safely modify messages without
/// overwriting each other's changes.
///
/// **Requires server capability:** ``Capability/condStore``
///
/// ### Example
///
/// ```
/// C: A001 STORE 1 (UNCHANGEDSINCE 12345) +FLAGS (\Seen)
/// S: * 1 FETCH (FLAGS (\Seen) MODSEQ (12346))
/// S: A001 OK STORE completed
/// ```
///
/// The `UNCHANGEDSINCE 12345` modifier is wrapped as an ``UnchangedSinceModifier`` with
/// `modificationSequence: 12345`. The server only applies the `+FLAGS (\Seen)` operation
/// if the message's mod-sequence is 12345 or lower.
///
/// - SeeAlso: [RFC 7162 Section 3.1.3](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.3)
/// - SeeAlso: ``StoreModifier/unchangedSince(_:)``
/// - SeeAlso: ``ChangedSinceModifier``
public struct UnchangedSinceModifier: Hashable, Sendable {
    /// The reference modification sequence value.
    ///
    /// The server only performs the operation if the message's current mod-sequence is equal to or less than this value.
    public var modificationSequence: ModificationSequenceValue

    /// Creates a new `UnchangedSinceModifier`.
    /// - parameter modificationSequence: The reference modification sequence value
    public init(modificationSequence: ModificationSequenceValue) {
        self.modificationSequence = modificationSequence
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeChangedSinceModifier(_ val: ChangedSinceModifier) -> Int {
        self.writeString("CHANGEDSINCE ") + self.writeModificationSequenceValue(val.modificationSequence)
    }

    @discardableResult mutating func writeUnchangedSinceModifier(_ val: UnchangedSinceModifier) -> Int {
        self.writeString("UNCHANGEDSINCE ") + self.writeModificationSequenceValue(val.modificationSequence)
    }
}
