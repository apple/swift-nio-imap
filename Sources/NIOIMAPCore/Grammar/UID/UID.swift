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

public protocol MessageIdentifier: Hashable, Codable, CustomDebugStringConvertible, ExpressibleByIntegerLiteral, Strideable {
    var rawValue: UInt32 { get set }

    init(rawValue: UInt32)
}

extension MessageIdentifier {
    /// The minimum `UID` is always *1*.
    public static var min: Self {
        self.init(rawValue: 1)
    }

    /// The maximum `UID` is always `UInt32.max`.
    public static var max: Self {
        self.init(rawValue: UInt32.max)
    }

    /// Creates a `UID` from some `BinaryInteger`, ensuring that the given value fits within a `UInt32`.
    /// - parameter source: The raw value to use.
    /// - returns: `nil` if `source` does not fit within a `UInt32`, otherwise a `UID`.
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard source > 0, let rawValue = UInt32(exactly: source) else { return nil }
        self.init(rawValue: rawValue)
    }

    init(_ wrapper: MessageIdentificationShiftWrapper) {
        precondition(wrapper.rawValue < UInt32.max)
        self.init(exactly: wrapper.rawValue + 1)!
    }

    /// Creates a human-readable `String` representation of the `UID`.
    /// `*` if `self = UInt32.max`, otherwise `self.rawValue` as a `String`.
    public var debugDescription: String {
        if self == .max {
            return "*"
        } else {
            return "\(self.rawValue)"
        }
    }

    /// Creates a new `UID` from an integer literal, skipping all validation.
    /// - parameter integerLiteral: The integer literal value.
    public init(integerLiteral value: UInt32) {
        assert(value >= 1)
        self.init(rawValue: value)
    }
}

/// Unique Message Identifier
///
/// Not that valid UIDs are 1 ... 4294967295 (UInt32.max).
/// The maximum value is often rendered as `*` when encoded.
///
/// See RFC 3501 section 2.3.1.1.
public struct UID: MessageIdentifier {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

extension BinaryInteger {
    public init<T: MessageIdentifier>(_ id: T) {
        self = Self(id.rawValue)
    }
}

// MARK: - Strideable

extension MessageIdentifier {
    public typealias Stride = Int64

    /// Evaluates if one `UID` (`lhs`) is strictly less than another (`rhs`).
    /// - parameter lhs: The first `UID` to evaluate.
    /// - parameter rhs: The second `UID` to evaluate.
    /// - returns: `true` if `lhs` strictly less than`rhs`, otherwise `false`.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Evaluates if one `UID` (`lhs`) is less than or equal to another (`rhs`).
    /// - parameter lhs: The first `UID` to evaluate.
    /// - parameter rhs: The second `UID` to evaluate.
    /// - returns: `true` if `lhs` is less than or equal to `rhs`, otherwise `false`.
    public static func <= (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }

    /// Gets the distance to the given `UID`.
    /// - parameter other: The `UID` to get the distance to.
    /// - returns: The distance.
    public func distance(to other: Self) -> Int64 {
        Int64(other.rawValue) - Int64(self.rawValue)
    }

    /// Advances the current UID by `n`.
    /// IMPORTANT: `n` *must* be `<= UInt32.max`. `Int64` is used as the stridable type as it allows
    /// values equal to `UInt32.max` on all platforms (including 32 bit platforms where `Int.max < UInt32.max`.
    /// - parameter n: How many to advance by.
    /// - returns: A new `UID`.
    public func advanced(by n: Int64) -> Self {
        precondition(n <= UInt32.max, "`n` must be less than UInt32.max")
        return Self(exactly: Int64(self.rawValue) + n)!
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

    @discardableResult mutating func writeMessageIdentifier<T: MessageIdentifier>(_ id: T) -> Int {
        if id == .max {
            return self.writeString("*")
        } else {
            return self.writeString("\(id.rawValue)")
        }
    }
}

// MARK: - Swift Ranges

extension UID {
    /// Creates a new `UIDRange` from `.min` to the given upper bound.
    /// - parameter value: The upper bound.
    /// - returns: A new `UIDRange`.
    public static prefix func ... (value: Self) -> MessageIdentifierRange<UID> {
        MessageIdentifierRange((.min) ... value)
    }

    /// Creates a new `UIDRange` from the given lower bound to `.max`
    /// - parameter value: The lower bound.
    /// - returns: A new `UIDRange`.
    public static postfix func ... (value: Self) -> MessageIdentifierRange<UID> {
        MessageIdentifierRange(value ... (.max))
    }

    /// Creates a `UIDRange` from two `UIDs`.
    /// - parameter lower: The lower bound of the range.
    /// - parameter upper: The upper bound of the range.
    /// - returns: A new `UIDRange` using the provided bounds.
    public static func ... (lower: Self, upper: Self) -> MessageIdentifierRange<UID> {
        MessageIdentifierRange(lower ... upper)
    }
}
