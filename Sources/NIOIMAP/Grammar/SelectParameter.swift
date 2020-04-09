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
    
    public struct SelectParameter: Equatable {
        public var name: String
        public var value: TaggedExtensionValue?
        
        public static func name(_ name: String, value: TaggedExtensionValue?) -> Self {
            return Self(name: name, value: value)
        }
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeSelectParameters(_ params: [NIOIMAP.SelectParameter]) -> Int {
        guard params.count > 0 else {
            return 0
        }
        
        return
            self.writeSpace() +
            self.writeArray(params) { (param, self) -> Int in
                self.writeSelectParameter(param)
            }
    }
    
    @discardableResult mutating func writeSelectParameter(_ param: NIOIMAP.SelectParameter) -> Int {
        self.writeSelectParameterName(param.name) +
        self.writeIfExists(param.value) { (value) -> Int in
            self.writeSpace() +
            self.writeTaggedExtensionValue(value)
        }
    }
    
    @discardableResult mutating func writeSelectParameterName(_ name: String) -> Int {
        return self.writeTaggedExtensionLabel(name)
    }
    
}
