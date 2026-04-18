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

/// Describes the metadata item type returned by the server in metadata responses (RFC 5464).
///
/// **Requires server capability:** ``Capability/metadata`` or ``Capability/metadataServer``
///
/// Entry kind response indicates whether a metadata entry belongs to the private namespace
/// (visible only to the authenticated user) or the shared namespace (visible to all users).
/// This information is returned by the server when responding to metadata queries.
/// See [RFC 5464 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5464#section-3.3).
///
/// ### Example
///
/// ```
/// C: A001 GETMETADATA "INBOX" ("/flags/\\Seen")
/// S: * METADATA "INBOX" (priv "/flags/\\Seen" "12345")
/// S: A001 OK GETMETADATA completed
/// ```
///
/// The response includes the entry type `priv` to indicate that the `/flags/\Seen` modification
/// sequence metadata is private to the authenticated user.
///
/// ## Related Types
///
/// - See ``EntryKindRequest`` for client-side entry type specification
/// - See ``MetadataResponse`` for complete metadata responses
/// - See ``EntryFlagName`` for flag entry names
///
/// - SeeAlso: [RFC 5464 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5464#section-3.3)
public struct EntryKindResponse: Hashable, Sendable {
    fileprivate var backing: String

    /// Private metadata item type (visible only to the authenticated user).
    ///
    /// Indicates that the metadata entry is in the `/private/` namespace and is not visible
    /// to other users. From [RFC 5464 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5464#section-3.3).
    public static let `private` = Self(backing: "priv")

    /// Shared metadata item type (visible to all users).
    ///
    /// Indicates that the metadata entry is in the `/shared/` namespace and is visible
    /// to any user with access to the mailbox. From [RFC 5464 Section 3.3](https://datatracker.ietf.org/doc/html/rfc5464#section-3.3).
    public static let shared = Self(backing: "shared")
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryKindResponse(_ response: EntryKindResponse) -> Int {
        self.writeString(response.backing)
    }
}
