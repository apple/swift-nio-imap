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
import StandardLibraryPreview

/// A collection of SequenceRanges, used to identify a potentially large number of messages.
public struct SequenceRangeSet: Hashable {
    /// The contained ranges.
    fileprivate var ranges: RangeSet<A>

    /// Creates a new `SequenceRangeSet` from a non-empty array of `SequenceRange`.
    /// - parameter ranges: The underlying array of ranges to use.
    /// - returns: `nil` if `ranges` is empty, otherwise a `SequenceRangeSet`.
    public init?(_ ranges: [SequenceRange]) {
        guard !ranges.isEmpty else { return nil }
        let rangesToInsert = ranges.map { Range($0) }
        self.ranges = RangeSet(rangesToInsert)
    }
}

extension SequenceRangeSet {
    /// SequenceNumberss shifted by 1, such that SequenceNumber 1 -> 0, and SequenceNumber.max -> UInt32.max - 1
    /// This allows us to store SequenceNumber.max + 1 inside a UInt32.
    fileprivate struct A: RawRepresentable, Hashable {
        var rawValue: UInt32
    }
}

extension SequenceRangeSet.A: Strideable {
    public init(_ num: SequenceNumber) {
        // Since SequenceNumber.min = 1, we can always do this:
        self.rawValue = num.rawValue - 1
    }

    func distance(to other: SequenceRangeSet.A) -> Int64 {
        Int64(other.rawValue) - Int64(self.rawValue)
    }

    func advanced(by n: Int64) -> SequenceRangeSet.A {
        SequenceRangeSet.A(rawValue: UInt32(Int64(rawValue) + n))
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
        self.ranges = RangeSet(Range(range))
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

extension SequenceRange {
    fileprivate init(_ r: Range<SequenceRangeSet.A>) {
        self.init(SequenceNumber(r.lowerBound) ... SequenceNumber(r.upperBound.advanced(by: -1)))
    }
}

extension SequenceNumber {
    fileprivate init(_ a: SequenceRangeSet.A) {
        precondition(a.rawValue < UInt32.max)
        self.init(rawValue: a.rawValue + 1)!
    }
}

extension Range where Element == SequenceRangeSet.A {
    fileprivate init(_ r: SequenceRange) {
        self = SequenceRangeSet.A(r.rawValue.lowerBound) ..< SequenceRangeSet.A(r.rawValue.upperBound).advanced(by: 1)
    }

    fileprivate init(_ num: SequenceNumber) {
        self = SequenceRangeSet.A(num) ..< SequenceRangeSet.A(num).advanced(by: 1)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceRangeSet(_ set: SequenceRangeSet) -> Int {
        self.writeArray(set.ranges.ranges, separator: ",", parenthesis: false) { (element, self) in
            return self.writeSequenceRange(SequenceRange(element))
        }
    }
}
