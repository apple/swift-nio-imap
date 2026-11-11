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

/// Bytes the parser can read from, in one or more contiguous runs.
///
/// This is the library's input seam. A caller hands over whatever it already holds — a `Data`, a
/// `DispatchData`, an array of bytes, an ``IMAPInputBuffer`` of network reads, or a type of its own —
/// and the parser reads through it without asking for the bytes to be flattened into one buffer
/// first.
///
/// ```swift
/// var buffer = IMAPInputBuffer()
/// buffer.append(bytesFromTheNetwork)
/// while let response = try parser.parseResponseStream(buffer: &buffer) { … }
/// ```
///
/// ## Which type to use
///
/// - **A connection accumulating received bytes: ``IMAPInputBuffer``.** That is what the parser entry
///   points are written for. Appending a read copies it only if it is small or has no fixed address
///   (a `Data`), discarding what has been parsed is O(1), and it is the only input a large literal can
///   be delivered out of without being copied.
/// - **Bytes you already hold: hand them over if they are consumable, otherwise append them to an
///   ``IMAPInputBuffer``.** ``CommandParser/parseCommandStream(buffer:)`` and
///   ``ResponseParser/parseResponseStream(buffer:)`` take a ``ConsumableParserInputBuffer``, because
///   they discard whatever they parsed; `DispatchData` and — in `NIOIMAP` — `ByteBuffer` are that, so
///   they can be passed directly. `Data`, `[UInt8]`, `ArraySlice<UInt8>` and `ContiguousArray<UInt8>`
///   conform to *this* protocol but deliberately not to that one, because trimming them moves the
///   remaining bytes. Appending an array to an ``IMAPInputBuffer`` costs one small object and no copy
///   (below 1 KiB, a copy into a shared tail), appending a `Data` one copy, and either is the way to
///   parse out of it.
/// - **Bytes in a shape of your own: conform.** Two members, ``byteRegions`` and ``count``, and the
///   library does the rest. See *Conforming*, below.
///
/// Conforming does not mean writing anything that reads bytes. Reading happens through a
/// ``ParseInput``, whose surface is internal: the cursor appears in this protocol's signatures because
/// the default implementation of ``withParseInput(limit:_:)`` builds one and hands it to the parser,
/// and a conformer never has to look inside it.
///
/// ## Conforming
///
/// A conformer describes its bytes as an ordered collection of ``ByteRegion``s and says how many
/// bytes there are in total. Everything else has a default implementation.
///
/// Two refinements are worth knowing about before writing one. ``ConsumableParserInputBuffer`` adds
/// "the parser may discard what it consumed", which the entry points above require, and
/// ``StableRegionParserInputBuffer`` adds "my region pointers stay valid for a borrow of me", which buys
/// a single-pass gather and copy-free extraction of large payloads. ``IMAPInputBuffer`` is all three,
/// and is the worked example of each.
///
/// A conformance to this protocol alone is still worth having: it is what
/// ``SynchronizingLiteralParser/parseContinuationsNecessary(_:)`` takes, and it is how the package's own
/// tests parse out of arrays.
///
/// - Important: ``byteRegions`` must begin at the read position, and its regions must add up to
///   ``count``. A conformer that keeps a read head as an offset has to *slice* its first region
///   rather than hand over the whole thing and expect the parser to skip the prefix — the parser
///   reports how much it consumed relative to what it was shown, so a skipped prefix gets counted
///   twice and bytes go missing. Both halves are asserted in debug builds.
///
/// ## Cost
///
/// The parser's per-region overhead is small but not free — each move from one region to
/// the next costs something, and bulk scans restart at every boundary. That is invisible for
/// network-sized reads and dominant for pathologically small ones: one-byte regions parse far slower
/// per byte than contiguous bytes do. Callers that can hand over larger regions should.
public protocol ParserInputBuffer {
    /// The collection of contiguous byte runs this buffer is made of.
    associatedtype Regions: Collection where Regions.Element: ByteRegion

