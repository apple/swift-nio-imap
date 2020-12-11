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

/// A collection of SequenceRanges, used to identify a potentially large number of messages.
public struct SequenceRangeSet: Hashable {
    /// The contained ranges.
    public var ranges: [SequenceRange]

    /// Creates a new `SequenceRangeSet` from a non-empty array of `SequenceRange`.
    /// - parameter ranges: The underlying array of ranges to use.
    /// - returns: `nil` if `ranges` is empty, otherwise a `SequenceRangeSet`.
    public init?(_ ranges: [SequenceRange]) {
        guard !ranges.isEmpty else { return nil }
        self.ranges = ranges
    }
}

extension SequenceRangeSet {
    /// Creates a `SequenceRangeSet` containing only one range.
    /// - parameter range: The single range to store.
    public init(_ range: ClosedRange<SequenceNumber>) {
        self.init(SequenceRange(range))
    }

    /// Creates a `SequenceRangeSet` containing only one range.
    /// - parameter range: The single range to store, up to `SequenceNumber.max`.
    public init(_ range: PartialRangeThrough<SequenceNumber>) {
        self.init(SequenceRange(range))
    }

    /// Creates a `SequenceRangeSet` containing only one range.
    /// - parameter range: The single range to store, from `SequenceNumber.min`.
    public init(_ range: PartialRangeFrom<SequenceNumber>) {
        self.init(SequenceRange(range))
    }

    /// Creates a `SequenceRangeSet` containing only one range.
    /// - parameter range: The single range to store.
    public init(_ range: SequenceRange) {
        self.ranges = [range]
    }
}

extension SequenceRangeSet: ExpressibleByArrayLiteral {
    /// Creates a new `SequenceRangeSet` from a non-empty array of `SequenceRange`. The array is assumed to be
    /// non-empty, and the initialiser will crash if this is not the case.
    /// - parameter elements: The underlying ranges to use.
    public init(arrayLiteral elements: SequenceRange...) {
        self.init(elements)!
    }
}

extension SequenceRangeSet {
    /// A `SequenceRangeSet` that contains a single range, that in turn covers every possible `SequenceNumber`.
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
