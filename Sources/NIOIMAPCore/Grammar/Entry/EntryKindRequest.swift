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

/// Which metadata items a `SEARCH MODSEQ` criterion considers (RFC 7162 `entry-type-req`).
///
/// **Requires server capability:** ``Capability/condStore``
///
/// A flag's modification sequence can be tracked separately for private (per-user) and shared
/// metadata items. This selects which of them the `MODSEQ` criterion compares against:
/// ```
/// entry-type-req  = entry-type-resp / "all"
/// entry-type-resp = "priv" / "shared"
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
/// `all` is ``EntryKindRequest/all``: the larger of the private and shared modification sequences.
///
/// ## Related types
///
/// - See ``EntryFlagName`` for the `"/flags/…"` entry name
/// - See ``SearchModificationSequence`` for the `MODSEQ` criterion
///
/// - SeeAlso: [RFC 7162 Section 3.1.5](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.5)
public struct EntryKindRequest: Hashable, Sendable {
    fileprivate var backing: String

    /// `priv`: private metadata items (visible only to the authenticated user).
    public static let `private` = Self(backing: "priv")

    /// `shared`: shared metadata items (visible to all users).
    public static let shared = Self(backing: "shared")

    /// `all`: both; the larger of the two modification sequences is used.
    public static let all = Self(backing: "all")
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryKindRequest(_ request: EntryKindRequest) -> Int {
        self.writeString(request.backing)
    }
}
