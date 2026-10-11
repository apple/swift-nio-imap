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

/// A percent-encoded user identifier for use in IMAP URLs and URLAUTH components.
///
/// User identifiers in IMAP URLs are percent-encoded to ensure they contain only URL-safe
/// characters. This encoding is applied when a user identifier contains non-ASCII characters,
/// spaces, or special characters that are not allowed in URL syntax (RFC 2192, RFC 3986).
///
/// Wraps a percent-encoded user identifier for use in server specifications
/// (via ``UserAuthenticationMechanism`` and ``IMAPServer``) and in URLAUTH access identifiers
/// (via ``Access`` with `user+` and `submit+` prefixes).
///
/// ### Examples
///
/// A user named "Frédéric" would be percent-encoded as "Fr%C3%A9d%C3%A9ric" (UTF-8 followed by hex encoding).
///
/// In a server specification:
/// ```
/// imap://Fr%C3%A9d%C3%A9ric@example.com/INBOX/;uid=20
/// ```
///
/// In a URLAUTH access identifier restricting to a specific user:
/// ```
/// imap://owner@example.com/INBOX/;uid=20;urlauth=user+Fr%C3%A9d%C3%A9ric:internal:...
/// ```
///
/// In a URLAUTH submission entity identifier:
/// ```
/// imap://owner@example.com/INBOX/;uid=20;urlauth=submit+Fr%C3%A9d%C3%A9ric:internal:...
/// ```
///
/// ## Related types
///
/// See ``Access`` for how encoded users are used in URLAUTH access identifiers,
/// ``UserAuthenticationMechanism`` for server-level user specifications, and
/// ``IMAPServer`` for the complete server connection information.
///
/// ## Validity
///
/// The value is written to the wire verbatim, so anything that isn't an `enc-user` is rejected:
///
/// - ``init(_:)`` returns `nil`. Use it for a value derived from input.
/// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one is a
///   bug to be caught on first run rather than handled.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) - URI Generic Syntax (percent-encoding)
/// - SeeAlso: [RFC 4467 Section 3](https://datatracker.ietf.org/doc/html/rfc4467#section-3) - IMAP URL Extensions
public struct EncodedUser: Hashable, Sendable {
    let stringValue: String

    /// Creates a value from a percent-encoded string, if the string is a valid `enc-user`.
    ///
    /// Hex digits in `pct-encoded` triplets are uppercased, for example `%c3` becomes `%C3`.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The percent-encoded string, for example `Fr%C3%A9d%C3%A9ric`.
    /// - returns: A new value, or `nil` if `stringValue` is not a valid `enc-user`.
    public init?(_ stringValue: String) {
        guard let normalized = Self.normalized(stringValue) else { return nil }
        self.stringValue = normalized
    }

    init(unchecked stringValue: String) {
        assert(Self.normalized(stringValue) == stringValue)
        self.stringValue = stringValue
    }

    /// The given string with uppercased `pct-encoded` hex digits, if it is an `enc-user`
    /// ([RFC 5092 Section 11](https://datatracker.ietf.org/doc/html/rfc5092#section-11)):
    /// ```
    /// enc-user = 1*achar
    /// ```
    /// See ``URLCharacterClass/achar``.
    static func normalized(_ string: String) -> String? {
        string.validatedAndNormalizedURLComponent(.achar)
    }
}

extension String {
    /// Creates a `String` from an ``EncodedUser``, still percent-encoded.
    ///
    /// - parameter other: The value to convert.
    public init(_ other: EncodedUser) {
        self = other.stringValue
    }
}

extension EncodedUser: ExpressibleByStringLiteral {
    /// Creates a value from a percent-encoded string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `enc-user`; this traps if it isn't.
    public init(stringLiteral value: String) {
        guard let normalized = Self.normalized(value) else {
            preconditionFailure("Invalid encoded user: \(String(reflecting: value))")
        }
        self.init(unchecked: normalized)
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedUser(_ user: EncodedUser) -> Int {
        self.writeString(user.stringValue)
    }
}
