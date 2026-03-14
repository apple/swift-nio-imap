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

/// Status attributes that can be requested and returned by a `STATUS` command.
///
/// The `STATUS` command returns information about a mailbox without selecting it.
/// ``MailboxAttribute`` enumerates the standard attributes that can be queried via the
/// `STATUS` command as defined in [RFC 3501 Section 6.3.10](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.10).
/// Each attribute corresponds to a specific piece of mailbox metadata.
///
/// ### Example
///
/// ```
/// C: A001 STATUS "INBOX" (MESSAGES UNSEEN)
/// S: * STATUS "INBOX" (MESSAGES 42 UNSEEN 3)
/// S: A001 OK STATUS completed
/// ```
///
/// The line `* STATUS "INBOX" (MESSAGES 42 UNSEEN 3)` returns a ``Response/untagged(_:)`` containing
/// ``ResponsePayload/mailboxData(_:)`` with these status attributes and their values wrapped in ``MailboxStatus``.
///
/// - SeeAlso: ``MailboxStatus``
public enum MailboxAttribute: String, CaseIterable, Sendable {
    /// The `MESSAGES` attribute: the number of messages in the mailbox.
    ///
    /// This attribute returns the total count of messages in the mailbox.
    /// See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    case messageCount = "MESSAGES"

    /// The `RECENT` attribute: the number of messages with the `\Recent` flag.
    ///
    /// This attribute returns the count of messages that have been added to the mailbox since
    /// the last time it was selected. See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    case recentCount = "RECENT"

    /// The `UIDNEXT` attribute: the next unique identifier value.
    ///
    /// This attribute predicts the UID value that will be assigned to the next message appended
    /// to the mailbox. See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    case uidNext = "UIDNEXT"

    /// The `UIDVALIDITY` attribute: the mailbox's unique identifier validity value.
    ///
    /// This attribute is a permanent unique identifier for the mailbox. If returned as zero,
    /// it indicates the mailbox does not support unique identifiers. See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    case uidValidity = "UIDVALIDITY"

    /// The `UNSEEN` attribute: the number of messages without the `\Seen` flag.
    ///
    /// This attribute returns the count of messages in the mailbox that do not have the `\Seen` flag set.
    /// See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    case unseenCount = "UNSEEN"

    /// The `SIZE` attribute: the total size of the mailbox in octets.
    ///
    /// This attribute returns the total size of all messages in the mailbox in bytes (octets).
    /// **Requires server capability:** ``Capability/statusSize``
    /// See [RFC 8438](https://datatracker.ietf.org/doc/html/rfc8438).
    case size = "SIZE"

    /// The `HIGHESTMODSEQ` attribute: the highest modification sequence value.
    ///
    /// This attribute returns the highest mod-sequence value assigned to any message in the mailbox.
    /// The `CONDSTORE` extension uses modification sequences to track message changes.
    /// **Requires server capability:** ``Capability/condstore``
    /// See [RFC 7162 Section 3.1](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1).
    case highestModificationSequence = "HIGHESTMODSEQ"

    /// The `APPENDLIMIT` attribute: the maximum message upload size in octets.
    ///
    /// This attribute specifies the maximum size (in bytes) of a single message that can be appended to the mailbox.
    /// **Requires server capability:** ``Capability/appendLimit``
    /// See [RFC 7889 Section 4](https://datatracker.ietf.org/doc/html/rfc7889#section-4).
    case appendLimit = "APPENDLIMIT"

    /// The `MAILBOXID` attribute: the server's object identifier for the mailbox.
    ///
    /// This attribute returns a permanent, server-assigned identifier that uniquely identifies the mailbox.
    /// Unlike `UIDVALIDITY`, this identifier is globally unique and never reused.
    /// **Requires server capability:** ``Capability/objectID``
    /// See [RFC 8474 Section 3](https://datatracker.ietf.org/doc/html/rfc8474#section-3).
    case mailboxID = "MAILBOXID"
}

/// Information about a mailbox returned by a `STATUS` command.
///
/// ``MailboxStatus`` represents the response to a `STATUS` command as specified in
/// [RFC 3501 Section 6.3.10](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.10).
/// The `STATUS` command allows clients to request mailbox information without selecting the mailbox.
///
/// All properties are optional, as the server returns only the requested attributes.
/// Access the properties that correspond to the attributes requested in the `STATUS` command.
///
/// ### Example
///
/// ```
/// C: A001 STATUS "Archive" (MESSAGES UIDVALIDITY UNSEEN)
/// S: * STATUS "Archive" (MESSAGES 1500 UIDVALIDITY 384160001 UNSEEN 34)
/// S: A001 OK STATUS completed
/// ```
///
/// The response contains a ``MailboxStatus`` with messageCount=1500, uidValidity=384160001, unseenCount=34.
/// Other properties would be `nil` since they were not requested.
///
/// - SeeAlso: ``MailboxAttribute``
public struct MailboxStatus: Hashable, Sendable {
    /// The `MESSAGES` attribute: total number of messages in the mailbox.
    ///
    /// This property is `nil` if the `MESSAGES` attribute was not requested or returned.
    /// See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    public var messageCount: Int?

    /// The `RECENT` attribute: number of messages with the `\Recent` flag.
    ///
    /// This property is `nil` if the `RECENT` attribute was not requested or returned.
    /// See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    public var recentCount: Int?

    /// The `UIDNEXT` attribute: the next unique identifier value to be assigned.
    ///
    /// This property is `nil` if the `UIDNEXT` attribute was not requested or returned.
    /// See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    public var nextUID: UID?

