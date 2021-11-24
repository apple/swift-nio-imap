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
public struct MessageIdentifierSet<T: MessageIdentifier>: Hashable {
    /// A set that contains a single range, that in turn contains all messages.
    public static var all: Self {
        MessageIdentifierSet(MessageIdentifierRange<T>.all)
    }

    /// A set that contains no UIDs.
    public static var empty: Self {
        MessageIdentifierSet()
    }

    /// A non-empty array of UID ranges.
    fileprivate var _ranges: RangeSet<MessageIdentificationShiftWrapper>

    fileprivate init(_ ranges: RangeSet<MessageIdentificationShiftWrapper>) {
        self._ranges = ranges
    }

    /// Creates a new `UIDSet` containing the UIDs in the given ranges.
    public init<S: Sequence>(_ ranges: S) where S.Element == MessageIdentifierRange<T> {
        self.init()
        ranges.forEach {
            self._ranges.insert(contentsOf: Range($0))
        }
    }

    public init() {
        self._ranges = RangeSet()
    }

    public init(_ id: T) {
        self._ranges = RangeSet(MessageIdentificationShiftWrapper(id) ..< (MessageIdentificationShiftWrapper(id).advanced(by: 1)))
    }
}

/// A wrapper around a `UIDSet` that enforces at least one element.
public struct MessageIdentifierSetNonEmpty<T: MessageIdentifier>: Hashable {
    /// A set that contains a single range, that in turn contains all messages.
    public static var all: Self {
        MessageIdentifierSetNonEmpty(set: .all)!
    }

    /// The underlying `UIDSet`
    public private(set) var set: MessageIdentifierSet<T>

    /// Creates a new `UIDSetNonEmpty` from a `UIDSet`, after first
    /// validating that the set is not emtpy.
    /// - parameter set: The underlying `UIDSet` to use.
    /// - returns: `nil` if the given `UIDSet` is empty.
    public init?(set: MessageIdentifierSet<T>) {
        guard set.count > 0 else {
            return nil
        }
        self.set = set
    }
}

// MARK: -

/// UIDs/SequenceNumbers shifted by 1, such that 1 -> 0, and `type`.max -> UInt32.max - 1
/// This allows us to store `type`.max + 1 inside a UInt32.
/// This applies for both UIDs and SequenceNumbers.
struct MessageIdentificationShiftWrapper: Hashable {
    var rawValue: UInt32

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    init<T: MessageIdentifier>(_ id: T) {
        // Since UID.min = 1, we can always do this:
        self.rawValue = id.rawValue - 1
    }
}

extension MessageIdentificationShiftWrapper: Strideable {
    func distance(to other: MessageIdentificationShiftWrapper) -> Int64 {
        Int64(other.rawValue) - Int64(self.rawValue)
    }

    func advanced(by n: Int64) -> MessageIdentificationShiftWrapper {
        MessageIdentificationShiftWrapper(rawValue: UInt32(Int64(rawValue) + n))
    }
}

extension Range where Element == MessageIdentificationShiftWrapper {
    fileprivate init<T: MessageIdentifier>(_ r: MessageIdentifierRange<T>) {
        self = MessageIdentificationShiftWrapper(r.range.lowerBound) ..< MessageIdentificationShiftWrapper(r.range.upperBound).advanced(by: 1)
    }

    fileprivate init<T: MessageIdentifier>(_ id: T) {
        self = MessageIdentificationShiftWrapper(id) ..< MessageIdentificationShiftWrapper(id).advanced(by: 1)
    }
}

extension MessageIdentifierRange {
    init(_ r: Range<MessageIdentificationShiftWrapper>) {
        self.init(T(r.lowerBound) ... T(r.upperBound.advanced(by: -1)))
    }
}

// MARK: -

extension MessageIdentifierSet {
    public struct RangeView: Sequence {
        fileprivate var underlying: RangeSet<MessageIdentificationShiftWrapper>.Ranges

