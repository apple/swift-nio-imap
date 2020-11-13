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
    public var rawValue: UInt32
    public init?(rawValue: Int) {
        guard rawValue >= 1, rawValue <= UInt32.max else { return nil }
        self.rawValue = UInt32(rawValue)
    }

    public init?(rawValue: UInt32) {
        guard rawValue >= 1 else { return nil }
        self.rawValue = UInt32(rawValue)
    }

    public static let min = SequenceNumber(1)
    public static let max = SequenceNumber(UInt32.max)
}

// MARK: - Integer literal

extension SequenceNumber: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt32) {
        self.init(rawValue: value)!
    }

    public init(_ value: Int) {
        self.init(rawValue: value)!
    }

    public init(_ value: UInt32) {
        self.rawValue = value
    }
}

// MARK: - Strideable

extension SequenceNumber: Strideable {
    public static func < (lhs: SequenceNumber, rhs: SequenceNumber) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func <= (lhs: SequenceNumber, rhs: SequenceNumber) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }

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
    public static prefix func ... (value: Self) -> SequenceRange {
        SequenceRange(left: .min, right: value)
    }

    public static postfix func ... (value: Self) -> SequenceRange {
        SequenceRange(left: value, right: .max)
    }

    public static func ... (lower: Self, upper: Self) -> SequenceRange {
        SequenceRange(left: lower, right: upper)
    }
}
