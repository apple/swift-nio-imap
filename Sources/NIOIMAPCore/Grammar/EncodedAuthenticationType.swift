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

/// A percent-encoded SASL authentication mechanism name for use in IMAP URLs.
///
/// IMAP URLs may specify an authentication mechanism requirement using the `;AUTH=` parameter.
/// When the mechanism name contains characters that are not allowed in URLs, the name must be
/// percent-encoded using UTF-8 followed by hexadecimal encoding (RFC 2192, RFC 3986).
///
/// Wraps a percent-encoded authentication mechanism name for use in URL construction.
/// The encoded string contains only ASCII-safe characters and can be safely included in IMAP URL syntax.
///
/// ### Examples
///
/// A standard mechanism like "PLAIN" would typically not require encoding:
/// ```
/// imap://user@example.com/INBOX/;uid=20;auth=PLAIN
/// ```
///
/// A custom mechanism with special characters might be percent-encoded:
/// ```
/// imap://user@example.com/INBOX/;uid=20;auth=MY-CUSTOM%2DAUTH
/// ```
///
/// In an IMAP URL structure:
/// ```
/// IMAPServer(
///   userAuthenticationMechanism: UserAuthenticationMechanism(
///     encodedUser: "user",
///     authenticationMechanism: IMAPURLAuthenticationMechanism.type(
///       "PLAIN"
///     )
///   ),
///   host: "example.com"
/// )
/// ```
///
/// ## Related types
///
/// See ``IMAPURLAuthenticationMechanism`` for the authentication mechanism specification,
/// ``UserAuthenticationMechanism`` for how mechanisms are combined with user identifiers,
/// and ``IMAPServer`` for the complete server specification.
///
/// ## Validity
///
/// The value is written to the wire verbatim, so anything that isn't an `enc-auth-type` is rejected:
///
/// - ``init(_:)`` returns `nil`. Use it for a value derived from input.
/// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one is a
///   bug to be caught on first run rather than handled.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) - URI Generic Syntax (percent-encoding)
public struct EncodedAuthenticationType: Hashable, Sendable {
    let stringValue: String

    /// Creates a value from a percent-encoded string, if the string is a valid `enc-auth-type`.
    ///
    /// Hex digits in `pct-encoded` triplets are uppercased, for example `%c3` becomes `%C3`.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The percent-encoded string, for example `PLAIN`.
    /// - returns: A new value, or `nil` if `stringValue` is `*` or not a valid `enc-auth-type`.
    public init?(_ stringValue: String) {
        guard let normalized = Self.normalized(stringValue) else { return nil }
        self.stringValue = normalized
    }

    init(unchecked stringValue: String) {
        assert(Self.normalized(stringValue) == stringValue)
        self.stringValue = stringValue
    }

    /// The given string with uppercased `pct-encoded` hex digits, if it is an `enc-auth-type`
    /// ([RFC 5092 Section 11](https://datatracker.ietf.org/doc/html/rfc5092#section-11)):
    /// ```
    /// enc-auth-type = 1*achar
    /// ```
    /// See ``URLCharacterClass/achar``. Not allowed: `*`, since `;AUTH=*` means any mechanism
    /// (``IMAPURLAuthenticationMechanism/any``).
    static func normalized(_ string: String) -> String? {
        guard string != Self.anyMechanism else { return nil }
        return string.normalizedURLComponent(.achar)
    }

    /// What `;AUTH=` is followed by to mean any mechanism.
    static let anyMechanism = "*"
}

extension String {
    /// Creates a `String` from an ``EncodedAuthenticationType``, still percent-encoded.
    ///
    /// - parameter other: The value to convert.
    public init(_ other: EncodedAuthenticationType) {
        self = other.stringValue
    }
}

extension EncodedAuthenticationType: ExpressibleByStringLiteral {
    /// Creates a value from a percent-encoded string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `enc-auth-type`; this traps if it isn't.
    public init(stringLiteral value: String) {
        guard let normalized = Self.normalized(value) else {
            preconditionFailure("Invalid encoded authentication type: \(String(reflecting: value))")
        }
        self.init(unchecked: normalized)
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedAuthenticationType(_ type: EncodedAuthenticationType) -> Int {
        self.writeString(type.stringValue)
    }
}
