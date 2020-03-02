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

    public struct AppendExtension: Equatable {
        var name: AppendExtensionName
        var value: AppendExtensionValue
        
        static func name(_ name: AppendExtensionName, value: AppendExtensionValue) -> Self {
            return Self(name: name, value: value)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeAppendExtension(_ data: NIOIMAP.AppendExtension) -> Int {
        self.writeAppendExtensionName(data.name) +
        self.writeSpace() +
        self.writeAppendExtensionValue(data.value)
    }
    
}
