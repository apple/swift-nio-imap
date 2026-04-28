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
import struct OrderedCollections.OrderedDictionary

/// Information about a mailbox returned by a `LIST` command.
///
/// ``MailboxInfo`` represents the complete response to a `LIST` command as specified in
/// [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
/// It contains the mailbox's attributes, its path, and any extension parameters.
///
/// ### Example
///
/// ```
/// C: A001 LIST "" "INBOX"
/// S: * LIST (\NoInferiors) NIL "INBOX"
/// S: A001 OK LIST completed
/// ```
///
/// The line `* LIST (\NoInferiors) NIL "INBOX"` is wrapped as ``Response/untagged(_:)`` containing
/// ``ResponsePayload/mailboxData(_:)`` with attributes ``MailboxInfo/Attribute/noSelect``,
/// path separator `nil` (no hierarchy), and name "INBOX".
///
/// - SeeAlso: ``MailboxPath``, ``MailboxInfo/Attribute``
public struct MailboxInfo: Hashable, Sendable {
    /// An array of mailbox attributes describing this mailbox's properties.
    ///
    /// Attributes indicate whether the mailbox is selectable, has children, is remote, etc.
    /// See ``Attribute`` for the standard attribute types.
    ///
    /// Note: Servers may omit attributes that can be inferred from other returned attributes.
    /// Use ``hasEffectiveAttribute(_:)`` to check for an attribute while accounting for
    /// inference rules per [RFC 9051 Section 6.3.9.4](https://datatracker.ietf.org/doc/html/rfc9051#section-6.3.9.4).
    public var attributes: [Attribute]

    /// The hierarchical path to this mailbox, including its name and optional separator.
    ///
    /// The path includes the mailbox name in Modified UTF-7 encoding and, if present,
    /// the path separator character used to delimit parent/child relationships.
    public var path: MailboxPath

    /// Extension parameters for future IMAP extensions.
    ///
    /// This dictionary provides forward compatibility for new mailbox parameters added
    /// by future IMAP extensions beyond those standardized in RFC 3501.
    public var extensions: OrderedDictionary<ByteBuffer, ParameterValue>

    /// Creates a new mailbox information record.
    ///
    /// - Parameter attributes: An array of ``Attribute`` values describing the mailbox's properties
    /// - Parameter path: The ``MailboxPath`` including the mailbox name and optional path separator
    /// - Parameter extensions: Any extension parameters beyond the RFC 3501 base protocol
    public init(
        attributes: [Attribute] = [],
        path: MailboxPath,
        extensions: OrderedDictionary<ByteBuffer, ParameterValue>
    ) {
        self.attributes = attributes
        self.path = path
        self.extensions = extensions
    }
}

// MARK: - Types

