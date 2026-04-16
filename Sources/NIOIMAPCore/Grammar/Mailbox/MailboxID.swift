//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A permanent server-assigned identifier for a mailbox.
///
/// ``MailboxID`` represents a stable, unique identifier assigned by the server to identify
/// a mailbox. Unlike mailbox names (which can be changed by renaming), a ``MailboxID`` persists
/// across the lifetime of the mailbox.
///
/// The `OBJECTID` extension defines mailbox identifiers following
/// [RFC 8474 Section 2](https://datatracker.ietf.org/doc/html/rfc8474#section-2).
/// Valid mailbox IDs are 1-255 alphanumeric characters plus hyphens and underscores.
///
/// ``MailboxID`` is returned as part of ``MailboxStatus`` when the `MAILBOXID` attribute is requested
/// in a `STATUS` command, or as part of the `NOTIFY` extension when monitoring mailbox changes.
///
/// **Requires server capability:** ``Capability/objectID``
///
/// - SeeAlso: ``MailboxStatus``, [RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474)
public struct MailboxID: Hashable, Sendable {
    fileprivate var objectID: ObjectID

    /// Creates a new mailbox ID from an `ObjectID`.
    ///
    /// This initializer is used internally to wrap an ``ObjectID`` as a ``MailboxID``.
    /// Prefer using ``init(_:)-6p8xp`` with a string for public API usage.
    ///
    /// - Parameter objectID: The underlying ``ObjectID`` value
    init(_ objectID: ObjectID) {
        self.objectID = objectID
    }

    /// Creates a new mailbox ID from a string.
    ///
    /// Valid mailbox IDs are 1-255 characters consisting of alphanumeric characters, hyphens, and underscores,
    /// following [RFC 8474 Section 2](https://datatracker.ietf.org/doc/html/rfc8474#section-2).
    ///
    /// - Parameter rawValue: The mailbox ID string to parse
    /// - Returns: A new ``MailboxID`` if the string is valid, or `nil` if it contains invalid characters
    public init?(_ rawValue: String) {
        guard let objectID = ObjectID(rawValue) else {
            return nil
        }

        self.init(objectID)
    }
}

extension String {
    /// Creates a new string from a mailbox ID.
    ///
    /// Returns the mailbox ID value as a string suitable for protocol transmission.
    ///
    /// - Parameter mailboxID: The mailbox ID to convert
    public init(_ mailboxID: MailboxID) {
        self = String(mailboxID.objectID)
    }
}

// MARK: - ExpressibleByStringLiteral

/// A ``MailboxID`` can be created using string literals.
///
/// String literals are validated at initialization time. Invalid characters will cause a fatal error.
/// Use the failable initializer ``init(_:)-6p8xp`` to handle invalid IDs gracefully.
extension MailboxID: ExpressibleByStringLiteral {
    /// Creates a new mailbox ID from a string literal.
    ///
    /// - Parameter value: The string literal value
    /// - Fatal error: If the string contains invalid characters
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)!
    }
}

// MARK: - CustomDebugStringConvertible

extension MailboxID: CustomDebugStringConvertible {
    /// A debug string representation showing the mailbox ID value in parentheses.
    ///
    /// - Returns: The mailbox ID value as a string, wrapped in parentheses
    public var debugDescription: String {
        "(\(String(self)))"
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxID(_ id: MailboxID) -> Int {
        self.writeObjectID(id.objectID)
    }
}
