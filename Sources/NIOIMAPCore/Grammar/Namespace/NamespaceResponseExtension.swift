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
import struct OrderedCollections.OrderedDictionary

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeNamespaceResponseExtensions(_ extensions: OrderedDictionary<ByteBuffer, [ByteBuffer]>) -> Int {
        extensions.reduce(into: 0) { (res, ext) in
            res += self.writeSpace() +
                self.writeIMAPString(ext.0) +
                self.writeSpace() +
                self.writeArray(ext.1) { (string, self) in
                    self.writeIMAPString(string)
                }
        }
    }
}
