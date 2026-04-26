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

/// An option value, which can be a single string or a nested array of values.
///
/// Allows option values to be nested arbitrarily deep, enabling representation
/// of complex structured data in the RFC 4466 extension mechanism. Values can be simple strings
/// or arrays of other option values, supporting flexible data representation.
///
/// - SeeAlso: [RFC 4466 IMAP4 Extensions](https://datatracker.ietf.org/doc/html/rfc4466)
public enum OptionValueComp: Hashable, Sendable {
    /// A single value
    case string(ByteBuffer)

    /// An array of values
    case array([OptionValueComp])
}

// MARK: - Conveniences

extension OptionValueComp: ExpressibleByArrayLiteral {
    /// Option values can be nested, so this provides recursion.
    public typealias ArrayLiteralElement = Self

    /// Creates a new `OptionValueComp` from the given elements.
    /// - parameter elements: The contents of the array.
    public init(arrayLiteral elements: OptionValueComp...) {
        let array = Array(elements)
        self = .array(array)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeOptionValue(_ value: OptionValueComp) -> Int {
        self.writeString("(") + self.writeOptionValueComp(value) + self.writeString(")")
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
