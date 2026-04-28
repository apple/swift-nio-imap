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

/// Specifies which type of metadata entries to query in `GETMETADATA` commands (RFC 5464).
///
/// **Requires server capability:** ``Capability/metadata`` or ``Capability/metadataServer``
///
/// Entry kind options determine whether metadata operations target private entries (visible only
/// to the authenticated user), shared entries (visible to all users), or both. This allows clients
/// to restrict metadata queries to specific visibility scopes. See [RFC 5464 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5464#section-3.3).
///
/// ### Example
///
/// ```
/// C: A001 GETMETADATA (DEPTH 0) "INBOX" ALL ("/flags/\\Seen")
/// S: * METADATA "INBOX" ("/flags/\\Seen" "12345")
/// S: A001 OK GETMETADATA completed
/// ```
///
/// The `ALL` option in the command queries modification sequences for the specified flags,
/// considering both private and shared metadata sources.
///
/// ## Related types
///
/// - See ``EntryKindResponse`` for server-returned entry type information
/// - See ``MetadataOption`` for other metadata query options
/// - See ``EntryFlagName`` for flag entry names
///
/// - SeeAlso: [RFC 5464 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5464#section-3.3)
public struct EntryKindRequest: Hashable, Sendable {
    fileprivate var backing: String

    /// Search or retrieve private metadata items (visible only to the authenticated user).
    ///
    /// Targets entries in the `/private/` namespace. From [RFC 5464 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5464#section-3.3).
    public static let `private` = Self(backing: "priv")

    /// Search or retrieve shared metadata items (visible to all users).
    ///
    /// Targets entries in the `/shared/` namespace. From [RFC 5464 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5464#section-3.3).
    public static let shared = Self(backing: "shared")

    /// Search or retrieve both private and shared metadata items.
    ///
    /// For modification sequence tracking, returns the largest modification sequence value
    /// across both private and shared entry types. From [RFC 5464 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5464#section-3.3).
    public static let all = Self(backing: "all")
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryKindRequest(_ request: EntryKindRequest) -> Int {
        self.writeString(request.backing)
    }
}
