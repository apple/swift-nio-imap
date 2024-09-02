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

public protocol MessageIdentifier: Hashable, Codable, CustomDebugStringConvertible, ExpressibleByIntegerLiteral, Strideable where Stride == Int64 {
    var rawValue: UInt32 { get set }

    init(rawValue: UInt32)
}

extension MessageIdentifier {
    /// The minimum `MessageIdentifier` is always *1*.
    public static var min: Self {
        self.init(rawValue: 1)
    }

    /// The maximum `MessageIdentifier` is always `UInt32.max`.
    public static var max: Self {
        self.init(rawValue: UInt32.max)
    }

    /// Creates a `MessageIdentifier` from some `BinaryInteger`, ensuring that the given value fits within a `UInt32`.
    /// - parameter source: The raw value to use.
    /// - returns: `nil` if `source` does not fit within a `UInt32`, otherwise a `UID`.
    @inlinable
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard source > 0, let rawValue = UInt32(exactly: source) else { return nil }
        self.init(rawValue: rawValue)
    }

    init(_ wrapper: MessageIdentificationShiftWrapper) {
        precondition(wrapper.rawValue < UInt32.max)
        self.init(exactly: wrapper.rawValue + 1)!
    }

    /// Creates a human-readable `String` representation of the `MessageIdentifier`.
    /// `*` if `self = UInt32.max`, otherwise `self.rawValue` as a `String`.
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeMessageIdentifier(self)
        }
    }

    /// Creates a new `MessageIdentifier` from an integer literal, skipping all validation.
    /// - parameter integerLiteral: The integer literal value.
    public init(integerLiteral value: UInt32) {
        assert(value >= 1)
        self.init(rawValue: value)
    }
}

/// Either a `UID` or a `SequenceNumber`. We weren't able to tell
/// at the time of parsing. Use `UID.init(Messageidentifier)` and
/// `SequenceNumber.init(MessageIdentifier)` to convert
/// between the two.
public struct UnknownMessageIdentifier: MessageIdentifier, Sendable {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

extension BinaryInteger {
    public init<IdentifierType: MessageIdentifier>(_ id: IdentifierType) {
        self = Self(id.rawValue)
    }
}

// MARK: - Strideable

extension MessageIdentifier {
    /// Evaluates if one `MessageIdentifier` (`lhs`) is strictly less than another (`rhs`).
    /// - parameter lhs: The first `MessageIdentifier` to evaluate.
    /// - parameter rhs: The second `MessageIdentifier` to evaluate.
    /// - returns: `true` if `lhs` strictly less than`rhs`, otherwise `false`.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Evaluates if one `MessageIdentifier` (`lhs`) is less than or equal to another (`rhs`).
    /// - parameter lhs: The first `MessageIdentifier` to evaluate.
    /// - parameter rhs: The second `MessageIdentifier` to evaluate.
    /// - returns: `true` if `lhs` is less than or equal to `rhs`, otherwise `false`.
    public static func <= (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }

    /// Gets the distance to the given `MessageIdentifier`.
    /// - parameter other: The `MessageIdentifier` to get the distance to.
    /// - returns: The distance.
    public func distance(to other: Self) -> Int64 {
        Int64(other.rawValue) - Int64(self.rawValue)
    }

    /// Advances the current `MessageIdentifier` by `n`.
    /// IMPORTANT: `n` *must* be `<= UInt32.max`. `Int64` is used as the stridable type as it allows
    /// values equal to `UInt32.max` on all platforms (including 32 bit platforms where `Int.max < UInt32.max`.
    /// - parameter n: How many to advance by.
    /// - returns: A new `MessageIdentifier`.
    public func advanced(by n: Int64) -> Self {
        precondition(n <= UInt32.max, "`n` must be less than UInt32.max")
        return Self(exactly: Int64(self.rawValue) + n)!
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult
    mutating func writeMessageIdentifier<IdentifierType: MessageIdentifier>(_ id: IdentifierType) -> Int {
        if id == .max {
            return self.writeString("*")
        } else {
            return self.writeString("\(id.rawValue)")
        }
    }
}
