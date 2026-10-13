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

/// A flag used in `MODSEQ` search operations.
///
/// Attribute flags represent message flags in the context of the `MODSEQ` conditional STORE extension
/// defined in [RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162). They are similar to standard
/// ``Flag`` values but are specifically used for searching based on modification sequences.
///
/// **Note:** Unlike ``Flag``, attribute flags do not include the `\Recent` flag, as `\Recent` is not persistent.
///
/// Attribute flags are case-insensitive: they are normalized to lowercase, and transmitted that way.
///
/// ## Validity
///
/// The flag is stored, and written, in its lowercased wire form: `\\seen` (two backslashes) for
/// the system flag `\Seen`. Anything that isn't an `attr-flag` is rejected: ``init(_:)`` returns `nil`,
/// ``init(stringLiteral:)`` traps.
///
/// ### Standard attribute flags
///
/// - ``answered`` - The message has been replied to.
/// - ``flagged`` - The message has been marked for attention.
/// - ``deleted`` - The message has been deleted.
/// - ``seen`` - The message has been read by the user.
/// - ``draft`` - The message is incomplete and has not been sent.
///
/// - SeeAlso: [RFC 7162 Section 3.1](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1)
/// - SeeAlso: ``Flag``
public struct AttributeFlag: Hashable, Sendable {
    /// The raw lowercase string representation of the flag.
    internal let stringValue: String

    /// The `\Answered` attribute flag - the message has been replied to.
    ///
    /// Corresponds to the `\Answered` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let answered: Self = "\\\\Answered"

    /// The `\Flagged` attribute flag - the message has been marked for attention.
    ///
    /// Corresponds to the `\Flagged` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let flagged: Self = "\\\\Flagged"

    /// The `\Deleted` attribute flag - the message has been deleted.
    ///
    /// Corresponds to the `\Deleted` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let deleted: Self = "\\\\Deleted"

    /// The `\Seen` attribute flag - the message has been read by the user.
    ///
    /// Corresponds to the `\Seen` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let seen: Self = "\\\\Seen"

    /// The `\Draft` attribute flag - the message is incomplete and has not been sent.
    ///
    /// Corresponds to the `\Draft` standard flag as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let draft: Self = "\\\\Draft"

    /// Creates an attribute flag from its wire form, if that is a valid `attr-flag`.
    ///
    /// The provided string is lowercased to normalize the flag value, allowing case-insensitive
    /// comparison.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The flag in wire form (for example, `\\Answered` or `$Forwarded`).
    ///   Will be lowercased.
    /// - returns: A new flag, or `nil` if the lowercased `stringValue` is not an `attr-flag`.
    public init?(_ stringValue: String) {
        let normalized = stringValue.lowercased()
        guard Self.isValidAttributeFlag(normalized) else { return nil }
        self.stringValue = normalized
    }

    /// Lowercases, like ``init(_:)``.
    init(unchecked stringValue: String) {
        let normalized = stringValue.lowercased()
        assert(Self.isValidAttributeFlag(normalized))
        self.stringValue = normalized
    }

    /// Whether the given string is an `attr-flag`
    /// ([RFC 7162 Section 7](https://datatracker.ietf.org/doc/html/rfc7162#section-7)):
    /// ```
    /// attr-flag           = "\\Answered" / "\\Flagged" / "\\Deleted" /
    ///                       "\\Seen" / "\\Draft" / attr-flag-keyword /
    ///                       attr-flag-extension
    /// attr-flag-extension = "\\" atom
    /// attr-flag-keyword   = atom
    /// ```
    /// ABNF `"\\"` is two backslashes: the flag's quoted-string escaping inside
    /// `entry-flag-name = DQUOTE "/flags/" attr-flag DQUOTE`. An `atom` has no `\` or `"`, so a
    /// valid flag can't end or escape out of that quoted string.
    static func isValidAttributeFlag(_ string: String) -> Bool {
        let escapedBackslash = "\\\\"
        guard string.hasPrefix(escapedBackslash) else { return string.isIMAPAtom }
        return string.dropFirst(escapedBackslash.count).isIMAPAtom
    }
}

extension String {
    /// Creates a `String` from an ``AttributeFlag``.
    ///
    /// - parameter other: The attribute flag to convert.
    public init(_ other: AttributeFlag) {
        self = other.stringValue
    }
}

// MARK: - Encoding

extension AttributeFlag: ExpressibleByStringLiteral {
    /// Creates an attribute flag from a string literal in wire form, lowercased.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: the lowercased `value` is an `attr-flag`; this traps if it isn't.
    public init(stringLiteral value: String) {
        precondition(
            Self.isValidAttributeFlag(value.lowercased()),
            "Invalid attribute flag: \(String(reflecting: value))"
        )
        self.init(unchecked: value)
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeAttributeFlag(_ flag: AttributeFlag) -> Int {
        // Verbatim: the stored form is already the wire form.
        assert(AttributeFlag.isValidAttributeFlag(flag.stringValue))
        return self.writeString(flag.stringValue)
    }
}
