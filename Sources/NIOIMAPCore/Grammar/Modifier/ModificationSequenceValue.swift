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

/// Represents the a *mod-sequence-value` as defined in RFC 7162.
public struct ModificationSequenceValue: Hashable {
    /// The raw value.
    public var value: UInt64

    /// A  zero *mod-sequence-value*
    public static var zero: Self {
        0
    }

    /// Creates a new ModificationSequenceValue.
    /// - parameter value: The raw value.
    public init(_ value: UInt64) {
        self.value = value
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension ModificationSequenceValue: ExpressibleByIntegerLiteral {
    /// A `ModificationSequenceValue` is defined as a 63-bit number. This means
    /// that the IntegerLiteralType is best represented as `UInt64`.
    public typealias IntegerLiteralType = UInt64

    /// Creates a `ModificationSequenceValue` from an integer literal.
    /// - parameter integerLiteral: The literal value.
    public init(integerLiteral value: UInt64) {
        self.value = value
    }
}

// MARK: - CustomDebugStringConvertible

extension ModificationSequenceValue: CustomDebugStringConvertible {
    /// `value` as a `String`.
    public var debugDescription: String {
        "\(self.value)"
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeModificationSequenceValue(_ value: ModificationSequenceValue) -> Int {
        self.writeString("\(value.value)")
    }
}
