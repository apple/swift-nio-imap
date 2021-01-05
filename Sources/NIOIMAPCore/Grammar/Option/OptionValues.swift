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

public struct OptionValues: Equatable {
    
    public var array: [ByteBuffer]
    
    public init(_ array: [ByteBuffer]) {
        self.array = array
    }
    
}

// MARK: - Conveniences

extension OptionValues: ExpressibleByArrayLiteral {
    /// Option values can be nested, so this provides recursion.
    public typealias ArrayLiteralElement = ByteBuffer

    /// Creates a new `OptionalValueComp` from the given elements.
    /// - parameter elements: The contents of the array.
    public init(arrayLiteral elements: ByteBuffer...) {
        self.array = elements
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeOptionValue(_ value: OptionValues) -> Int {
        self.writeArray(value.array) { (option, self) in
            self.writeIMAPString(option)
        }
    }
}
