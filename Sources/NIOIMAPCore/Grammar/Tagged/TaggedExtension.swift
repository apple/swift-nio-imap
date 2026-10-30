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
    @discardableResult mutating func writeTaggedExtension<Kind>(
        _ ext: KeyValue<ExtensionKey<Kind>, ParameterValue>
    ) -> Int {
        self.writeExtensionKey(ext.key) + self.writeSpace() + self.writeParameterValue(ext.value)
    }

    @discardableResult mutating func writeParameters<Kind>(
        _ params: OrderedDictionary<ExtensionKey<Kind>, ParameterValue?>
    ) -> Int {
        if params.isEmpty {
            return 0
        }

        return
            self.writeSpace()
            + self.writeOrderedDictionary(params) { (param, self) -> Int in
                self.writeParameter(param)
            }
    }

    @discardableResult mutating func writeParameter<Kind>(
        _ param: KeyValue<ExtensionKey<Kind>, ParameterValue?>
    ) -> Int {
        self.writeExtensionKey(param.key)
            + self.writeIfExists(param.value) { (value) -> Int in
                self.writeSpace() + self.writeParameterValue(value)
            }
    }
}