    /// The buffer's bytes, in order, starting at the read position.
    var byteRegions: Regions { get }

    /// The total number of bytes, across every region.
    var count: Int { get }

    /// How many regions ``byteRegions`` holds.
    ///
    /// The default implementation counts ``byteRegions``. Override it when the count is cheaper to
    /// come by than the regions themselves — `DispatchData` allocates an array to present its
    /// regions, and the gather only needs the number in order to size its table.
    var regionCount: Int { get }

    /// Reads through the buffer's bytes.
    ///
    /// This is the gather: it collects the buffer's regions into one flat table and hands `body` a
    /// cursor over them. Nothing about the cursor may outlive the call.
    ///
    /// The default implementation walks ``byteRegions``, holding each region's accessor open for as
    /// long as the cursor exists. ``StableRegionParserInputBuffer`` conformers replace it with a
    /// single pass, and must do so with an explicit one-line witness of their own — see that
    /// protocol.
    ///
    /// - Parameters:
    ///   - limit: The most bytes the parser may consume. Bytes past it are invisible to it, which is
    ///     how a caller parses a prefix of what it holds without slicing first.
    ///   - body: A closure that reads through the cursor.
    /// - Returns: Whatever `body` returns.
    func withParseInput<R>(limit: Int, _ body: (inout ParseInput) throws -> R) rethrows -> R
}

/// A ``ParserInputBuffer`` the parser can also consume from, so that a caller does not have to trim
/// it by hand.
///
/// ``ConsumableParserInputBuffer/parse(limit:_:)`` is the entry point that trims: whatever the
/// parser consumed is discarded when it returns, including when it throws.
///
/// - Important: ``discardFirst(_:)`` must be O(1) amortised in the number of bytes discarded. A
///   conformer that moves the remaining bytes down instead makes a caller that trims after every
///   message quadratic over the life of a connection. That is why `Data` and `Array` are deliberately
///   *not* consumable here, even though removing a prefix from them is one line: the one line is the slow
///   one. Callers that want to consume a `Data` can conform it themselves and know what it costs.
public protocol ConsumableParserInputBuffer: ParserInputBuffer {
    /// Discards the first `k` bytes.
    ///
    /// - Parameter k: How many bytes to discard. Must not exceed ``ParserInputBuffer/count``.
    mutating func discardFirst(_ k: Int)
}

/// A ``ParserInputBuffer`` whose region pointers stay valid for as long as the buffer is borrowed.
///
/// **This is one of the two unsafe seams on the parser's read side, and conforming to it is an
/// assertion the compiler cannot check.** ``ByteRegion`` promises only that a pointer is valid for the
/// duration of a ``ByteRegion/withUnsafeBytes(_:)`` call. A conformer here promises more: that the
/// pointers it pushes into a ``RegionSink`` stay valid for as long as a borrow of `self` lasts, so the
/// gather can collect them in one pass instead of nesting one accessor scope per region.
///
/// What that buys is not mainly speed. The generic gather recurses once per region, so it needs a
/// depth cap and has to coalesce the tail beyond it; a single pass needs neither, at any region
/// count.
///
/// It is also where zero-copy extraction comes from. A conformer that owns its bytes can pass an
/// ``IMAPByteStorage`` to ``RegionSink/append(_:owner:offset:)``, and a large payload extracted from
/// that region is then handed to the caller as a reference to the input rather than as a copy.
/// Passing `nil` is always correct and means such an extraction copies.
public protocol StableRegionParserInputBuffer: ParserInputBuffer {
    /// Pushes every region, in order, into `sink`.
    ///
    /// - Parameter sink: The table to fill. The only thing that can be done with it is appending.
    borrowing func withStableRegions(into sink: inout RegionSink)
}

