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

public struct CreateParameter: Equatable {
    public var name: String
    public var value: ParameterValue?

    public init(name: String, value: ParameterValue? = nil) {
        self.name = name
        self.value = value
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeCreateParameters(_ params: [CreateParameter]) -> Int {
        guard params.count > 0 else {
            return 0 // don't do anything
        }

        return
            self.writeSpace() +
            self.writeArray(params) { (param, self) -> Int in
                self.writeCreateParameter(param)
            }
    }

    @discardableResult mutating func writeCreateParameter(_ param: CreateParameter) -> Int {
        self.writeCreateParameterName(param.name) +
            self.writeIfExists(param.value) { (value) -> Int in
                self.writeSpace() +
                    self.writeParameterValue(value)
            }
    }
}