extension MailboxInfo {
    /// A single mailbox attribute that describes a property or characteristic of a mailbox.
    ///
    /// Mailbox attributes are returned as part of ``MailboxInfo`` in response to `LIST` commands
    /// and indicate whether a mailbox is selectable, has children, is a remote mailbox, etc.
    /// Standard attributes are defined in [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2),
    /// with additional attributes defined by IMAP extensions such as
    /// [RFC 6154 (Special-Use Mailboxes)](https://datatracker.ietf.org/doc/html/rfc6154).
    ///
    /// Attributes are compared case-insensitively per the IMAP specification.
    /// Custom attributes can be created using the initializer, while standard attributes
    /// are available as static properties for convenience.
    ///
    /// - SeeAlso: ``MailboxInfo``
    public struct Attribute: Hashable, Sendable {
        /// The mailbox cannot be selected with a `SELECT` command.
        ///
        /// Indicates that the mailbox exists but is not selectable.
        /// A common example is a mailbox used only to contain child mailboxes.
        /// See [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
        public static var noSelect: Self { Self(#"\Noselect"#) }

        /// The mailbox has been marked as interesting by the server.
        ///
        /// The `\Marked` attribute indicates that the mailbox probably contains new messages
        /// since it was last accessed. See [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
        public static var marked: Self { Self(#"\Marked"#) }

        /// The mailbox does not have new messages since last access.
        ///
        /// The `\Unmarked` attribute is the counterpart to `\Marked`, indicating that the server
        /// has no indication of new messages in the mailbox. See [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
        public static var unmarked: Self { Self(#"\Unmarked"#) }

        /// The mailbox does not refer to any existing mailbox.
        ///
        /// The `\Nonexistent` attribute indicates that the mailbox name is reported by the server
        /// as a reference only (not an actual mailbox). Per [RFC 9051 Section 6.3.9](https://datatracker.ietf.org/doc/html/rfc9051#section-6.3.9),
        /// this attribute implies `\NoSelect`. See [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
        public static var nonExistent: Self { Self(#"\Nonexistent"#) }

        /// The mailbox cannot have any child mailboxes.
        ///
        /// The `\Noinferiors` attribute indicates that the mailbox cannot contain child mailboxes
        /// in a hierarchical namespace. Per [RFC 9051 Section 6.3.9](https://datatracker.ietf.org/doc/html/rfc9051#section-6.3.9),
        /// this attribute implies `\HasNoChildren`. See [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
        public static var noInferiors: Self { Self(#"\Noinferiors"#) }

        /// The mailbox has been subscribed to by the user.
        ///
        /// The `\Subscribed` attribute is reported in response to `LSUB` commands, indicating
        /// that the user has explicitly subscribed to this mailbox for display in the client UI.
        /// See [RFC 3501 Section 6.3.9](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.9).
        public static var subscribed: Self { Self(#"\Subscribed"#) }

        /// The mailbox is located on a remote server.
        ///
        /// The `\Remote` attribute indicates that the mailbox exists on a different IMAP server
        /// than the one handling the connection. See [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
        public static var remote: Self { Self(#"\Remote"#) }

        /// The mailbox has child mailboxes in the hierarchy.
        ///
        /// The `\HasChildren` attribute indicates that the mailbox has one or more child mailboxes
        /// in the hierarchical namespace. See [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
        public static var hasChildren: Self { Self(#"\HasChildren"#) }

        /// The mailbox does not have any child mailboxes.
        ///
        /// The `\HasNoChildren` attribute indicates that, at the time of the `LIST` response,
        /// the mailbox has no child mailboxes. Note that this does not guarantee the mailbox
        /// cannot have children in the future. See [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
        public static var hasNoChildren: Self { Self(#"\HasNoChildren"#) }

        fileprivate var backing: String

        /// Creates a new attribute with the specified name.
        ///
        /// Use the static properties (``noSelect``, ``marked``, etc.) for standard attributes
        /// or create custom attributes for extension or server-specific attributes.
        /// Attribute names are case-insensitive per the IMAP specification.
        ///
        /// - Parameter str: The attribute name, typically starting with backslash (for example, "\\Noselect")
        public init(_ str: String) {
            self.backing = str
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.backing.lowercased() == rhs.backing.lowercased()
        }

        public func hash(into hasher: inout Hasher) {
            self.backing.lowercased().hash(into: &hasher)
        }

        /// Returns whether this attribute implies another attribute per [RFC 9051 Section 6.3.9.4](https://datatracker.ietf.org/doc/html/rfc9051#section-6.3.9.4).
        ///
        /// The following inference rules are defined:
        ///
        /// | Returned Attribute | Implied Attribute |
        /// |--------------------|-------------------|
        /// | `\NoInferiors`     | `\HasNoChildren`  |
        /// | `\NonExistent`     | `\NoSelect`       |
        public func implies(_ other: Self) -> Bool {
            switch (self, other) {
            case (.noInferiors, .hasNoChildren), (.nonExistent, .noSelect):
                true
            default:
                false
            }
        }
    }
}

extension String {
    /// The raw attribute name as a string.
    ///
    /// Returns the attribute name in its original format. The backing storage is always lowercase
    /// for consistency with IMAP's case-insensitive attribute names.
    public init(_ other: MailboxInfo.Attribute) {
        self = other.backing
    }
}

extension Sequence where Element == MailboxInfo.Attribute {
    /// Returns whether this sequence contains a given attribute either directly or by implication,
    /// per [RFC 9051 Section 6.3.9.4](https://datatracker.ietf.org/doc/html/rfc9051#section-6.3.9.4).
    ///
    /// The following inference rules are defined:
    ///
    /// | Returned Attribute | Implied Attribute |
    /// |--------------------|-------------------|
    /// | `\NoInferiors`     | `\HasNoChildren`  |
    /// | `\NonExistent`     | `\NoSelect`       |
    public func containsEffective(_ attribute: MailboxInfo.Attribute) -> Bool {
        contains { $0 == attribute || $0.implies(attribute) }
    }
}

extension MailboxInfo {
    /// Returns whether this mailbox's attributes include a given attribute either directly
    /// or by implication, per [RFC 9051 Section 6.3.9.4](https://datatracker.ietf.org/doc/html/rfc9051#section-6.3.9.4).
    ///
    /// The following inference rules are defined:
    ///
    /// | Returned Attribute | Implied Attribute |
    /// |--------------------|-------------------|
    /// | `\NoInferiors`     | `\HasNoChildren`  |
    /// | `\NonExistent`     | `\NoSelect`       |
    public func hasEffectiveAttribute(_ attribute: Attribute) -> Bool {
        attributes.containsEffective(attribute)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    private mutating func writeMailboxPathSeparator(_ character: Character?) -> Int {
        switch character {
        case nil:
            return self.writeNil()
        case "\\":
            return self.writeString(#""\""#)
        case "\"":
            return self.writeString(#""\\""#)
        case let character?:
            return self.writeString("\"\(character)\"")
        }
    }

    @discardableResult mutating func writeMailboxInfo(_ list: MailboxInfo) -> Int {
        self.writeString("(")
            + self.writeIfExists(list.attributes) { (flags) -> Int in
                self.writeMailboxListFlags(flags)
            } + self.writeString(") ") + self.writeMailboxPathSeparator(list.path.pathSeparator) + self.writeSpace()
            + self.writeMailbox(list.path.name)
    }

    @discardableResult mutating func writeMailboxListFlags(_ flags: [MailboxInfo.Attribute]) -> Int {
        self.writeArray(flags, parenthesis: false) { (element, self) in
            self.writeString(element.backing)
        }
    }
}
