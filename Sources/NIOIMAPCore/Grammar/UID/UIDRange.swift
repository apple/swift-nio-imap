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

/// Represents a range of `UID`s using lower and upper bounds.
public struct MessageIdentifierRange<IdentifierType: MessageIdentifier>: Hashable {
    /// The range expressed as a native Swift range.
    public var range: ClosedRange<IdentifierType>

    /// Creates a new `UIDRange`.
    /// - parameter range: A closed range with `UID`s as the upper and lower bound.
    public init(_ range: ClosedRange<IdentifierType>) {
        self.range = range
    }

    /// Creates a new `UIDRange` from a partial range, using `.min` as the lower bound.
    /// - parameter range: A partial with a `UID` as the upper bound.
    public init(_ range: PartialRangeThrough<IdentifierType>) {
        self.init(IdentifierType.min ... range.upperBound)
    }

    /// Creates a new `UIDRange` from a partial range, using `.max` as the upper bound.
    /// - parameter rawValue: A partial with a `UID` as the lower bound.
    public init(_ range: PartialRangeFrom<IdentifierType>) {
        self.init(range.lowerBound ... IdentifierType.max)
    }
}

// MARK: - CustomDebugStringConvertible

extension MessageIdentifierRange: CustomDebugStringConvertible {
    /// Creates a human-readable representation of the range.
    public var debugDescription: String {
        if self.range.lowerBound < self.range.upperBound {
            return "\(self.range.lowerBound):\(self.range.upperBound)"
        } else {
            return "\(self.range.lowerBound)"
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
        self.init(value ... value)
    }
}

extension MessageIdentifierRange {
    /// Creates a range that covers every valid UID.
    public static var all: Self {
        Self((.min) ... (.max))
    }
}

extension MessageIdentifier {
    /// Creates a new `SequenceRange` from `.min` to `value`.
    /// - parameter value: The upper bound.
    /// - returns: A new `SequenceRange`.
    public static prefix func ... (value: Self) -> MessageIdentifierRange<Self> {
        MessageIdentifierRange<Self>((.min) ... value)
    }

    /// Creates a new `SequenceRange` from `value` to `.max`.
    /// - parameter value: The lower bound.
    /// - returns: A new `SequenceRange`.
    public static postfix func ... (value: Self) -> MessageIdentifierRange<Self> {
        MessageIdentifierRange<Self>(value ... (.max))
    }

    /// Creates a `SequenceRange` from lower and upper bounds.
    /// - parameter lower: The lower bound.
    /// - parameter upper: The upper bound.
    /// - returns: A new `SequenceRange`.
    public static func ... (lower: Self, upper: Self) -> MessageIdentifierRange<Self> {
        MessageIdentifierRange<Self>(lower ... upper)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessageIdentifierRange<T>(_ range: MessageIdentifierRange<T>) -> Int {
        self.writeMessageIdentifier(range.range.lowerBound) +
            self.write(if: range.range.lowerBound < range.range.upperBound) {
                self.writeString(":") +
                    self.writeMessageIdentifier(range.range.upperBound)
            }
    }
}
