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

    public enum AppendData: Equatable {
        case literal(Int)
        case literal8(Int)
        case dataExtension(AppendDataExtension)
    }

}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeAppendData(_ data: NIOIMAP.AppendData) -> Int {
        switch data {
        case .literal(let size):
            return self.writeString("{\(size)}\r\n")
        case .literal8(let size):
            return self.writeString("~{\(size)}\r\n")
        case .dataExtension(let data):
            return self.writeAppendDataExtension(data)
        }
    }
    
}
