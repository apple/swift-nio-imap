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

/// IMAPv4 `status-att`
public enum MailboxAttribute: String, CaseIterable {
    case messageCount = "MESSAGES"
    case recentCount = "RECENT"
    case uidNext = "UIDNEXT"
    case uidValidity = "UIDVALIDITY"
    case unseenCount = "UNSEEN"
    case size = "SIZE"
    case highestModificationSequence = "HIGHESTMODSEQ"
}

public struct MailboxStatus: Equatable {
    
    /// `MESSAGES`
    /// The number of messages in the mailbox.
    public var messageCount: Int?
    /// `RECENT`
    /// The number of messages with the \Recent flag set.
    public var recentCount: Int?
    /// `UIDNEXT`
    /// The next unique identifier value of the mailbox.
    public var nextUID: Int?
    /// `UIDVALIDITY`
    /// The unique identifier validity value of the mailbox.
    public var uidValidity: Int?
    /// `UNSEEN`
    /// The number of messages which do not have the `\Seen` flag set.
    public var unseenCount: Int?
    
    public var size: Int?
    
    public var deletedCount: Int?
    
    public var modSequence: ModifierSequenceValue?
    
    /// Creates a new `MailboxStatus`. All parameters default to `nil`.
    /// - parameter messageCount: The number of messages in the mailbox.
    /// - parameter recentCount: The number of messages with the \Recent flag set.
    /// - parameter nextUID: The next unique identifier value of the mailbox.
    /// - parameter uidValidity: The unique identifier validity value of the mailbox.
    /// - parameter unseenCount: The number of messages which do not have the `\Seen` flag set.
    /// - parameter size: The number of messages which do not have the `\Seen` flag set.
    /// - parameter deletedCount: The number of messages with the `\Deleted` flag set.
    /// - parameter modSequence:
    public init(
        messageCount: Int? = nil,
        recentCount: Int? = nil,
        nextUID: Int? = nil,
        uidValidity: Int? = nil,
        unseenCount: Int? = nil,
        size: Int? = nil,
        deletedCount: Int? = nil,
        modSequence: ModifierSequenceValue? = nil
    ) {
        self.messageCount = messageCount
        self.recentCount = recentCount
        self.nextUID = nextUID
        self.uidValidity = uidValidity
        self.unseenCount = unseenCount
        self.size = size
        self.deletedCount = deletedCount
        self.modSequence = modSequence
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
        self.writeString("STATUS ") +
            self.writeArray(option) { (att, self) in
                self.writeMailboxAttribute(att)
            }
    }

    @discardableResult mutating func writeMailboxStatus(_ status: MailboxStatus) -> Int {

        var array: [(String, String)] = []
        
        func append<A>(_ keypath: WritableKeyPath<MailboxStatus, A?>, _ string: String) {
            guard let value = status[keyPath: keypath] else { return }
            array.append((string, "\(value)"))
        }
        
        append(\.messageCount, "MESSAGES")
        append(\.recentCount, "RECENT")
        append(\.nextUID, "UIDNEXT")
        append(\.uidValidity, "UIDVALIDITY")
        append(\.unseenCount, "UNSEEN")
        append(\.size, "SIZE")
        append(\.deletedCount, "DELETED")
        append(\.modSequence, "HIGHESTMODSEQ")
        
        return self.writeArray(array, parenthesis: false) { (element, self) -> Int in
            self.writeString("\(element.0) \(element.1)")
        }
    }
}
