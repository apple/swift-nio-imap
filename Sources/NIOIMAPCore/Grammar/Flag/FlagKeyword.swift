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

extension Flag {
    /// A user-defined custom flag keyword.
    ///
    /// Keywords are custom flags defined by clients and servers beyond the five standard flags (``Flag/answered``,
    /// ``Flag/flagged``, ``Flag/deleted``, ``Flag/seen``, ``Flag/draft``). They allow applications to mark
    /// messages with application-specific labels.
    ///
    /// Keywords are case-preserving but case-insensitive for comparison, meaning `Flag.Keyword("$Forwarded")`
    /// and `Flag.Keyword("$forwarded")` are considered equal, but preserve their original casing when
    /// transmitted. This follows [RFC 3501 Section 2.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.2).
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 STORE 1 +FLAGS (\Seen $Forwarded)
    /// S: * 1 FETCH (FLAGS (\Answered \Seen $Forwarded))
    /// S: A001 OK STORE completed
    /// ```
    ///
    /// The `$Forwarded` keyword corresponds to a ``Flag`` wrapping a ``Flag.Keyword``.
    ///
    /// - SeeAlso: [RFC 3501 Section 2.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.2)
    /// - SeeAlso: ``Flag``
    public struct Keyword: Hashable, Sendable {
        /// Performs a case-insensitive equality comparison.
        ///
        /// Two keywords are equal if their uppercased representations match, regardless of their original casing.
        ///
        /// - parameter lhs: The first keyword to compare.
        /// - parameter rhs: The second keyword to compare.
        /// - returns: `true` if the keywords are equal (case-insensitive), otherwise `false`.
        public static func == (lhs: Keyword, rhs: Keyword) -> Bool {
            lhs.rawValue.uppercased() == rhs.rawValue.uppercased()
        }

        /// The case-preserved raw string representation of the keyword.
        ///
        /// This value preserves the original casing for wire format transmission, while comparison operations
        /// use case-insensitive matching.
        let rawValue: String

        /// Creates a keyword from a string.
        ///
        /// The string must contain only valid IMAP atom characters as defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501),
        /// plus response special characters. Returns `nil` if the string contains invalid characters.
        ///
        /// - parameter string: The keyword string. Each character must be an atom character or response special.
        /// - returns: A new keyword, or `nil` if the string contains invalid characters.
        public init?(_ string: String) {
            /// RFC 3501 defines `flag-keyword` as `atom`,
            /// but Gmail sends flags with `[` and `]` in them.
            guard
                string.utf8.allSatisfy({ (c) -> Bool in
                    c.isAtomChar || c.isResponseSpecial
                })
            else { return nil }
            self.rawValue = string
        }

        init(unchecked string: String) {
            /// RFC 3501 defines `flag-keyword` as `atom`,
            /// but Gmail sends flags with `[` and `]` in them.
            assert(
                string.utf8.allSatisfy { (c) -> Bool in
                    c.isAtomChar || c.isResponseSpecial
                }
            )
            self.rawValue = string
        }

        /// Hashes the keyword for use in sets and dictionaries.
        ///
        /// Hashing is case-insensitive, ensuring that two keywords with the same characters in different
        /// cases produce the same hash value.
        ///
        /// - parameter hasher: The hasher to update with this keyword's hash value.
        public func hash(into hasher: inout Hasher) {
            rawValue.uppercased().hash(into: &hasher)
        }
    }
}

extension String {
    /// Creates a `String` from a ``Flag.Keyword``.
    ///
    /// - parameter other: The keyword to convert.
    public init(_ other: Flag.Keyword) {
        self = other.rawValue
    }
}

extension Flag.Keyword: CustomDebugStringConvertible {
    /// A debug representation showing the keyword in IMAP format.
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            _ = $0.writeFlagKeyword(self)
        }
    }
}

// MARK: - Convenience

extension Flag.Keyword {
    /// The `$Forwarded` keyword, commonly used to mark messages that have been forwarded.
    ///
    /// This is a registered keyword in the special-use keywords registry.
    public static let forwarded = Self(unchecked: "$Forwarded")

    /// The `$Junk` keyword, commonly used to mark messages as spam or junk mail.
    ///
    /// This is a registered keyword in the special-use keywords registry.
    public static let junk = Self(unchecked: "$Junk")

    /// The `$NotJunk` keyword, commonly used to mark messages as not spam.
    ///
    /// This is a registered keyword in the special-use keywords registry.
    public static let notJunk = Self(unchecked: "$NotJunk")

    /// The `Redirected` keyword (unregistered).
    ///
    /// This is a non-standard keyword sometimes used by mail systems to mark redirected messages.
    public static let unregistered_redirected = Self(unchecked: "Redirected")

    /// The `Forwarded` keyword (unregistered).
    ///
    /// This is a non-standard keyword for marking forwarded messages. Prefer ``forwarded`` for standard usage.
    public static let unregistered_forwarded = Self(unchecked: "Forwarded")

    /// The `Junk` keyword (unregistered).
    ///
    /// This is a non-standard keyword for marking spam. Prefer ``junk`` for standard usage.
    public static let unregistered_junk = Self(unchecked: "Junk")

    /// The `NotJunk` keyword (unregistered).
    ///
    /// This is a non-standard keyword for marking non-spam messages. Prefer ``notJunk`` for standard usage.
    public static let unregistered_notJunk = Self(unchecked: "NotJunk")

    /// The `$MailFlagBit0` keyword for color marking (bit 0).
    ///
    /// This keyword is commonly used by mail systems to represent color flags on messages, with different bits representing different colors.
    public static let colorBit0 = Self(unchecked: "$MailFlagBit0")

    /// The `$MailFlagBit1` keyword for color marking (bit 1).
    ///
    /// This keyword is commonly used by mail systems to represent color flags on messages.
    public static let colorBit1 = Self(unchecked: "$MailFlagBit1")

    /// The `$MailFlagBit2` keyword for color marking (bit 2).
    ///
    /// This keyword is commonly used by mail systems to represent color flags on messages.
    public static let colorBit2 = Self(unchecked: "$MailFlagBit2")

    /// The `$MDNSent` keyword, indicating a Message Disposition Notification has been sent for this message.
    public static let mdnSent = Self(unchecked: "$MDNSent")
}

// MARK: - String Literal

extension Flag: ExpressibleByStringLiteral {
    /// Creates a flag from a string literal, used for creating static custom keywords.
    ///
    /// This allows writing flags directly as string literals (e.g., `let flag: Flag = "$Custom"`),
    /// which is useful for static keyword definitions and testing.
    ///
    /// - parameter stringLiteral: The string literal to construct a keyword flag from.
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFlagKeyword(_ keyword: Flag.Keyword) -> Int {
        self.writeString(keyword.rawValue)
    }
}
