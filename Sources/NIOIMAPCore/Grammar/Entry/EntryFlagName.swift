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

/// A metadata entry name for a system flag used with metadata operations (RFC 5464).
///
/// **Requires server capability:** ``Capability/metadata`` or ``Capability/metadataServer``
///
/// This type wraps an ``AttributeFlag`` to represent it as a metadata entry name in the special
/// `/flags/` namespace. Flag entries allow metadata operations on flag modification sequences
/// through the entry name format `/flags/flagname`. See [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464)
/// for details on metadata entry organization.
///
/// ### Example
///
/// ```
/// C: A001 GETMETADATA "INBOX" DEPTH 0 ("/flags/\\Seen")
/// S: * METADATA "INBOX" ("/flags/\\Seen" "12345")
/// S: A001 OK GETMETADATA completed
/// ```
///
/// The entry name `/flags/\Seen` is represented using ``EntryFlagName`` wrapping the
/// ``AttributeFlag`` for `\Seen`. The value `12345` is the modification sequence for that flag.
///
/// ## Related Types
///
/// - See ``AttributeFlag`` for system flag representation
/// - See ``MetadataEntryName`` for general metadata entry names
/// - See ``SearchModificationSequence`` for flag modification sequences in search operations
///
/// - SeeAlso: [RFC 5464](https://datatracker.ietf.org/doc/html/rfc5464)
public struct EntryFlagName: Hashable, Sendable {
    /// The flag wrapped as a metadata entry.
    ///
    /// Represents a system flag (e.g., `\Seen`, `\Flagged`, `\Deleted`) in metadata entry form.
    public var flag: AttributeFlag

    /// Creates a new `EntryFlagName` wrapping an `AttributeFlag`.
    ///
    /// - parameter flag: The flag to wrap as a metadata entry.
    public init(flag: AttributeFlag) {
        self.flag = flag
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryFlagName(_ name: EntryFlagName) -> Int {
        self.writeString("\"/flags/") + self.writeAttributeFlag(name.flag) + self.writeString("\"")
    }
}
