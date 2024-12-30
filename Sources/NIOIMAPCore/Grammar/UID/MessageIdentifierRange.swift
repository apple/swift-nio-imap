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

/// Represents a range of `MessageIdentifier`s using lower and upper bounds.
public struct MessageIdentifierRange<IdentifierType: MessageIdentifier>: Hashable {
    /// The range expressed as a native Swift range.
    public var range: ClosedRange<IdentifierType>

    /// Creates a new `MessageIdentifierRange`.
    /// - parameter range: A closed range with `MessageIdentifier`s as the upper and lower bound.
    public init(_ range: ClosedRange<IdentifierType>) {
        self.range = range
    }

    /// Creates a new `MessageIdentifierRange` from a partial range, using `.min` as the lower bound.
    /// - parameter range: A partial with a `MessageIdentifier` as the upper bound.
    public init(_ range: PartialRangeThrough<IdentifierType>) {
        self.init(IdentifierType.min...range.upperBound)
    }

    /// Creates a new `MessageIdentifierRange` from a partial range, using `.max` as the upper bound.
    /// - parameter rawValue: A partial with a `MessageIdentifier` as the lower bound.
    public init(_ range: PartialRangeFrom<IdentifierType>) {
        self.init(range.lowerBound...IdentifierType.max)
    }
}

extension MessageIdentifierRange: Sendable where IdentifierType: Sendable {}

// MARK: - CustomDebugStringConvertible

extension MessageIdentifierRange: CustomDebugStringConvertible {
    /// Creates a human-readable representation of the range.
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeMessageIdentifierRange(self)
        }
    }
}

// MARK: - Integer Literal

extension MessageIdentifierRange: ExpressibleByIntegerLiteral {
    /// Creates a range from a single number - essentially a range containing one value.
    /// - parameter value: The raw number to use as both the upper and lower bounds.
    public init(integerLiteral value: UInt32) {
        self.init(IdentifierType(integerLiteral: value))
    }

    /// Creates a range from a single number - essentially a range containing one value.
    /// - parameter value: The raw number to use as both the upper and lower bounds.
    public init(_ value: IdentifierType) {
        self.init(value...value)
    }
}

extension MessageIdentifierRange {
    /// Creates a range that covers every valid `MessageIdentifier`.
    public static var all: Self {
        Self((.min)...(.max))
    }
}

extension MessageIdentifier {
    /// Creates a new `MessageIdentifierRange` from `.min` to `value`.
    /// - parameter value: The upper bound.
    /// - returns: A new `MessageIdentifierRange`.
    public static prefix func ... (value: Self) -> MessageIdentifierRange<Self> {
        MessageIdentifierRange<Self>((.min)...value)
    }

    /// Creates a new `MessageIdentifierRange` from `value` to `.max`.
    /// - parameter value: The lower bound.
    /// - returns: A new `MessageIdentifierRange`.
    public static postfix func ... (value: Self) -> MessageIdentifierRange<Self> {
        MessageIdentifierRange<Self>(value...(.max))
    }

    /// Creates a `MessageIdentifierRange` from lower and upper bounds.
    /// - parameter lower: The lower bound.
    /// - parameter upper: The upper bound.
    /// - returns: A new `MessageIdentifier`.
    public static func ... (lower: Self, upper: Self) -> MessageIdentifierRange<Self> {
        MessageIdentifierRange<Self>(lower...upper)
    }
}

extension MessageIdentifierRange where IdentifierType == SequenceNumber {
    init(_ range: MessageIdentifierRange<UnknownMessageIdentifier>) {
        self.init(SequenceNumber(range.range.lowerBound)...SequenceNumber(range.range.upperBound))
    }
}

extension MessageIdentifierRange where IdentifierType == UID {
    init(_ range: MessageIdentifierRange<UnknownMessageIdentifier>) {
        self.init(UID(range.range.lowerBound)...UID(range.range.upperBound))
    }
}

extension MessageIdentifierRange where IdentifierType == UnknownMessageIdentifier {
    init(_ range: MessageIdentifierRange<UID>) {
        self.init(IdentifierType(range.range.lowerBound)...IdentifierType(range.range.upperBound))
    }

    init(_ range: MessageIdentifierRange<SequenceNumber>) {
        self.init(IdentifierType(range.range.lowerBound)...IdentifierType(range.range.upperBound))
    }
}

// MARK: - Convenience

extension MessageIdentifierRange {
    /// The range's lower bound.
    public var lowerBound: IdentifierType {
        range.lowerBound
    }

    /// The range's upper bound.
    public var upperBound: IdentifierType {
        range.upperBound
    }

    /// The number of elements in the range.
    ///
    /// - Complexity: O(1)
    @inlinable public var count: Int {
        range.count
    }

    /// A Boolean value indicating whether the range is empty.
    @inlinable public var isEmpty: Bool {
        range.isEmpty
    }

    /// Returns a copy of this range clamped to the given limiting range.
    @inlinable public func clamped(to limits: MessageIdentifierRange) -> MessageIdentifierRange {
        Self(range.clamped(to: limits.range))
    }

    /// Returns a Boolean value indicating whether this range and the given range
    /// contain an element in common.
    @inlinable public func overlaps(_ other: MessageIdentifierRange) -> Bool {
        range.overlaps(other.range)
    }

    /// Returns a Boolean value indicating whether the given element is contained
    /// within the range.
    @inlinable public func contains(_ element: IdentifierType) -> Bool {
        range.contains(element)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessageIdentifierRange<T>(_ range: MessageIdentifierRange<T>, descending: Bool = false) -> Int {
        let a = descending ? range.range.upperBound : range.range.lowerBound
        let b = descending ? range.range.lowerBound : range.range.upperBound
        return self.writeMessageIdentifier(a)
        + self.write(if: range.range.lowerBound < range.range.upperBound) {
            self.writeString(":") + self.writeMessageIdentifier(b)
        }
    }
}
