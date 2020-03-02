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
    
    public struct RenameParameter: Equatable {
        var name: RenameParameterName
        var value: RenameParameterValue?
        
        static func name(_ name: RenameParameterName, value: RenameParameterValue?) -> Self {
            return Self(name: name, value: value)
        }
    }
    
    public typealias RenameParameters = [RenameParameter]
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeRenameParameters(_ params: [NIOIMAP.RenameParameter]) -> Int {
        self.writeSpace() +
        self.writeArray(params) { (param, self) -> Int in
            self.writeRenameParameter(param)
        }
    }
    
    @discardableResult mutating func writeRenameParameter(_ param: NIOIMAP.RenameParameter) -> Int {
        self.writeRenameParameterName(param.name) +
        self.writeIfExists(param.value) { (value) -> Int in
            self.writeSpace() +
            self.writeRenameParameterValue(value)
        }
    }
    
}
