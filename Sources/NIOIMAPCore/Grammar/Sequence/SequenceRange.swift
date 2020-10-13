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
public struct SequenceRange: Equatable, RawRepresentable {
    public var rawValue: ClosedRange<SequenceNumber>

    public var range: ClosedRange<SequenceNumber> { rawValue }

    public init(rawValue: ClosedRange<SequenceNumber>) {
        self.rawValue = rawValue
    }
}

extension SequenceRange {
    public init(_ range: ClosedRange<SequenceNumber>) {
        self.init(rawValue: range)
    }

    public init(_ range: PartialRangeThrough<SequenceNumber>) {
        self.init(SequenceNumber.min ... range.upperBound)
    }

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
    public init(integerLiteral value: Int) {
        self.init(SequenceNumber(integerLiteral: value))
    }

    public init(_ value: SequenceNumber) {
        self.init(rawValue: value ... value)
    }
}

extension SequenceRange {
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
