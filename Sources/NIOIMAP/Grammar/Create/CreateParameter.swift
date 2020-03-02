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
    
    public struct CreateParameter: Equatable {
        var name: CreateParameterName
        var value: CreateParameterValue?
        
        static func name(_ name: CreateParameterName, value: CreateParameterValue?) -> Self {
            return Self(name: name, value: value)
        }
    }
    
    public typealias CreateParameters = [CreateParameter]
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeCreateParameters(_ params: [NIOIMAP.CreateParameter]) -> Int {
        self.writeSpace() +
        self.writeArray(params) { (param, self) -> Int in
            self.writeCreateParameter(param)
        }
    }
    
    @discardableResult mutating func writeCreateParameter(_ param: NIOIMAP.CreateParameter) -> Int {
        self.writeCreateParameterName(param.name) +
        self.writeIfExists(param.value) { (value) -> Int in
            self.writeSpace() +
            self.writeCreateParameterValue(value)
        }
    }
    
}
