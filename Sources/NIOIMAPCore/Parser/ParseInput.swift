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

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// Compiler constraints not obvious from the code (the others are at their sites: `RegionEntry`,
// `_span(_:)`, `ParseInput.head`):
//
// - The lifetime checker is a SIL pass. `swiftc -typecheck` accepts code a real build rejects, so
//   verify lifetime changes with a full build.
// - Spell it `@_lifetime`. `@lifetime` without the underscore only warns. Annotations name
//   parameters, never properties.
//
// Unsafe seams. In the byte, encoder and parser code — `NIOIMAPCore`'s `Bytes/`, `Parser/` and
// `EncodeBuffer*.swift`, and `NIOIMAP`'s `Bytes/` — memory safety and `Sendable` are compiler-checked
// except at these thirteen. Not counted: reading through a pointer, or binding it to `UInt8`, inside the
// `withUnsafe…` closure that produced it. Outside that scope, `Base64/Chromium.swift` and
// `MailboxName.swift` use pointers too; both predate this list.
//
// 1. Read: `_span(_:)`, below, and the region table it reads, a `withUnsafeTemporaryAllocation` the
//    gather fills (ParserInputBuffer.swift). A `Span` may be rebuilt from a table entry. Entries are written
//    only below the table's capacity and read only below the count filled.
// 2. Read: `StableRegionParserInputBuffer.withStableRegions(into:)` via `RegionSink`
//    (ParserInputBuffer.swift). The conformer's region pointers outlive their accessor and its owners
//    keep them alive. `RegionSink` holds owners unretained (`Unmanaged`) and its init is
//    `@_lifetime(immortal)`; it is `~Copyable`, and only the gather creates one. `IMAPInputBuffer`
//    retains only regions with `IMAPByteStorage.hasStableAddress` and copies the rest.
// 3. Write: `OutputSegment: @unchecked Sendable` (OutputSegment.swift). Handed-out ranges and the bytes
//    still being written are disjoint; a segment never reallocates. An `IMAPInputBuffer` tail is written
//    only while that buffer is its sole owner, and its `Regions` view reads only up to `used`.
// 4. Write: `IMAPOutputBuffer.OpenTail` (IMAPOutputBuffer.swift). Writes go through its cached raw
//    pointer into the open segment, not through the segment. `Storage.tail` holds that segment for as
//    long as `open` describes it.
// 5. Write: `@exclusivity(unchecked)` on `IMAPOutputBuffer.Storage`'s properties (IMAPOutputBuffer.swift).
//    No runtime exclusivity check. `Storage` is private, `IMAPOutputBuffer` is not `Sendable`, and every
//    write first checks that the box is uniquely referenced.
// 6. Write: `IMAPBuffer.makeDispatchData()` donating a pointer to `bytesNoCopy`
//    (IMAPBufferList+DispatchData.swift). Contained by `IMAPByteStorage.hasStableAddress`: other
//    regions copy.
// 7. Write: `IMAPBufferList.makeDispatchData()` copying a run of regions into a `malloc` it hands to
//    `bytesNoCopy` with `.free` (IMAPBufferList+DispatchData.swift). Exact-size, filled before the
//    hand-off, and not touched after it.
// 8. Write: `EncodeBuffer.writeDecimal(_:minimumDigits:)` formats into a `withUnsafeTemporaryAllocation`
//    (EncodeBuffer.swift). `maximumDecimalLength` holds every digit of a number up to
//    `maximumDecimalBitWidth` bits plus a sign; padding stops at the start; only the written suffix is read.
// 9. Write: `EncodeBuffer.writeQuotedIMAPString(_:)` escapes into a `withUnsafeTemporaryAllocation`
//    (ByteBuffer+WriteLiteral.swift). Its `2 * count + 2` bytes fit every byte escaped, plus both quotes.
// 10. Public: `IMAPBuffer.withUnsafeBytesAndOwner(_:)` (IMAPBuffer.swift) lets its pointer escape the
//     closure. It hands out only bytes with a fixed address, and they stay valid while the caller holds
//     `owner`; correct use outside the closure is the caller's job.
// 11. Public: `StableAddressByteRegion` (ByteRegion.swift) is a promise nothing checks; seams 2, 6 and 10
//     rest on it, through `IMAPByteStorage.hasStableAddress`. The library conforms the stdlib byte arrays
//     and `DispatchDataRegion`, not `DispatchData.Region`, which does not keep its bytes alive; `NIOIMAP`
//     conforms `ByteBuffer`.
// 12. Sendable: `DispatchDataRegion: @unchecked Sendable` (ParserInputBuffer+Foundation.swift), what
//     `IMAPInputBuffer.append(contentsOf:)` keeps. Its pointer is into the `DispatchData` it holds, which
//     is immutable and keeps its regions alive.
// 13. Sendable: `GrammarParser: @unchecked Sendable` (GrammarParser.swift), older than this list. Its
//     `parsedStringCache` closure is not `@Sendable`.

