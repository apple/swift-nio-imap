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

public struct SequenceSet: Equatable {
    public var ranges: [SequenceRange]

    public init?(_ ranges: [SequenceRange]) {
        guard !ranges.isEmpty else { return nil }
        self.ranges = ranges
    }
}

extension SequenceSet {
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

extension SequenceSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: SequenceRange...) {
        self.init(elements)!
    }
}

extension SequenceSet {
    public static let all: SequenceSet = SequenceSet(SequenceRange.all)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceSet(_ set: SequenceSet) -> Int {
        self.writeArray(set.ranges, separator: ",", parenthesis: false) { (element, self) in
            self.writeSequenceRange(element)
        }
    }
}
