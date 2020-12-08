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

/// A simple key/value pair where the value is optional.
public struct Parameter: Equatable {
    /// The key.
    public var name: String

    /// The value associated with the key.
    public var value: ParameterValue?

    /// Creates a new `Parameter`.
    /// - parameter name: The key.
    /// - parameter value: The value, defaults to `nil`.
    public init(name: String, value: ParameterValue? = nil) {
        self.name = name
        self.value = value
    }
}

public struct TaggedExtension: Equatable {
    public var label: String
    public var value: ParameterValue

    public init(label: String, value: ParameterValue) {
        self.label = label
        self.value = value
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeTaggedExtension(_ ext: TaggedExtension) -> Int {
        self.writeString(ext.label) +
            self.writeSpace() +
            self.writeParameterValue(ext.value)
    }

    @discardableResult mutating func writeParameters(_ params: [Parameter]) -> Int {
        if params.isEmpty {
            return 0
        }

        return
            self.writeSpace() +
            self.writeArray(params) { (param, self) -> Int in
                self.writeParameter(param)
            }
    }

    @discardableResult mutating func writeParameter(_ param: Parameter) -> Int {
        self.writeString(param.name) +
            self.writeIfExists(param.value) { (value) -> Int in
                self.writeSpace() +
                    self.writeParameterValue(value)
            }
    }
}
