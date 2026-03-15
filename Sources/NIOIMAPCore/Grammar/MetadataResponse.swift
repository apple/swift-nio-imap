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

/// Response data sent by a server in reply to a `GETMETADATA` command (RFC 5464).
///
/// **Requires server capability:** ``Capability/metadata`` or ``Capability/metadataServer``
///
/// The `METADATA` response contains either requested metadata entry values or a list of available entries.
/// The response type depends on whether the client requested specific entry names or a list of entries.
/// See [RFC 5464 Section 4.4](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4).
///
/// ### Example
///
/// ```
/// C: A001 GETMETADATA "INBOX" ("/shared/comment")
/// S: * METADATA "INBOX" ("/shared/comment" "Team discussion folder")
/// S: A001 OK GETMETADATA completed
/// ```
///
/// The line `* METADATA "INBOX" (...)` is wrapped as ``Response/untagged(_:)`` containing
/// ``ResponsePayload/metadataData(_:)`` with a ``MetadataResponse/values(values:mailbox:)`` case.
/// Each entry name maps to a ``MetadataValue`` (which may be `nil` if not found).
///
/// ## Related Types
///
/// - See ``MetadataEntryName`` for entry name representation
/// - See ``MetadataValue`` for entry values
/// - See ``MetadataOption`` for query options
///
/// - SeeAlso: [RFC 5464 Section 4.4](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4)
public enum MetadataResponse: Hashable, Sendable {
    /// Metadata entries with their values for a specific mailbox.
    ///
    /// Contains an ordered dictionary mapping entry names to their values. Values may be `nil`
    /// if the entry does not exist. From [RFC 5464 Section 4.4.1](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4.1).
    case values(values: OrderedDictionary<MetadataEntryName, MetadataValue>, mailbox: MailboxName)

    /// A list of available metadata entry names for a mailbox.
    ///
    /// Provides a catch-all for future extensions that return a list of available entries
    /// without their values. From [RFC 5464 Section 4.4.2](https://datatracker.ietf.org/doc/html/rfc5464#section-4.4.2).
    case list(list: [MetadataEntryName], mailbox: MailboxName)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMetadataResponse(_ resp: MetadataResponse) -> Int {
        switch resp {
        case .values(values: let values, mailbox: let mailbox):
            return self.writeString("METADATA ") + self.writeMailbox(mailbox) + self.writeSpace()
                + self.writeEntryValues(values)
        case .list(list: let list, mailbox: let mailbox):
            return self.writeString("METADATA ") + self.writeMailbox(mailbox) + self.writeSpace()
                + self.writeEntryList(list)
        }
    }
}
