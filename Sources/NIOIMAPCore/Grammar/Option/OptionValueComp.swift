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

/// IMAPv4 `option-val-comp`
public enum OptionValueComp: Equatable {
    case string(ByteBuffer)
    case array([OptionValueComp])
}

// MARK: - Conveniences

extension OptionValueComp: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Self

    public init(arrayLiteral elements: OptionValueComp...) {
        let array = Array(elements)
        self = .array(array)
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeOptionValue(_ value: OptionValueComp) -> Int {
        self.writeString("(") +
            self.writeOptionValueComp(value) +
            self.writeString(")")
    }

    @discardableResult mutating func writeOptionValueComp(_ option: OptionValueComp) -> Int {
        switch option {
        case .string(let string):
            return self.writeIMAPString(string)
        case .array(let array):
            return self.writeArray(array) { (option, self) in
                self.writeOptionValueComp(option)
            }
        }
    }
}
