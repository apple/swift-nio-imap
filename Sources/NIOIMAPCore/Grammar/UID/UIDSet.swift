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

/// A set contains an array of `UIDRange` to represent a (potentially large) collection of messages.
///
/// UIDs are _not_ sorted.
public struct UIDSet: Hashable {
    /// A non-empty array of UID ranges.
    fileprivate var ranges: RangeSet<A>

    fileprivate init(_ ranges: RangeSet<A>) {
        self.ranges = ranges
    }

    /// Creates a new `UIDSet` containing the UIDs in the given ranges.
    public init<S: Sequence>(_ ranges: S) where S.Element == UIDRange {
        self.init()
        ranges.forEach {
            self.ranges.insert(contentsOf: Range($0))
        }
    }

    public init() {
        self.ranges = RangeSet()
    }
}

// MARK: -

extension UIDSet {
    /// UIDs shifted by 1, such that UID 1 -> 0, and UID.max -> UInt32.max - 1
    /// This allows us to store UID.max + 1 inside a UInt32.
    fileprivate struct A: RawRepresentable, Hashable {
        var rawValue: UInt32
    }
}

extension UIDSet.A: Strideable {
    public init(_ uid: UID) {
        // Since UID.min = 1, we can always do this:
        self.rawValue = uid.rawValue - 1
    }

    func distance(to other: UIDSet.A) -> Int64 {
        Int64(other.rawValue) - Int64(self.rawValue)
    }

    func advanced(by n: Int64) -> UIDSet.A {
        UIDSet.A(rawValue: UInt32(Int64(rawValue) + n))
    }
}

extension UID {
    fileprivate init(_ a: UIDSet.A) {
        precondition(a.rawValue < UInt32.max)
        self.init(rawValue: a.rawValue + 1)!
    }
}

extension Range where Element == UIDSet.A {
    fileprivate init(_ r: UIDRange) {
        self = UIDSet.A(r.rawValue.lowerBound) ..< UIDSet.A(r.rawValue.upperBound).advanced(by: 1)
    }

    fileprivate init(_ uid: UID) {
        self = UIDSet.A(uid) ..< UIDSet.A(uid).advanced(by: 1)
    }
}

extension UIDRange {
    fileprivate init(_ r: Range<UIDSet.A>) {
        self.init(UID(r.lowerBound) ... UID(r.upperBound.advanced(by: -1)))
    }
}

// MARK: -

extension UIDSet {
    /// Creates a `UIDSet` from a closed range.
    /// - parameter range: The closed range to use.
    public init(_ range: ClosedRange<UID>) {
        self.init(UIDRange(range))
    }

    /// Creates a `UIDSet` from a partial range.
    /// - parameter range: The partial range to use.
    public init(_ range: PartialRangeThrough<UID>) {
        self.init(UIDRange(range))
    }

    /// Creates a `UIDSet` from a partial range.
    /// - parameter range: The partial range to use.
    public init(_ range: PartialRangeFrom<UID>) {
        self.init(UIDRange(range))
    }

    /// Creates a set from a single range.
    /// - parameter range: The `UIDRange` to construct a set from.
    public init(_ range: UIDRange) {
        let a: Range<A> = Range(range)
        self.ranges = RangeSet(a)
    }
}

extension UIDSet {
    public init(_ uid: UID) {
        self.ranges = RangeSet(A(uid) ..< (A(uid).advanced(by: 1)))
    }
}

// MARK: - CustomStringConvertible

extension UIDSet: CustomStringConvertible {
    /// Creates a human-readable text representation of the set by joined ranges with a comma.
    public var description: String {
        ranges
            .ranges
            .map { "\(UIDRange($0))" }
            .joined(separator: ",")
    }
}

// MARK: - Array Literal

extension UIDSet: ExpressibleByArrayLiteral {
    /// Creates a new UIDSet from a literal array of ranges.
    /// - parameter arrayLiteral: The elements to use, assumed to be non-empty.
    public init(arrayLiteral elements: UIDRange...) {
        self.init(elements)
    }
}

extension UIDSet {
    /// A set that contains a single range, that in turn contains all messages.
    public static let all = UIDSet(UIDRange.all)
    /// A set that contains no UIDs.
    public static let empty = UIDSet()
}

