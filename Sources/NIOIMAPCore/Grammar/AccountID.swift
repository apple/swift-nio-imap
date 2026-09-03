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

/// A server-assigned identifier for the account that owns a mailbox.
///
/// An `AccountID` identifies the account to which a mailbox belongs. When used alongside
/// ``MailboxID``, it fully disambiguates mailboxes in environments where multiple accounts
/// are accessible through a single IMAP session (for example, shared mailboxes or "Other
/// Users" namespaces).
///
/// Valid `AccountID` values are 1-255 alphanumeric characters, hyphens, or underscores.
/// The server MUST return the same `AccountID` for all mailboxes that belong to the same
/// account, and MUST NOT return the same `AccountID` for mailboxes belonging to different
/// accounts.
///
/// **Requires server capability:** ``Capability/objectIDPlus``
///
/// - SeeAlso: ``CompoundObjectID``
public struct AccountID: Hashable, Sendable {
    fileprivate var objectID: ObjectID

    /// Creates a new `AccountID` from an `ObjectID`.
    init(_ objectID: ObjectID) {
        self.objectID = objectID
    }

    /// Creates a new `AccountID` from a `String`.
    ///
    /// Valid account IDs are 1-255 alphanumeric or `-` or `_` characters.
    ///
    /// - Parameter rawValue: A candidate account ID string value
    /// - Returns: An `AccountID` if the string is valid, or `nil` if it fails validation
    public init?(_ rawValue: String) {
        guard let objectID = ObjectID(rawValue) else {
            return nil
        }

        self.init(objectID)
    }
}

extension String {
    public init(_ accountID: AccountID) {
        self = String(accountID.objectID)
    }
}

// MARK: - ExpressibleByStringLiteral

extension AccountID: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)!
    }
}

// MARK: - CustomDebugStringConvertible

extension AccountID: CustomDebugStringConvertible {
    /// `value` as a `String`.
    public var debugDescription: String {
        "(\(String(self)))"
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAccountID(_ id: AccountID) -> Int {
        self.writeObjectID(id.objectID)
    }
}
