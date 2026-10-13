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

/// A special-use mailbox attribute from RFC 6154.
///
/// The `SPECIAL-USE` extension allows servers to advertise the special purpose of certain mailboxes.
/// Helps clients automatically identify important mailboxes like Drafts, Sent, Trash, and Junk
/// without relying on localized mailbox names or user configuration.
///
/// The attribute values are compared case-insensitively, but keep their original casing.
/// Servers can advertise these attributes in `LIST` responses, and clients can create mailboxes
/// with these attributes using the `CREATE-SPECIAL-USE` extension.
///
/// ## Validity
///
/// An attribute is written to the wire verbatim, so anything that isn't a `"\" atom` is
/// rejected: ``init(_:)`` returns `nil`, ``init(stringLiteral:)`` traps.
///
/// - SeeAlso: [RFC 6154 IMAP Special-Use Mailbox Attributes](https://datatracker.ietf.org/doc/html/rfc6154)
public struct UseAttribute: Hashable, Sendable {
    /// A mailbox that presents all messages in the user's store.
    public static let all: Self = "\\All"

    /// Used to archive messages - note that the meaning of "archived" will vary from server to server.
    public static let archive: Self = "\\Archive"

    /// Used to store draft messages that have not been sent.
    public static let drafts: Self = "\\Drafts"

    /// Stores messages that have been marked as "important" for some reason.
    public static let flagged: Self = "\\Flagged"

    /// Stores messages deemed to be spam or junk mail, for example, from a mailing list.
    public static let junk: Self = "\\Junk"

    /// Holds copies of messages that have been sent.
    public static let sent: Self = "\\Sent"

    /// Holds messages that have been deleted or marked for deletion.
    public static let trash: Self = "\\Trash"

    /// Holds messages that have been temporarily removed from the user's
    /// attention and scheduled to reappear at a later "awaken" time.
    ///
    /// - SeeAlso: [RFC 9979 Section 8.1](https://www.rfc-editor.org/rfc/rfc9979.html#section-8.1)
    public static let snoozed: Self = "\\Snoozed"

    /// Holds messages that have been composed but are scheduled to be sent at a
    /// future time rather than immediately.
    ///
    /// - SeeAlso: [RFC 9979 Section 8.2](https://www.rfc-editor.org/rfc/rfc9979.html#section-8.2)
    public static let scheduled: Self = "\\Scheduled"

    /// Holds messages bearing the ``Flag/Keyword/memo`` keyword: user-created
    /// notes or annotations regarding other messages.
    ///
    /// - SeeAlso: [RFC 9979 Section 8.3](https://www.rfc-editor.org/rfc/rfc9979.html#section-8.3)
    public static let memos: Self = "\\Memos"

    internal let stringValue: String

    /// Creates a `UseAttribute` from a string, if the string is a valid attribute. Note that
    /// usually it should be sufficient to just use the predefined attributes, for example `.drafts`.
    ///
    /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
    /// returning `nil`.
    ///
    /// - parameter stringValue: The attribute, for example `\Drafts`.
    /// - returns: A new attribute, or `nil` if `stringValue` is not a `"\" atom`.
    public init?(_ stringValue: String) {
        guard Self.isValidAttribute(stringValue) else { return nil }
        self.stringValue = stringValue
    }

    init(unchecked stringValue: String) {
        assert(Self.isValidAttribute(stringValue))
        self.stringValue = stringValue
    }

    /// Whether the given string is a `use-attr`
    /// ([RFC 6154 Section 6](https://datatracker.ietf.org/doc/html/rfc6154#section-6)):
    /// ```
    /// use-attr        =  "\All" / "\Archive" / "\Drafts" / "\Flagged" /
    ///                    "\Junk" / "\Sent" / "\Trash" / use-attr-ext
    /// use-attr-ext    =  "\" atom
    /// ```
    static func isValidAttribute(_ string: String) -> Bool {
        string.hasPrefix("\\") && string.dropFirst().isIMAPAtom
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.stringValue.lowercased() == rhs.stringValue.lowercased()
    }

    public func hash(into hasher: inout Hasher) {
        self.stringValue.lowercased().hash(into: &hasher)
    }
}

extension UseAttribute {
    /// Special Use can be returned as part of the `LIST` response. They’ll then be
    /// wrapped in `MailboxInfo.Attribute`.
    public init(_ other: MailboxInfo.Attribute) {
        // Both are `"\" atom`.
        self.init(unchecked: String(other))
    }
}

extension String {
    /// The raw value of the attribute, for example `\Trash`, in its original casing.
    public init(_ other: UseAttribute) {
        self = other.stringValue
    }
}

// MARK: - Encoding

extension UseAttribute: ExpressibleByStringLiteral {
    /// Creates an attribute from a string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a `"\" atom`; this traps if it isn't.
    public init(stringLiteral value: String) {
        precondition(Self.isValidAttribute(value), "Invalid use attribute: \(String(reflecting: value))")
        self.init(unchecked: value)
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeUseAttribute(_ att: UseAttribute) -> Int {
        // Verbatim: `"\" atom` needs no quoting.
        assert(UseAttribute.isValidAttribute(att.stringValue))
        return self.writeString(att.stringValue)
    }
}
