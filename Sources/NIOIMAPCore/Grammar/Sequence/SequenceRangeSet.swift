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

// IMAPv4 sequence-set
public struct SequenceRangeSet: Equatable {
    public var ranges: [SequenceRange]

    public init?(_ ranges: [SequenceRange]) {
        guard !ranges.isEmpty else { return nil }
        self.ranges = ranges
    }
}

extension SequenceRangeSet {
    public init(_ range: ClosedRange<SequenceNumber>) {
        self.init(SequenceRange(range))
    }

    public init(_ range: PartialRangeThrough<SequenceNumber>) {
        self.init(SequenceRange(range))
    }

    public init(_ range: PartialRangeFrom<SequenceNumber>) {
        self.init(SequenceRange(range))
    }

    public init(_ range: SequenceRange) {
        self.ranges = [range]
    }
}

extension SequenceRangeSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: SequenceRange...) {
        self.init(elements)!
    }
}

extension SequenceRangeSet {
    public static let all: SequenceRangeSet = SequenceRangeSet(SequenceRange.all)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceRangeSet(_ set: SequenceRangeSet) -> Int {
        self.writeArray(set.ranges, separator: ",", parenthesis: false) { (element, self) in
            self.writeSequenceRange(element)
        }
    }
}
