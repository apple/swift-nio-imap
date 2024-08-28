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

/// Specifies which type of metadata item to perform a search on.
public struct EntryKindRequest: Hashable, Sendable {
    fileprivate var backing: String

    /// Search private metadata items.
    public static let `private` = Self(backing: "priv")

    /// Search shared metadata items.
    public static let shared = Self(backing: "shared")

    /// The server should use the largest value among `.private` and `.shared` mod-sequences
    /// for the metadata item.
    public static let all = Self(backing: "all")
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryKindRequest(_ request: EntryKindRequest) -> Int {
        self.writeString(request.backing)
    }
}
