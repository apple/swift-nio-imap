//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// Building a `RangeSet` from many ranges, e.g. an ESEARCH `ALL 3,7:9,12,…` with thousands of elements.
//
// `RangeSet` is not inlinable, so its public initializers run unspecialized in the stdlib.
// `RangeSet(_: some Sequence)` sorts, and each element read in that sort mallocs: two mallocs per range.
// `insert(contentsOf:)` per range barely allocates, but costs ~140 ns each.
//
// `Collection.indices(where:)` is inlinable and ends in `RangeSet(_orderedRanges:)`, the stdlib's
// no-sort initializer. So for ranges that are already sorted, we run it over a virtual collection
// whose indices are the range bounds:
//
//     ranges   3..<4      7..<10      12..<13
//     indices  3     4    7     10    12  (endIndex 13)
//     element  true  false true false true
//
// `indices(where: { $0 })` then returns exactly the ranges. 5,000 ranges: ~40 µs and no per-range
// malloc, against ~280 µs and 10,000 mallocs for `RangeSet(array)`.
//
// The result rests only on what `indices(where:)` is documented to return; should its body change,
// this stays correct and only gets slower.

extension MessageIdentifierSet {
    /// A `RangeSet` holding the union of `ranges`.
    ///
    /// Sorted input (the usual case) takes the fast path above; anything else falls back to
    /// `RangeSet(_:)`. `consuming`, so the in-place merge does not copy.
    @usableFromInline
    static func makeRangeSet(
        _ ranges: consuming [Range<MessageIdentificationShiftWrapper>]
    ) -> RangeSet<MessageIdentificationShiftWrapper> {
        var merged = consume ranges
        guard let count = mergeSortedRanges(&merged) else {
            // Unsorted. Every element of `merged` is still contained in the union, so this is correct.
            return RangeSet(merged)
        }
        switch count {
        case 0:
            return RangeSet()
        case 1:
            return RangeSet(merged[0])
        default:
            merged.removeLast(merged.count - count)
            var cursor = 0
            return withUnsafeMutablePointer(to: &cursor) { cursor in
                // The collection, and so the pointer, does not outlive this closure: `indices(where:)`
                // returns only `Range` values.
                RangeBoundaries(ranges: merged, cursor: cursor).indices(where: { $0 })
            }
        }
    }

    /// Merges overlapping and adjacent ranges in place, for input sorted by lower bound, and drops
    /// empty ones. `[1..<4, 2..<5, 5..<6, 8..<9]` becomes `[1..<6, 8..<9, …]`.
    ///
    /// - Returns: How many merged ranges lead `ranges` — sorted, non-empty, and with a gap between
    ///   each — or `nil` if the input is not sorted. Either way, every element of `ranges` stays
    ///   contained in the union of the input.
    private static func mergeSortedRanges(_ ranges: inout [Range<MessageIdentificationShiftWrapper>]) -> Int? {
        var count = 0
        for index in ranges.indices {
            let range = ranges[index]
            if range.isEmpty { continue }
            guard count > 0 else {
                ranges[0] = range
                count = 1
                continue
            }
            let last = ranges[count - 1]
            guard last.lowerBound <= range.lowerBound else { return nil }
            if range.lowerBound <= last.upperBound {
                ranges[count - 1] = last.lowerBound..<Swift.max(last.upperBound, range.upperBound)
            } else {
                ranges[count] = range
                count += 1
            }
        }
        return count
    }
}

/// The bounds of sorted ranges with a gap between each, as a collection: indices are
/// `[l0, u0, l1, u1, …, lN]`, `endIndex` is `uN`, and an element is `true` at a lower bound.
///
/// An index is a bound, not a position, so finding its position takes a search. `cursor` remembers the
/// last position: `indices(where:)` walks in order, so each lookup is O(1). Any other access pattern
/// still works, through a binary search.
private struct RangeBoundaries: Collection {
    typealias Index = MessageIdentificationShiftWrapper

    /// At least two ranges, sorted, non-empty, with a gap between each.
    let ranges: [Range<Index>]

    /// The position, in `[l0, u0, l1, …]`, of the bound looked up last.
    let cursor: UnsafeMutablePointer<Int>

    var startIndex: Index { ranges[0].lowerBound }

    var endIndex: Index { ranges[ranges.count - 1].upperBound }

    subscript(index: Index) -> Bool {
        position(of: index) % 2 == 0
    }

    func index(after index: Index) -> Index {
        bound(at: position(of: index) + 1)
    }

    /// The bound at `position` in `[l0, u0, l1, u1, …]`.
    private func bound(at position: Int) -> Index {
        let range = ranges[position / 2]
        return position % 2 == 0 ? range.lowerBound : range.upperBound
    }

    /// The position of `index` in `[l0, u0, l1, u1, …]`.
    private func position(of index: Index) -> Int {
        let last = cursor.pointee
        if bound(at: last) == index { return last }
        let boundCount = ranges.count * 2
        if last + 1 < boundCount, bound(at: last + 1) == index {
            cursor.pointee = last + 1
            return last + 1
        }
        var low = 0
        var high = boundCount - 1
        while low < high {
            let middle = (low + high) / 2
            if bound(at: middle) < index {
                low = middle + 1
            } else {
                high = middle
            }
        }
        cursor.pointee = low
        return low
    }
}
