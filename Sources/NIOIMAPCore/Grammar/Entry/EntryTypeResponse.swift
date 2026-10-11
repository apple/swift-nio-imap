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
/// ```
/// entry-type-resp = "priv" / "shared"
/// ```
///
/// - See ``EntryKindRequest``, which adds `all`
///
/// - SeeAlso: [RFC 7162 Section 3.1.5](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.5)
public struct EntryKindResponse: Hashable, Sendable {
    fileprivate var backing: String

    /// `priv`: private metadata items (visible only to the authenticated user).
    public static let `private` = Self(backing: "priv")

    /// `shared`: shared metadata items (visible to all users).
    public static let shared = Self(backing: "shared")
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryKindResponse(_ response: EntryKindResponse) -> Int {
        self.writeString(response.backing)
    }
}
