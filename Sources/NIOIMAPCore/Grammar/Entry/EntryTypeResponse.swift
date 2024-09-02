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

/// Describes the metadata item type.
public struct EntryKindResponse: Hashable, Sendable {
    fileprivate var backing: String

    /// `priv` - Private metadata item type.
    public static let `private` = Self(backing: "priv")

    /// `shared` - Shared metadata item type.
    public static let shared = Self(backing: "shared")
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEntryKindResponse(_ response: EntryKindResponse) -> Int {
        self.writeString(response.backing)
    }
}
