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

/// A non-empty collection of mailbox names for use with RFC 7377 MULTIMAILBOX SEARCH.
///
/// **Requires server capability:** ``Capability/multiSearch``
///
/// Represents a non-empty list of mailbox names used with mailbox filters in RFC 7377 MULTIMAILBOX SEARCH.
/// The filter types are defined in RFC 5465 NOTIFY but are re-used by RFC 7377. Certain filters like
/// ``MailboxFilter/subtree(_:)`` and ``MailboxFilter/mailboxes(_:)`` require one or more specific mailbox names.
/// See [RFC 7377 Section 3](https://datatracker.ietf.org/doc/html/rfc7377#section-3).
///
/// ### Example
///
/// ```
/// C: A001 SEARCH IN (SUBTREE "Archive" SUBTREE "Sent Mail") RETURN (MIN MAX) UNSEEN
/// S: * ESEARCH UID MIN 1 MAX 42
/// S: A001 OK SEARCH completed
/// ```
///
/// The mailbox names `"Archive"` and `"Sent Mail"` form a ``Mailboxes`` collection that specifies
/// which mailboxes (via ``MailboxFilter``) are included in a multi-mailbox search operation.
///
/// ## Related types
///
/// - See ``MailboxFilter`` for different ways to select mailboxes
/// - See ``MailboxName`` for individual mailbox name representation
///
/// - SeeAlso: [RFC 7377 Section 3](https://datatracker.ietf.org/doc/html/rfc7377#section-3)
public struct Mailboxes: Hashable, Sendable {
    /// Array of one or more mailbox names.
    ///
    /// Must contain at least one mailbox. The mailboxes are represented as
    /// ``MailboxName`` values, which can include standard or UTF-7-modified mailbox names.
    public let content: [MailboxName]

    /// Creates a new `Mailboxes` collection from one or more mailbox names.
    ///
    /// - parameter mailboxes: One or more mailbox names to include in the collection.
    /// - returns: A new `Mailboxes` if at least one mailbox is provided, otherwise `nil`.
    public init?(_ mailboxes: [MailboxName]) {
        guard mailboxes.count >= 1 else {
            return nil
        }
        self.content = mailboxes
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxes(_ mailboxes: Mailboxes) -> Int {
        self.writeArray(mailboxes.content) { (mailbox, buffer) -> Int in
            buffer.writeMailbox(mailbox)
        }
    }
}
