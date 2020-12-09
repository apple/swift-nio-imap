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

/// A range of messages using message `SequenceNumber`s.
public struct SequenceRange: Hashable, RawRepresentable {
    
    /// The underlying range.
    public var rawValue: ClosedRange<SequenceNumber>

    /// Creates a new `SequenceRange` from a closed range.
    /// - parameter rawValue: The underlying range to use.
    public init(rawValue: ClosedRange<SequenceNumber>) {
        self.rawValue = rawValue
    }
}

extension SequenceRange {
    
    /// Creates a new `SequenceRange` from a closed range.
    /// - parameter range: The underlying range to use.
    public init(_ range: ClosedRange<SequenceNumber>) {
        self.init(rawValue: range)
    }

    /// Creates a new `SequenceRange` using `.min` as the lower bound.
    /// - parameter rawValue: The underlying range to use.
    public init(_ range: PartialRangeThrough<SequenceNumber>) {
        self.init(SequenceNumber.min ... range.upperBound)
    }

    /// Creates a new `SequenceRange` using `.max` as the upper bound.
    /// - parameter rawValue: The underlying range to use.
    public init(_ range: PartialRangeFrom<SequenceNumber>) {
        self.init(range.lowerBound ... SequenceNumber.max)
    }

    internal init(left: SequenceNumber, right: SequenceNumber) {
        if left <= right {
            self.init(rawValue: left ... right)
        } else {
            self.init(rawValue: right ... left)
        }
    }
}

extension SequenceRange: ExpressibleByIntegerLiteral {
    
    /// Creates a new `SequenceRange` using a single number, essentially a range with one element.
    /// - parameter value: The raw value to use as the upper and lower bounds.
    public init(integerLiteral value: UInt32) {
        self.init(SequenceNumber(integerLiteral: value))
    }

    /// Creates a new `SequenceRange` using a single number, essentially a range with one element.
    /// - parameter value: The raw value to use as the upper and lower bounds.
    public init(_ value: SequenceNumber) {
        self.init(rawValue: value ... value)
    }
}

extension SequenceRange {
    
    /// A `SequenceRange` that covers every possible `SequenceNumber`.
    public static let all = SequenceRange((.min) ... (.max))
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceRange(_ range: SequenceRange) -> Int {
        if range == .all {
            return self.writeSequenceNumberOrWildcard(range.range.upperBound)
        } else {
            return self.writeSequenceNumberOrWildcard(range.range.lowerBound) +
                self.write(if: range.range.lowerBound < range.range.upperBound) {
                    self.writeString(":") +
                        self.writeSequenceNumberOrWildcard(range.range.upperBound)
                }
        }
    }
}
