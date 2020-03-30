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
    
    public struct FetchModifier: Equatable {
        public var name: String
        public var value: FetchModifierParameter?
        
        public static func name(_ name: String, value: FetchModifierParameter?) -> Self {
            return Self(name: name, value: value)
        }
    }
    
    public typealias FetchModifiers = [FetchModifier]
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeFetchModifiers(_ params: NIOIMAP.FetchModifiers) -> Int {
        self.writeSpace() +
        self.writeArray(params) { (param, self) -> Int in
            self.writeFetchModifier(param)
        }
    }
    
    @discardableResult mutating func writeFetchModifier(_ param: NIOIMAP.FetchModifier) -> Int {
        self.writeFetchModifierName(param.name) +
        self.writeIfExists(param.value) { (value) -> Int in
            self.writeSpace() +
            self.writeFetchModifierParameter(value)
        }
    }
    
}
