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
    
    // Exracted from `IDParamsList`
    public struct IDParamsListElement: Equatable {
        public var key: ByteBuffer
        public var value: NString
        
        public static func key(_ key: ByteBuffer, value: NString) -> Self {
            return Self(key: key, value: value)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeIDParamsListElement(_ element: NIOIMAP.IDParamsListElement) -> Int {
        self.writeIMAPString(element.key) +
        self.writeSpace() +
        self.writeNString(element.value)
    }
    
    @discardableResult mutating func writeIDParamsList(_ list: [NIOIMAP.IDParamsListElement]?) -> Int {
        if let array = list {
            return self.writeArray(array) { (element, self) in
                self.writeIDParamsListElement(element)
            }
        } else {
            return self.writeNil()
        }
    }
    
    @discardableResult mutating func writeIDResponse(_ response: [NIOIMAP.IDParamsListElement]?) -> Int {
        self.writeString("ID ") +
        self.writeIDParamsList(response)
    }
    
    @discardableResult mutating func writeID(_ id: [NIOIMAP.IDParamsListElement]?) -> Int {
        self.writeString("ID ") +
        self.writeIDParamsList(id)
    }
    
}