/// The table a ``StableRegionParserInputBuffer`` fills, one region at a time.
///
/// The library owns the storage and validates every push, so a conformer cannot get the bookkeeping
/// wrong: it cannot overrun the table, and it cannot describe a range that lies outside the owner it
/// names. It is neither copyable nor escapable, so it cannot outlive the gather that created it.
public struct RegionSink: ~Copyable, ~Escapable {
    /// Where the entries go. Sized from ``ParserInputBuffer/regionCount``.
    private let table: UnsafeMutableBufferPointer<RegionEntry>

    /// How many entries have been pushed.
    private(set) var filled: Int

    /// How many bytes have been pushed, for the conformance assertion in the gather.
    private(set) var byteCount: Int

    @_lifetime(immortal)
    internal init(table: UnsafeMutableBufferPointer<RegionEntry>) {
        self.table = table
        self.filled = 0
        self.byteCount = 0
    }

    /// Adds one region.
    ///
    /// - Parameters:
    ///   - bytes: The region's bytes. Must stay valid for as long as `self` and the borrow of the
    ///     buffer that produced it — this is the promise
    ///     ``StableRegionParserInputBuffer`` makes.
    ///   - owner: Who keeps `bytes` alive, if the buffer can vouch for them, so that a large
    ///     extraction can refer to the input rather than copying it. `nil` means an extraction
    ///     copies, which is always correct.
    ///   - offset: Where `bytes` begins inside `owner`. Zero when the region is all of the owner;
    ///     the head offset when the region is the unconsumed tail of one.
    @_lifetime(self: copy self)
    public mutating func append(_ bytes: UnsafeBufferPointer<UInt8>, owner: IMAPByteStorage?, offset: Int) {
        precondition(
            filled < table.count,
            "a ParserInputBuffer pushed more than the \(table.count) regions its regionCount promised"
        )
        if let owner {
            precondition(
                offset >= 0 && offset + bytes.count <= owner.count,
                "a region of \(bytes.count) bytes at offset \(offset) does not fit its owner's \(owner.count)"
            )
        }
        table[filled] = RegionEntry(
            bytes: bytes,
            owner: owner.map { Unmanaged.passUnretained($0) },
            ownerOffset: offset
        )
        filled += 1
        byteCount += bytes.count
    }

    /// The entries pushed so far.
    internal var filledTable: ChunkTable {
        ChunkTable(rebasing: table[..<filled])
    }
}

/// `RegionSink` is deliberately **not** `Sendable`.
///
/// It points at a table on the gather's stack, and the pointers pushed into it are valid only for that
/// gather. Being neither copyable nor escapable already keeps it there; this says why.
@available(*, unavailable)
extension RegionSink: Sendable {}

// MARK: - The generic gather

extension ParserInputBuffer {
    /// The most frames the recursive gather may use.
    ///
    /// One region costs one frame, and a frame here is not small, especially in a debug build, because a
    /// generic region accessor plus its closure is several physical frames. A Swift concurrency task
    /// thread has a limited stack, and the parser recurses below the gather on top of that — so 64
    /// frames is the budget. It is deliberately conservative: 256 was tried first and overflowed a test thread's
    /// stack, and a stack overflow cannot be caught, so "the caller passed a lot of regions" would
    /// otherwise be a killed process.
    ///
    /// Regions past the cap are coalesced rather than dropped, so the input stays unbounded and only the
    /// stack is bounded. Types that really do carry many regions conform to
    /// ``StableRegionParserInputBuffer`` and never come here — that path has no recursion and no cap.
    internal static var maximumGatherDepth: Int { 64 }

    public var regionCount: Int { byteRegions.count }

    public func withParseInput<R>(limit: Int, _ body: (inout ParseInput) throws -> R) rethrows -> R {
        let regions = byteRegions
        assertRegionsAddUp(regions)
        // One entry per region up to the cap, plus one for a coalesced tail.
        let capacity = Swift.min(regionCount, Self.maximumGatherDepth) + 1
        return try withUnsafeTemporaryAllocation(of: RegionEntry.self, capacity: capacity) { table in
            try Self.descend(regions, regions.startIndex, 0, 0, table, limit, body)
        }
    }

