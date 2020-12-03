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

/// Defines if certain flags should be added, removed, or replaced.
public struct StoreFlags: Hashable {
    
    /// What operation to perform on the flags.
    public enum Operation: String, Hashable {
    
        /// Add to the flags for the message.
        case add = "+"
        
        /// Remove from the flags for the message.
        case remove = "-"
        
        /// Replace the flags for the message (other than \Recent).
        case replace = ""
    }

    /// Convenience function to create a new *add* operation.
    /// - parameter silent: `false` of the server should return the new flags list for the message(s), otherwise `true`.
    /// - parameter list: The `Flag`s to add.
    /// - returns: A new `StoreFlags`
    public static func add(silent: Bool, list: [Flag]) -> Self {
        Self(operation: .add, silent: silent, flags: list)
    }

    /// Convenience function to create a new *remove* operation.
    /// - parameter silent: `false` of the server should return the new flags list for the message(s), otherwise `true`.
    /// - parameter list: The `Flag`s to remove.
    /// - returns: A new `StoreFlags`
    public static func remove(silent: Bool, list: [Flag]) -> Self {
        Self(operation: .remove, silent: silent, flags: list)
    }

    /// Convenience function to create a new *add* operation.
    /// - parameter silent: `false` of the server should return the new flags list for the message(s), otherwise `true`.
    /// - parameter list: The `Flag`s to replace.
    /// - returns: A new `StoreFlags`
    public static func replace(silent: Bool, list: [Flag]) -> Self {
        Self(operation: .replace, silent: silent, flags: list)
    }

    /// The type of flag operation e.g. add, remove, or replace.
    public var operation: Operation
    
    /// `false` if the server should return the new `Flag`s list for each message, otherwise `true`.
    public var silent: Bool
    
    /// The `Flag`s to operate on.
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
