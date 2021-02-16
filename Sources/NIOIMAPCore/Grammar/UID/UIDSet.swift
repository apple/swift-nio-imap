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
    fileprivate var _ranges: RangeSet<UIDShiftWrapper>

    fileprivate init(_ ranges: RangeSet<UIDShiftWrapper>) {
        self._ranges = ranges
    }

    /// Creates a new `UIDSet` containing the UIDs in the given ranges.
    public init<S: Sequence>(_ ranges: S) where S.Element == UIDRange {
        self.init()
        ranges.forEach {
            self._ranges.insert(contentsOf: Range($0))
        }
    }

    public init() {
        self._ranges = RangeSet()
    }
}

// MARK: -

extension UIDSet {
    /// UIDs shifted by 1, such that UID 1 -> 0, and UID.max -> UInt32.max - 1
    /// This allows us to store UID.max + 1 inside a UInt32.
    fileprivate struct UIDShiftWrapper: Hashable {
        var rawValue: UInt32
    }
}

extension UIDSet.UIDShiftWrapper: Strideable {
    public init(_ uid: UID) {
        // Since UID.min = 1, we can always do this:
        self.rawValue = uid.rawValue - 1
    }

    func distance(to other: UIDSet.UIDShiftWrapper) -> Int64 {
        Int64(other.rawValue) - Int64(self.rawValue)
    }

    func advanced(by n: Int64) -> UIDSet.UIDShiftWrapper {
        UIDSet.UIDShiftWrapper(rawValue: UInt32(Int64(rawValue) + n))
    }
}

extension UID {
    fileprivate init(_ wrapper: UIDSet.UIDShiftWrapper) {
        precondition(wrapper.rawValue < UInt32.max)
        self.init(exactly: wrapper.rawValue + 1)!
    }
}

extension Range where Element == UIDSet.UIDShiftWrapper {
    fileprivate init(_ r: UIDRange) {
        self = UIDSet.UIDShiftWrapper(r.range.lowerBound) ..< UIDSet.UIDShiftWrapper(r.range.upperBound).advanced(by: 1)
    }

    fileprivate init(_ uid: UID) {
        self = UIDSet.UIDShiftWrapper(uid) ..< UIDSet.UIDShiftWrapper(uid).advanced(by: 1)
    }
}

extension UIDRange {
    fileprivate init(_ r: Range<UIDSet.UIDShiftWrapper>) {
        self.init(UID(r.lowerBound) ... UID(r.upperBound.advanced(by: -1)))
    }
}

// MARK: -

extension UIDSet {
    public struct RangeView: Sequence {
        fileprivate var underlying: RangeSet<UIDShiftWrapper>.Ranges

        public func makeIterator() -> AnyIterator<UIDRange> {
            var u = underlying.makeIterator()
            return AnyIterator {
                guard let r = u.next() else { return nil }
                return UIDRange(r)
            }
        }
    }

