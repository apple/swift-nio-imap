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
    fileprivate var ranges: RangeSet<SequenceNumberWrapper>

    /// Creates a new `SequenceRangeSet` from a non-empty array of `SequenceRange`.
    /// - parameter ranges: The underlying array of ranges to use.
    /// - returns: `nil` if `ranges` is empty, otherwise a `SequenceRangeSet`.
    public init?(_ ranges: [SequenceRange]) {
        guard !ranges.isEmpty else { return nil }
        let rangesToInsert = ranges.map { Range($0) }
        self.ranges = RangeSet(rangesToInsert)
    }

    fileprivate init(rangeSet: RangeSet<SequenceNumberWrapper>) {
        self.ranges = rangeSet
    }
}

extension SequenceRangeSet {
    /// SequenceNumberss shifted by 1, such that SequenceNumber 1 -> 0, and SequenceNumber.max -> UInt32.max - 1
    /// This allows us to store SequenceNumber.max + 1 inside a UInt32.
    fileprivate struct SequenceNumberWrapper: Hashable {
        var rawValue: UInt32
    }
}

extension SequenceRangeSet.SequenceNumberWrapper: Strideable {
    init(_ num: SequenceNumber) {
        // Since SequenceNumber.min = 1, we can always do this:
        self.rawValue = num.rawValue - 1
    }

    func distance(to other: SequenceRangeSet.SequenceNumberWrapper) -> Int64 {
        Int64(other.rawValue) - Int64(self.rawValue)
    }

    func advanced(by n: Int64) -> SequenceRangeSet.SequenceNumberWrapper {
        SequenceRangeSet.SequenceNumberWrapper(rawValue: UInt32(Int64(rawValue) + n))
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
    fileprivate init(_ r: Range<SequenceRangeSet.SequenceNumberWrapper>) {
        self.init(SequenceNumber(r.lowerBound) ... SequenceNumber(r.upperBound.advanced(by: -1)))
    }
}

extension SequenceNumber {
    fileprivate init(_ a: SequenceRangeSet.SequenceNumberWrapper) {
        precondition(a.rawValue < UInt32.max)
        self.init(exactly: a.rawValue + 1)!
    }
}

extension Range where Element == SequenceRangeSet.SequenceNumberWrapper {
    fileprivate init(_ r: SequenceRange) {
        self = SequenceRangeSet.SequenceNumberWrapper(r.range.lowerBound) ..< SequenceRangeSet.SequenceNumberWrapper(r.range.upperBound).advanced(by: 1)
    }

    fileprivate init(_ num: SequenceNumber) {
        self = SequenceRangeSet.SequenceNumberWrapper(num) ..< SequenceRangeSet.SequenceNumberWrapper(num).advanced(by: 1)
    }
}

extension SequenceRangeSet: Collection {
    public struct Index {
        fileprivate var rangeIndex: RangeSet<SequenceNumberWrapper>.Ranges.Index
        fileprivate var indexInRange: SequenceNumber.Stride
    }

    public var startIndex: Index { Index(rangeIndex: ranges.ranges.startIndex, indexInRange: 0) }
    public var endIndex: Index {
        guard !ranges.ranges.isEmpty else { return Index(rangeIndex: ranges.ranges.endIndex, indexInRange: 0) }
        return Index(rangeIndex: ranges.ranges.endIndex, indexInRange: SequenceNumber.Stride(ranges.ranges.last!.count))
    }

    public func index(after i: Index) -> Index {
        precondition(i.rangeIndex < ranges.ranges.endIndex)
        let count = SequenceNumber.Stride(ranges.ranges[i.rangeIndex].count)
        if i.indexInRange.advanced(by: 1) < count {
            return Index(rangeIndex: i.rangeIndex, indexInRange: i.indexInRange.advanced(by: 1))
        }
        let nextRange = ranges.ranges.index(after: i.rangeIndex)
        guard nextRange < ranges.ranges.endIndex else { return endIndex }
        return Index(rangeIndex: nextRange, indexInRange: 0)
    }

    public subscript(position: Index) -> SequenceNumber {
        SequenceNumber(ranges.ranges[position.rangeIndex].lowerBound).advanced(by: position.indexInRange)
    }

    public var isEmpty: Bool {
        ranges.isEmpty
    }

    /// The number of UIDs in the set.
    public var count: Int {
        ranges.ranges.reduce(into: 0) { $0 += $1.count }
    }
}

extension SequenceRangeSet.Index: Comparable {
    public static func < (lhs: SequenceRangeSet.Index, rhs: SequenceRangeSet.Index) -> Bool {
        if lhs.rangeIndex == rhs.rangeIndex {
            return lhs.indexInRange < rhs.indexInRange
        } else {
            return lhs.rangeIndex < rhs.rangeIndex
        }
    }

    public static func > (lhs: SequenceRangeSet.Index, rhs: SequenceRangeSet.Index) -> Bool {
        if lhs.rangeIndex == rhs.rangeIndex {
            return lhs.indexInRange > rhs.indexInRange
        } else {
            return lhs.rangeIndex > rhs.rangeIndex
        }
    }

    public static func == (lhs: SequenceRangeSet.Index, rhs: SequenceRangeSet.Index) -> Bool {
        (lhs.rangeIndex == rhs.rangeIndex) && (lhs.indexInRange == rhs.indexInRange)
    }
}

extension SequenceRangeSet: SetAlgebra {
    public typealias Element = SequenceNumber

    public init() {
        self.ranges = RangeSet()
    }

    public func contains(_ member: SequenceNumber) -> Bool {
        self.ranges.contains(SequenceNumberWrapper(member))
    }

    public func union(_ other: Self) -> Self {
        Self(rangeSet: self.ranges.union(other.ranges))
    }

    public func intersection(_ other: Self) -> Self {
        Self(rangeSet: ranges.intersection(other.ranges))
    }

    public func symmetricDifference(_ other: SequenceRangeSet) -> SequenceRangeSet {
        Self(rangeSet: ranges.symmetricDifference(other.ranges))
    }

    public mutating func insert(_ newMember: SequenceNumber) -> (inserted: Bool, memberAfterInsert: SequenceNumber) {
        guard !contains(newMember) else { return (false, newMember) }
        let r: Range<SequenceNumberWrapper> = Range(newMember)
        ranges.insert(contentsOf: r)
        return (true, newMember)
    }

    public mutating func remove(_ member: SequenceNumber) -> SequenceNumber? {
        guard contains(member) else { return nil }
        let r: Range<SequenceNumberWrapper> = Range(member)
        ranges.remove(contentsOf: r)
        return member
    }

    public mutating func update(with newMember: SequenceNumber) -> SequenceNumber? {
        guard !contains(newMember) else { return newMember }
        let r: Range<SequenceNumberWrapper> = Range(newMember)
        ranges.insert(contentsOf: r)
        return nil
    }

    public mutating func formUnion(_ other: SequenceRangeSet) {
        ranges.formUnion(other.ranges)
    }

    public mutating func formIntersection(_ other: SequenceRangeSet) {
        ranges.formIntersection(other.ranges)
    }

    public mutating func formSymmetricDifference(_ other: SequenceRangeSet) {
        ranges.formSymmetricDifference(other.ranges)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceRangeSet(_ set: SequenceRangeSet) -> Int {
        self.writeArray(set.ranges.ranges, separator: ",", parenthesis: false) { (element, self) in
            self.writeSequenceRange(SequenceRange(element))
        }
    }
}
