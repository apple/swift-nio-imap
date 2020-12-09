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

/// Message Sequence Number
///
/// See RFC 3501 section 2.3.1.2.
///
/// IMAPv4 `seq-number`
public struct SequenceNumber: RawRepresentable, Hashable {
    
    /// The minimum sequence number is always 1.
    public static let min = SequenceNumber(1)
    
    /// The maximum sequence number is always `UInt32.max`.
    public static let max = SequenceNumber(UInt32.max)
    
    /// The raw value of the sequence number, defined in RFC 3501 to be an unsigned 32-bit integer.
    public var rawValue: UInt32
    
    /// Creates a new `SequenceNumber` after performing some sanity checks.
    /// - parameter rawValue: An `Int` that is converted for use as the `rawValue`.
    /// - returns: `nil` if `rawValue` is `0` or does not fit within a `UInt32`.
    public init?(rawValue: Int) {
        guard rawValue >= 1, rawValue <= UInt32.max else { return nil }
        self.rawValue = UInt32(rawValue)
    }

    /// Creates a new `SequenceNumber` after performing some sanity checks.
    /// - parameter rawValue: A raw number that is sanity checked to make sure it's greater than 0 as required.
    /// - returns: `nil` if `rawValue` is `0`, otherwise a `SequenceNumber`.
    public init?(rawValue: UInt32) {
        guard rawValue >= 1 else { return nil }
        self.rawValue = UInt32(rawValue)
    }
}

// MARK: - Integer literal

extension SequenceNumber: ExpressibleByIntegerLiteral {
    
    /// Creates a new `SequenceNumber` from a `UInt32` without performing sanity checks.
    /// - parameter value: The raw value to use.
    public init(integerLiteral value: UInt32) {
        self.init(rawValue: value)!
    }

    /// Creates a new `SequenceNumber` from a `Int` without performing sanity checks.
    /// - parameter value: The raw value to use.
    public init(_ value: Int) {
        self.init(rawValue: value)!
    }

    /// Creates a new `SequenceNumber` from a `UInt32` without performing sanity checks.
    /// - parameter value: The raw value to use.
    public init(_ value: UInt32) {
        self.rawValue = value
    }
}

extension SequenceNumber {
    
    /// Creates a new `SequenceNumber` from a `BinaryInteger` after
    /// ensuring that the value fits within a `UInt32`.
    /// - parameter source: The raw value to use.
    /// - returns: `nil` if `source` doesn't fit within a `UInt32`, otherwise a `SequenceNumber`.
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard let rawValue = UInt32(exactly: source) else { return nil }
        self.init(rawValue: rawValue)
    }
}

// MARK: - Strideable

extension SequenceNumber: Strideable {
    
    /// Evaluates if one `SequenceNumber` (`lhs`) is strictly less than another (`rhs`).
    /// - parameter lhs: The first number to compare.
    /// - parameter rhs: The second number to compare.
    /// - returns: `true` if `lhs` is strictly less than `rhs`, otherwise `false`.
    public static func < (lhs: SequenceNumber, rhs: SequenceNumber) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Evaluates if one `SequenceNumber` (`lhs`) is less than or equal to another (`rhs`).
    /// - parameter lhs: The first number to compare.
    /// - parameter rhs: The second number to compare.
    /// - returns: `true` if `lhs` is less than or equal to `rhs`, otherwise `false`.
    public static func <= (lhs: SequenceNumber, rhs: SequenceNumber) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }

    /// Calculates the distance from the current `SequenceNumber` to `other`.
    /// - parameter other: The `SequenceNumber` of interest.
    /// - returns: The distance.
    public func distance(to other: SequenceNumber) -> Int64 {
        Int64(other.rawValue) - Int64(self.rawValue)
    }

    /// Advances the current `SequenceNumber` by `n`.
    /// IMPORTANT: `n` *must* be `<= UInt32.max`. `Int64` is used as the stridable type as it allows
    /// values equal to `UInt32.max` on all platforms (including 32 bit platforms where `Int.max < UInt32.max`.
    /// - parameter n: How many to advance by.
    /// - returns: A new `SequenceNumber`.
    public func advanced(by n: Int64) -> SequenceNumber {
        precondition(n <= UInt32.max, "`n` must be less than UInt32.max")
        return SequenceNumber(UInt32(Int64(self.rawValue) + n))
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceNumber(_ num: SequenceNumber) -> Int {
        self.writeString("\(num.rawValue)")
    }

    @discardableResult mutating func writeSequenceNumberOrWildcard(_ num: SequenceNumber) -> Int {
        if num.rawValue == UInt32.max {
            return self.writeString("*")
        } else {
            return self.writeString("\(num.rawValue)")
        }
    }
}

// MARK: - Swift Ranges

extension SequenceNumber {
    
    /// Creates a new `SequenceRange` from `.min` to `value`.
    /// - parameter value: The upper bound.
    /// - returns: A new `SequenceRange`.
    public static prefix func ... (value: Self) -> SequenceRange {
        SequenceRange(left: .min, right: value)
    }

    /// Creates a new `SequenceRange` from `value` to `.max`.
    /// - parameter value: The lower bound.
    /// - returns: A new `SequenceRange`.
    public static postfix func ... (value: Self) -> SequenceRange {
        SequenceRange(left: value, right: .max)
    }

    /// Creates a `SequenceRange` from lower and upper bounds.
    /// - parameter lower: The lower bound.
    /// - parameter upper: The upper bound.
    /// - returns: A new `SequenceRange`.
    public static func ... (lower: Self, upper: Self) -> SequenceRange {
        SequenceRange(left: lower, right: upper)
    }
}
