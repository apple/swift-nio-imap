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
/// Wraps a percent-encoded mailbox name for use in URL construction. The encoded
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
///       encodedMailbox: "Draft%20Messages",
///       ...
///     ),
///     ...
///   )
/// )
/// ```
///
/// ## Related types
///
/// See ``MailboxUIDValidity`` for mailbox references with UID validity values, and
/// ``MessagePath`` for the complete message location specification in URLs.
///
/// ## Validity
///
/// The value is written to the wire verbatim, so anything that isn't an `enc-mailbox` is rejected:
///
/// - ``init(_:)`` returns `nil`. Use it for a value derived from input.
/// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one is a
///   bug to be caught on first run rather than handled.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) - URI Generic Syntax (percent-encoding)
public struct EncodedMailbox: Hashable, Sendable {
    let stringValue: String

    /// Creates a value from a percent-encoded string, if the string is a valid `enc-mailbox`.
    ///
    /// Hex digits in `pct-encoded` triplets are uppercased, for example `%c3` becomes `%C3`.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The percent-encoded string, for example `Draft%20Messages`.
    /// - returns: A new value, or `nil` if `stringValue` is not a valid `enc-mailbox`.
    public init?(_ stringValue: String) {
        guard let normalized = Self.normalized(stringValue) else { return nil }
        self.stringValue = normalized
    }

    init(unchecked stringValue: String) {
        assert(Self.normalized(stringValue) == stringValue)
        self.stringValue = stringValue
    }

    /// The given string with uppercased `pct-encoded` hex digits, if it is an `enc-mailbox`
    /// ([RFC 5092 Section 11](https://datatracker.ietf.org/doc/html/rfc5092#section-11)):
    /// ```
    /// enc-mailbox = 1*bchar
    /// ```
    /// See ``URLCharacterClass/bchar``.
    static func normalized(_ string: String) -> String? {
        string.normalizedURLComponent(.bchar)
    }
}

extension String {
    /// Creates a `String` from an ``EncodedMailbox``, still percent-encoded.
    ///
    /// - parameter other: The value to convert.
    public init(_ other: EncodedMailbox) {
        self = other.stringValue
    }
}

extension EncodedMailbox: ExpressibleByStringLiteral {
    /// Creates a value from a percent-encoded string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `enc-mailbox`; this traps if it isn't.
    public init(stringLiteral value: String) {
        guard let normalized = Self.normalized(value) else {
            preconditionFailure("Invalid encoded mailbox: \(String(reflecting: value))")
        }
        self.init(unchecked: normalized)
    }
}

extension EncodedMailbox {
    /// This value without its trailing `/`, which the URL grammar claims for what follows, e.g.
    /// `INBOX/` → `INBOX`; `nil` if there is no trailing `/` or nothing would remain.
    func removingTrailingSlash() -> Self? {
        guard self.stringValue.utf8.count > 1, self.stringValue.utf8.last == UInt8(ascii: "/") else { return nil }
        return Self(unchecked: String(self.stringValue.dropLast()))
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedMailbox(_ type: EncodedMailbox) -> Int {
        self.writeString(type.stringValue)
    }
}
