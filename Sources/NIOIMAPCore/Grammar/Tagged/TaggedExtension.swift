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
    @discardableResult mutating func writeTaggedExtension(_ ext: KeyValue<String, ParameterValue>) -> Int {
        self.writeString(ext.key) + self.writeSpace() + self.writeParameterValue(ext.value)
    }

    @discardableResult mutating func writeParameters(_ params: OrderedDictionary<String, ParameterValue?>) -> Int {
        if params.isEmpty {
            return 0
        }

        return
            self.writeSpace()
            + self.writeOrderedDictionary(params) { (param, self) -> Int in
                self.writeParameter(param)
            }
    }

    @discardableResult mutating func writeParameter(_ param: KeyValue<String, ParameterValue?>) -> Int {
        self.writeString(param.key)
            + self.writeIfExists(param.value) { (value) -> Int in
                self.writeSpace() + self.writeParameterValue(value)
            }
    }
}
