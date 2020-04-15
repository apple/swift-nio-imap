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



extension IMAPCore {
    
    public enum StoreAttributeFlagsType: String, Equatable {
        case add = "+"
        case remove = "-"
        case other = ""
    }
    
    public struct StoreAttributeFlags: Equatable {

        public static func add(silent: Bool, list: [Flag]) -> Self {
            return Self(type: .add, silent: silent, flags: list)
        }
        
        public static func remove(silent: Bool, list: [Flag]) -> Self {
            return Self(type: .remove, silent: silent, flags: list)
        }
        
        public static func other(silent: Bool, list: [Flag]) -> Self {
            return Self(type: .other, silent: silent, flags: list)
        }
        
        public var type: StoreAttributeFlagsType
        public var silent: Bool
        public var flags: [Flag]
    }
    
}
