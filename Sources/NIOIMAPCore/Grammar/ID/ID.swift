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

extension _EncodeBuffer {
    @discardableResult mutating func writeIDParameters(_ values: OrderedDictionary<String, String?>) -> Int {
        guard values.count > 0 else {
            return self.writeNil()
        }
        return self.writeOrderedDictionary(values) { (e, self) in
            self.writeIMAPString(e.key) +
                self.writeSpace() +
                self.writeNString(e.value)
        }
    }

    @discardableResult mutating func writeIDResponse(_ response: OrderedDictionary<String, String?>) -> Int {
        self.writeString("ID ") +
            self.writeIDParameters(response)
    }
}
