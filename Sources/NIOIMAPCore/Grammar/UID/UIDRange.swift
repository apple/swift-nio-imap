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
public struct UIDRange: Hashable {
    /// The range expressed as a native Swift range.
    public var range: ClosedRange<UID>

    /// Creates a new `UIDRange`.
    /// - parameter range: A closed range with `UID`s as the upper and lower bound.
    public init(_ range: ClosedRange<UID>) {
        self.range = range
    }

    /// Creates a new `UIDRange` from a partial range, using `.min` as the lower bound.
    /// - parameter range: A partial with a `UID` as the upper bound.
    public init(_ range: PartialRangeThrough<UID>) {
        self.init(UID.min ... range.upperBound)
    }

    /// Creates a new `UIDRange` from a partial range, using `.max` as the upper bound.
    /// - parameter rawValue: A partial with a `UID` as the lower bound.
    public init(_ range: PartialRangeFrom<UID>) {
        self.init(range.lowerBound ... UID.max)
    }
}

// MARK: - CustomDebugStringConvertible

extension UIDRange: CustomDebugStringConvertible {
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

extension UIDRange: ExpressibleByIntegerLiteral {
    /// Creates a range from a single number - essentially a range containing one value.
    /// - parameter value: The raw number to use as both the upper and lower bounds.
    public init(integerLiteral value: UInt32) {
        self.init(UID(integerLiteral: value))
    }

    /// Creates a range from a single number - essentially a range containing one value.
    /// - parameter value: The raw number to use as both the upper and lower bounds.
    public init(_ value: UID) {
        self.init(value ... value)
    }
}

extension UIDRange {
    /// Creates a range that covers every valid UID.
    public static let all = UIDRange((.min) ... (.max))
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeUIDRange(_ range: UIDRange) -> Int {
        self.writeUID(range.range.lowerBound) +
            self.write(if: range.range.lowerBound < range.range.upperBound) {
                self._writeString(":") +
                    self.writeUID(range.range.upperBound)
            }
    }
}
