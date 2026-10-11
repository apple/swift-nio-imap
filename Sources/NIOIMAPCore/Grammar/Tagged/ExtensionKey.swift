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

/// The name of a tagged extension, such as a `CREATE`, `SELECT`, `RENAME`, `FETCH`, or `STORE`
/// parameter, an `APPEND` extension, or a `SEARCH` return option (a `tagged-ext-label` in
/// [RFC 4466](https://datatracker.ietf.org/doc/html/rfc4466)).
///
/// `Kind` is the type being extended, for example ``SelectParameter``. Keys of different kinds are
/// different types, so a `STORE` key can't be used where a `FETCH` key is expected.
///
/// ### Example
///
/// ```
/// C: A001 SELECT INBOX (CONDSTORE)
/// ```
///
/// `CONDSTORE` is an `ExtensionKey<SelectParameter>`.
///
/// ## Validity
///
/// A label is written to the wire verbatim, so anything that isn't a `tagged-ext-label` is rejected:
///
/// - ``init(_:)`` returns `nil`. Use it for a label derived from input.
/// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one is a
///   bug to be caught on first run rather than handled.
///
/// Labels compare case-insensitively, so `"x-gm:a" == "X-GM:A"`
/// ([RFC 4466 Section 3](https://datatracker.ietf.org/doc/html/rfc4466#section-3)). The original
/// case is kept and written to the wire.
///
/// - SeeAlso: [RFC 4466](https://datatracker.ietf.org/doc/html/rfc4466)
public struct ExtensionKey<Kind>: Hashable, Sendable {
    let stringValue: String

    /// Creates a label from a string, if the string is a valid `tagged-ext-label`.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The label, for example `CONDSTORE`.
    /// - returns: A new label, or `nil` if `stringValue` is not a valid `tagged-ext-label`.
    public init?(_ stringValue: String) {
        guard Self.isValidLabel(stringValue) else { return nil }
        self.stringValue = stringValue
    }

    init(unchecked stringValue: String) {
        assert(Self.isValidLabel(stringValue))
        self.stringValue = stringValue
    }

    /// Whether the given string is a `tagged-ext-label`
    /// ([RFC 4466 Section 3](https://datatracker.ietf.org/doc/html/rfc4466#section-3)):
    /// ```
    /// tagged-ext-label    = tagged-label-fchar *tagged-label-char
    /// tagged-label-fchar  = ALPHA / "-" / "_" / "."
    /// tagged-label-char   = tagged-label-fchar / DIGIT / ":"
    /// ```
    static func isValidLabel(_ string: String) -> Bool {
        guard let first = string.utf8.first, first.isTaggedLabelFchar else { return false }
        return string.utf8.dropFirst().allSatisfy(\.isTaggedLabelChar)
    }

    /// Compares case-insensitively.
    ///
    /// Valid values are ASCII, so `uppercased()` is ASCII case-folding.
    public static func == (lhs: ExtensionKey<Kind>, rhs: ExtensionKey<Kind>) -> Bool {
        lhs.stringValue.uppercased() == rhs.stringValue.uppercased()
    }

    /// Hashes the case-folded value, consistent with `==`.
    public func hash(into hasher: inout Hasher) {
        self.stringValue.uppercased().hash(into: &hasher)
    }
}

extension String {
    /// Creates a `String` from an ``ExtensionKey``.
    ///
    /// - parameter other: The label to convert.
    public init<Kind>(_ other: ExtensionKey<Kind>) {
        self = other.stringValue
    }
}

extension ExtensionKey: ExpressibleByStringLiteral {
    /// Creates a label from a string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `tagged-ext-label`; this traps if it isn't.
    public init(stringLiteral value: String) {
        precondition(Self.isValidLabel(value), "Invalid tagged extension label: \(String(reflecting: value))")
        self.init(unchecked: value)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    /// Every `tagged-ext-label` is an `atom`, so `writeAtom` adds a debug check.
    @discardableResult mutating func writeExtensionKey<Kind>(_ key: ExtensionKey<Kind>) -> Int {
        self.writeAtom(key.stringValue)
    }
}
