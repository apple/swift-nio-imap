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

import NIO

extension NIOIMAP {
    
    public enum StoreAttributeFlagsType: String, Equatable {
        case add = "+"
        case remove = "-"
        case other = ""
    }
    
    public struct StoreAttributeFlags: Equatable {

        static func add(silent: Bool, list: FlagList) -> Self {
            return Self(type: .add, silent: silent, flags: list)
        }
        
        static func remove(silent: Bool, list: FlagList) -> Self {
            return Self(type: .remove, silent: silent, flags: list)
        }
        
        static func other(silent: Bool, list: FlagList) -> Self {
            return Self(type: .other, silent: silent, flags: list)
        }
        
        var type: StoreAttributeFlagsType
        var silent: Bool
        var flags: FlagList
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeStoreAttributeFlags(_ flags: NIOIMAP.StoreAttributeFlags) -> Int {
        let silentString = flags.silent ? ".SILENT" : ""
        return
            self.writeString("\(flags.type.rawValue)FLAGS\(silentString) ") +
            self.writeFlags(flags.flags)
    }
    
}
