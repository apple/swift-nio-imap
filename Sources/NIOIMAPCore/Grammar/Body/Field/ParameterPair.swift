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

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeBodyParameterPairs(_ params: [KeyValue<String, String>]) -> Int {
        guard params.count > 0 else {
            return self.writeNil()
        }
        return self.writeArray(params) { (element, buffer) in
            buffer.writeParameterPair(element)
        }
    }

    @discardableResult mutating func writeParameterPair(_ pair: KeyValue<String, String>) -> Int {
        self.writeIMAPString(pair.key) +
            self.writeSpace() +
            self.writeIMAPString(pair.value)
    }
}