        public func makeIterator() -> AnyIterator<MessageIdentifierRange<T>> {
            var u = underlying.makeIterator()
            return AnyIterator {
                guard let r = u.next() else { return nil }
                return MessageIdentifierRange<T>(r)
            }
        }
    }

    public var ranges: RangeView {
        RangeView(underlying: _ranges.ranges)
    }
}

// MARK: -

extension MessageIdentifierSet {
    /// Creates a `UIDSet` from a closed range.
    /// - parameter range: The closed range to use.
    public init(_ range: ClosedRange<T>) {
        self.init(MessageIdentifierRange<T>(range))
    }

    /// Creates a `UIDSet` from a partial range.
    /// - parameter range: The partial range to use.
    public init(_ range: PartialRangeThrough<T>) {
        self.init(MessageIdentifierRange<T>(range))
    }

    /// Creates a `UIDSet` from a partial range.
    /// - parameter range: The partial range to use.
    public init(_ range: PartialRangeFrom<T>) {
        self.init(MessageIdentifierRange<T>(range))
    }

    /// Creates a `UIDSet` from a range.
    /// - parameter range: The range to use.
    public init(_ range: Range<T>) {
        if range.isEmpty {
            self.init()
        } else {
            self.init(range.lowerBound ... range.upperBound.advanced(by: -1))
        }
    }

    /// Creates a set from a single range.
    /// - parameter range: The `UIDRange` to construct a set from.
    public init(_ range: MessageIdentifierRange<T>) {
        let a: Range<MessageIdentificationShiftWrapper> = Range(range)
        self._ranges = RangeSet(a)
    }
}

// MARK: - CustomDebugStringConvertible

extension MessageIdentifierSet: CustomDebugStringConvertible {
    /// Creates a human-readable text representation of the set by joined ranges with a comma.
    public var debugDescription: String {
        _ranges
            .ranges
            .map { "\(MessageIdentifierRange<T>($0))" }
            .joined(separator: ",")
    }
}

extension MessageIdentifierSetNonEmpty: CustomDebugStringConvertible {
    /// Creates a human-readable text representation of the set by joined ranges with a comma.
    public var debugDescription: String {
        self.set.debugDescription
    }
}

// MARK: - Array Literal

extension MessageIdentifierSet: ExpressibleByArrayLiteral {
    /// Creates a new UIDSet from a literal array of ranges.
    /// - parameter arrayLiteral: The elements to use, assumed to be non-empty.
    public init(arrayLiteral elements: MessageIdentifierRange<T>...) {
        self.init(elements)
    }
}

extension MessageIdentifierSetNonEmpty: ExpressibleByArrayLiteral {
    /// Creates a new UIDSet from a literal array of ranges.
    /// - parameter arrayLiteral: The elements to use, assumed to be non-empty.
    public init(arrayLiteral elements: MessageIdentifierRange<T>...) {
        precondition(elements.count > 0, "At least one element is required.")
        self.set = MessageIdentifierSet(elements)
    }
}

extension MessageIdentifierSet: BidirectionalCollection {
    public struct Index {
        fileprivate var rangeIndex: RangeSet<MessageIdentificationShiftWrapper>.Ranges.Index
        fileprivate var indexInRange: T.Stride
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
                let indexCount = T.Stride(_ranges.ranges[result.rangeIndex].count)
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
                let indexesInRangeCount = T.Stride(_ranges.ranges[result.rangeIndex].count)
                if result.indexInRange.advanced(by: remainingDistance) < indexesInRangeCount {
                    result.indexInRange = result.indexInRange.advanced(by: remainingDistance)
                    break
                }
                let nextRange = _ranges.ranges.index(after: result.rangeIndex)
                let step = result.indexInRange.distance(to: T.Stride(_ranges.ranges[result.rangeIndex].count))
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

