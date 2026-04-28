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

/// A persistent object identifier for message content.
///
/// An `EmailID` is a server-assigned, immutable identifier that uniquely identifies the immutable
/// content of a single message. It persists across mailboxes and remains the same even after
/// COPY or MOVE operations, allowing clients to quickly identify identical messages without
/// redownloading content.
///
/// Valid `EmailID` values are 1-255 alphanumeric characters, hyphens, or underscores.
/// The server MUST return the same `EmailID` for identical message content and MUST return the
/// same `EmailID` as the source message for the matching destination in COPYUID pairings.
///
/// **Requires server capability:** ``Capability/objectID``
///
/// ### Example
///
/// ```
/// C: A001 UID FETCH 1 (EMAILID)
/// S: * 1 FETCH (UID 1 EMAILID (550e8400-e29b-41d4-a716-446655440000))
/// S: A001 OK Completed
/// ```
///
/// The `EMAILID (550e8400-e29b-41d4-a716-446655440000)` is the persistent content identifier
/// for this message. If copied to another mailbox, the copied message will receive the same
/// `EMAILID`, allowing clients to recognize the messages as identical content.
///
/// ## Related proprietary identifiers
///
/// Gmail servers provide a similar but proprietary identifier via the `X-GM-MSGID` field (see
/// ``FetchAttribute/gmailMessageID``). While both serve similar purposes, `EMAILID` is
/// the standardized RFC 8474 alternative for cross-server compatibility.
///
/// - SeeAlso: [RFC 8474 Section 5.1](https://datatracker.ietf.org/doc/html/rfc8474#section-5.1), ``ThreadID``
public struct EmailID: Hashable, Sendable {
    fileprivate var objectID: ObjectID

    /// Creates a new `EmailID` from an `ObjectID`.
    init(_ objectID: ObjectID) {
        self.objectID = objectID
    }

    /// Creates a new `EmailID` from a `String`.
    ///
    /// Valid email IDs are 1-255 alphanumeric or `-` or `_` characters.
    ///
    /// - Parameter rawValue: A candidate email ID string value
    /// - Returns: An `EmailID` if the string is valid, or `nil` if it fails validation
    public init?(_ rawValue: String) {
        guard let objectID = ObjectID(rawValue) else {
            return nil
        }

        self.init(objectID)
    }
}

extension String {
    public init(_ emailID: EmailID) {
        self = String(emailID.objectID)
    }
}

// MARK: - ExpressibleByStringLiteral

extension EmailID: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)!
    }
}

// MARK: - CustomDebugStringConvertible

extension EmailID: CustomDebugStringConvertible {
    /// `value` as a `String`.
    public var debugDescription: String {
        "(\(String(self)))"
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEmailID(_ id: EmailID) -> Int {
        self.writeObjectID(id.objectID)
    }
}