/// One contiguous run of input bytes, plus whoever can keep those bytes alive.
///
/// The gather (a later phase) fills a flat table of these and hands it to a ``ParseInput``. A table of
/// `Span<UInt8>` is not expressible — no container may hold a non-escapable element — which is why the
/// bytes are a pointer here and become a `Span` only inside the cursor.
///
/// `owner` is *unretained* on purpose. The gather borrows whatever holds the boxes for as long as the
/// cursor exists, so the boxes cannot go away underneath it, and reading an `Unmanaged` emits no
/// reference counting. Exactly one retain happens per extraction, when the owner is handed to an
/// ``IMAPBuffer``.
///
/// `nil` is always a correct answer for `owner`: it means an extraction copies rather than pinning the
/// input, which is the right default for a caller whose region pointers this package cannot vouch for.
internal struct RegionEntry {
    /// The bytes of this region. Valid for as long as the gather that produced the table is running.
    internal var bytes: UnsafeBufferPointer<UInt8>

    /// Who owns `bytes`, if anybody can vouch for them, so that an extraction can retain instead of copy.
    internal var owner: Unmanaged<IMAPByteStorage>?

    /// Where `bytes` begins inside the owner's storage.
    ///
    /// - Important: This is *not* redundant, and leaving it out silently returns the wrong bytes. An
    ///   owner box spans a whole network read while a region may be a *slice* of that read — a staging
    ///   type slices its head region rather than re-boxing it after a partial consume — so the offset of
    ///   the region inside its owner is not generally zero.
    internal var ownerOffset: Int

    internal init(
        bytes: UnsafeBufferPointer<UInt8>,
        owner: Unmanaged<IMAPByteStorage>? = nil,
        ownerOffset: Int = 0
    ) {
        self.bytes = bytes
        self.owner = owner
        self.ownerOffset = ownerOffset
    }
}

/// The flat region table a ``ParseInput`` reads from. One allocation per gather, never per byte.
internal typealias ChunkTable = UnsafeBufferPointer<RegionEntry>

/// Rebuilds a `Span` from a region table entry.
///
/// **This is the one unsafe seam in the parser cursor**, and it is deliberately ten lines long so that
/// it can be audited in ten seconds. What it asserts is that the bytes a table entry points at outlive
/// the cursor: the gather holds every region's accessor scope open — or, for a stable-region conformer,
/// vouches for the pointers explicitly — for as long as the cursor exists.
///
/// Two spellings that do not work, recorded so they are not retried:
///
/// - It must be a *free function*. `@_unsafeNonescapableResult` on a `mutating` method does not work.
/// - It must be `@_lifetime(immortal)`. `@_lifetime(borrow x)` fails the SIL lifetime checker here,
///   because the reconstructed span is stored into `self`.
@_unsafeNonescapableResult
@_lifetime(immortal)
@inline(__always)
internal func _span(_ bytes: UnsafeBufferPointer<UInt8>) -> Span<UInt8> {
    Span<UInt8>(_unsafeElements: bytes)
}

