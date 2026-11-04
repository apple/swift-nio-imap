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

extension SearchKey {
    /// The name of a server-side saved search filter, as used by ``SearchKey/filter(_:)``.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 SEARCH FILTER on-the-road
    /// ```
    ///
    /// ## Validity
    ///
    /// A name is written to the wire verbatim, so anything that isn't a `filter-name` is rejected:
    ///
    /// - ``init(_:)`` returns `nil`. Use it for a name derived from input.
    /// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one is a
    ///   bug to be caught on first run rather than handled.
    ///
    /// - SeeAlso: [RFC 5466](https://datatracker.ietf.org/doc/html/rfc5466)
    public struct FilterName: Hashable, Sendable {
        let stringValue: String

        /// Creates a filter name from a string, if the string is a valid `filter-name`.
        ///
        /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
        /// returning `nil`.
        ///
        /// - parameter stringValue: The name, for example `on-the-road`.
        /// - returns: A new name, or `nil` if `stringValue` is not a valid `filter-name`.
        public init?(_ stringValue: String) {
            guard Self.isValidName(stringValue) else { return nil }
            self.stringValue = stringValue
        }

        init(unchecked stringValue: String) {
            assert(Self.isValidName(stringValue))
            self.stringValue = stringValue
        }

        /// Whether the given string is a `filter-name`
        /// ([RFC 5466 Section 4](https://datatracker.ietf.org/doc/html/rfc5466#section-4)):
        /// ```
        /// filter-name = 1*<any ATOM-CHAR except "/">
        /// ```
        static func isValidName(_ string: String) -> Bool {
            string.isIMAPAtom && !string.utf8.contains(UInt8(ascii: "/"))
        }
    }
}

extension String {
    /// Creates a `String` from a ``SearchKey/FilterName``.
    ///
    /// - parameter other: The filter name to convert.
    public init(_ other: SearchKey.FilterName) {
        self = other.stringValue
    }
}

extension SearchKey.FilterName: ExpressibleByStringLiteral {
    /// Creates a filter name from a string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `filter-name`; this traps if it isn't.
    public init(stringLiteral value: String) {
        precondition(Self.isValidName(value), "Invalid filter name: \(String(reflecting: value))")
        self.init(unchecked: value)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFilterName(_ name: SearchKey.FilterName) -> Int {
        self.writeAtom(name.stringValue)
    }
}
