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

@testable import NIOIMAPCore

/// One region to hand to a ``ParseInput``, described the way a real staging type would produce it: a run
/// of owned bytes, plus the slice of them that is actually visible.
///
/// The two are separate on purpose. An owner box spans a whole network read while a region may be the
/// *tail* of that read after a partial consume, so `visible.lowerBound` is the region's offset inside its
/// owner — the number that a zero-copy extraction gets wrong if it is ignored.
struct TestRegion {
    /// Everything the owner keeps alive.
    var owned: [UInt8]
    /// The part of `owned` the cursor gets to see.
    var visible: Range<Int>
    /// Whether the region carries an owner, which is what lets an extraction retain rather than copy.
    var vouching: Vouching

    enum Vouching {
        /// Carries an owner: an extraction may retain the bytes.
        case vouched
        /// No owner: an extraction has to copy.
        case unvouched
    }

    init(owned: [UInt8], visible: Range<Int>? = nil, vouching: Vouching = .vouched) {
        self.owned = owned
        self.visible = visible ?? 0..<owned.count
        self.vouching = vouching
    }

    /// A region whose visible bytes are all of it.
    init(_ text: String, vouching: Vouching = .vouched) {
        self.init(owned: Array(text.utf8), vouching: vouching)
    }

    /// A region that is the tail of a larger owned run — the shape a partially consumed head region has.
    init(prefix: String, visible text: String, vouching: Vouching = .vouched) {
        let owned = Array(prefix.utf8) + Array(text.utf8)
        self.init(owned: owned, visible: prefix.utf8.count..<owned.count, vouching: vouching)
    }

    var visibleBytes: [UInt8] { Array(owned[visible]) }
}

/// A ``ParserInputBuffer`` over ``TestRegion``s, for driving the cursor from tests.
///
/// It exists because the shipped conformers cannot express everything the cursor has to cope with. This
/// one can: it slices its head region, it can decline to vouch for a region so that an extraction has to
/// copy, and — unlike the recursive gather, which skips them — it hands over empty regions, because a
/// one-pass conformer is allowed to.
struct TestInputBuffer: StableRegionParserInputBuffer, ConsumableParserInputBuffer {
    private struct Entry {
        var storage: IMAPByteStorage
        var visible: Range<Int>
        var vouching: TestRegion.Vouching
    }

    private var entries: [Entry]

    private(set) var count: Int

    init(_ regions: [TestRegion]) {
        self.entries = regions.map {
            Entry(storage: IMAPByteStorage($0.owned), visible: $0.visible, vouching: $0.vouching)
        }
        self.count = self.entries.reduce(0) { $0 + $1.visible.count }
    }

    var byteRegions: [IMAPBuffer] {
        entries.map { IMAPBuffer($0.storage, $0.visible) }
    }

    var regionCount: Int { entries.count }

    borrowing func withStableRegions(into sink: inout RegionSink) {
        for entry in entries {
            let bytes = entry.storage.withUnsafeBytes { $0 }
            let visible = UnsafeRawBufferPointer(rebasing: bytes[entry.visible])
            sink.append(
                visible.bindMemory(to: UInt8.self),
                owner: entry.vouching == .vouched ? entry.storage : nil,
                offset: entry.visible.lowerBound
            )
        }
    }

    func withParseInput<R>(limit: Int, _ body: (inout ParseInput) throws -> R) rethrows -> R {
        try _stableWithParseInput(limit: limit, body)
    }

    /// Moves the read head, slicing the first region rather than dropping its consumed prefix — the
    /// shape that gets the offset arithmetic wrong if either term is missing.
    mutating func discardFirst(_ k: Int) {
        var remaining = k
        while remaining > 0, let first = entries.first {
            if remaining < first.visible.count {
                entries[0].visible = (first.visible.lowerBound + remaining)..<first.visible.upperBound
                count -= remaining
                return
            }
            count -= first.visible.count
            remaining -= first.visible.count
            entries.removeFirst()
        }
    }
}

/// Builds ``ParseInput`` cursors for tests.
///
/// The multi-region form goes through the real one-pass gather, so these tests cover
/// ``RegionSink``, the owner offsets and the empty-region policy as well as the cursor itself.
enum ParseInputHarness {
    /// Runs `body` with a cursor over `regions`.
    static func withInput<R>(
        _ regions: [TestRegion],
        limit: Int = .max,
        _ body: (inout ParseInput) throws -> R
    ) rethrows -> R {
        let buffer = TestInputBuffer(regions)
        // `limit:` explicitly, so this binds the conformer's own witness — the one-pass gather.
        return try buffer.withParseInput(limit: limit, body)
    }

    /// Runs `body` with a single-region cursor built the way a caller with contiguous bytes would build
    /// one: no table, and therefore no owner, so every extraction copies.
    static func withSpan<R>(
        _ bytes: [UInt8],
        limit: Int = .max,
        _ body: (inout ParseInput) throws -> R
    ) rethrows -> R {
        try bytes.withUnsafeBufferPointer { buffer in
            var input = ParseInput(_span(buffer), limit: limit)
            return try body(&input)
        }
    }

    static func withSpan<R>(
        _ text: String,
        limit: Int = .max,
        _ body: (inout ParseInput) throws -> R
    ) rethrows -> R {
        try withSpan(Array(text.utf8), limit: limit, body)
    }
}

/// Runs `body` and returns the error it threw, or `nil` if it returned.
///
/// `#expect(throws:)` cannot be used around a cursor: its closure would have to capture an `inout` value
/// of a non-escapable type.
func errorThrown<T>(by body: () throws -> T) -> Error? {
    do {
        _ = try body()
        return nil
    } catch {
        return error
    }
}