/// A borrowing cursor over one or more runs of input bytes.
///
/// This is what the parser reads through, and what ``ParserInputBuffer/withParseInput(limit:_:)``
/// hands to its closure. It is a plain 56-byte `BitwiseCopyable` value, so saving and
/// restoring it for backtracking — which every `parseOneOf` and `parseOptional` does — is a `memcpy`
/// with no reference counting.
///
/// It is `~Escapable` because it caches the current region as a `Span`, and that is load-bearing rather
/// than incidental: it makes it structurally impossible for the parser to keep input bytes past the
/// call. Nobody can drop `~Escapable` in a later refactor without first deleting the cached span.
/// Bytes the parser wants to keep are copied out with `extractBytes(length:)`, or referred to through
/// an owner with `extractBuffer(upTo:)` — both `internal`, like the rest of the reading surface; see
/// below.
///
/// ## This is not the type to hand the parser
///
/// If you are looking for how to give the parser bytes, you want ``ParserInputBuffer`` — in a
/// connection, ``IMAPInputBuffer``. `ParseInput` is `public` for one reason only: it appears in the
/// closure signature of ``ParserInputBuffer/withParseInput(limit:_:)`` and
/// ``ConsumableParserInputBuffer/parse(limit:_:)``, which a caller outside this module has to be able
/// to spell in order to conform. Everything that *reads* through a cursor — both initialisers, every
/// primitive, every combinator, and the read position itself — is `internal`.
///
/// So there is nothing a client can do with one, and nothing it needs to do: no public API takes a
/// cursor. ``CommandParser/parseCommandStream(buffer:)`` and
/// ``ResponseParser/parseResponseStream(buffer:)`` take the *buffer* and open their own cursor over
/// it, and a conformer's obligation is to describe its bytes, not to read them — see
/// ``ParserInputBuffer``, whose gather is where every `ParseInput` is built.
///
/// - Note: The reading surface becomes public if a parser entry point is ever added that takes a
///   cursor directly, so that one gather can serve several parses. Until then, treat the parameter as
///   opaque.
///
/// ## The invariant
///
/// `head` is empty **if and only if** the whole input is consumed. The initialisers establish that and
/// `advance(by:)` restores it, so every primitive may read the head's length as "bytes available right
/// now" and no primitive needs to know that regions exist. Do not reintroduce a per-primitive
/// "normalize first" precondition: it is an invariant to remember at a dozen sites, guarding a failure
/// mode that is silent — a multi-region extraction that stops after its first region.
///
/// ## The limit
///
/// `limit` caps how many bytes may ever be consumed through this cursor. It replaces clamping the input
/// down to a slice before parsing, so bytes past it are invisible to every primitive rather than merely
/// discouraged.
public struct ParseInput: ~Escapable {
    /// Every region, in order. Empty for a single-span cursor.
    private var table: ChunkTable

    /// The current region, already advanced past what has been consumed of it.
    ///
    /// Storing this is what forces `~Escapable`, and what makes the common case — a byte from the region
    /// we are already in — a subscript rather than a table lookup.
    private var head: Span<UInt8>

    /// Which entry of `table` `head` came from.
    ///
    /// `Int32` rather than `Int` so that ``lastParsedNewline`` fits in the same word and the cursor stays
    /// compact. A table of more than two billion regions is not a thing that happens;
    /// the gather bounds it far below that.
    private var regionIndex: Int32

    /// The line ending of the most recent ``matchNewline()``.
    ///
    /// It lives on the cursor because the caller that needs it — a response parser deciding whether a
    /// bare CR was a split CRLF — is several grammar frames above the primitive that knows the answer,
    /// and because ``composite(tracker:_:)``'s whole-value restore then rewinds it for free along with
    /// the read position.
    internal private(set) var lastParsedNewline: Newline?

