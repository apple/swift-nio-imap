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

extension NIOIMAP {

    public struct ModifierSequenceValue: Equatable {
        public var value: Int
        
        public static var zero: Self {
            return Self(0)!
        }
        
        public static func value(_ value: Int) -> Self {
            return Self(value)!
        }
        
        public init?(_ value: Int) {
            guard value >= 0 else {
                return nil
            }
            self.value = value
        }
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeModifierSequenceValue(_ value: NIOIMAP.ModifierSequenceValue) -> Int {
        self.writeString("\(value.value)")
    }
    
}
