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

public struct FieldParameterPair: Equatable {
    public var field: String
    public var value: String

    public init(field: String, value: String) {
        self.field = field
        self.value = value
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeBodyFieldParameters(_ params: [FieldParameterPair]) -> Int {
        guard params.count > 0 else {
            return self.writeNil()
        }
        return self.writeArray(params) { (element, buffer) in
            buffer.writeFieldParameterPair(element)
        }
    }

    @discardableResult mutating func writeFieldParameterPair(_ pair: FieldParameterPair) -> Int {
        self.writeIMAPString(pair.field) +
            self.writeSpace() +
            self.writeIMAPString(pair.value)
    }
}
