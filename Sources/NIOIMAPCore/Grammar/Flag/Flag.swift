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

/// A message flag.
///
/// Flags are attributes attached to messages that indicate message state or special properties.
/// They are part of the base [IMAP protocol](https://datatracker.ietf.org/doc/html/rfc3501).
///
/// ## Standard flags
///
/// [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) defines five standard system flags:
/// - ``answered`` - The message has been replied to.
/// - ``flagged`` - The message has been marked for attention.
/// - ``deleted`` - The message has been deleted.
/// - ``seen`` - The message has been read by the user.
/// - ``draft`` - The message is incomplete and has not been sent.
///
/// ## Case handling
///
/// Flags are compared case-insensitively, meaning `Flag("\\SEEN")` and `Flag("\\Seen")` are considered equal.
/// Flags also preserve their original casing when encoded and decoded.
///
/// ## Extension flags
///
/// Beyond the five standard flags, custom flags can be created. These are defined in
/// [RFC 3501 Section 2.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.2).
/// Custom flags must begin with a backslash (`\`).
///
/// Example showing standard and custom flags:
/// ```
/// C: A001 STORE 1 +FLAGS (\Seen \Junk)
/// S: * 1 FETCH (FLAGS (\Answered \Seen \Junk))
/// S: A001 OK STORE completed
/// ```
public struct Flag: Hashable, Sendable {
    /// The raw case-sensitive ``Swift/String`` value.
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

extension Flag: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            _ = $0.writeFlag(self)
        }
    }
}

extension Flag {
    /// `\Answered` - The message has been replied to.
    ///
    /// Defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501). Indicates the
    /// message is a response to another message.
    public static let answered = Self("\\Answered")

    /// `\Flagged` - The message has been marked for attention.
    ///
    /// Defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let flagged = Self("\\Flagged")

    /// `\Deleted` - The message has been deleted.
    ///
    /// Defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501). Marks a message for
    /// deletion until the ``Command/expunge`` command is executed or the mailbox is closed.
    public static let deleted = Self("\\Deleted")

    /// `\Seen` - The message has been read by the user.
    ///
    /// Defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let seen = Self("\\Seen")

    /// `\Draft` - The message is not yet complete.
    ///
    /// Defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let draft = Self("\\Draft")

    /// Convenience function to create a new flag from a `Keyword`.
    /// - parameter keyword: The `Keyword` to use to make the `Flag`.
    /// - returns: A new `Flag`
    public static func keyword(_ keyword: Keyword) -> Self {
        self.init(keyword.rawValue)
    }

    /// Creates a new custom flag complying to [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) flag-extension syntax.
    ///
    /// Custom flags must begin with a backslash (`\`).
    ///
    /// ### Example
    ///
    /// ```
    /// let junkFlag = Flag.extension("\\Junk")
    /// let importantFlag = Flag.extension("\\Important")
    /// ```
    ///
    /// - parameter string: The custom flag name. Must begin with a single `\`. Will crash if not.
    /// - returns: A newly-created `Flag`
    /// - Note: If the provided extension is invalid (does not begin with `\`), a runtime assertion will fail.
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
