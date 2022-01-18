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

/// See `MessageIdentifierRange<SequenceNumber>`
public typealias SequenceRange = MessageIdentifierRange<SequenceNumber>

/// See `MessageIdentifierRange<UID>`
public typealias UIDRange = MessageIdentifierRange<UID>

/// See `MessageIdentifierSet<SequenceNumber>`
public typealias SequenceSet = MessageIdentifierSet<SequenceNumber>

/// See `MessageIdentifierSet<UID>`
public typealias UIDSet = MessageIdentifierSet<UID>

/// See `MessageIdentifierSetNonEmpty<UID>`
public typealias UIDSetNonEmpty = MessageIdentifierSetNonEmpty<UID>

/// A set contains an array of `MessageIdentifierRange<MessageIdentifier>>` to represent a (potentially large) collection of messages.
///
/// `MessageIdentifier`s are _not_ sorted.
public struct MessageIdentifierSet<IdentifierType: MessageIdentifier>: Hashable {
    /// A set that contains a single range, that in turn contains all messages.
    public static var all: Self {
        MessageIdentifierSet(MessageIdentifierRange<IdentifierType>.all)
    }

    /// A set that contains no `MessageIdentifier`s.
    public static var empty: Self {
        MessageIdentifierSet()
    }

    /// A non-empty array of `MessageIdentifier` ranges.
    fileprivate var _ranges: RangeSet<MessageIdentificationShiftWrapper>

    fileprivate init(_ ranges: RangeSet<MessageIdentificationShiftWrapper>) {
        self._ranges = ranges
    }

    /// Creates a new `MessageIdentifierSet` containing the `MessageIdentifier`s in the given ranges.
    public init<S: Sequence>(_ ranges: S) where S.Element == MessageIdentifierRange<IdentifierType> {
        self.init()
        ranges.forEach {
            self._ranges.insert(contentsOf: Range($0))
        }
    }

    public init() {
        self._ranges = RangeSet()
    }

    public init(_ id: IdentifierType) {
        self._ranges = RangeSet(MessageIdentificationShiftWrapper(id) ..< (MessageIdentificationShiftWrapper(id).advanced(by: 1)))
    }
}

/// A wrapper around a `MessageIdentifierSet` that enforces at least one element.
public struct MessageIdentifierSetNonEmpty<IdentifierType: MessageIdentifier>: Hashable {
    /// A set that contains a single range, that in turn contains all messages.
    public static var all: Self {
        MessageIdentifierSetNonEmpty(set: .all)!
    }

    /// The underlying `MessageIdentifierSet`
    public private(set) var set: MessageIdentifierSet<IdentifierType>

    /// Creates a new `MessageIdentifierSetNonEmpty` from a `MessageIdentifierSet`, after first
    /// validating that the set is not emtpy.
    /// - parameter set: The underlying `MessageIdentifierSet` to use.
    /// - returns: `nil` if the given `MessageIdentifierSet` is empty.
    public init?(set: MessageIdentifierSet<IdentifierType>) {
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

    init<IdentifierType: MessageIdentifier>(_ id: IdentifierType) {
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
    fileprivate init<IdentifierType: MessageIdentifier>(_ r: MessageIdentifierRange<IdentifierType>) {
        self = MessageIdentificationShiftWrapper(r.range.lowerBound) ..< MessageIdentificationShiftWrapper(r.range.upperBound).advanced(by: 1)
    }

    fileprivate init<IdentifierType: MessageIdentifier>(_ id: IdentifierType) {
        self = MessageIdentificationShiftWrapper(id) ..< MessageIdentificationShiftWrapper(id).advanced(by: 1)
    }
}

extension MessageIdentifierRange {
    init(_ r: Range<MessageIdentificationShiftWrapper>) {
        self.init(IdentifierType(r.lowerBound) ... IdentifierType(r.upperBound.advanced(by: -1)))
    }
}

// MARK: -

extension MessageIdentifierSet {
    /// Returns `true` if there are no gaps in the values, i.e. the set is non-sparse.
    ///
    /// For example: `5:10` is contiguous, but `5:6,8` is _not_.
    ///
    /// - Note: Returns `true` for the empty set.
    public var isContiguous: Bool {
        _ranges.ranges.count <= 1
    }
}

extension MessageIdentifierSet {
    public struct RangeView: RandomAccessCollection {
        fileprivate var underlying: RangeSet<MessageIdentificationShiftWrapper>.Ranges

        public var startIndex: Int { underlying.startIndex }
        public var endIndex: Int { underlying.endIndex }

        public subscript(i: Int) -> MessageIdentifierRange<IdentifierType> {
            MessageIdentifierRange<IdentifierType>(underlying[i])
        }
    }

    public var ranges: RangeView {
        RangeView(underlying: _ranges.ranges)
    }
}

extension MessageIdentifierSet.RangeView: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = MessageIdentifierRange<IdentifierType>

    public init(arrayLiteral elements: ArrayLiteralElement...) {
        let set = MessageIdentifierSet(elements)
        self = set.ranges
    }
}

extension MessageIdentifierSet.RangeView: Equatable {
    public static func == (lhs: MessageIdentifierSet<IdentifierType>.RangeView, rhs: MessageIdentifierSet<IdentifierType>.RangeView) -> Bool {
        lhs.elementsEqual(rhs)
    }
}

// MARK: -

extension MessageIdentifierSet {
    /// Creates a `MessageIdentifierSet` from a closed range.
    /// - parameter range: The closed range to use.
    public init(_ range: ClosedRange<IdentifierType>) {
        self.init(MessageIdentifierRange<IdentifierType>(range))
    }