    /// How many bytes have been consumed since this cursor was built.
    ///
    /// - Important: Relative to *this cursor*, not to the buffer it was gathered from. A staging type
    ///   that trims by this number must present its regions starting at its own read head; the
    ///   conformance requirement in the gather says so, and it is asserted there.
    internal private(set) var consumed: Int

    /// The most bytes this cursor may ever consume.
    internal private(set) var limit: Int

    /// Multi-region entry point. `owner` ties the cursor's lifetime to a borrow of whatever holds the
    /// regions — the gather's own storage — so the table cannot outlive the bytes it describes.
    @_lifetime(borrow owner)
    internal init<Owner: ~Copyable & ~Escapable>(
        table: ChunkTable,
        owner: borrowing Owner,
        limit: Int = .max
    ) {
        self.table = table
        self.head = table.isEmpty ? _span(UnsafeBufferPointer(start: nil, count: 0)) : _span(table[0].bytes)
        self.regionIndex = 0
        self.lastParsedNewline = nil
        self.consumed = 0
        self.limit = limit
        self.normalizeHead()
    }

    /// Single contiguous region. No table, no owner — so an extraction always copies, which is the right
    /// answer when there is nobody to keep the bytes alive.
    @_lifetime(copy bytes)
    internal init(_ bytes: Span<UInt8>, limit: Int = .max) {
        self.table = ChunkTable(start: nil, count: 0)
        self.head = bytes
        self.regionIndex = 0
        self.lastParsedNewline = nil
        self.consumed = 0
        self.limit = limit
    }
}

// MARK: - The head invariant

// `@_lifetime(self: copy self)` on mutating methods with parameters, here, in `ParseInput+Combinators.swift`
// and in `ParserInputBuffer.swift`, is what Swift 6.3+ infers. Swift 6.2 infers it only for methods without
// parameters. Remove once 6.4 is the minimum: https://github.com/apple/swift-nio-imap/issues/875

extension ParseInput {
    /// Moves to the next region. Returns `false` when there is none.
    private mutating func loadNext() -> Bool {
        let next = Int(regionIndex) + 1
        guard next < table.count else { return false }
        regionIndex = Int32(next)
        head = _span(table[next].bytes)
        return true
    }

    /// Restores the invariant: `head` is empty only when the input is exhausted.
    ///
    /// Loops rather than loading one region, because a gather is allowed to hand over empty regions — the
    /// recursive one skips them, the one-pass one is not obliged to.
    @discardableResult
    private mutating func normalizeHead() -> Bool {
        while head.isEmpty {
            guard loadNext() else { return false }
        }
        return true
    }

    /// Bytes available in the current region without crossing a region boundary or the limit.
    ///
    /// This, not `head.count`, is what every primitive measures against: bytes past the limit are
    /// invisible, and the cheapest way to hold that everywhere is to have one accessor say so.
    private var headAvailable: Int {
        Swift.min(head.count, limit - consumed)
    }

    /// Consumes `n` bytes, or everything visible if `n` exceeds that, and restores the invariant.
    ///
    /// Note the loop shape: the take is computed, applied, and *only then* is the head refilled, so
    /// landing exactly on a region boundary refills before returning. Advancing an exhausted cursor, or
    /// advancing by zero, is a no-op that still leaves the invariant true.
    @_lifetime(self: copy self)
    internal mutating func advance(by n: Int) {
        precondition(n >= 0, "cannot advance by \(n)")
        var wanted = n
        while true {
            let take = Swift.min(wanted, headAvailable)
            head = head.extracting(droppingFirst: take)
            consumed += take
            wanted -= take
            guard normalizeHead() else { return }  // exhausted; `wanted` may still be positive
            if wanted == 0 || headAvailable == 0 { return }
        }
    }