    /// Reads through the buffer's bytes, with no limit on how many the parser may consume.
    ///
    /// - Parameter body: A closure that reads through the cursor.
    /// - Returns: Whatever `body` returns.
    ///
    /// - Note: This is deliberately a *different* signature from
    ///   ``ParserInputBuffer/withParseInput(limit:_:)`` rather than a default argument on it. A
    ///   default argument here would shadow a conformer's own witness, so a one-pass conformer would
    ///   silently take the generic path whenever the caller left the limit out — which is the common
    ///   case, and the failure is invisible.
    public func withParseInput<R>(_ body: (inout ParseInput) throws -> R) rethrows -> R {
        try withParseInput(limit: .max, body)
    }

    /// Fills the table one region deeper per frame.
    ///
    /// The nesting is forced: a cursor cannot be threaded *through* a chain of accessor scopes, so
    /// the descent writes pointers into a flat table on the way down and builds the cursor at the
    /// innermost frame, where every scope is still open. Do not restructure this into a loop that
    /// opens and closes one region at a time.
    private static func descend<R>(
        _ regions: Regions,
        _ index: Regions.Index,
        _ depth: Int,
        _ filled: Int,
        _ table: UnsafeMutableBufferPointer<RegionEntry>,
        _ limit: Int,
        _ body: (inout ParseInput) throws -> R
    ) rethrows -> R {
        guard index != regions.endIndex else {
            var input = ParseInput(table: ChunkTable(rebasing: table[..<filled]), owner: regions, limit: limit)
            return try body(&input)
        }
        // Coalescing at the cap, or when the table is full because `regionCount` under-reported.
        guard depth < maximumGatherDepth, filled < table.count - 1 else {
            return try coalescing(regions, index, filled, table, limit, body)
        }
        let next = regions.index(after: index)
        return try regions[index].withUnsafeBytes { raw -> R in
            guard !raw.isEmpty else {
                // An empty region carries no bytes, so it needs no entry — but it does cost a frame.
                return try descend(regions, next, depth + 1, filled, table, limit, body)
            }
            table[filled] = RegionEntry(bytes: raw.bindMemory(to: UInt8.self))
            return try descend(regions, next, depth + 1, filled + 1, table, limit, body)
        }
    }

    /// Copies every region from `index` onwards into one buffer, and parses that as a single region.
    ///
    /// This is the pathological path: a caller that hands over more regions than the recursion can
    /// safely descend gets a copy of the tail rather than a stack overflow. Nothing is dropped, and
    /// the copy is bounded by the bytes the caller passed.
    private static func coalescing<R>(
        _ regions: Regions,
        _ index: Regions.Index,
        _ filled: Int,
        _ table: UnsafeMutableBufferPointer<RegionEntry>,
        _ limit: Int,
        _ body: (inout ParseInput) throws -> R
    ) rethrows -> R {
        var tail = [UInt8]()
        for region in regions[index...] {
            region.withUnsafeBytes { tail.append(contentsOf: $0) }
        }
        return try tail.withUnsafeBytes { raw -> R in
            var count = filled
            if !raw.isEmpty {
                table[filled] = RegionEntry(bytes: raw.bindMemory(to: UInt8.self))
                count += 1
            }
            var input = ParseInput(table: ChunkTable(rebasing: table[..<count]), owner: tail, limit: limit)
            return try body(&input)
        }
    }

    /// Checks the conformance requirement that the regions add up to `count`.
    ///
    /// A buffer whose regions do not start at its read position usually still parses — it parses the
    /// bytes it already handed out a second time — so the symptom is corrupted output far from the
    /// cause. Failing here instead means a bad conformer fails in its first test.
    private func assertRegionsAddUp(_ regions: Regions) {
        assert(
            regions.reduce(0) { $0 + $1.withUnsafeBytes { $0.count } } == count,
            "\(Self.self)'s regions hold \(regions.reduce(0) { $0 + $1.withUnsafeBytes { $0.count } }) bytes "
                + "but its count is \(count). Regions must begin at the read position and add up to count."
        )
    }
}

