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

public struct UIDSet: Hashable {
    public var ranges: [UIDRange]

    public init?(_ ranges: [UIDRange]) {
        guard !ranges.isEmpty else { return nil }
        self.ranges = ranges
    }
}

extension UIDSet {
    public init(_ range: ClosedRange<UID>) {
        self.init(UIDRange(range))
    }

    public init(_ range: PartialRangeThrough<UID>) {
        self.init(UIDRange(range))
    }

    public init(_ range: PartialRangeFrom<UID>) {
        self.init(UIDRange(range))
    }

    public init(_ range: UIDRange) {
        self.ranges = [range]
    }
}

// MARK: - CustomStringConvertible

extension UIDSet: CustomStringConvertible {
    public var description: String {
        ranges.map { "\($0)" }.joined(separator: ",")
    }
}

// MARK: - Array Literal

extension UIDSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: UIDRange...) {
        self.init(elements)!
    }
}

extension UIDSet {
    public static let all = UIDSet(UIDRange.all)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDSet(_ set: UIDSet) -> Int {
        self.writeArray(set.ranges, separator: ",", parenthesis: false) { (element, self) in
            self.writeUIDRange(element)
        }
    }
}
