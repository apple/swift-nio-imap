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

/// A percent-encoded mailbox name for use in IMAP URLs.
///
/// IMAP URLs include mailbox names as part of the URL path. When a mailbox name contains
/// characters that are not allowed in URLs (such as spaces, special characters, or non-ASCII
/// characters), the name must be percent-encoded using UTF-8 followed by hexadecimal encoding
/// (RFC 2192, RFC 3986).
///
/// This type wraps a percent-encoded mailbox name for use in URL construction. The encoded
/// string contains only ASCII-safe characters and can be safely included in IMAP URL syntax.
///
/// ### Example
///
/// A mailbox named "Draft Messages" would be percent-encoded as "Draft%20Messages".
/// In an IMAP URL:
/// ```
/// imap://user@example.com/Draft%20Messages/;uid=20
/// ```
///
/// Wrapped as:
/// ```
/// NetworkMessagePath(
///   server: IMAPServer(...),
///   messagePath: MessagePath(
///     mailboxReference: MailboxUIDValidity(
///       encodedMailbox: EncodedMailbox(mailbox: "Draft%20Messages"),
///       ...
///     ),
///     ...
///   )
/// )
/// ```
///
/// ## Related Types
///
/// See ``MailboxUIDValidity`` for mailbox references with UID validity values, and
/// ``MessagePath`` for the complete message location specification in URLs.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) - URI Generic Syntax (percent-encoding)
public struct EncodedMailbox: Hashable, Sendable {
    /// The percent-encoded mailbox name string.
    ///
    /// Contains only URL-safe ASCII characters. Non-ASCII and special characters are
    /// percent-encoded according to RFC 3986 using UTF-8.
    public var mailbox: String

    /// Creates a new percent-encoded mailbox name.
    /// - parameter mailbox: The percent-encoded mailbox name string.
    public init(mailbox: String) {
        self.mailbox = mailbox
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedMailbox(_ type: EncodedMailbox) -> Int {
        self.writeString(type.mailbox)
    }
}