    /// Narrows the limit to the next `count` bytes.
    ///
    /// This is how a caller that has to *look* at bytes before it knows how many of them may be parsed
    /// clamps the cursor afterwards — the command parser frames synchronizing literals over everything
    /// that has arrived, and only then knows how much of it is valid to parse. The alternative is
    /// gathering the same regions twice, once per pass.
    ///
    /// - Parameter count: How many more bytes may be consumed. The limit only ever narrows, so passing
    ///   more than is already allowed leaves it alone.
    @_lifetime(self: copy self)
    internal mutating func narrowLimit(toNext count: Int) {
        precondition(count >= 0, "cannot narrow the limit to \(count) bytes")
        limit = Swift.min(limit, consumed + count)
    }
}

// MARK: - Reading without consuming

extension ParseInput {
    /// Whether any byte is available.
    internal var isEmpty: Bool {
        headAvailable == 0
    }

    /// How many bytes are visible, across every remaining region and inside the limit.
    ///
    /// O(regions remaining). Prefer ``isEmpty`` or a `peek` when that is the actual question.
    internal var remaining: Int {
        var total = head.count
        var index = Int(regionIndex) + 1
        while index < table.count {
            total += table[index].bytes.count
            index += 1
        }
        return Swift.min(total, limit - consumed)
    }

    /// The byte `k` bytes ahead of the read position, or `nil` if it is past the end or the limit.
    ///
    /// Because the cursor is a `BitwiseCopyable` value, a cross-region look-ahead walks a *local copy*
    /// rather than needing indexed access to the table.
    internal func peek(at k: Int = 0) -> UInt8? {
        precondition(k >= 0, "cannot peek at \(k)")
        guard k < limit - consumed else { return nil }
        if k < head.count { return head[k] }  // fast path: no copy
        var walker = copy self
        var offset = k
        while true {
            offset -= walker.head.count
            guard walker.loadNext() else { return nil }
            if offset < walker.head.count { return walker.head[offset] }
        }
    }

    /// The next two bytes, or `nil` if fewer than two are visible.
    internal func peek2() -> (UInt8, UInt8)? {
        if 2 <= headAvailable { return (head[0], head[1]) }  // fast path: one region, no copy
        guard let first = peek(at: 0), let second = peek(at: 1) else { return nil }
        return (first, second)
    }

    /// Scoped access to the current contiguous run — for `memchr` and other bulk operations.
    ///
    /// Scoped rather than a property: a `Span` cannot be returned out of a borrow of the cursor, and a
    /// chunk *iterator* is not expressible at all, which is why cross-region walks live in here rather
    /// than in the grammar.
    ///
    /// By the invariant the span handed to `body` is empty only when the input is exhausted. It is
    /// clamped to the limit, so a bulk operation cannot read past it.
    internal func withCurrentChunk<R>(_ body: (Span<UInt8>) throws -> R) rethrows -> R {
        try body(head.extracting(first: headAvailable))
    }
}

// MARK: - Bulk scans

extension ParseInput {
    /// The distance to the first occurrence of `byte`, or `nil` if it is not among the visible bytes.
    ///
    /// Non-consuming. `memchr` per region: a bounds-checked byte-at-a-time loop over the same bytes
    /// is much slower, so this and ``scanWhile(_:)`` are the only two places that scan, and
    /// everything that needs to find something goes through one of them.
    internal func scanUntil(byte: UInt8) -> Int? {
        var scanned = 0
        var walker = copy self
        while true {
            let available = walker.headAvailable
            guard available > 0 else { return nil }
            let hit = walker.withCurrentChunk { chunk in
                chunk.withUnsafeBufferPointer { buffer -> Int? in
                    guard let base = buffer.baseAddress,
                        let found = memchr(base, Int32(byte), buffer.count)
                    else { return nil }
                    return UnsafeRawPointer(found) - UnsafeRawPointer(base)
                }
            }
            if let hit { return scanned + hit }
            scanned += available
            walker.advance(by: available)
        }
    }

