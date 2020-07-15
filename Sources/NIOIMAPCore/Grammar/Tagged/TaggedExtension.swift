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

public struct Parameter: Equatable {
    public var name: String
    public var value: ParameterValue?

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
