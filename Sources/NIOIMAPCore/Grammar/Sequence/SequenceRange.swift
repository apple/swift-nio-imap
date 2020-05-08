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

/// IMAPv4 `seq-range`
public struct SequenceRange: Equatable {
    public static var wildcard: SequenceRange {
        Self(.last ... .last)
    }

    public static func single(_ num: Int) -> SequenceRange {
        Self(.number(num) ... .number(num))
    }

    public var closedRange: ClosedRange<SequenceNumber>

    public var from: SequenceNumber {
        closedRange.lowerBound
    }

    public var to: SequenceNumber {
        closedRange.upperBound
    }

    public init(from: SequenceNumber, to: SequenceNumber) {
        if from < to {
            self.init(from ... to)
        } else {
            self.init(to ... from)
        }
    }

    public init(_ closedRange: ClosedRange<SequenceNumber>) {
        self.closedRange = closedRange
    }
}

// MARK: - Integer literal

extension SequenceRange: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int

    public init(integerLiteral value: Self.IntegerLiteralType) {
        self.closedRange = ClosedRange(uncheckedBounds: (.number(value), .number(value)))
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeSequenceRange(_ range: SequenceRange) -> Int {
        self.writeSequenceNumber(range.closedRange.lowerBound) +
            self.writeIfTrue(range.closedRange.lowerBound < range.closedRange.upperBound) {
                self.writeString(":") +
                    self.writeSequenceNumber(range.closedRange.upperBound)
            }
    }
}

// MARK: - Swift ranges

extension SequenceNumber {
    // always flip for wildcard to be on right
    public static prefix func ... (maximum: Self) -> SequenceRange {
        SequenceRange(maximum ... .last)
    }

    public static postfix func ... (minimum: Self) -> SequenceRange {
        SequenceRange(minimum ... .last)
    }

    public static func ... (minimum: Self, maximum: Self) -> SequenceRange {
        if minimum < maximum {
            return SequenceRange(minimum ... maximum)
        } else {
            return SequenceRange(maximum ... minimum)
        }
    }
}
