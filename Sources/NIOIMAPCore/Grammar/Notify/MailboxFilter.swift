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

/// Filters to select mailboxes for the MULTIMAILBOX SEARCH extension (RFC 7377).
///
/// **Requires server capability:** ``Capability/multiSearch``
///
/// Mailbox filters are used with RFC 7377 MULTIMAILBOX SEARCH to specify which mailboxes the client wishes
/// to search across in a single command. The filter types are defined in RFC 5465 NOTIFY but are re-used by RFC 7377.
/// Filters can target individual mailboxes, groups of mailboxes, or special mailbox categories.
/// See [RFC 7377 Section 3](https://datatracker.ietf.org/doc/html/rfc7377#section-3).
///
/// ### Example
///
/// ```
/// C: A001 SEARCH IN (INBOXES PERSONAL) RETURN (MIN MAX) UNSEEN
/// S: * ESEARCH UID MIN 1 MAX 42
/// S: A001 OK SEARCH completed
/// ```
///
/// The filters `INBOXES` and `PERSONAL` in the example select specific mailboxes across which to search.
/// Different filters like ``personal``, ``subscribed``, or ``subtree(_:)`` allow flexible mailbox selection.
///
/// - SeeAlso: [RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377)
public enum MailboxFilter: Hashable, Sendable {
    /// All selectable mailboxes that may receive messages in the user's personal namespace(s).
    ///
    /// Corresponds to the `INBOXES` keyword. This filter matches all selectable mailboxes where
    /// the Message Delivery Agent (MDA) might deliver messages. From [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2).
    case inboxes

    /// All selectable mailboxes in the user's personal namespace(s).
    ///
    /// Corresponds to the `PERSONAL` keyword. This includes all personal mailboxes, not just those
    /// that may receive messages from delivery. From [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2).
    case personal

    /// All mailboxes subscribed to by the user.
    ///
    /// Corresponds to the `SUBSCRIBED` keyword. This matches any mailbox that the user has
    /// explicitly subscribed to. From [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2).
    case subscribed

    /// A mailbox and all of its selectable child mailboxes.
    ///
    /// Corresponds to the `SUBTREE` keyword. This recursively includes the specified mailbox
    /// and all selectable subfolders beneath it. From [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2).
    case subtree(Mailboxes)

    /// A list of specific mailbox names.
    ///
    /// Corresponds to a list of mailbox names. This filter matches exactly the specified mailboxes.
    /// From [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2).
    case mailboxes(Mailboxes)

    /// The currently selected mailbox.
    ///
    /// Corresponds to the `SELECTED` keyword. This filter matches the mailbox currently selected
    /// in the connection. From [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2).
    case selected

    /// The currently selected mailbox when using message sequence numbers (MSNs) and `*` wildcard.
    ///
    /// Corresponds to the `SELECTED-DELAYED` keyword. This variant is forbidden in the RFC 7377
    /// MULTIMAILBOX SEARCH context and is used only with traditional sequence-based operations.
    /// Note: Forbidden in an [RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377) context.
    /// From [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2).
    case selectedDelayed

    /// A mailbox and all selectable child mailboxes one level down in the hierarchy.
    ///
    /// Corresponds to the `SUBTREE-ONE` keyword. This includes the specified mailbox and only
    /// its immediate selectable children, not deeper descendants. From [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2).
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
