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

/// A simple key/value container, used to make the `IDParamsList` API
/// slightly more palatable.
public struct IDParameter: Equatable {
    /// Some `String` key.
    public var key: String

    /// Some optional value.
    public var value: ByteBuffer?

    /// Creates a new `IDParameter` key/value pair.
    /// - parameter key: Some `String` key.
    /// - parameter value: The value to be associated with `key`?
    public init(key: String, value: ByteBuffer?) {
        self.key = key
        self.value = value
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIDParameter(_ parameter: IDParameter) -> Int {
        self.writeIMAPString(parameter.key) +
            self.writeSpace() +
            self.writeNString(parameter.value)
    }

    @discardableResult mutating func writeIDParameters(_ array: [IDParameter]) -> Int {
        guard array.count > 0 else {
            return self.writeNil()
        }
        return self.writeArray(array) { (element, self) in
            self.writeIDParameter(element)
        }
    }

    @discardableResult mutating func writeIDResponse(_ response: [IDParameter]) -> Int {
        self.writeString("ID ") +
            self.writeIDParameters(response)
    }
}
