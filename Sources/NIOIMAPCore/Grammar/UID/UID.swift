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
/// Not that valid UIDs are 1 ... 4294967295 (UInt32.max).
/// The maximum value is often rendered as `*` when encoded.
///
/// See RFC 3501 section 2.3.1.1.
public struct UID: Hashable, Codable {
    /// The minimum `UID` is always *1*.
    public static let min = UID(1)

    /// The maximum `UID` is always `UInt32.max`.
    public static let max = UID(exactly: UInt32.max)!

    let rawValue: UInt32

    /// Creates a `UID` from some `BinaryInteger`, ensuring that the given value fits within a `UInt32`.
    /// - parameter source: The raw value to use.
    /// - returns: `nil` if `source` does not fit within a `UInt32`, otherwise a `UID`.
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard source > 0, let rawValue = UInt32(exactly: source) else { return nil }
        self.rawValue = rawValue
    }
}

// MARK: - CustomStringConvertible

extension UID: CustomStringConvertible {
    /// Creates a human-readable `String` representation of the `UID`.
    /// `*` if `self = UInt32.max`, otherwise `self.rawValue` as a `String`.
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
    /// Creates a new `UID` from an integer literal, skipping all validation.
    /// - parameter integerLiteral: The integer literal value.
    public init(integerLiteral value: UInt32) {
        assert(value >= 1)
        self.rawValue = value
    }
}

extension BinaryInteger {
    public init(_ uid: UID) {
        self = Self(uid.rawValue)
    }
}

// MARK: - Strideable

extension UID: Strideable {
    /// Evaluates if one `UID` (`lhs`) is strictly less than another (`rhs`).
    /// - parameter lhs: The first `UID` to evaluate.
    /// - parameter rhs: The second `UID` to evaluate.
    /// - returns: `true` if `lhs` strictly less than`rhs`, otherwise `false`.
    public static func < (lhs: UID, rhs: UID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Evaluates if one `UID` (`lhs`) is less than or equal to another (`rhs`).
    /// - parameter lhs: The first `UID` to evaluate.
    /// - parameter rhs: The second `UID` to evaluate.
    /// - returns: `true` if `lhs` is less than or equal to `rhs`, otherwise `false`.
    public static func <= (lhs: UID, rhs: UID) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }

    /// Gets the distance to the given `UID`.
    /// - parameter other: The `UID` to get the distance to.
    /// - returns: The distance.
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
        return UID(exactly: Int64(self.rawValue) + n)!
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
    /// Creates a new `UIDRange` from `.min` to the given upper bound.
    /// - parameter value: The upper bound.
    /// - returns: A new `UIDRange`.
    public static prefix func ... (value: Self) -> UIDRange {
        UIDRange((.min) ... value)
    }

    /// Creates a new `UIDRange` from the given lower bound to `.max`
    /// - parameter value: The lower bound.
    /// - returns: A new `UIDRange`.
    public static postfix func ... (value: Self) -> UIDRange {
        UIDRange(value ... (.max))
    }

    /// Creates a `UIDRange` from two `UIDs`.
    /// - parameter lower: The lower bound of the range.
    /// - parameter upper: The upper bound of the range.
    /// - returns: A new `UIDRange` using the provided bounds.
    public static func ... (lower: Self, upper: Self) -> UIDRange {
        UIDRange(lower ... upper)
    }
}
