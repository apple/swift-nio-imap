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

import NIO

/// A metadata entry name used with `GETMETADATA` and `SETMETADATA` commands (RFC 5464).
///
/// **Requires server capability:** ``Capability/metadata`` or ``Capability/metadataServer``
///
/// Metadata entry names identify specific metadata entries on a mailbox or server. Entry names are
/// hierarchical paths similar to mailbox names, using `/` as a separator. Standard entries begin with
/// `/shared/` or `/private/` to indicate whether the entry is shared among users or private to the user.
/// See [RFC 5464 Section 3.2.1](https://datatracker.ietf.org/doc/html/rfc5464#section-3.2.1).
///
/// ### Example
///
/// ```
/// C: A001 GETMETADATA "INBOX" ("/shared/comment" "/private/notes")
/// S: * METADATA "INBOX" ("/shared/comment" "This is the inbox" "/private/notes" NIL)
/// S: A001 OK GETMETADATA completed
/// ```
///
/// The entry names `"/shared/comment"` and `"/private/notes"` represent ``MetadataEntryName`` values
/// in the ``MetadataResponse/values(values:mailbox:)`` response. They appear in ``Response/untagged(_:)``
/// containing ``ResponsePayload/metadata(_:)``.
///
/// ## Related types
///
/// - See ``MetadataValue`` for metadata entry values
/// - See ``MetadataResponse`` for complete metadata responses
/// - See ``MetadataOption`` for options in metadata commands
///
/// - SeeAlso: [RFC 5464 Section 3.2.1](https://datatracker.ietf.org/doc/html/rfc5464#section-3.2.1)
public struct MetadataEntryName: Hashable, Sendable {
    fileprivate var backing: ByteBuffer

    /// Creates a `MetadataEntryName` from a `ByteBuffer`.
    ///
    /// - parameter buffer: The raw `ByteBuffer` containing the entry name bytes.
    public init(_ buffer: ByteBuffer) {
        self.backing = buffer
    }

    /// Creates a `MetadataEntryName` from a `String`.
    ///
    /// - parameter string: The entry name as a string (for example, `"/shared/comment"` or `"/private/notes"`).
    public init(_ string: String) {
        self.backing = ByteBuffer(string: string)
    }
}

extension String {
    /// Creates a `String` from a `MetadataEntryName`.
    ///
    /// - parameter metadataEntryName: The entry name to convert.
    public init(_ metadataEntryName: MetadataEntryName) {
        self = String(buffer: metadataEntryName.backing)
    }
}

extension MetadataEntryName: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self.backing = ByteBuffer(string: value)
    }
}