    /// The `UIDVALIDITY` attribute: the mailbox's unique identifier validity value.
    ///
    /// This property is `nil` if the `UIDVALIDITY` attribute was not requested or returned.
    /// See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    public var uidValidity: UIDValidity?

    /// The `UNSEEN` attribute: number of messages without the `\Seen` flag.
    ///
    /// This property is `nil` if the `UNSEEN` attribute was not requested or returned.
    /// See [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2).
    public var unseenCount: Int?

    /// The `SIZE` attribute: total size of the mailbox in bytes (octets).
    ///
    /// This property is `nil` if the `SIZE` attribute was not requested or returned.
    /// **Requires server capability:** ``Capability/statusSize``
    /// See [RFC 8438](https://datatracker.ietf.org/doc/html/rfc8438).
    public var size: Int?

    /// The `HIGHESTMODSEQ` attribute: the highest modification sequence value assigned to any message.
    ///
    /// This property is `nil` if the `HIGHESTMODSEQ` attribute was not requested or returned.
    /// The `CONDSTORE` extension uses modification sequences to track which messages have changed.
    /// **Requires server capability:** ``Capability/condstore``
    /// See [RFC 7162 Section 3.1](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1).
    public var highestModificationSequence: ModificationSequenceValue?

    /// The `APPENDLIMIT` attribute: maximum size per message in bytes (octets).
    ///
    /// This property is `nil` if the `APPENDLIMIT` attribute was not requested or returned.
    /// The `APPENDLIMIT` extension specifies per-mailbox upload limits.
    /// **Requires server capability:** ``Capability/appendLimit``
    /// See [RFC 7889 Section 4](https://datatracker.ietf.org/doc/html/rfc7889#section-4).
    public var appendLimit: Int?

    /// The `MAILBOXID` attribute: the server's permanent object identifier for the mailbox.
    ///
    /// This property is `nil` if the `MAILBOXID` attribute was not requested or returned.
    /// The `OBJECTID` extension assigns stable, unique identifiers to mailboxes that persist
    /// even if the mailbox is renamed or moved.
    /// **Requires server capability:** ``Capability/objectID``
    /// See [RFC 8474 Section 3](https://datatracker.ietf.org/doc/html/rfc8474#section-3).
    public var mailboxID: MailboxID?

    /// Creates a new mailbox status record with optional attribute values.
    ///
    /// All parameters default to `nil`. Initialize only the attributes that were requested
    /// in the corresponding `STATUS` command.
    ///
    /// - Parameter messageCount: The `MESSAGES` count if requested
    /// - Parameter recentCount: The `RECENT` count if requested
    /// - Parameter nextUID: The `UIDNEXT` value if requested
    /// - Parameter uidValidity: The `UIDVALIDITY` value if requested
    /// - Parameter unseenCount: The `UNSEEN` count if requested
    /// - Parameter size: The `SIZE` value if requested
    /// - Parameter highestModificationSequence: The `HIGHESTMODSEQ` value if requested
    /// - Parameter appendLimit: The `APPENDLIMIT` value if requested
    /// - Parameter mailboxID: The `MAILBOXID` value if requested
    public init(
        messageCount: Int? = nil,
        recentCount: Int? = nil,
        nextUID: UID? = nil,
        uidValidity: UIDValidity? = nil,
        unseenCount: Int? = nil,
        size: Int? = nil,
        highestModificationSequence: ModificationSequenceValue? = nil,
        appendLimit: Int? = nil,
        mailboxID: MailboxID? = nil
    ) {
        self.messageCount = messageCount
        self.recentCount = recentCount
        self.nextUID = nextUID
        self.uidValidity = uidValidity
        self.unseenCount = unseenCount
        self.size = size
        self.highestModificationSequence = highestModificationSequence
        self.appendLimit = appendLimit
        self.mailboxID = mailboxID
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxAttributes(_ atts: [MailboxAttribute]) -> Int {
        self.writeArray(atts, parenthesis: false) { (element, self) in
            self.writeMailboxAttribute(element)
        }
    }

    @discardableResult mutating func writeMailboxAttribute(_ att: MailboxAttribute) -> Int {
        self.writeString(att.rawValue)
    }

    @discardableResult mutating func writeMailboxOptions(_ option: [MailboxAttribute]) -> Int {
        self.writeString("STATUS ")
            + self.writeArray(option) { (att, self) in
                self.writeMailboxAttribute(att)
            }
    }

    @discardableResult mutating func writeMailboxStatus(_ status: MailboxStatus) -> Int {
        var array: [(String, String)] = []

        func append<A>(_ keypath: KeyPath<MailboxStatus, A?>, _ string: String) {
            guard let value = status[keyPath: keypath] else { return }
            array.append((string, "\(value)"))
        }

        append(\.messageCount, "MESSAGES")
        append(\.recentCount, "RECENT")
        append(\.nextUID?.rawValue, "UIDNEXT")
        append(\.uidValidity?.rawValue, "UIDVALIDITY")
        append(\.unseenCount, "UNSEEN")
        append(\.size, "SIZE")
        append(\.highestModificationSequence, "HIGHESTMODSEQ")
        append(\.appendLimit, "APPENDLIMIT")
        append(\.mailboxID, "MAILBOXID")

        return self.writeArray(array, parenthesis: false) { (element, self) -> Int in
            self.writeString("\(element.0) \(element.1)")
        }
    }
}
