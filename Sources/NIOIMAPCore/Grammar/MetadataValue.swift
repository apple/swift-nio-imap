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

/// A metadata entry value returned from a `GETMETADATA` command or set with `SETMETADATA` (RFC 5464).
///
/// **Requires server capability:** ``Capability/metadata`` or ``Capability/metadataServer``
///
/// Metadata values can be any octet string or `nil` (representing a non-existent or deleted entry).
/// Values are stored and retrieved as binary data, though their interpretation is application-specific.
/// A `nil` value represents either a non-existent entry or an entry that has been deleted.
/// See [RFC 5464 Section 4.4.1](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4.1).
///
/// ### Example
///
/// ```
/// C: A001 GETMETADATA "INBOX" ("/shared/comment" "/private/notes")
/// S: * METADATA "INBOX" ("/shared/comment" "Team folder" "/private/notes" NIL)
/// S: A001 OK GETMETADATA completed
/// ```
///
/// The values in the response are ``MetadataValue`` instances:
/// - `MetadataValue(ByteBuffer("Team folder"))` for `/shared/comment`
/// - `MetadataValue(nil)` for `/private/notes` (not set or deleted)
///
/// ## Related Types
///
/// - See ``MetadataEntryName`` for entry names
/// - See ``MetadataResponse`` for complete metadata responses
/// - See ``MetadataOption`` for metadata query options
///
/// - SeeAlso: [RFC 5464 Section 4.4.1](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4.1)
public struct MetadataValue: Hashable, Sendable {
    /// The raw value bytes, or `nil` if the entry is not set or has been deleted.
    ///
    /// Contains the raw octet sequence representing the metadata value. When `nil`, the entry
    /// either does not exist or has been explicitly deleted via `SETMETADATA`.
    public let bytes: ByteBuffer?

    /// Creates a new `MetadataValue` with optional raw bytes.
    ///
    /// - parameter bytes: The raw value bytes, or `nil` for non-existent/deleted entries.
    public init(_ bytes: ByteBuffer?) {
        self.bytes = bytes
    }
}

extension MetadataValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.bytes = nil
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMetadataValue(_ value: MetadataValue) -> Int {
        guard let bytes = value.bytes else {
            return self.writeNil()
        }
        return self.writeLiteral8(bytes.readableBytesView)
    }
}
