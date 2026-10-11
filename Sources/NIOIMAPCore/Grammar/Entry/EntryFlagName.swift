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

/// The flag whose modification sequence a `SEARCH MODSEQ` criterion tests (RFC 7162 `entry-flag-name`).
///
/// **Requires server capability:** ``Capability/condStore``
///
/// Wraps an ``AttributeFlag`` as an entry name in the `/flags/` namespace:
/// ```
/// entry-flag-name = DQUOTE "/flags/" attr-flag DQUOTE
/// ```
///
/// ### Example
///
/// ```
/// C: a SEARCH MODSEQ "/flags/\\draft" all 620162338
/// S: * SEARCH 2 5 6 7 11 12 18 19 20 23 (MODSEQ 917162500)
/// S: a OK Search complete
/// ```
///
/// The entry name `"/flags/\\draft"` is an ``EntryFlagName`` wrapping the ``AttributeFlag`` `\draft`.
///
/// ## Related types
///
/// - See ``AttributeFlag`` for the flag
/// - See ``EntryKindRequest`` for the `priv` / `shared` / `all` that follows
/// - See ``SearchModificationSequence`` for the `MODSEQ` criterion
///
/// - SeeAlso: [RFC 7162 Section 3.1.5](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.5)
public struct EntryFlagName: Hashable, Sendable {
    /// The flag wrapped as a metadata entry.
    ///
    /// Represents a system flag (for example, `\Seen`, `\Flagged`, or `\Deleted`) in metadata entry form.
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
