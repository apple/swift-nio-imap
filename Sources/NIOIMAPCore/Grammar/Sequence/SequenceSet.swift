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

// RFC 5182 extended sequence-set
public enum SequenceSet: Equatable {
    // IMAPv4 sequence-set
    case range(SequenceRangeSet)
    // RFC 5182 'seq-last-command'
    case lastCommand
}

extension SequenceSet {
    public init?(_ ranges: [SequenceRange]) {
        if let rangeSet = SequenceRangeSet(ranges) {
            self = .range(rangeSet)
        } else {
            return nil
        }
    }

    public init(_ range: ClosedRange<SequenceNumber>) {
        self = .range(SequenceRangeSet(range))
    }

    public init(_ range: PartialRangeThrough<SequenceNumber>) {
        self = .range(SequenceRangeSet(range))
    }

    public init(_ range: PartialRangeFrom<SequenceNumber>) {
        self = .range(SequenceRangeSet(range))
    }

    public init(_ range: SequenceRange) {
        self = .range(SequenceRangeSet(range))
    }
}

extension SequenceSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: SequenceRange...) {
        self = .range(SequenceRangeSet(elements)!)
    }
}

extension SequenceSet {
    public static let all: SequenceSet = .range(SequenceRangeSet.all)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceSet(_ set: SequenceSet) -> Int {
        switch set {
        case .range(let sequenceRangeSet):
            return self.writeSequenceRangeSet(sequenceRangeSet)
        case .lastCommand:
            return self.writeString("$")
        }
    }
}
