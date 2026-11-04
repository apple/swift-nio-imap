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

extension Command {
    /// The identifier a client prefixes a command with, and the server echoes in the command's
    /// tagged response.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 NOOP
    /// S: A001 OK NOOP completed
    /// ```
    ///
    /// `A001` is the tag.
    ///
    /// ## Validity
    ///
    /// A tag is written to the wire verbatim, so anything that isn't a `tag` is rejected:
    ///
    /// - ``init(_:)`` returns `nil`. Use it for a tag derived from input.
    /// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one
    ///   is a bug to be caught on first run rather than handled.
    ///
    /// - SeeAlso: [RFC 3501 Section 2.2.1](https://datatracker.ietf.org/doc/html/rfc3501#section-2.2.1)
    public struct Tag: Hashable, Sendable {
        let stringValue: String

        /// Creates a tag from a string, if the string is a valid `tag`.
        ///
        /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
        /// returning `nil`.
        ///
        /// - parameter stringValue: The tag, for example `A001`.
        /// - returns: A new tag, or `nil` if `stringValue` is not a valid `tag`.
        public init?(_ stringValue: String) {
            guard Self.isValidTag(stringValue) else { return nil }
            self.stringValue = stringValue
        }

        init(unchecked stringValue: String) {
            assert(Self.isValidTag(stringValue))
            self.stringValue = stringValue
        }

        /// Whether the given string is a `tag`
        /// ([RFC 3501 Section 9](https://datatracker.ietf.org/doc/html/rfc3501#section-9)):
        /// ```
        /// tag = 1*<any ASTRING-CHAR except "+">
        /// ```
        static func isValidTag(_ string: String) -> Bool {
            !string.isEmpty && string.utf8.allSatisfy(\.isTagChar)
        }
    }
}

extension String {
    /// Creates a `String` from a ``Command/Tag``.
    ///
    /// - parameter other: The tag to convert.
    public init(_ other: Command.Tag) {
        self = other.stringValue
    }
}

extension Command.Tag: ExpressibleByStringLiteral {
    /// Creates a tag from a string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `tag`; this traps if it isn't.
    public init(stringLiteral value: String) {
        precondition(Self.isValidTag(value), "Invalid command tag: \(String(reflecting: value))")
        self.init(unchecked: value)
    }
}

extension Command.Tag: CustomStringConvertible {
    /// The tag, for example `A001`.
    public var description: String {
        self.stringValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeTag(_ tag: Command.Tag) -> Int {
        assert(Command.Tag.isValidTag(tag.stringValue))
        return self.writeString(tag.stringValue)
    }
}
