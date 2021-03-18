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
public struct EntryKindResponse: Equatable {
    var _backing: String

    /// `priv` - Private metadata item type.
    public static var `private` = Self(_backing: "priv")

    /// `shared` - Shared metadata item type.
    public static var shared = Self(_backing: "shared")
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeEntryKindResponse(_ response: EntryKindResponse) -> Int {
        self._writeString(response._backing)
    }
}
