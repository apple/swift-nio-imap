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
    fileprivate var value: UInt64

    /// A  zero *mod-sequence-value*
    public static var zero: Self {
        0
    }

    /// Creates a new ModificationSequenceValue.
    /// - parameter value: The raw value.
    public init(_ value: UInt64) {
        precondition(value <= UInt64(Int64.max), "mod-sequence-values are 63-bit")
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

// MARK: - BinaryInteger

extension BinaryInteger {
    public init(_ modificationSequenceValue: ModificationSequenceValue) {
        self = Self(modificationSequenceValue.value)
    }
}

// MARK: - Strideable

extension ModificationSequenceValue: Strideable {
    /// Evaluates if one `ModificationSequenceValue` (`lhs`) is strictly less than another (`rhs`).
    /// - parameter lhs: The first `ModificationSequenceValue` to evaluate.
    /// - parameter rhs: The second `ModificationSequenceValue` to evaluate.
    /// - returns: `true` if `lhs` strictly less than`rhs`, otherwise `false`.
    public static func < (lhs: ModificationSequenceValue, rhs: ModificationSequenceValue) -> Bool {
        lhs.value < rhs.value
    }

    /// Evaluates if one `ModificationSequenceValue` (`lhs`) is less than or equal to another (`rhs`).
    /// - parameter lhs: The first `ModificationSequenceValue` to evaluate.
    /// - parameter rhs: The second `ModificationSequenceValue` to evaluate.
    /// - returns: `true` if `lhs` is less than or equal to `rhs`, otherwise `false`.
    public static func <= (lhs: ModificationSequenceValue, rhs: ModificationSequenceValue) -> Bool {
        lhs.value <= rhs.value
    }

    /// Gets the distance to the given `ModificationSequenceValue`.
    /// - parameter other: The `ModificationSequenceValue` to get the distance to.
    /// - returns: The distance.
    public func distance(to other: ModificationSequenceValue) -> Int64 {
        Int64(other.value) - Int64(self.value)
    }

    /// Advances the current ModificationSequenceValue by `n`.
    /// - parameter n: How many to advance by.
    /// - returns: A new `ModificationSequenceValue`.
    public func advanced(by n: Int64) -> ModificationSequenceValue {
        ModificationSequenceValue(UInt64(Int64(self.value) + n))
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeModificationSequenceValue(_ value: ModificationSequenceValue) -> Int {
        self.writeString("\(value.value)")
    }
}