extension UIDSet: Collection {
    public struct Index {
        fileprivate var rangeIndex: RangeSet<A>.Ranges.Index
        fileprivate var indexInRange: UID.Stride
    }

    public var startIndex: Index { Index(rangeIndex: ranges.ranges.startIndex, indexInRange: 0) }
    public var endIndex: Index {
        guard !ranges.ranges.isEmpty else { return Index(rangeIndex: ranges.ranges.endIndex, indexInRange: 0) }
        return Index(rangeIndex: ranges.ranges.endIndex, indexInRange: UID.Stride(ranges.ranges.last!.count))
    }

    public func index(after i: Index) -> Index {
        precondition(i.rangeIndex < ranges.ranges.endIndex)
        let count = UID.Stride(ranges.ranges[i.rangeIndex].count)
        if i.indexInRange.advanced(by: 1) < count {
            return Index(rangeIndex: i.rangeIndex, indexInRange: i.indexInRange.advanced(by: 1))
        }
        let nextRange = ranges.ranges.index(after: i.rangeIndex)
        guard nextRange < ranges.ranges.endIndex else { return endIndex }
        return Index(rangeIndex: nextRange, indexInRange: 0)
    }

    public subscript(position: Index) -> UID {
        UID(ranges.ranges[position.rangeIndex].lowerBound).advanced(by: position.indexInRange)
    }

    public var isEmpty: Bool {
        ranges.isEmpty
    }

    /// The number of UIDs in the set.
    public var count: Int {
        ranges.ranges.reduce(into: 0) { $0 += $1.count }
    }
}

extension UIDSet.Index: Comparable {
    public static func < (lhs: UIDSet.Index, rhs: UIDSet.Index) -> Bool {
        if lhs.rangeIndex == rhs.rangeIndex {
            return lhs.indexInRange < rhs.indexInRange
        } else {
            return lhs.rangeIndex < rhs.rangeIndex
        }
    }

    public static func > (lhs: UIDSet.Index, rhs: UIDSet.Index) -> Bool {
        if lhs.rangeIndex == rhs.rangeIndex {
            return lhs.indexInRange > rhs.indexInRange
        } else {
            return lhs.rangeIndex > rhs.rangeIndex
        }
    }

    public static func == (lhs: UIDSet.Index, rhs: UIDSet.Index) -> Bool {
        (lhs.rangeIndex == rhs.rangeIndex) && (lhs.indexInRange == rhs.indexInRange)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDSet(_ set: UIDSet) -> Int {
        self.writeArray(set.ranges.ranges, separator: ",", parenthesis: false) { (element, self) in
            let r = UIDRange(element)
            return self.writeUIDRange(r)
        }
    }
}

// MARK: - Set Algebra

extension UIDSet: SetAlgebra {
    public typealias Element = UID

    public func contains(_ member: UID) -> Bool {
        ranges.contains(A(member))
    }

    public func union(_ other: Self) -> Self {
        UIDSet(ranges.union(other.ranges))
    }

    public func intersection(_ other: Self) -> Self {
        UIDSet(ranges.intersection(other.ranges))
    }

    public func symmetricDifference(_ other: UIDSet) -> UIDSet {
        UIDSet(ranges.symmetricDifference(other.ranges))
    }

    public mutating func insert(_ newMember: UID) -> (inserted: Bool, memberAfterInsert: UID) {
        guard !contains(newMember) else { return (false, newMember) }
        let r: Range<A> = Range(newMember)
        ranges.insert(contentsOf: r)
        return (true, newMember)
    }

    public mutating func remove(_ member: UID) -> UID? {
        guard contains(member) else { return nil }
        let r: Range<A> = Range(member)
        ranges.remove(contentsOf: r)
        return member
    }

    public mutating func update(with newMember: UID) -> UID? {
        guard !contains(newMember) else { return newMember }
        let r: Range<A> = Range(newMember)
        ranges.insert(contentsOf: r)
        return nil
    }

    public mutating func formUnion(_ other: UIDSet) {
        ranges.formUnion(other.ranges)
    }

    public mutating func formIntersection(_ other: UIDSet) {
        ranges.formIntersection(other.ranges)
    }

    public mutating func formSymmetricDifference(_ other: UIDSet) {
        ranges.formSymmetricDifference(other.ranges)
    }
}
