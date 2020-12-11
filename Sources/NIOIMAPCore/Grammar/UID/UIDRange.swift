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
public struct UIDRange: Hashable, RawRepresentable {
    /// The range expressed as a native Swift range.
    public var rawValue: ClosedRange<UID>

    /// Creates a new `UIDRange`.
    /// - parameter rawValue: A closed range with `UID`s as the upper and lower bound.
    public init(rawValue: ClosedRange<UID>) {
        self.rawValue = rawValue
    }
}

extension UIDRange {
    /// Creates a new `UIDRange`.
    /// - parameter rawValue: A closed range with `UID`s as the upper and lower bound.
    public init(_ range: ClosedRange<UID>) {
        self.init(rawValue: range)
    }

    /// Creates a new `UIDRange` from a partial range, using `.min` as the lower bound.
    /// - parameter rawValue: A partial with a `UID` as the upper bound.
    public init(_ range: PartialRangeThrough<UID>) {
        self.init(UID.min ... range.upperBound)
    }

    /// Creates a new `UIDRange` from a partial range, using `.max` as the upper bound.
    /// - parameter rawValue: A partial with a `UID` as the lower bound.
    public init(_ range: PartialRangeFrom<UID>) {
        self.init(range.lowerBound ... UID.max)
    }

    internal init(left: UID, right: UID) {
        if left <= right {
            self.init(rawValue: left ... right)
        } else {
            self.init(rawValue: right ... left)
        }
    }
}

// MARK: - CustomStringConvertible

extension UIDRange: CustomStringConvertible {
    /// Creates a human-readable representation of the range.
    public var description: String {
        if self.rawValue.lowerBound < self.rawValue.upperBound {
            return "\(self.rawValue.lowerBound):\(self.rawValue.upperBound)"
        } else {
            return "\(self.rawValue.lowerBound)"
        }
    }
}

// MARK: - Integer Literal

extension UIDRange: ExpressibleByIntegerLiteral {
    /// Creates a range from a single number - essentially a range containing one value.
    /// - parameter value: The raw number to use as both the upper and lower bounds.
    public init(integerLiteral value: UInt32) {
        self.init(UID(integerLiteral: value))
    }

    /// Creates a range from a single number - essentially a range containing one value.
    /// - parameter value: The raw number to use as both the upper and lower bounds.
    public init(_ value: UID) {
        self.init(rawValue: value ... value)
    }
}

extension UIDRange {
    /// Creates a range that covers every valid UID.
    public static let all = UIDRange((.min) ... (.max))
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDRange(_ range: UIDRange) -> Int {
        self.writeUID(range.rawValue.lowerBound) +
            self.write(if: range.rawValue.lowerBound < range.rawValue.upperBound) {
                self.writeString(":") +
                    self.writeUID(range.rawValue.upperBound)
            }
    }
}
