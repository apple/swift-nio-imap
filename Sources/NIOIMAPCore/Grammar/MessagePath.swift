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

/// A complete message location reference for use in IMAP URLs.
///
/// The message path specifies the mailbox, unique identifier (UID), and optionally the message section
/// and byte range for a specific piece of message content on an IMAP server. This is the core building
/// block for IMAP URL paths (RFC 2192/5092) and URLAUTH-authorized URLs (RFC 4467).
///
/// A message path is used in:
/// - **IMAP URLs**: `imap://server/mailbox/;uid=N[;section=S][;partial=start.length]`
/// - **URLAUTH URLs**: `imap://server/mailbox/;uidvalidity=V/;uid=N;urlauth=...`
/// - **CATENATE operations**: Reference existing messages when composing new messages (RFC 4469)
///
/// ### Message Path Components
///
/// 1. **Mailbox Reference** (``MailboxUIDValidity``): Identifies the mailbox with optional UID validity
/// 2. **Message UID** (``IUID``): The message unique identifier
/// 3. **Section** (``URLMessageSection``, optional): Specific part of the message structure
/// 4. **Byte Range** (``MessagePath/ByteRange``, optional): Specific bytes within the section
///
/// ### Examples
///
/// Simple message reference:
/// ```
/// imap://user@example.com/INBOX/;uid=20
/// ```
///
/// Message with specific MIME section:
/// ```
/// imap://user@example.com/INBOX/;uid=20;section=1.2.MIME
/// ```
///
/// Message with byte range (fetch bytes 0-1023 of section 2):
/// ```
/// imap://user@example.com/INBOX/;uid=20;section=2;partial=0.1024
/// ```
///
/// In a URLAUTH context with UID validity:
/// ```
/// C: a001 GENURLAUTH "imap://user@example.com/INBOX/;uidvalidity=4294967295/;uid=20;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uidvalidity=4294967295/;uid=20;urlauth=anonymous:internal:..."
/// ```
///
/// ## Related Types
///
/// - ``MailboxUIDValidity`` provides the mailbox reference
/// - ``IUID`` wraps the message unique identifier
/// - ``URLMessageSection`` specifies message sections
/// - ``NetworkMessagePath`` combines a server with a message path
/// - ``URLCommand`` uses message paths for `fetch` operations
/// - ``URLFetchType`` provides variations on message path construction
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 4467](https://datatracker.ietf.org/doc/html/rfc4467) - IMAP URLAUTH Extension
/// - SeeAlso: [RFC 4469](https://datatracker.ietf.org/doc/html/rfc4469) - IMAP CATENATE Extension
public struct MessagePath: Hashable, Sendable {
    /// Mailbox reference with optional UID validity value.
    ///
    /// Identifies which mailbox contains the message and optionally verifies that the UID is still valid.
    public var mailboxReference: MailboxUIDValidity

    /// The unique identifier of the message within the mailbox.
    public var iUID: IUID

    /// Optional section of the message (e.g., "1", "2.MIME", "TEXT").
    ///
    /// When `nil`, refers to the entire message. When specified, refers to a specific
    /// part or substructure of the message.
    public var section: URLMessageSection?

    /// Optional byte range within the message or section.
    ///
    /// When specified, retrieves only a portion of the message content (bytes `start` through
    /// `start + length - 1`). Useful for partial transfers of large messages.
    public var range: MessagePath.ByteRange?

    /// Creates a new message path specification.
    /// - parameter mailboxReference: Mailbox reference with optional UID validity.
    /// - parameter iUID: The message unique identifier.
    /// - parameter section: Optional message section. Defaults to `nil`.
    /// - parameter range: Optional byte range. Defaults to `nil`.
    public init(
        mailboxReference: MailboxUIDValidity,
        iUID: IUID,
        section: URLMessageSection? = nil,
        range: MessagePath.ByteRange? = nil
    ) {
        self.mailboxReference = mailboxReference
        self.iUID = iUID
        self.section = section
        self.range = range
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessagePath(_ data: MessagePath) -> Int {
        self.writeEncodedMailboxUIDValidity(data.mailboxReference) + self.writeIUID(data.iUID)
            + self.writeIfExists(data.section) { section in
                self.writeURLMessageSection(section)
            }
            + self.writeIfExists(data.range) { partial in
                self.writeMessagePathByteRange(partial)
            }
    }
}
