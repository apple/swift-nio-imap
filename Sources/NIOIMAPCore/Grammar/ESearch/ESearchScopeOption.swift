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

/// RFC 6237
/// Options for future extensions.
public struct ESearchScopeOption: Equatable {
    public var name: String
    public var value: ParameterValue?

    public init(name: String, value: ParameterValue? = nil) {
        self.name = name
        self.value = value
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeESearchScopeOption(_ option: ESearchScopeOption) -> Int {
        self.writeString(option.name) +
            self.writeIfExists(option.value) { value in
                self.writeString(" ") + self.writeParameterValue(value)
            }
    }
}
