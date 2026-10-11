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

/// The metadata item type of a flag's modification sequence (RFC 7162 `entry-type-resp`).
///
/// **Requires server capability:** ``Capability/condStore``
///
/// A flag's modification sequence can be tracked separately for private (per-user) and shared
/// metadata items. This names one of the two:
/// ```
/// entry-type-resp = "priv" / "shared"
/// ```
///
/// It is not sent on its own. It is the `priv` / `shared` part of an ``EntryKindRequest``,
/// which adds `all`.
///
/// ### Example
///
/// ```
/// C: a SEARCH MODSEQ "/flags/\\draft" priv 620162338
/// S: * SEARCH 2 5 6 7 11 12 18 19 20 23 (MODSEQ 917162500)
/// S: a OK Search complete
/// ```
///
/// The `priv` after the entry name is ``EntryKindResponse/private``.
///
/// ## Related types
///
/// - See ``EntryKindRequest``, which adds `all`
/// - See ``EntryFlagName`` for the `"/flags/…"` entry name
/// - See ``SearchModificationSequence`` for the `MODSEQ` criterion
///
/// - SeeAlso: [RFC 7162 Section 3.1.5](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.5)
public struct EntryKindResponse: Hashable, Sendable {
    fileprivate var backing: String

    /// `priv`: private metadata items (visible only to the authenticated user).
    ///
    /// Modification sequences tracked per user.
    public static let `private` = Self(backing: "priv")

    /// `shared`: shared metadata items (visible to all users).
    ///
    /// Modification sequences tracked for everyone with access to the mailbox.
    public static let shared = Self(backing: "shared")
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryKindResponse(_ response: EntryKindResponse) -> Int {
        self.writeString(response.backing)
    }
}