    public subscript(position: Index) -> T {
        T(_ranges.ranges[position.rangeIndex].lowerBound).advanced(by: position.indexInRange)
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

extension MessageIdentifierSet.Index: Comparable {
    public static func < (lhs: MessageIdentifierSet.Index, rhs: MessageIdentifierSet.Index) -> Bool {
        if lhs.rangeIndex == rhs.rangeIndex {
            return lhs.indexInRange < rhs.indexInRange
        } else {
            return lhs.rangeIndex < rhs.rangeIndex
        }
    }

    public static func > (lhs: MessageIdentifierSet.Index, rhs: MessageIdentifierSet.Index) -> Bool {
        if lhs.rangeIndex == rhs.rangeIndex {
            return lhs.indexInRange > rhs.indexInRange
        } else {
            return lhs.rangeIndex > rhs.rangeIndex
        }
    }

    public static func == (lhs: MessageIdentifierSet.Index, rhs: MessageIdentifierSet.Index) -> Bool {
        (lhs.rangeIndex == rhs.rangeIndex) && (lhs.indexInRange == rhs.indexInRange)
    }
}

// MARK: - Set Algebra

extension MessageIdentifierSet: SetAlgebra {
    public typealias Element = T

    public func contains(_ member: T) -> Bool {
        _ranges.contains(MessageIdentificationShiftWrapper(member))
    }

    public func union(_ other: Self) -> Self {
        MessageIdentifierSet(_ranges.union(other._ranges))
    }

    public func intersection(_ other: Self) -> Self {
        MessageIdentifierSet(_ranges.intersection(other._ranges))
    }

    public func symmetricDifference(_ other: MessageIdentifierSet) -> MessageIdentifierSet {
        MessageIdentifierSet(_ranges.symmetricDifference(other._ranges))
    }

    @discardableResult
    public mutating func insert(_ newMember: T) -> (inserted: Bool, memberAfterInsert: T) {
        guard !contains(newMember) else { return (false, newMember) }
        let r: Range<MessageIdentificationShiftWrapper> = Range(newMember)
        _ranges.insert(contentsOf: r)
        return (true, newMember)
    }

    @discardableResult
    public mutating func remove(_ member: T) -> T? {
        guard contains(member) else { return nil }
        let r: Range<MessageIdentificationShiftWrapper> = Range(member)
        _ranges.remove(contentsOf: r)
        return member
    }

    @discardableResult
    public mutating func update(with newMember: T) -> T? {
        guard !contains(newMember) else { return newMember }
        let r: Range<MessageIdentificationShiftWrapper> = Range(newMember)
        _ranges.insert(contentsOf: r)
        return nil
    }

    public mutating func formUnion(_ other: MessageIdentifierSet) {
        _ranges.formUnion(other._ranges)
    }

    public mutating func formIntersection(_ other: MessageIdentifierSet) {
        _ranges.formIntersection(other._ranges)
    }

    public mutating func formSymmetricDifference(_ other: MessageIdentifierSet) {
        _ranges.formSymmetricDifference(other._ranges)
    }
}

// MARK: - Encoding

extension MessageIdentifierSet: IMAPEncodable {
    @_spi(NIOIMAPInternal) public func writeIntoBuffer(_ buffer: inout EncodeBuffer) -> Int {
        buffer.writeArray(self._ranges.ranges, separator: ",", parenthesis: false) { (element, buffer) in
            let r = MessageIdentifierRange<T>(element)
            return buffer.writeMessageIdentifierRange(r)
        }
    }
}

extension MessageIdentifierSetNonEmpty: IMAPEncodable {
    @_spi(NIOIMAPInternal) public func writeIntoBuffer(_ buffer: inout EncodeBuffer) -> Int {
        self.set.writeIntoBuffer(&buffer)
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeUIDSet<T: MessageIdentifier>(_ set: MessageIdentifierSet<T>) -> Int {
        set.writeIntoBuffer(&self)
    }

    @discardableResult mutating func writeUIDSet<T: MessageIdentifier>(_ set: MessageIdentifierSetNonEmpty<T>) -> Int {
        set.writeIntoBuffer(&self)
    }
}