// MARK: - The one-pass gather

extension StableRegionParserInputBuffer {
    /// Reads through the buffer's bytes in a single pass, with no recursion and no depth cap.
    ///
    /// Conformers forward to this from their own ``ParserInputBuffer/withParseInput(limit:_:)``:
    ///
    /// ```swift
    /// public func withParseInput<R>(limit: Int, _ body: (inout ParseInput) throws -> R) rethrows -> R {
    ///     try _stableWithParseInput(limit: limit, body)
    /// }
    /// ```
    ///
    /// The forward has to be written out like that rather than left to a default implementation on
    /// this protocol. A default here satisfies the *base* protocol's requirement, and which of the
    /// two the compiler picks depends on where the call is made from — so `parse` would take the
    /// generic path while a direct call took this one, with nothing failing to announce it.
    ///
    /// - Parameters:
    ///   - limit: The most bytes the parser may consume.
    ///   - body: A closure that reads through the cursor.
    /// - Returns: Whatever `body` returns.
    public func _stableWithParseInput<R>(
        limit: Int,
        _ body: (inout ParseInput) throws -> R
    ) rethrows -> R {
        try withUnsafeTemporaryAllocation(
            of: RegionEntry.self,
            capacity: Swift.max(regionCount, 1)
        ) { table in
            var sink = RegionSink(table: table)
            withStableRegions(into: &sink)
            assert(
                sink.byteCount == count,
                "\(Self.self) pushed \(sink.byteCount) bytes but its count is \(count). Regions must "
                    + "begin at the read position and add up to count."
            )
            var input = ParseInput(table: sink.filledTable, owner: self, limit: limit)
            return try body(&input)
        }
    }
}

// MARK: - Consuming

extension ConsumableParserInputBuffer {
    /// Reads through the buffer's bytes and discards whatever the parser consumed.
    ///
    /// This is the entry point a connection uses: the caller cannot forget to trim, and cannot trim
    /// by the wrong amount.
    ///
    /// Trimming happens on every exit path, a thrown error included, because the streaming literal
    /// modes legitimately make progress and *then* report that they need more bytes. A parser that
    /// wants its position back on failure gets that from the cursor's own backtracking instead, which
    /// leaves nothing consumed to trim.
    ///
    /// - Parameters:
    ///   - limit: The most bytes the parser may consume.
    ///   - body: A closure that reads through the cursor.
    /// - Returns: Whatever `body` returns.
    public mutating func parse<R>(
        limit: Int = .max,
        _ body: (inout ParseInput) throws -> R
    ) rethrows -> R {
        var consumed = 0
        defer { if consumed > 0 { self.discardFirst(consumed) } }
        // `limit:` is passed explicitly so that this binds a conformer's own witness rather than the
        // no-limit convenience overload, which would send a one-pass conformer down the generic path.
        return try withParseInput(limit: limit) { input in
            defer { consumed = input.consumed }
            return try body(&input)
        }
    }
}

// MARK: - Stdlib conformances

// Read-only on purpose: removing a prefix from an array moves the rest of it, so these are the
// "parse all of this" sources — tests, fuzzing, one-shot callers — and not connection buffers.
extension Array: ParserInputBuffer where Element == UInt8 {
    public var byteRegions: CollectionOfOne<[UInt8]> { CollectionOfOne(self) }
}

extension ArraySlice: ParserInputBuffer where Element == UInt8 {
    public var byteRegions: CollectionOfOne<ArraySlice<UInt8>> { CollectionOfOne(self) }
}

extension ContiguousArray: ParserInputBuffer where Element == UInt8 {
    public var byteRegions: CollectionOfOne<ContiguousArray<UInt8>> { CollectionOfOne(self) }
}
