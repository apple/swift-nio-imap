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

public enum StoreAttributeFlagsType: String, Equatable {
    case add = "+"
    case remove = "-"
    case other = ""
}

public struct StoreAttributeFlags: Equatable {
    public static func add(silent: Bool, list: [Flag]) -> Self {
        Self(type: .add, silent: silent, flags: list)
    }

    public static func remove(silent: Bool, list: [Flag]) -> Self {
        Self(type: .remove, silent: silent, flags: list)
    }

    public static func other(silent: Bool, list: [Flag]) -> Self {
        Self(type: .other, silent: silent, flags: list)
    }

    public var type: StoreAttributeFlagsType
    public var silent: Bool
    public var flags: [Flag]
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeStoreAttributeFlags(_ flags: StoreAttributeFlags) -> Int {
        let silentString = flags.silent ? ".SILENT" : ""
        return
            self.writeString("\(flags.type.rawValue)FLAGS\(silentString) ") +
            self.writeFlags(flags.flags)
    }
}
