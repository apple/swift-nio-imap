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

/// A persistent server-assigned object identifier.
///
/// An `ObjectID` is the base type for RFC 8474 object identifiers, which provide persistent,
/// immutable identifiers for mailboxes and messages. This is an internal type used to share
/// code between the stronger public types ``EmailID`` (for message content), ``ThreadID``
/// (for related messages), and ``MailboxID`` (for mailboxes).
///
/// Valid `ObjectID` values are 1-255 alphanumeric characters, hyphens, or underscores, ensuring
/// they can be safely transmitted in IMAP protocol messages.
///
/// - SeeAlso: [RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474)
internal struct ObjectID: Hashable, Sendable {
    /// The `String` representation.
    fileprivate var rawValue: String

    /// Creates a new `ObjectID` from a `String`.
    ///
    /// Valid Object IDs are 1-255 alphanumeric or `-` or `_` characters.
    ///
    /// - Parameter rawValue: A candidate object ID string value
    /// - Returns: An `ObjectID` if the string is valid, or `nil` if it fails validation
    init?(_ rawValue: String) {
        guard (1...255).contains(rawValue.count) else {
            return nil
        }
        guard rawValue.utf8.allSatisfy({ $0.isObjectIDChar }) else {
            return nil
        }

        self.rawValue = rawValue
    }
}

extension String {
    internal init(_ objectID: ObjectID) {
        self = objectID.rawValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeObjectID(_ id: ObjectID) -> Int {
        self.writeString("\(id.rawValue)")
    }
}
