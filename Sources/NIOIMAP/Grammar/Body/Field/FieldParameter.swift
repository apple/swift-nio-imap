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
import IMAPCore

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyFieldParameters(_ params: [IMAPCore.FieldParameterPair]) -> Int {
        guard params.count > 0 else {
            return self.writeNil()
        }
        return self.writeArray(params) { (element, buffer) in
            buffer.writeFieldParameterPair(element)
        }
    }
    
    @discardableResult mutating func writeFieldParameterPair(_ pair: IMAPCore.FieldParameterPair) -> Int {
        self.writeIMAPString(pair.field) +
        self.writeSpace() +
        self.writeIMAPString(pair.value)
    }

}