    /// How many leading bytes satisfy `predicate`, or `nil` if *every* visible byte does.
    ///
    /// Non-consuming. `nil` means "the run might continue in bytes that have not arrived yet", which is
    /// what both character-class parsers turn into `IncompleteMessage`. Callers therefore never have to
    /// compare a count against the input length to work out which case they are in.
    ///
    /// The pointer is hoisted once per region: this is the primitive behind every atom and every number,
    /// so a naive loop here would be the parser's slowest path rather than a detail.
    internal func scanWhile(_ predicate: (UInt8) -> Bool) -> Int? {
        var scanned = 0
        var walker = copy self
        while true {
            let available = walker.headAvailable
            guard available > 0 else { return nil }
            let stop = walker.withCurrentChunk { chunk in
                chunk.withUnsafeBufferPointer { buffer -> Int? in
                    for index in 0..<buffer.count {
                        if !predicate(buffer[index]) { return index }
                    }
                    return nil
                }
            }
            if let stop { return scanned + stop }
            scanned += available
            walker.advance(by: available)
        }
    }
}

// MARK: - Consuming primitives

extension ParseInput {
    /// Consumes and returns one byte.
    internal mutating func readByte() throws -> UInt8 {
        guard let byte = peek(at: 0) else { throw IncompleteMessage() }
        advance(by: 1)
        return byte
    }

    /// Consumes and copies the next `length` bytes.
    ///
    /// Copying is the right answer for everything the parsed model keeps as a small field: those are
    /// bounded by ``IMAPDefaults/lineLengthLimit`` and almost always far smaller, so owning them
    /// outright beats pinning the whole input. Raw message payloads go through
    /// ``extractBuffer(upTo:)`` instead.
    @_lifetime(self: copy self)
    internal mutating func extractBytes(length: Int) throws -> [UInt8] {
        precondition(length >= 0, "cannot extract \(length) bytes")
        guard length > 0 else { return [] }
        // Only walk the table when the answer isn't already in the current region.
        guard headAvailable >= length || remaining >= length else { throw IncompleteMessage() }
        var bytes = [UInt8]()
        bytes.reserveCapacity(length)
        var wanted = length
        while wanted > 0 {
            let take = Swift.min(wanted, headAvailable)
            withCurrentChunk { chunk in
                chunk.extracting(first: take).withUnsafeBufferPointer { bytes.append(contentsOf: $0) }
            }
            advance(by: take)
            wanted -= take
        }
        return bytes
    }

    /// Consumes raw message bytes — the streaming-literal path.
    ///
    /// Returns what is available, never more than `maxLength`, and never crossing a region boundary: a
    /// short return costs the three streaming drivers one extra trip through their state machine and
    /// nothing else, and it is what keeps an ``IMAPBuffer`` to one owner and one range.
    ///
    /// Runs of at least ``IMAPBuffer/copyThreshold`` bytes are handed out as a reference to the input's
    /// storage when the current region has an owner, so a multi-megabyte literal reaches the caller
    /// without being copied. That decision lives here and nowhere else, so no call site has to know
    /// which representation it got.
    ///
    /// - Important: The emptiness check is on the *input*, not on how many bytes are about to be taken.
    ///   `maxLength == 0` with bytes available returns an empty result rather than throwing, which is
    ///   what `APPEND … {0+}` needs: the command parser has no zero-remaining special case and relies on
    ///   getting an empty payload back so that it can move on to the end of the literal.
    @_lifetime(self: copy self)
    internal mutating func extractBuffer(upTo maxLength: Int) throws -> IMAPBuffer {
        precondition(maxLength >= 0, "cannot extract up to \(maxLength) bytes")
        let available = headAvailable
        guard available > 0 else { throw IncompleteMessage() }
        let take = Swift.min(maxLength, available)
        if take >= IMAPBuffer.copyThreshold, Int(regionIndex) < table.count {
            let entry = table[Int(regionIndex)]
            if let owner = entry.owner {
                // The offset within the OWNER, not within the region: `ownerOffset` is where the region
                // starts inside the owner's storage, and `bytes.count - head.count` is how far into the
                // region we already are. Dropping either term returns the wrong bytes.
                let offset = entry.ownerOffset + (entry.bytes.count - head.count)
                advance(by: take)
                return IMAPBuffer(owner.takeUnretainedValue(), offset..<(offset + take))
            }
        }
        return IMAPBuffer(try extractBytes(length: take))
    }
}

