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

/// A percent-encoded message section reference for use in IMAP URLs.
///
/// IMAP message sections (as defined in RFC 3501) specify parts of message structures
/// using dot-separated numeric notation (for example, "1", "1.2", or "1.2.3"). When used in IMAP URLs,
/// section references are percent-encoded to ensure URL safety (RFC 2192, RFC 3986).
///
/// Wraps a percent-encoded section reference for use in URL construction.
/// The encoded string contains only ASCII-safe characters and can be safely included in IMAP URL syntax.
///
/// ### Example
///
/// A section reference like "1.2.MIME" (the MIME headers of the second part of the first part)
/// would be percent-encoded in an IMAP URL:
/// ```
/// imap://user@example.com/INBOX/;uid=20;section=1.2.MIME
/// ```
///
/// In a message path structure:
/// ```
/// MessagePath(
///   mailboxReference: MailboxUIDValidity(...),
///   iUID: IUID(uid: UID(100)),
///   section: URLMessageSection(
///     encodedSection: "1.2.MIME"
///   )
/// )
/// ```
///
/// ## Related types
///
/// See ``URLMessageSection`` for the complete message section specification,
/// ``MessagePath`` for the full message location including sections, and
/// ``SectionSpecifier`` for RFC 3501 section syntax details.
///
/// ## Validity
///
/// The value is written to the wire verbatim, so anything that isn't an `enc-section` is rejected:
///
/// - ``init(_:)`` returns `nil`. Use it for a value derived from input.
/// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one is a
///   bug to be caught on first run rather than handled.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5) - FETCH Command
/// - SeeAlso: [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) - URI Generic Syntax (percent-encoding)
public struct EncodedSection: Hashable, Sendable {
    let stringValue: String

    /// Creates a value from a percent-encoded string, if the string is a valid `enc-section`.
    ///
    /// Hex digits in `pct-encoded` triplets are uppercased, for example `%c3` becomes `%C3`.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The percent-encoded string, for example `1.2.MIME`.
    /// - returns: A new value, or `nil` if `stringValue` is not a valid `enc-section`.
    public init?(_ stringValue: String) {
        guard let normalized = Self.normalized(stringValue) else { return nil }
        self.stringValue = normalized
    }

    init(unchecked stringValue: String) {
        assert(Self.normalized(stringValue) == stringValue)
        self.stringValue = stringValue
    }

    /// The given string with uppercased `pct-encoded` hex digits, if it is an `enc-section`
    /// ([RFC 5092 Section 11](https://datatracker.ietf.org/doc/html/rfc5092#section-11)):
    /// ```
    /// enc-section = 1*bchar
    /// ```
    /// See ``URLCharacterClass/bchar``.
    static func normalized(_ string: String) -> String? {
        string.validatedAndNormalizedURLComponent(.bchar)
    }
}

extension String {
    /// Creates a `String` from an ``EncodedSection``, still percent-encoded.
    ///
    /// - parameter other: The value to convert.
    public init(_ other: EncodedSection) {
        self = other.stringValue
    }
}

extension EncodedSection: ExpressibleByStringLiteral {
    /// Creates a value from a percent-encoded string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `enc-section`; this traps if it isn't.
    public init(stringLiteral value: String) {
        guard let normalized = Self.normalized(value) else {
            preconditionFailure("Invalid encoded section: \(String(reflecting: value))")
        }
        self.init(unchecked: normalized)
    }
}

extension EncodedSection {
    /// This value without its trailing `/`, which the URL grammar claims for what follows, e.g.
    /// `1.2/` → `1.2`; `nil` if there is no trailing `/` or nothing would remain.
    func removingTrailingSlash() -> Self? {
        guard self.stringValue.utf8.count > 1, self.stringValue.utf8.last == UInt8(ascii: "/") else { return nil }
        return Self(unchecked: String(self.stringValue.dropLast()))
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedSection(_ section: EncodedSection) -> Int {
        self.writeString(section.stringValue)
    }
}
