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

public struct StoreFlags: Equatable {
    /// What operation to perform on the flags.
    public enum Operation: String, Equatable {
        /// Add to the flags for the message.
        case add = "+"
        /// Remove from the flags for the message.
        case remove = "-"
        /// Replace the flags for the message (other than \Recent).
        case replace = ""
    }

    public static func add(silent: Bool, list: [Flag]) -> Self {
        Self(operation: .add, silent: silent, flags: list)
    }

    public static func remove(silent: Bool, list: [Flag]) -> Self {
        Self(operation: .remove, silent: silent, flags: list)
    }

    public static func replace(silent: Bool, list: [Flag]) -> Self {
        Self(operation: .replace, silent: silent, flags: list)
    }

    public var operation: Operation
    public var silent: Bool
    public var flags: [Flag]
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeStoreAttributeFlags(_ flags: StoreFlags) -> Int {
        let silentString = flags.silent ? ".SILENT" : ""
        return
            self.writeString("\(flags.operation.rawValue)FLAGS\(silentString) ") +
            self.writeFlags(flags.flags)
    }
}
