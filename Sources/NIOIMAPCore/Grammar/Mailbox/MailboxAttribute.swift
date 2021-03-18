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

/// Mailbox attributes that may be requested and returned as part of a *LIST* command.
public enum MailboxAttribute: String, CaseIterable {
    /// `MESSAGES`
    /// The number of messages in the mailbox.
    case messageCount = "MESSAGES"

    /// `RECENT`
    /// The number of messages with the \Recent flag set.
    case recentCount = "RECENT"

    /// `UIDNEXT`
    /// The next unique identifier value of the mailbox.
    case uidNext = "UIDNEXT"

    /// `UIDVALIDITY`
    /// The unique identifier validity value of the mailbox.
    case uidValidity = "UIDVALIDITY"

    /// `UNSEEN`
    /// The number of messages which do not have the `\Seen` flag set.
    case unseenCount = "UNSEEN"

    /// `SIZE`
    /// RFC 8438
    /// The total size of the mailbox in octets.
    case size = "SIZE"

    /// `HIGHESTMODSEQ`
    /// RFC 7162
    /// The highest mod-sequence value of all messages in the mailbox.
    case highestModificationSequence = "HIGHESTMODSEQ"
}

/// The (aggregated) information about a mailbox that the server reports as part of the response to e.g. a `SELECT` command.
public struct MailboxStatus: Equatable {
    /// `MESSAGES`
    /// The number of messages in the mailbox.
    public var messageCount: Int?
    /// `RECENT`
    /// The number of messages with the \Recent flag set.
    public var recentCount: Int?
    /// `UIDNEXT`
    /// The next unique identifier value of the mailbox.
    public var nextUID: UID?
    /// `UIDVALIDITY`
    /// The unique identifier validity value of the mailbox.
    public var uidValidity: UIDValidity?
    /// `UNSEEN`
    /// The number of messages which do not have the `\Seen` flag set.
    public var unseenCount: Int?

    /// `SIZE`
    /// RFC 8438
    /// The total size of the mailbox in octets.
    public var size: Int?

    /// `HIGHESTMODSEQ`
    /// RFC 7162
    /// The highest mod-sequence value of all messages in the mailbox.
    public var highestModificationSequence: ModificationSequenceValue?

    /// Creates a new `MailboxStatus`. All parameters default to `nil`.
    /// - parameter messageCount: RFC 3501: `MESSAGES` - The number of messages in the mailbox.
    /// - parameter recentCount: RFC 3501: `RECENT` - The number of messages with the \Recent flag set.
    /// - parameter nextUID: RFC 3501: `UIDNEXT` - The next unique identifier value of the mailbox.
    /// - parameter uidValidity: RFC 3501: `UIDVALIDITY` - The unique identifier validity value of the mailbox.
    /// - parameter unseenCount: RFC 3501: `UNSEEN` - The number of messages which do not have the `\Seen` flag set.
    /// - parameter size: RFC 8438: `SIZE` - The number of messages which do not have the `\Seen` flag set.
    /// - parameter highestModificationSequence: RFC 7162: `SIZE` - The total size of the mailbox in octets.
    public init(
        messageCount: Int? = nil,
        recentCount: Int? = nil,
        nextUID: UID? = nil,
        uidValidity: UIDValidity? = nil,
        unseenCount: Int? = nil,
        size: Int? = nil,
        highestModificationSequence: ModificationSequenceValue? = nil
    ) {
        self.messageCount = messageCount
        self.recentCount = recentCount
        self.nextUID = nextUID
        self.uidValidity = uidValidity
        self.unseenCount = unseenCount
        self.size = size
        self.highestModificationSequence = highestModificationSequence
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeMailboxAttributes(_ atts: [MailboxAttribute]) -> Int {
        self.writeArray(atts, parenthesis: false) { (element, self) in
            self.writeMailboxAttribute(element)
        }
    }

    @discardableResult mutating func writeMailboxAttribute(_ att: MailboxAttribute) -> Int {
        self._writeString(att.rawValue)
    }

    @discardableResult mutating func writeMailboxOptions(_ option: [MailboxAttribute]) -> Int {
        self._writeString("STATUS ") +
            self.writeArray(option) { (att, self) in
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

        return self.writeArray(array, parenthesis: false) { (element, self) -> Int in
            self._writeString("\(element.0) \(element.1)")
        }
    }
}
