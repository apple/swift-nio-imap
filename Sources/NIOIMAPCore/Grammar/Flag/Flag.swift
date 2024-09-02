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

/// IMAP Flag
///
/// Flags are case preserving, but case insensitive.
/// As such e.g. `.extension("\\FOOBAR") == .extension("\\FooBar")`, but
/// it will round-trip preserving its case.
public struct Flag: Hashable, Sendable {
    /// The raw case-sensitive `String` value.
    internal let stringValue: String

    /// Creates a new `Flag` from the given `String`. Note that casing is preserved, however
    /// when checking if two `Flag`s are equal, then the comparison is case-insensitive.
    public init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    /// Compares two flags to see if they are equivalent. Note that the comparison is case-insensitive.
    /// - parameter lhs: The first flag to compare.
    /// - parameter rhs: The second flag to compare.
    /// - returns: `true` if the flags are equal, otherwise `false`.
    public static func == (lhs: Flag, rhs: Flag) -> Bool {
        lhs.stringValue.uppercased() == rhs.stringValue.uppercased()
    }

    /// Hashes the `Flag` using some given `Hasher`. Note that the `Flag` is first upper-cased.
    /// - parameter hasher: The `Hasher` to hash the `Flag` into.
    public func hash(into hasher: inout Hasher) {
        stringValue.uppercased().hash(into: &hasher)
    }

    /// The hash value of the `Flag`. Typically used as a unique access key in, for example, a `Dictionary` or `Set`.
    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}

extension String {
    public init(_ other: Flag) {
        self = other.stringValue
    }
}

extension Flag {
    /// `\\Answered` - The message has been replied to.
    public static let answered = Self("\\Answered")

    /// `\\Flagged` - The message has been marked by the user, typically as a reminder
    /// that some action is required.
    public static let flagged = Self("\\Flagged")

    /// `\\Deleted` - The message has been deleted and should no
    /// longer be shown to the user, unless they specifically request to
    /// view deleted messages.
    public static let deleted = Self("\\Deleted")

    /// `\\Seen` - The message has been read by the user
    public static let seen = Self("\\Seen")

    /// `\\Draft` - The message is not yet complete
    public static let draft = Self("\\Draft")

    /// Convenience function to create a new flag from a `Keyword`.
    /// - parameter keyword: The `Keyword` to use to make the `Flag`.
    /// - returns: A new `Flag`
    public static func keyword(_ keyword: Keyword) -> Self {
        self.init(keyword.rawValue)
    }

    /// Creates a new `Flag` that complies to RFC 3501 `flag-extension`
    /// Note: If the provided extension is invalid then we will crash
    /// - parameter string: The new flag text, *must* begin with a single '\'
    /// - returns: A newly-create `Flag`
    public static func `extension`(_ string: String) -> Self {
        precondition(string.first == "\\", "Flag extensions must begin with \\")
        return Self(string)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFlags(_ flags: [Flag]) -> Int {
        self.writeArray(flags) { (flag, self) -> Int in
            self.writeFlag(flag)
        }
    }

    @discardableResult mutating func writeFlag(_ flag: Flag) -> Int {
        writeString(flag.stringValue)
    }
}
