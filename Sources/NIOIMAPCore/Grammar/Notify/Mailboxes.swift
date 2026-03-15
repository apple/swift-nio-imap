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

/// A non-empty collection of mailbox names (RFC 5465 NOTIFY).
///
/// **Requires server capability:** ``Capability/notify``
///
/// This type represents a non-empty list of mailbox names used with mailbox filters in the NOTIFY
/// extension. Certain filters like ``MailboxFilter/subtree(_:)`` and ``MailboxFilter/mailboxes(_:)``
/// require one or more specific mailbox names. See [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2).
///
/// ### Example
///
/// ```
/// C: A001 NOTIFY SET (SUBTREE ("Archive" "Sent Mail"))
/// S: * OK NOTIFY registered for SUBTREE Archive and Sent Mail
/// S: A001 OK NOTIFY completed
/// ```
///
/// The mailbox names `"Archive"` and `"Sent Mail"` form a ``Mailboxes`` collection that specifies
/// which mailboxes and their subfolders should be monitored for notifications.
///
/// ## Related Types
///
/// - See ``MailboxFilter`` for different ways to select mailboxes
/// - See ``MailboxName`` for individual mailbox name representation
///
/// - SeeAlso: [RFC 5465 Section 3.2](https://datatracker.ietf.org/doc/html/rfc5465#section-3.2)
public struct Mailboxes: Hashable, Sendable {
    /// Array of one or more mailbox names.
    ///
    /// This collection must contain at least one mailbox. The mailboxes are represented as
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
