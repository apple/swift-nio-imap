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
/// ## Validity
///
/// A flag is either an `atom` (a keyword) or a `\` followed by an `atom` (an extension), so it can
/// always be written to the wire as-is. Anything else is rejected, in one of two ways:
///
/// - ``init(_:)`` returns `nil`. Use it for a flag derived from input.
/// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one is a
///   bug to be caught on first run rather than handled.
///
/// Note that a string literal picks the trapping initializer: `Flag("\\Seen")` is a `Flag`,
/// whereas `Flag(someString)` is a `Flag?`.
///
/// ## Extension flags
///
/// Beyond the five standard flags, custom flags can be created — either as keywords such as
/// `$Forwarded`, or as extension flags, which are defined in
/// [RFC 3501 Section 2.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.2) and
/// begin with a backslash (`\`).
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

    /// Creates a new `Flag` from the given `String`, if the string is a valid flag.
    ///
    /// Note that casing is preserved, however when checking if two `Flag`s are equal, then the
    /// comparison is case-insensitive.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The flag, for example `\Seen` or `$Forwarded`.
    /// - returns: A new flag, or `nil` if `stringValue` is not a valid flag.
    public init?(_ stringValue: String) {
        guard Flag.isValidFlag(stringValue) else { return nil }
        self.stringValue = stringValue
    }

    init(unchecked stringValue: String) {
        assert(Flag.isValidFlag(stringValue))
        self.stringValue = stringValue
    }

    /// Whether the given string is a `flag`:
    /// ```
    /// flag            = "\Answered" / "\Flagged" / "\Deleted" / "\Seen" / "\Draft" /
    ///                   flag-keyword / flag-extension
    ///                     ; Does not include "\Recent"
    /// flag-extension  = "\" atom
    /// flag-keyword    = atom
    /// ```
    /// The two branches differ: a keyword also admits resp-specials (see
    /// ``Flag/Keyword/isValidKeyword(_:)``), an extension does not. The `\Recent` carve-out is
    /// deliberately not enforced: ``Flag`` models `flag-fetch = flag / "\Recent"`, so `\Recent`
    /// is accepted here as an ordinary `flag-extension`.
    ///
    /// A `Flag` is written to the wire verbatim, so this is what keeps a flag built from
    /// untrusted input from injecting arbitrary IMAP into the stream.
    static func isValidFlag(_ string: String) -> Bool {
        guard string.hasPrefix("\\") else { return Keyword.isValidKeyword(string) }
        return string.dropFirst().isIMAPAtom
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
    public static let answered: Self = "\\Answered"

    /// `\Flagged` - The message has been marked for attention.
    ///
    /// Defined in [RFC 9051](https://www.rfc-editor.org/rfc/rfc9051.html).
    ///
    /// A flagged message can additionally carry one of seven colors, encoded as
    /// a 3-bit mask via the ``Keyword/colorBit0``, ``Keyword/colorBit1``, and
    /// ``Keyword/colorBit2`` keywords ([RFC 9979](https://www.rfc-editor.org/rfc/rfc9979.html)).
    /// Prefer the higher-level ``FlaggedState`` API for reading and updating a
    /// message's flagged mark and its color.
    ///
    /// - SeeAlso: ``FlaggedState``
    public static let flagged: Self = "\\Flagged"

    /// `\Deleted` - The message has been deleted.
    ///
    /// Defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501). Marks a message for
    /// deletion until the ``Command/expunge`` command is executed or the mailbox is closed.
    public static let deleted: Self = "\\Deleted"

    /// `\Seen` - The message has been read by the user.
    ///
    /// Defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let seen: Self = "\\Seen"

    /// `\Draft` - The message is not yet complete.
    ///
    /// Defined in [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    public static let draft: Self = "\\Draft"

    /// Convenience function to create a new flag from a `Keyword`.
    /// - parameter keyword: The `Keyword` to use to make the `Flag`.
    /// - returns: A new `Flag`
    public static func keyword(_ keyword: Keyword) -> Self {
        // A `Keyword` has already been validated, and a keyword is a flag.
        self.init(unchecked: keyword.rawValue)
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
    /// - parameter string: The custom flag name, a single `\` followed by an `atom`.
    /// - returns: A newly-created `Flag`
    /// - Precondition: `string` is a valid `flag-extension`; this traps if it isn't. Use
    ///   ``init(_:)`` for a string derived from input.
    public static func `extension`(_ string: String) -> Self {
        precondition(string.first == "\\", "Flag extensions must begin with \\")
        precondition(isValidFlag(string), "Invalid flag extension: \(String(reflecting: string))")
        return Self(unchecked: string)
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
