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

/// Unique Message Identifier
///
/// See RFC 3501 section 2.3.1.1.
public struct UID: RawRepresentable, Hashable, Codable {
    public var rawValue: UInt32

    public init?(rawValue: Int) {
        guard rawValue >= 1, rawValue <= UInt32.max else { return nil }
        self.rawValue = UInt32(rawValue)
    }

    public init?(rawValue: UInt32) {
        guard rawValue >= 1 else { return nil }
        self.rawValue = rawValue
    }

    public static let min = UID(1)
    public static let max = UID(UInt32.max)
}

// MARK: - CustomStringConvertible

extension UID: CustomStringConvertible {
    public var description: String {
        if self == .max {
            return "*"
        } else {
            return "\(self.rawValue)"
        }
    }
}

// MARK: - Integer literal

extension UID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt32) {
        self.init(value)
    }

    /// Create a `UID`, asserting with invalid values.
    /// - parameter value: An integer value that must be a non-zero `UInt32` value.
    public init(_ value: Int) {
        assert(value <= UInt32.max, "UID must be a UInt32")
        self.init(UInt32(value))
    }

    /// Create a `UID`, asserting with invalid values.
    /// - parameter value: A `UInt32` that must be non-zero.
    public init(_ value: UInt32) {
        assert(value >= 1, "UID cannot be 0")
        self.init(rawValue: Int(value))!
    }
}

extension UID {
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard let rawValue = UInt32(exactly: source) else { return nil }
        self.init(rawValue: rawValue)
    }
}

// MARK: - Strideable

extension UID: Strideable {
    public static func < (lhs: UID, rhs: UID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func <= (lhs: UID, rhs: UID) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }

    public func distance(to other: UID) -> Int64 {
        Int64(other.rawValue) - Int64(self.rawValue)
    }

    /// Advances the current UID by `n`.
    /// IMPORTANT: `n` *must* be `<= UInt32.max`. `Int64` is used as the stridable type as it allows
    /// values equal to `UInt32.max` on all platforms (including 32 bit platforms where `Int.max < UInt32.max`.
    /// - parameter n: How many to advance by.
    /// - returns: A new `UID`.
    public func advanced(by n: Int64) -> UID {
        precondition(n <= UInt32.max, "`n` must be less than UInt32.max")
        return UID(UInt32(Int64(self.rawValue) + n))
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUID(_ num: UID) -> Int {
        if num == .max {
            return self.writeString("*")
        } else {
            return self.writeString("\(num.rawValue)")
        }
    }
}

// MARK: - Swift Ranges

extension UID {
    public static prefix func ... (value: Self) -> UIDRange {
        UIDRange(left: .min, right: value)
    }

    public static postfix func ... (value: Self) -> UIDRange {
        UIDRange(left: value, right: .max)
    }

    public static func ... (lower: Self, upper: Self) -> UIDRange {
        UIDRange(left: lower, right: upper)
    }
}