    /// Creates a `MessageIdentifierSet` from a partial range.
    /// - parameter range: The partial range to use.
    public init(_ range: PartialRangeThrough<IdentifierType>) {
        self.init(MessageIdentifierRange<IdentifierType>(range))
    }

    /// Creates a `MessageIdentifierSet` from a partial range.
    /// - parameter range: The partial range to use.
    public init(_ range: PartialRangeFrom<IdentifierType>) {
        self.init(MessageIdentifierRange<IdentifierType>(range))
    }

    /// Creates a `MessageIdentifierSet` from a range.
    /// - parameter range: The range to use.
    public init(_ range: Range<IdentifierType>) {
        if range.isEmpty {
            self.init()
        } else {
            self.init(range.lowerBound ... range.upperBound.advanced(by: -1))
        }
    }

    /// Creates a set from a single range.
    /// - parameter range: The `MessageIdentifierRange` to construct a set from.
    public init(_ range: MessageIdentifierRange<IdentifierType>) {
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
            .map { "\(MessageIdentifierRange<IdentifierType>($0))" }
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
    /// Creates a new MessageIdentifierSet from a literal array of ranges.
    /// - parameter arrayLiteral: The elements to use, assumed to be non-empty.
    public init(arrayLiteral elements: MessageIdentifierRange<IdentifierType>...) {
        self.init(elements)
    }
}

extension MessageIdentifierSetNonEmpty: ExpressibleByArrayLiteral {
    /// Creates a new MessageIdentifierSet from a literal array of ranges.
    /// - parameter arrayLiteral: The elements to use, assumed to be non-empty.
    public init(arrayLiteral elements: MessageIdentifierRange<IdentifierType>...) {
        precondition(elements.count > 0, "At least one element is required.")
        self.set = MessageIdentifierSet(elements)
    }
}

extension MessageIdentifierSet: BidirectionalCollection {
    public struct Index {
        fileprivate var rangeIndex: RangeSet<MessageIdentificationShiftWrapper>.Ranges.Index
        fileprivate var indexInRange: IdentifierType.Stride
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
                let indexCount = IdentifierType.Stride(_ranges.ranges[result.rangeIndex].count)
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
                let indexesInRangeCount = IdentifierType.Stride(_ranges.ranges[result.rangeIndex].count)
                if result.indexInRange.advanced(by: remainingDistance) < indexesInRangeCount {
                    result.indexInRange = result.indexInRange.advanced(by: remainingDistance)
                    break
                }
                let nextRange = _ranges.ranges.index(after: result.rangeIndex)
                let step = result.indexInRange.distance(to: IdentifierType.Stride(_ranges.ranges[result.rangeIndex].count))
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

    public subscript(position: Index) -> IdentifierType {
        IdentifierType(_ranges.ranges[position.rangeIndex].lowerBound).advanced(by: position.indexInRange)
    }

    public var isEmpty: Bool {
        _ranges.isEmpty
    }

    /// The number of `MessageIdentifier`s in the set.
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
    public typealias Element = IdentifierType

    public func contains(_ member: IdentifierType) -> Bool {
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
    public mutating func insert(_ newMember: IdentifierType) -> (inserted: Bool, memberAfterInsert: IdentifierType) {
        guard !contains(newMember) else { return (false, newMember) }
        let r: Range<MessageIdentificationShiftWrapper> = Range(newMember)
        _ranges.insert(contentsOf: r)
        return (true, newMember)
    }

    @discardableResult
    public mutating func remove(_ member: IdentifierType) -> IdentifierType? {
        guard contains(member) else { return nil }
        let r: Range<MessageIdentificationShiftWrapper> = Range(member)
        _ranges.remove(contentsOf: r)
        return member
    }

    @discardableResult
    public mutating func update(with newMember: IdentifierType) -> IdentifierType? {
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

extension MessageIdentifierSet where IdentifierType == SequenceNumber {
    init(_ set: MessageIdentifierSet<UnknownMessageIdentifier>) {
        let converted = set.ranges.map { range in
            MessageIdentifierRange<SequenceNumber>(range)
        }
        self.init(converted)
    }
}

extension MessageIdentifierSet where IdentifierType == UID {
    init(_ set: MessageIdentifierSet<UnknownMessageIdentifier>) {
        let converted = set.ranges.map { range in
            MessageIdentifierRange<UID>(range)
        }
        self.init(converted)
    }
}

extension MessageIdentifierSet where IdentifierType == UnknownMessageIdentifier {
    init(_ set: MessageIdentifierSet<UID>) {
        let converted = set.ranges.map { range in
            MessageIdentifierRange<UnknownMessageIdentifier>(range)
        }
        self.init(converted)
    }

    init(_ set: MessageIdentifierSet<SequenceNumber>) {
        let converted = set.ranges.map { range in
            MessageIdentifierRange<UnknownMessageIdentifier>(range)
        }
        self.init(converted)
    }
}

// MARK: - Encoding

extension MessageIdentifierSet: IMAPEncodable {
    @_spi(NIOIMAPInternal) public func writeIntoBuffer(_ buffer: inout EncodeBuffer) -> Int {
        buffer.writeArray(self._ranges.ranges, separator: ",", parenthesis: false) { (element, buffer) in
            let r = MessageIdentifierRange<IdentifierType>(element)
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
    @discardableResult mutating func writeUIDSet<IdentifierType: MessageIdentifier>(_ set: MessageIdentifierSet<IdentifierType>) -> Int {
        set.writeIntoBuffer(&self)
    }

    @discardableResult mutating func writeUIDSet<IdentifierType: MessageIdentifier>(_ set: MessageIdentifierSetNonEmpty<IdentifierType>) -> Int {
        set.writeIntoBuffer(&self)
    }
}
