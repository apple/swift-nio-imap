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
    /// The `$Forwarded` keyword corresponds to a ``Flag`` wrapping a ``Flag/Keyword``.
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
        /// Preserves the original casing for wire format transmission, while comparison operations
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
    /// Creates a `String` from a ``Flag/Keyword``.
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
    /// A registered keyword in the special-use keywords registry.
    public static let forwarded = Self(unchecked: "$Forwarded")

    /// The `$Junk` keyword, commonly used to mark messages as spam or junk mail.
    ///
    /// A registered keyword in the special-use keywords registry.
    public static let junk = Self(unchecked: "$Junk")

    /// The `$NotJunk` keyword, commonly used to mark messages as not spam.
    ///
    /// A registered keyword in the special-use keywords registry.
    public static let notJunk = Self(unchecked: "$NotJunk")

    /// The `Redirected` keyword (unregistered).
    ///
    /// A non-standard keyword sometimes used by mail systems to mark redirected messages.
    public static let unregistered_redirected = Self(unchecked: "Redirected")

    /// The `Forwarded` keyword (unregistered).
    ///
    /// A non-standard keyword for marking forwarded messages. Prefer ``forwarded`` for standard usage.
    public static let unregistered_forwarded = Self(unchecked: "Forwarded")

    /// The `Junk` keyword (unregistered).
    ///
    /// A non-standard keyword for marking spam. Prefer ``junk`` for standard usage.
    public static let unregistered_junk = Self(unchecked: "Junk")

    /// The `NotJunk` keyword (unregistered).
    ///
    /// A non-standard keyword for marking non-spam messages. Prefer ``notJunk`` for standard usage.
    public static let unregistered_notJunk = Self(unchecked: "NotJunk")

    /// The `$MailFlagBit0` keyword, bit 0 of a flagged message's color.
    ///
    /// Together with ``colorBit1`` and ``colorBit2``, this keyword forms a 3-bit
    /// mask that gives a `\Flagged` message one of seven colors. Prefer the
    /// higher-level ``FlaggedState`` API for reading and updating a message's flagged
    /// state and color.
    ///
    /// - SeeAlso: [RFC 9979 Section 3](https://www.rfc-editor.org/rfc/rfc9979.html#section-3)
    /// - SeeAlso: ``FlaggedState``
    public static let colorBit0 = Self(unchecked: "$MailFlagBit0")

    /// The `$MailFlagBit1` keyword, bit 1 of a flagged message's color.
    ///
    /// Together with ``colorBit0`` and ``colorBit2``, this keyword forms a 3-bit
    /// mask that gives a `\Flagged` message one of seven colors. Prefer the
    /// higher-level ``FlaggedState`` API for reading and updating a message's flagged
    /// state and color.
    ///
    /// - SeeAlso: [RFC 9979 Section 3](https://www.rfc-editor.org/rfc/rfc9979.html#section-3)
    /// - SeeAlso: ``FlaggedState``
    public static let colorBit1 = Self(unchecked: "$MailFlagBit1")

    /// The `$MailFlagBit2` keyword, bit 2 of a flagged message's color.
    ///
    /// Together with ``colorBit0`` and ``colorBit1``, this keyword forms a 3-bit
    /// mask that gives a `\Flagged` message one of seven colors. Prefer the
    /// higher-level ``FlaggedState`` API for reading and updating a message's flagged
    /// state and color.
    ///
    /// - SeeAlso: [RFC 9979 Section 3](https://www.rfc-editor.org/rfc/rfc9979.html#section-3)
    /// - SeeAlso: ``FlaggedState``
    public static let colorBit2 = Self(unchecked: "$MailFlagBit2")

    /// The `$MDNSent` keyword, indicating a Message Disposition Notification has been sent for this message.
    public static let mdnSent = Self(unchecked: "$MDNSent")

    // MARK: RFC 9979

    /// The `$autosent` keyword, marking a message that was generated and sent
    /// automatically on the user's behalf, such as a vacation auto-reply.
    ///
    /// Advisory; set by the server on delivery of the user's copy.
    ///
    /// - SeeAlso: [RFC 9979 Section 7.1](https://www.rfc-editor.org/rfc/rfc9979.html#section-7.1)
    public static let autoSent = Self(unchecked: "$autosent")

    /// The `$canunsubscribe` keyword, indicating the message carries a
    /// [RFC 8058](https://datatracker.ietf.org/doc/html/rfc8058)-compliant
    /// `List-Unsubscribe` header that a client can use for one-click unsubscribe.
    ///
    /// Advisory; set by the server on delivery after its own reputation checks.
    ///
    /// - SeeAlso: [RFC 9979 Section 6.1](https://www.rfc-editor.org/rfc/rfc9979.html#section-6.1)
    public static let canUnsubscribe = Self(unchecked: "$canunsubscribe")

    /// The `$followed` keyword, indicating the user is particularly interested in
    /// future messages in the thread.
    ///
    /// Set and cleared by the client. Mutually exclusive with ``muted``: if both
    /// appear on a thread, the thread is treated as followed.
    ///
    /// - SeeAlso: [RFC 9979 Section 7.2](https://www.rfc-editor.org/rfc/rfc9979.html#section-7.2)
    public static let followed = Self(unchecked: "$followed")

    /// The `$hasattachment` keyword, indicating the message has one or more attachments.
    ///
    /// Advisory; set by the server on delivery, or by the client when neither
    /// ``hasAttachment`` nor ``hasNoAttachment`` is set. Mutually exclusive with
    /// ``hasNoAttachment``.
    ///
    /// - SeeAlso: [RFC 9979 Section 4.1](https://www.rfc-editor.org/rfc/rfc9979.html#section-4.1)
    public static let hasAttachment = Self(unchecked: "$hasattachment")

    /// The `$hasmemo` keyword, applied to a message that has an associated memo
    /// (a message bearing the ``memo`` keyword) in the same thread.
    ///
    /// Advisory; set and cleared by the client. Mutually exclusive with ``memo``.
    ///
    /// - SeeAlso: [RFC 9979 Section 5.1](https://www.rfc-editor.org/rfc/rfc9979.html#section-5.1)
    public static let hasMemo = Self(unchecked: "$hasmemo")

    /// The `$hasnoattachment` keyword, explicitly indicating the message has no
    /// attachments (as opposed to not yet having been analyzed).
    ///
    /// Advisory; set by the server on delivery, or by the client when neither
    /// ``hasAttachment`` nor ``hasNoAttachment`` is set. Mutually exclusive with
    /// ``hasAttachment``.
    ///
    /// - SeeAlso: [RFC 9979 Section 4.2](https://www.rfc-editor.org/rfc/rfc9979.html#section-4.2)
    public static let hasNoAttachment = Self(unchecked: "$hasnoattachment")

    /// The `$imported` keyword, marking a message that was imported from another
    /// system rather than received through normal mail delivery.
    ///
    /// Advisory; set by the server during import.
    ///
    /// - SeeAlso: [RFC 9979 Section 7.3](https://www.rfc-editor.org/rfc/rfc9979.html#section-7.3)
    public static let imported = Self(unchecked: "$imported")

    /// The `$istrusted` keyword, indicating the server verified the sender's
    /// identity with a high degree of confidence.
    ///
    /// Advisory; set by the server on delivery. Servers must apply it with care,
    /// and never solely on the basis of SPF, DKIM, or DMARC.
    ///
    /// - SeeAlso: [RFC 9979 Section 7.4](https://www.rfc-editor.org/rfc/rfc9979.html#section-7.4)
    public static let isTrusted = Self(unchecked: "$istrusted")

    /// The `$maskedemail` keyword, indicating the message arrived via a masked
    /// email alias created to protect the user's primary address.
    ///
    /// Advisory; set by the server on delivery.
    ///
    /// - SeeAlso: [RFC 9979 Section 7.5](https://www.rfc-editor.org/rfc/rfc9979.html#section-7.5)
    public static let maskedEmail = Self(unchecked: "$maskedemail")

    /// The `$memo` keyword, identifying a message as a note-to-self regarding
    /// another message in the same thread.
    ///
    /// Set and cleared by the client. Mutually exclusive with ``hasMemo``, which
    /// is applied to the annotated message.
    ///
    /// - SeeAlso: [RFC 9979 Section 5.2](https://www.rfc-editor.org/rfc/rfc9979.html#section-5.2)
    public static let memo = Self(unchecked: "$memo")

    /// The `$muted` keyword, indicating the user is not interested in future
    /// messages in the thread.
    ///
    /// Set and cleared by the client. Mutually exclusive with ``followed``: if
    /// both appear on a thread, the thread is treated as followed.
    ///
    /// - SeeAlso: [RFC 9979 Section 7.6](https://www.rfc-editor.org/rfc/rfc9979.html#section-7.6)
    public static let muted = Self(unchecked: "$muted")

    /// The `$new` keyword, indicating the message should be emphasized as if it
    /// were new — typically a snoozed message that has just returned to the inbox.
    ///
    /// Advisory; set by the server. Clients clear it once the user interacts with
    /// the message.
    ///
    /// - SeeAlso: [RFC 9979 Section 7.7](https://www.rfc-editor.org/rfc/rfc9979.html#section-7.7)
    public static let new = Self(unchecked: "$new")

    /// The `$notify` keyword, indicating the client should present a notification
    /// for the message.
    ///
    /// Set by the server on delivery, or by client filtering rules. Clients may
    /// clear it once the user interacts with the message.
    ///
    /// - SeeAlso: [RFC 9979 Section 7.8](https://www.rfc-editor.org/rfc/rfc9979.html#section-7.8)
    public static let notify = Self(unchecked: "$notify")

    /// The `$unsubscribed` keyword, recording that the user has attempted to
    /// unsubscribe from the message's mailing list.
    ///
    /// Set by the client after a one-click unsubscribe attempt. Must not be set if
    /// the attempt definitely failed.
    ///
    /// - SeeAlso: [RFC 9979 Section 6.2](https://www.rfc-editor.org/rfc/rfc9979.html#section-6.2)
    public static let unsubscribed = Self(unchecked: "$unsubscribed")
}

// MARK: - String Literal

extension Flag: ExpressibleByStringLiteral {
    /// Creates a flag from a string literal, used for creating static custom keywords.
    ///
    /// This allows writing flags directly as string literals (for example, `let flag: Flag = "$Custom"`),
    /// which is useful for static keyword definitions and testing.
    ///
    /// - parameter value: The string literal to construct a keyword flag from.
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
