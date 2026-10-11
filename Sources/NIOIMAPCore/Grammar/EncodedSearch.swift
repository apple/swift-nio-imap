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

/// A percent-encoded search query for use in IMAP URLs.
///
/// Search queries in IMAP URLs (RFC 5092) must be percent-encoded to avoid conflicts with
/// URL syntax. This type wraps such an encoded search string.
///
/// ## Validity
///
/// The value is written to the wire verbatim, so anything that isn't an `enc-search` is rejected:
///
/// - ``init(_:)`` returns `nil`. Use it for a value derived from input.
/// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one is a
///   bug to be caught on first run rather than handled.
///
/// - SeeAlso: [RFC 5092 IMAP URL Scheme](https://datatracker.ietf.org/doc/html/rfc5092)
public struct EncodedSearch: Hashable, Sendable {
    let stringValue: String

    /// Creates a value from a percent-encoded string, if the string is a valid `enc-search`.
    ///
    /// Hex digits in `pct-encoded` triplets are uppercased, for example `%c3` becomes `%C3`.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The percent-encoded string, for example `SUBJECT%20Hello`.
    /// - returns: A new value, or `nil` if `stringValue` is not a valid `enc-search`.
    public init?(_ stringValue: String) {
        guard let normalized = Self.normalized(stringValue) else { return nil }
        self.stringValue = normalized
    }

    init(unchecked stringValue: String) {
        assert(Self.normalized(stringValue) == stringValue)
        self.stringValue = stringValue
    }

    /// The given string with uppercased `pct-encoded` hex digits, if it is an `enc-search`
    /// ([RFC 5092 Section 11](https://datatracker.ietf.org/doc/html/rfc5092#section-11)):
    /// ```
    /// enc-search = 1*bchar
    /// ```
    /// See ``URLCharacterClass/bchar``.
    static func normalized(_ string: String) -> String? {
        string.validatedAndNormalizedURLComponent(.bchar)
    }
}

extension String {
    /// Creates a `String` from an ``EncodedSearch``, still percent-encoded.
    ///
    /// - parameter other: The value to convert.
    public init(_ other: EncodedSearch) {
        self = other.stringValue
    }
}

extension EncodedSearch: ExpressibleByStringLiteral {
    /// Creates a value from a percent-encoded string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `enc-search`; this traps if it isn't.
    public init(stringLiteral value: String) {
        guard let normalized = Self.normalized(value) else {
            preconditionFailure("Invalid encoded search: \(String(reflecting: value))")
        }
        self.init(unchecked: normalized)
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedSearch(_ query: EncodedSearch) -> Int {
        self.writeString(query.stringValue)
    }
}
