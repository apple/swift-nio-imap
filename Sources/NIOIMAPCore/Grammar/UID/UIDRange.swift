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

/// IMAPv4 `uid-range`
public struct UIDRange: Hashable, RawRepresentable {
    public var rawValue: ClosedRange<UID>

    public var range: ClosedRange<UID> { rawValue }

    public init(rawValue: ClosedRange<UID>) {
        self.rawValue = rawValue
    }
}

extension UIDRange {
    public init(_ range: ClosedRange<UID>) {
        self.init(rawValue: range)
    }

    public init(_ range: PartialRangeThrough<UID>) {
        self.init(UID.min ... range.upperBound)
    }

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

extension UIDRange: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt32) {
        self.init(UID(integerLiteral: value))
    }

    public init(_ value: UID) {
        self.init(rawValue: value ... value)
    }
}

extension UIDRange {
    public static let all = UIDRange((.min) ... (.max))
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDRange(_ range: UIDRange) -> Int {
        if range == .all {
            return self.writeUID(range.range.upperBound)
        } else {
            return self.writeUID(range.range.lowerBound) +
                self.write(if: range.range.lowerBound < range.range.upperBound) {
                    self.writeString(":") +
                        self.writeUID(range.range.upperBound)
                }
        }
    }
}
