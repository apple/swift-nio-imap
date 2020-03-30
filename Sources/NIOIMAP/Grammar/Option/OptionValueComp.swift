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

import NIO

extension NIOIMAP {

    /// IMAPv4 `option-value`
    public typealias OptionValue = OptionValueComp

    /// IMAPv4 `option-val-comp`
    public enum OptionValueComp: Equatable {
        case string(ByteBuffer)
        case array([OptionValueComp])
    }

}

// MARK: - Conveniences
extension NIOIMAP.OptionValueComp: ExpressibleByArrayLiteral {

    public typealias ArrayLiteralElement = Self

    public init(arrayLiteral elements: NIOIMAP.OptionValueComp...) {
        let array = Array(elements)
        self = .array(array)
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeOptionValue(_ value: NIOIMAP.OptionValue) -> Int {
        self.writeString("(") +
        self.writeOptionValueComp(value) +
        self.writeString(")")
    }

    @discardableResult mutating func writeOptionValueComp(_ option: NIOIMAP.OptionValueComp) -> Int {
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