// MARK: - Matching

extension ParseInput {
    /// How ``matchFixed(_:caseSensitivity:)`` compares letters.
    enum CaseSensitivity {
        /// `SELECT` matches only `SELECT`.
        case caseSensitive
        /// `SELECT` also matches `select` and `Select`: what IMAP keywords need.
        case caseInsensitive
    }

    /// Consumes `needle` if it is next, and consumes nothing otherwise.
    ///
    /// - Parameters:
    ///   - needle: The bytes to match. Must be ASCII.
    ///   - caseSensitivity: How to compare letters. ASCII case folding is a mask, so the insensitive
    ///     compare costs nothing extra.
    /// - Throws: `IncompleteMessage` when everything that has arrived matches a prefix of `needle`, so
    ///   more bytes could still complete it; ``ParserError`` when a byte disagrees, which no
    ///   continuation can fix.
    @_lifetime(self: copy self)
    internal mutating func matchFixed(_ needle: String, caseSensitivity: CaseSensitivity = .caseInsensitive) throws {
        assert(needle.utf8.allSatisfy { $0 & 0b1000_0000 == 0 }, "needle needs to be ASCII but \(needle) isn't")
        let caseSensitive = caseSensitivity == .caseSensitive
        let mask: UInt8 = caseSensitive ? 0xFF : 0xDF
        let count = needle.utf8.count
        // Fast path: the whole needle is in the current region, so compare through two hoisted pointers.
        // This runs on every failed alternative of every `parseOneOf`, which is most of the parser's work.
        if count <= headAvailable {
            let matches = withCurrentChunk { chunk in
                chunk.withUnsafeBufferPointer { buffer in
                    Self.bytesMatch(buffer, needle: needle, mask: mask)
                }
            }
            guard matches else {
                throw ParserError(hint: caseSensitive ? "Fixed string mismatch" : "Fixed string mismatch (ci)")
            }
            advance(by: count)
            return
        }
        var offset = 0
        for expected in needle.utf8 {
            guard let byte = peek(at: offset) else { throw IncompleteMessage() }
            guard byte & mask == expected & mask else {
                throw ParserError(hint: caseSensitive ? "Fixed string mismatch" : "Fixed string mismatch (ci)")
            }
            offset += 1
        }
        advance(by: offset)
    }

    /// Whether `buffer` starts with `needle`, comparing under `mask`.
    ///
    /// `static` so that the closure below captures the needle rather than the cursor: handing a
    /// `self`-capturing closure to something that also borrows `self` is what makes the compiler take a
    /// copy, and on the encode side that cost an allocation per call before anyone noticed.
    ///
    /// `utf8Span` is what the package's macOS 26 floor buys here: the needle's bytes come out as a
    /// `Span` with no optional to unwrap and no fallback path for a string that turns out not to be
    /// contiguous, which is what `withContiguousStorageIfAvailable` needs and what makes the same
    /// comparison in the encoder longer than this one.
    private static func bytesMatch(_ buffer: UnsafeBufferPointer<UInt8>, needle: String, mask: UInt8) -> Bool {
        let expected = needle.utf8Span.span
        for index in 0..<expected.count where buffer[index] & mask != expected[index] & mask {
            return false
        }
        return true
    }

    /// Consumes a line ending, and records which kind it was in ``lastParsedNewline``.
    ///
    /// Some servers send a stray space before the line ending, so spaces are skipped first, up to
    /// ``maximumStraySpaces``. Spaces within the cap with nothing after them report
    /// ``IncompleteMessage``. Nothing is consumed unless a line ending is found, so a caller does not
    /// need to wrap this in ``composite(tracker:_:)`` to keep its position on a failure.
    @discardableResult
    internal mutating func matchNewline() throws -> Newline {
        let (newline, length) = try newlineAhead()
        advance(by: length)
        lastParsedNewline = newline
        return newline
    }

