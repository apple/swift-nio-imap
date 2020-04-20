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
    
    // Exracted from `IDParamsList`
    public struct IDParameter: Equatable {
        public var key: String
        public var value: NString
        
        public static func key(_ key: String, value: NString) -> Self {
            return Self(key: key, value: value)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeIDParameter(_ parameter: NIOIMAP.IDParameter) -> Int {
        self.writeIMAPString(parameter.key) +
        self.writeSpace() +
        self.writeNString(parameter.value)
    }
    
    @discardableResult mutating func writeIDParameters(_ array: [NIOIMAP.IDParameter]) -> Int {
        guard array.count > 0 else {
            return self.writeNil()
        }
        return self.writeArray(array) { (element, self) in
            self.writeIDParameter(element)
        }
    }
    
    @discardableResult mutating func writeIDResponse(_ response: [NIOIMAP.IDParameter]) -> Int {
        self.writeString("ID ") +
        self.writeIDParameters(response)
    }
    
    @discardableResult mutating func writeID(_ id: [NIOIMAP.IDParameter]) -> Int {
        self.writeString("ID ") +
        self.writeIDParameters(id)
    }
    
}