    public var ranges: RangeView {
        RangeView(underlying: _ranges.ranges)
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

    /// Creates a `UIDSet` from a range.
    /// - parameter range: The range to use.
    public init(_ range: Range<UID>) {
        if range.isEmpty {
            self.init()
        } else {
            self.init(range.lowerBound ... range.upperBound.advanced(by: -1))
        }
    }

    /// Creates a set from a single range.
    /// - parameter range: The `UIDRange` to construct a set from.
    public init(_ range: UIDRange) {
        let a: Range<UIDShiftWrapper> = Range(range)
        self._ranges = RangeSet(a)
    }
}

extension UIDSet {
    public init(_ uid: UID) {
        self._ranges = RangeSet(UIDShiftWrapper(uid) ..< (UIDShiftWrapper(uid).advanced(by: 1)))
    }
}

// MARK: - CustomDebugStringConvertible

extension UIDSet: CustomDebugStringConvertible {
    /// Creates a human-readable text representation of the set by joined ranges with a comma.
    public var debugDescription: String {
        _ranges
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

extension UIDSet: BidirectionalCollection {
    public struct Index {
        fileprivate var rangeIndex: RangeSet<UIDShiftWrapper>.Ranges.Index
        fileprivate var indexInRange: UID.Stride
    }

    public var startIndex: Index { Index(rangeIndex: _ranges.ranges.startIndex, indexInRange: 0) }
    public var endIndex: Index {
        Index(rangeIndex: _ranges.ranges.endIndex, indexInRange: 0)
    }

    public func index(after i: Index) -> Index {
        index(i, offsetBy: 1)
    }

    public func index(before i: Index) -> Index {
        index(i, offsetBy: -1)
    }

    /// Returns an index that is the specified distance from the given index.
    ///
    /// - Note: The complexity of this is _not_ O(1)
    ///
    /// - Complexity: O(n)
    public func index(_ i: Self.Index, offsetBy distance: Int) -> Self.Index {
        if distance < 0 {
            var result = i
            result.indexInRange = result.indexInRange.advanced(by: distance)
            while true {
                if result.indexInRange >= 0 {
                    break
                }
                guard _ranges.ranges.startIndex < result.rangeIndex else {
                    break
                }
                // We need to find the previous range:
                result.rangeIndex = _ranges.ranges.index(before: result.rangeIndex)
                let indexCount = UID.Stride(_ranges.ranges[result.rangeIndex].count)
                result.indexInRange = result.indexInRange.advanced(by: Int(indexCount))
            }
            return result
        } else {
            var remainingDistance = distance
            var result = i
            while remainingDistance > 0 {
                guard result.rangeIndex < _ranges.ranges.endIndex else {
                    result.indexInRange = result.indexInRange.advanced(by: remainingDistance)
                    break
                }
                let indexesInRangeCount = UID.Stride(_ranges.ranges[result.rangeIndex].count)
                if result.indexInRange.advanced(by: remainingDistance) < indexesInRangeCount {
                    result.indexInRange = result.indexInRange.advanced(by: remainingDistance)
                    break
                }
                let nextRange = _ranges.ranges.index(after: result.rangeIndex)
                let step = result.indexInRange.distance(to: UID.Stride(_ranges.ranges[result.rangeIndex].count))
                result = Index(rangeIndex: nextRange, indexInRange: 0)
                remainingDistance -= step
            }
            return result
        }
    }

    /// Returns the distance between two indices.
    ///
    /// - Note: The complexity of this is _not_ O(1)
    ///
    /// - Complexity: O(n)
    public func distance(from start: Self.Index, to end: Self.Index) -> Int {
        if start.rangeIndex == end.rangeIndex {
            return start.indexInRange.distance(to: end.indexInRange)
        } else if start.rangeIndex < end.rangeIndex {
            let offset = Int(Int64(_ranges.ranges[start.rangeIndex].count) - start.indexInRange)
            let nextRange = _ranges.ranges.index(after: start.rangeIndex)
            return offset + distance(from: Index(rangeIndex: nextRange, indexInRange: 0), to: end)
        } else {
            return -distance(from: end, to: start)
        }
    }

    public subscript(position: Index) -> UID {
        UID(_ranges.ranges[position.rangeIndex].lowerBound).advanced(by: position.indexInRange)
    }

    public var isEmpty: Bool {
        _ranges.isEmpty
    }

    /// The number of UIDs in the set.
    ///
    /// - Note: The complexity of this is _not_ O(1)
    ///
    /// - Complexity: O(n)
    public var count: Int {
        _ranges.ranges.reduce(into: 0) { $0 += $1.count }
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
        self.writeArray(set._ranges.ranges, separator: ",", parenthesis: false) { (element, self) in
            let r = UIDRange(element)
            return self.writeUIDRange(r)
        }
    }
}

// MARK: - Set Algebra

extension UIDSet: SetAlgebra {
    public typealias Element = UID

    public func contains(_ member: UID) -> Bool {
        _ranges.contains(UIDShiftWrapper(member))
    }

    public func union(_ other: Self) -> Self {
        UIDSet(_ranges.union(other._ranges))
    }

    public func intersection(_ other: Self) -> Self {
        UIDSet(_ranges.intersection(other._ranges))
    }

    public func symmetricDifference(_ other: UIDSet) -> UIDSet {
        UIDSet(_ranges.symmetricDifference(other._ranges))
    }

    @discardableResult
    public mutating func insert(_ newMember: UID) -> (inserted: Bool, memberAfterInsert: UID) {
        guard !contains(newMember) else { return (false, newMember) }
        let r: Range<UIDShiftWrapper> = Range(newMember)
        _ranges.insert(contentsOf: r)
        return (true, newMember)
    }

    @discardableResult
    public mutating func remove(_ member: UID) -> UID? {
        guard contains(member) else { return nil }
        let r: Range<UIDShiftWrapper> = Range(member)
        _ranges.remove(contentsOf: r)
        return member
    }

    @discardableResult
    public mutating func update(with newMember: UID) -> UID? {
        guard !contains(newMember) else { return newMember }
        let r: Range<UIDShiftWrapper> = Range(newMember)
        _ranges.insert(contentsOf: r)
        return nil
    }

    public mutating func formUnion(_ other: UIDSet) {
        _ranges.formUnion(other._ranges)
    }

    public mutating func formIntersection(_ other: UIDSet) {
        _ranges.formIntersection(other._ranges)
    }

    public mutating func formSymmetricDifference(_ other: UIDSet) {
        _ranges.formSymmetricDifference(other._ranges)
    }
}
