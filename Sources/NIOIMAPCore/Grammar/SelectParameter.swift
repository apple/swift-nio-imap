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

/// Parameters that modify the behavior of `SELECT` and `EXAMINE` commands.
///
/// The RFC 7162 `CONDSTORE` and `QRESYNC` extensions allow clients to pass parameters
/// to `SELECT` and `EXAMINE` commands to synchronize mailbox state efficiently. These
/// parameters let clients retrieve only messages that have changed since their last
/// synchronization, reducing bandwidth and latency.
///
/// ### Example
///
/// ```
/// C: A001 SELECT INBOX (QRESYNC (1 12345))
/// S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
/// S: * OK [UIDVALIDITY 3]
/// S: * OK [UIDNEXT 11]
/// S: * OK [MODSEQ 12346]
/// S: * 10 EXISTS
/// S: A001 OK [READ-WRITE] SELECT completed
/// ```
///
/// The `(QRESYNC (1 12345))` portion is represented as a `SelectParameter` with
/// `case qresync(...)`.
///
/// - SeeAlso: [RFC 7162 Section 3.2.5](https://datatracker.ietf.org/doc/html/rfc7162#section-3.2.5) (Quick Resynchronization)
/// - SeeAlso: [RFC 7162 Section 3.1.1](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.1) (CONDSTORE Extension)
/// - SeeAlso: ``Command/select(_:_:)``
public struct QResyncParameter: Hashable, Sendable {
    /// The last known UID validity.
    ///
    /// The client provides the last `UIDVALIDITY` value it saw for this mailbox.
    /// If the server's current `UIDVALIDITY` differs, the mailbox contents have changed
    /// fundamentally, and the client must resync completely.
    ///
    /// - SeeAlso: ``UIDValidity``
    public var uidValidity: UIDValidity

    /// The last known modification sequence value.
    ///
    /// The client provides the last `MODSEQ` value from its previous synchronization.
    /// The server will only return messages with modification sequences greater than
    /// this value (messages that have changed since the client's last sync).
    ///
    /// - SeeAlso: ``ModificationSequenceValue``
    public var modificationSequenceValue: ModificationSequenceValue

    /// Optional set of message UIDs known to the client.
    ///
    /// If provided, the server optimizes the response by not sending messages with
    /// UIDs in this set (since the client already has them). Useful for resuming
    /// interrupted synchronizations.
    ///
    /// - SeeAlso: ``UIDSet``
    public var knownUIDs: UIDSet?

    /// Optional sequence-to-UID mapping of client-known messages.
    ///
    /// Allows the client and server to quickly identify expunged messages and
    /// renumbering effects by comparing sequence numbers to UIDs.
    ///
    /// - SeeAlso: ``SequenceMatchData``
    public var sequenceMatchData: SequenceMatchData?

    /// Creates a new quick resynchronization parameter set.
    ///
    /// - parameter uidValidity: The last known UID validity
    /// - parameter modificationSequenceValue: The last known modification sequence
    /// - parameter knownUIDs: Optional set of UIDs the client already knows about
    /// - parameter sequenceMatchData: Optional sequence-to-UID mapping
    public init(
        uidValidity: UIDValidity,
        modificationSequenceValue: ModificationSequenceValue,
        knownUIDs: UIDSet?,
        sequenceMatchData: SequenceMatchData?
    ) {
        self.uidValidity = uidValidity
        self.modificationSequenceValue = modificationSequenceValue
        self.knownUIDs = knownUIDs
        self.sequenceMatchData = sequenceMatchData
    }
}

/// A parameter that modifies the behavior of `SELECT` and `EXAMINE` commands.
///
/// The `SelectParameter` enum provides three options for controlling how the server
/// returns information during mailbox selection, enabling efficient synchronization
/// through the `CONDSTORE` and `QRESYNC` extensions (RFC 7162).
///
/// **Requires server capability:** ``Capability/qresync`` or ``Capability/condStore``
/// (depending on which case is used).
///
/// - SeeAlso: [RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162) (CONDSTORE and QRESYNC)
/// - SeeAlso: ``Command/select(_:_:)``
public enum SelectParameter: Hashable, Sendable {
    /// A generic SELECT parameter (catch-all for extensions).
    ///
    /// Used for parameters not specifically handled by other cases. This allows
    /// future extensions to add new parameters without requiring code changes.
    ///
    /// - parameter KeyValue: A key-value pair representing the parameter
    case basic(KeyValue<String, ParameterValue?>)

    /// Perform a quick resynchronization of the mailbox (RFC 7162 `QRESYNC` extension).
    ///
    /// Enables efficient resynchronization by asking the server to return only messages
    /// that have changed since a known modification sequence value. The server can skip
    /// sending messages the client already has, reducing bandwidth for subsequent syncs.
    ///
    /// **Requires server capability:** ``Capability/qresync``
    ///
    /// - parameter QResyncParameter: The resynchronization parameters (UID validity, mod-seq, known UIDs)
    ///
    /// - SeeAlso: [RFC 7162 Section 3.2.5](https://datatracker.ietf.org/doc/html/rfc7162#section-3.2.5)
    case qresync(QResyncParameter)

    /// Request conditional store support in this mailbox (RFC 7162 `CONDSTORE` extension).
    ///
    /// Tells the server to track and return modification sequences (`MODSEQ`) for all
    /// messages in this mailbox. This enables conditional store operations using
    /// ``StoreModifier/unchangedSince(_:)`` and fetch filtering using
    /// ``FetchModifier/changedSince(_:)``.
    ///
    /// **Requires server capability:** ``Capability/condStore``
    ///
    /// - SeeAlso: [RFC 7162 Section 3.1.1](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.1)
    /// - SeeAlso: ``UnchangedSinceModifier``, ``ChangedSinceModifier``
    case condStore
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSelectParameters(_ params: [SelectParameter]) -> Int {
        if params.isEmpty {
            return 0
        }

        return
            self.writeSpace()
            + self.writeArray(params) { (param, self) -> Int in
                self.writeSelectParameter(param)
            }
    }

    @discardableResult mutating func writeSelectParameter(_ param: SelectParameter) -> Int {
        switch param {
        case .qresync(let param):
            return self.writeQResyncParameter(param: param)
        case .basic(let param):
            return self.writeParameter(param)
        case .condStore:
            return self.writeString("CONDSTORE")
        }
    }

    @discardableResult mutating func writeQResyncParameter(param: QResyncParameter) -> Int {
        self.writeString("QRESYNC (\(param.uidValidity.rawValue) ")
            + self.writeModificationSequenceValue(param.modificationSequenceValue)
            + self.writeIfExists(param.knownUIDs) { (set) -> Int in
                self.writeSpace() + self.writeUIDSet(set)
            }
            + self.writeIfExists(param.sequenceMatchData) { (data) -> Int in
                self.writeSpace() + self.writeSequenceMatchData(data)
            } + self.writeString(")")
    }
}
