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

/// Filters to be used when selecting mailboxes to be notified about.
public enum MailboxFilter: Equatable {
    /// All selectable mailboxes in the user's personal
    /// namespace(s) to which messages may be delivered by a Message Delivery Agent (MDA)
    case inboxes

    /// All selectable mailboxes in the user's personal namespace(s)
    case personal

    /// All mailboxes subscribed to by the user.
    case subscribed

    /// All selectable mailboxes that are subordinate to
    /// the specified mailbox plus the specified mailbox itself.
    case subtree(Mailboxes)

    /// A list of mailbox names.
    case mailboxes(Mailboxes)

    /// Selected mailbox.
    case selected

    /// Selected mailbox when using MSNs and '*'
    /// Note:  Forbidden in an RFC 7377 context.
    case selectedDelayed

    /// Specified mailbox and all selectable child mailboxes, one
    /// hierarchy level down.
    case subtreeOne(Mailboxes)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxFilter(_ filter: MailboxFilter) -> Int {
        switch filter {
        case .inboxes:
            return self.writeString("inboxes")
        case .personal:
            return self.writeString("personal")
        case .subscribed:
            return self.writeString("subscribed")
        case .subtree(let mailboxes):
            return self.writeString("subtree ") + self.writeMailboxes(mailboxes)
        case .mailboxes(let mailboxes):
            return self.writeString("mailboxes ") + self.writeMailboxes(mailboxes)
        case .selected:
            return self.writeString("selected")
        case .selectedDelayed:
            return self.writeString("selected-delayed")
        case .subtreeOne(let mailboxes):
            return self.writeString("subtree-one ") + self.writeMailboxes(mailboxes)
        }
    }
}