    /// Most stray spaces tolerated before a line ending.
    ///
    /// Lenient towards peers that pad lines, but bounded so a hostile run of spaces cannot make the
    /// parser scan without limit. 1024 is far beyond any real padding.
    internal static let maximumStraySpaces = 1024

    /// The line ending at the read position, and how many bytes it takes up including skipped spaces.
    private func newlineAhead() throws -> (Newline, Int) {
        // One linear pass over the spaces: `peek(at:)` walks from the head each call, so peeking at a
        // growing offset would be quadratic in the spaces times the regions.
        // The scan stops one past the cap, so a hostile run is not read in full. A space at `offset`
        // after that means the cap was exceeded, and falls through to the error below.
        var scanned = 0
        let spaces = scanWhile { byte in
            scanned += 1
            return byte == UInt8(ascii: " ") && scanned <= Self.maximumStraySpaces
        }
        // Only spaces so far, within the cap: more spaces, or the line ending, may still arrive.
        guard let offset = spaces else { throw IncompleteMessage() }

        guard let first = peek(at: offset) else { throw IncompleteMessage() }
        guard let second = peek(at: offset + 1) else {
            // One byte, and no more may ever arrive as far as this cursor is concerned.
            switch first {
            case UInt8(ascii: "\n"): return (.lf, offset + 1)
            case UInt8(ascii: "\r"): return (.cr, offset + 1)
            default: throw ParserError(hint: "Expected newline")
            }
        }
        switch (first, second) {
        case (UInt8(ascii: "\r"), UInt8(ascii: "\n")): return (.crlf, offset + 2)
        case (UInt8(ascii: "\n"), _): return (.lf, offset + 1)
        case (UInt8(ascii: "\r"), _): return (.cr, offset + 1)
        default: throw ParserError(hint: "Expected newline")
        }
    }

    /// Consumes a leading `LF`, if there is one. Reports whether it did.
    ///
    /// This is how a CRLF split across two reads is stitched back together: the CR ended one parse and
    /// the LF is skipped at the start of the next.
    @discardableResult
    internal mutating func skipLF() -> Bool {
        guard peek(at: 0) == UInt8(ascii: "\n") else { return false }
        advance(by: 1)
        return true
    }
}

extension ParseInput {
    /// A line ending kind.
    internal enum Newline: Sendable, Hashable {
        case crlf
        case cr
        case lf
    }
}

/// `ParseInput` is deliberately **not** `Sendable`, and could not honestly be.
///
/// It holds pointers into somebody else's bytes that are valid only for the gather that produced it, and
/// being non-escapable is what enforces that. What crosses a thread is what the parser *extracted* — an
/// `[UInt8]` or an ``IMAPBuffer``, both of which own or retain their bytes.
@available(*, unavailable)
extension ParseInput: Sendable {}

// MARK: - Backtracking

extension ParseInput {
    /// Runs `body`, and restores the read position if it throws.
    ///
    /// This is the parser's backtracking primitive, and it is why the cursor is a small
    /// `BitwiseCopyable` value: the save is a `memcpy` and the restore is another, with no reference
    /// counting, and it runs on every alternative of every `parseOneOf`.
    ///
    /// `let save = copy self` completes before `body(&self, …)` is called, so there is no overlapping
    /// access to `self` even though both mention it.
    @_lifetime(self: copy self)
    internal mutating func composite<T>(
        tracker: StackTracker,
        _ body: (inout ParseInput, StackTracker) throws -> T
    ) throws -> T {
        var tracker = tracker
        try tracker.newStackFrame()
        let save = copy self
        do {
            return try body(&self, tracker)
        } catch {
            self = save
            throw error
        }
    }
}
