//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// The name of a character set, such as `UTF-8`, as used by `SEARCH`, `SORT`, and the
/// `BADCHARSET` response code.
///
/// ## Validity
///
/// [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501#section-9) defines
/// `charset = atom / quoted`. A name is written as an atom where it is one, and quoted
/// otherwise — never as a literal, which `charset` doesn't allow. So anything that can't be
/// quoted is rejected:
///
/// - ``init(_:)`` returns `nil`. Use it for a name derived from input.
/// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one is a
///   bug to be caught on first run rather than handled.
///
/// Names compare case-insensitively, so `"utf-8" == "UTF-8"`
/// ([RFC 2978 Section 2.3](https://datatracker.ietf.org/doc/html/rfc2978#section-2.3); RFC 3501
/// uses those names). The original case is kept and written to the wire.
public struct CharacterSetName: Hashable, Sendable {
    let stringValue: String

    /// Creates a character set name from a string, if the string is a valid `charset`.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The name, for example `UTF-8`.
    /// - returns: A new name, or `nil` if `stringValue` is not a valid `charset`.
    public init?(_ stringValue: String) {
        guard Self.isValidName(stringValue) else { return nil }
        self.stringValue = stringValue
    }

    init(unchecked stringValue: String) {
        assert(Self.isValidName(stringValue))
        self.stringValue = stringValue
    }

    /// Whether the given string can be written as a `charset`:
    /// ```
    /// charset         = atom / quoted
    /// quoted          = DQUOTE *QUOTED-CHAR DQUOTE
    /// QUOTED-CHAR     = <any TEXT-CHAR except quoted-specials> /
    ///                   "\" quoted-specials
    /// ```
    /// Every `atom` is also a non-empty run of `TEXT-CHAR`, so that is the whole check. The empty
    /// string is rejected: it's no character set.
    static func isValidName(_ string: String) -> Bool {
        !string.isEmpty && string.utf8.allSatisfy(\.isTextChar)
    }

    /// Compares case-insensitively.
    ///
    /// Valid values are ASCII, so `uppercased()` is ASCII case-folding.
    public static func == (lhs: CharacterSetName, rhs: CharacterSetName) -> Bool {
        lhs.stringValue.uppercased() == rhs.stringValue.uppercased()
    }

    /// Hashes the case-folded value, consistent with `==`.
    public func hash(into hasher: inout Hasher) {
        self.stringValue.uppercased().hash(into: &hasher)
    }
}

extension String {
    /// Creates a `String` from a ``CharacterSetName``, unquoted.
    ///
    /// - parameter other: The name to convert.
    public init(_ other: CharacterSetName) {
        self = other.stringValue
    }
}

extension CharacterSetName: ExpressibleByStringLiteral {
    /// Creates a character set name from a string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `charset`; this traps if it isn't.
    public init(stringLiteral value: String) {
        precondition(Self.isValidName(value), "Invalid character set name: \(String(reflecting: value))")
        self.init(unchecked: value)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    /// Writes an atom where possible, so `UTF-8` stays `UTF-8` on the wire; quoted otherwise.
    @discardableResult mutating func writeCharacterSetName(_ name: CharacterSetName) -> Int {
        guard !name.stringValue.isIMAPAtom else { return self.writeString(name.stringValue) }
        return self.writeQuotedIMAPString(name.stringValue.utf8)
    }
}
