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

/// Mapping of message sequence numbers to UIDs for synchronization.
///
/// A `SequenceMatchData` combines message sequence numbers and corresponding UIDs
/// in ascending order, used during mailbox synchronization with the `QRESYNC`
/// extension (RFC 7162). This allows the server and client to efficiently identify
/// expunged messages and determine message renumbering effects.
///
/// The parallel sets allow the client to construct a complete view of the mailbox:
/// - If the client knows sequence numbers 1-5 correspond to UIDs [100, 101, 102, 103, 104],
///   and the next synchronization shows sequence 1-4 with UIDs [100, 101, 102, 104],
///   the client can infer that message 103 was expunged.
///
/// ### Example
///
/// ```
/// C: A001 SELECT INBOX (QRESYNC (1 12345 1:5 100:104))
/// S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
/// S: * OK [UIDVALIDITY 3]
/// S: * OK [UIDNEXT 11]
/// S: * OK [MODSEQ 12346]
/// S: * 4 EXISTS
/// S: A001 OK [READ-WRITE] SELECT completed
/// ```
///
/// The `1:5 100:104` portion represents a `SequenceMatchData` with:
/// - `knownSequenceSet: [1, 2, 3, 4, 5]` (message numbers)
/// - `knownUidSet: [100, 101, 102, 103, 104]` (corresponding UIDs)
///
/// **Important:** Both sets must be provided in ascending order and of equal length,
/// though ascending order is not currently enforced at runtime.
///
/// - SeeAlso: [RFC 7162 Section 3.2.5.2](https://datatracker.ietf.org/doc/html/rfc7162#section-3.2.5.2) (Quick Resynchronization)
/// - SeeAlso: ``QResyncParameter``, ``SelectParameter/qresync(_:)``
public struct SequenceMatchData: Hashable, Sendable {
    /// Message sequence numbers known to the client (in ascending order).
    ///
    /// These are message numbers as they existed in the client's last view of the
    /// mailbox. Each value corresponds to the UID at the same position in ``knownUidSet``.
    ///
    /// The `*` wildcard is not allowed in this set.
    ///
    /// - SeeAlso: ``LastCommandSet``
    public var knownSequenceSet: LastCommandSet<UID>

    /// Message UIDs corresponding to ``knownSequenceSet`` (in ascending order).
    ///
    /// These are the UIDs of messages that had the sequence numbers in ``knownSequenceSet``
    /// during the client's last synchronization. Comparing these to the current mailbox
    /// state allows the client to identify expunged and renumbered messages.
    ///
    /// The `*` wildcard is not allowed in this set.
    ///
    /// - SeeAlso: ``LastCommandSet``
    public var knownUidSet: LastCommandSet<UID>

    /// Creates a new sequence-to-UID mapping for resynchronization.
    ///
    /// **Note:** Both `knownSequenceSet` and `knownUidSet` should be provided in
    /// ascending order, though this is not currently enforced at runtime.
    ///
    /// - parameter knownSequenceSet: Message sequence numbers known to the client (ascending)
    /// - parameter knownUidSet: Corresponding UIDs (ascending)
    public init(knownSequenceSet: LastCommandSet<UID>, knownUidSet: LastCommandSet<UID>) {
        self.knownSequenceSet = knownSequenceSet
        self.knownUidSet = knownUidSet
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceMatchData(_ data: SequenceMatchData) -> Int {
        self.writeString("(") + self.writeLastCommandSet(data.knownSequenceSet) + self.writeSpace()
            + self.writeLastCommandSet(data.knownUidSet) + self.writeString(")")
    }
}
