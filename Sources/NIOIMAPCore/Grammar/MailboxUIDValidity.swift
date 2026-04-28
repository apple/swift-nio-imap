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

/// A mailbox reference with optional UID validity value for use in IMAP URLs.
///
/// In IMAP URLs, a mailbox is identified by its percent-encoded name and an optional UID validity value.
/// The UID validity (``UIDValidity``) is a server-assigned value that helps detect when messages in a
/// mailbox have been invalidated (for example, after a mailbox has been deleted and recreated).
/// Including the UID validity in a URL helps ensure the URL is not referencing stale or invalid message UIDs.
///
/// Combines a ``EncodedMailbox`` and optional ``UIDValidity`` to create a complete mailbox
/// reference for use in ``MessagePath`` structures. It forms the core of IMAP URL mailbox addressing.
///
/// ### Examples
///
/// Mailbox with UID validity value (preferred for long-term URLs):
/// ```
/// imap://user@example.com/INBOX/;uidvalidity=4294967295/;uid=20
/// ```
///
/// Mailbox without UID validity (URL remains valid even after recreating mailbox):
/// ```
/// imap://user@example.com/INBOX/;uid=20
/// ```
///
/// In a URLAUTH-authorized URL with UID validity for validation:
/// ```
/// C: a001 GENURLAUTH "imap://user@example.com/INBOX/;uidvalidity=4294967295/;uid=20;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uidvalidity=4294967295/;uid=20;urlauth=anonymous:internal:..."
/// ```
///
/// ## Related types
///
/// See ``MessagePath`` for the complete message location (mailbox reference, UID, optional section, optional byte range),
/// ``UIDValidity`` for UID validity value details, and ``NetworkMessagePath`` for the full network-accessible URL.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 3501 Section 2.3.1.1](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.1.1) - Unique Identifier (UID)
public struct MailboxUIDValidity: Hashable, Sendable {
    /// The percent-encoded mailbox name.
    ///
    /// Contains only URL-safe ASCII characters. Non-ASCII and special characters in the
    /// mailbox name are percent-encoded according to RFC 3986 using UTF-8.
    public var encodedMailbox: EncodedMailbox

    /// Optional UID validity value for staleness detection.
    ///
    /// When specified, the IMAP server can verify that UIDs in this mailbox have not been
    /// invalidated since the URL was created. If `nil`, no UID validity check is performed.
    /// UID validity changes when a mailbox is deleted and recreated, invalidating any UIDs
    /// that were valid under the previous UID validity value.
    public var uidValidity: UIDValidity?

    /// Creates a new mailbox reference with optional UID validity.
    /// - parameter encodeMailbox: The percent-encoded mailbox name.
    /// - parameter uidValidity: Optional UID validity value for staleness detection. Defaults to `nil`.
    public init(encodeMailbox: EncodedMailbox, uidValidity: UIDValidity? = nil) {
        self.encodedMailbox = encodeMailbox
        self.uidValidity = uidValidity
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedMailboxUIDValidity(_ ref: MailboxUIDValidity) -> Int {
        self.writeEncodedMailbox(ref.encodedMailbox)
            + self.writeIfExists(ref.uidValidity) { value in
                self.writeString(";UIDVALIDITY=") + self.writeUIDValidity(value)
            }
    }
}
