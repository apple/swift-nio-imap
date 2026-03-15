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

/// A persistent object identifier for related messages.
///
/// A `ThreadID` is a server-assigned, immutable identifier that uniquely identifies a set of messages
/// the server believes should be grouped together when presented to the user. Typically based on a
/// combination of `References`, `In-Reply-To`, and `Subject` headers, the `ThreadID` allows clients
/// to recognize related messages across mailboxes without implementing their own threading logic.
///
/// Valid `ThreadID` values are 1-255 alphanumeric characters, hyphens, or underscores.
/// The server MUST return the same `ThreadID` for all messages with the same ``EmailID``, and
/// SHOULD return the same `ThreadID` for related messages even if they are in different mailboxes.
/// The server MUST NOT change the `ThreadID` once assigned.
///
/// If the server does not support threading, it MUST return `nil` for all FETCH requests for the
/// `THREADID` data item.
///
/// **Requires server capability:** ``Capability/objectID``
///
/// ### Example
///
/// ```
/// C: A001 UID FETCH 1:3 (THREADID)
/// S: * 1 FETCH (UID 1 THREADID (abc123def456))
/// S: * 2 FETCH (UID 2 THREADID (abc123def456))
/// S: * 3 FETCH (UID 3 THREADID (xyz789abc123))
/// S: A001 OK Completed
/// ```
///
/// Messages 1 and 2 have the same `THREADID (abc123def456)`, indicating they are related.
/// Message 3 has a different `THREADID (xyz789abc123)`, indicating it belongs to a different thread.
///
/// ## Related Proprietary Identifiers
///
/// Gmail servers provide a similar but proprietary identifier via the `X-GM-THRID` field (see
/// ``MessageAttribute.gmailThreadID(_:)``). While both serve similar purposes, `THREADID` is
/// the standardized RFC 8474 alternative for cross-server compatibility.
///
/// - SeeAlso: [RFC 8474 Section 5.2](https://datatracker.ietf.org/doc/html/rfc8474#section-5.2), ``EmailID``, ``ObjectID``
public struct ThreadID: Hashable, Sendable {
    fileprivate var objectID: ObjectID

    /// Creates a new `ThreadID` from an `ObjectID`.
    init(_ objectID: ObjectID) {
        self.objectID = objectID
    }

    /// Creates a new `ThreadID` from a `String`.
    ///
    /// Valid thread IDs are 1-255 alphanumeric or `-` or `_` characters.
    ///
    /// - Parameter rawValue: A candidate thread ID string value
    /// - Returns: A `ThreadID` if the string is valid, or `nil` if it fails validation
    public init?(_ rawValue: String) {
        guard let objectID = ObjectID(rawValue) else {
            return nil
        }

        self.init(objectID)
    }
}

extension String {
    public init(_ threadID: ThreadID) {
        self = String(threadID.objectID)
    }
}

// MARK: - ExpressibleByStringLiteral

extension ThreadID: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)!
    }
}

// MARK: - CustomDebugStringConvertible

extension ThreadID: CustomDebugStringConvertible {
    /// `value` as a `String`.
    public var debugDescription: String {
        "(\(String(self)))"
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeThreadID(_ id: ThreadID) -> Int {
        self.writeObjectID(id.objectID)
    }
}
