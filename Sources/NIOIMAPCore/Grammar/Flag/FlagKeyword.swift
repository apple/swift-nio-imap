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
    /// IMAP Flag Keyword
    ///
    /// `Keyword`s are case preserving, but case insensitive.
    /// As such e.g. `Flag.Keyword("$Forwarded") == Flag.Keyword("$forwarded")`, but
    /// it will round-trip preserving its case.
    public struct Keyword: Hashable {
        /// Performs a case-insensitive equality comparison.
        /// - parameter lhs: The first flag to compare.
        /// - parameter rhs: The second flag to compare.
        /// - returns `true` if the given `Keyword`s are equal, otherwise `false`.
        public static func == (lhs: Keyword, rhs: Keyword) -> Bool {
            lhs.rawValue.uppercased() == rhs.rawValue.uppercased()
        }

        /// The raw case-preserved string value of the `Keyword`.
        let rawValue: String

        /// Creates a new `Keyword`.
        /// - parameter string: A raw `String` to create the `Keyword`.  Each character in the`String` must be a valid atom-char as defined in RFC 3501.
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
            assert(string.utf8.allSatisfy { (c) -> Bool in
                c.isAtomChar || c.isResponseSpecial
            })
            self.rawValue = string
        }

        /// Hashes the `Keyword` using a given hasher, used to insert into a `Set`, `Dictionary`, etc.
        /// - parameter hasher: The hasher to use.
        public func hash(into hasher: inout Hasher) {
            rawValue.uppercased().hash(into: &hasher)
        }
    }
}

extension String {
    public init(_ other: Flag.Keyword) {
        self = other.rawValue
    }
}

// MARK: - Convenience

extension Flag.Keyword {
    /// `$Forwarded`
    public static let forwarded = Self(unchecked: "$Forwarded")

    /// `$Junk`
    public static let junk = Self(unchecked: "$Junk")

    /// `$NotJunk`
    public static let notJunk = Self(unchecked: "$NotJunk")

    /// `Redirected`
    public static let unregistered_redirected = Self(unchecked: "Redirected")

    /// `Forwarded`
    public static let unregistered_forwarded = Self(unchecked: "Forwarded")

    /// `Junk`
    public static let unregistered_junk = Self(unchecked: "Junk")

    /// `NotJunk`
    public static let unregistered_notJunk = Self(unchecked: "NotJunk")

    /// `$MailFlagBit0`
    public static let colorBit0 = Self(unchecked: "$MailFlagBit0")

    /// `$MailFlagBit1`
    public static let colorBit1 = Self(unchecked: "$MailFlagBit1")

    /// `$MailFlagBit2`
    public static let colorBit2 = Self(unchecked: "$MailFlagBit2")

    /// `$MDNSent`
    public static let mdnSent = Self(unchecked: "$MDNSent")
}

// MARK: - String Literal

extension Flag: ExpressibleByStringLiteral {
    /// Creates a new `keyword` flag from a string literal. Typically used when making static custom keywords
    /// that are embedded in code (e.g. Mail client features that depend on flags). Also useful when writing tests.
    /// - parameter stringLiteral: The string literal to construct a `Keyword` from.
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
