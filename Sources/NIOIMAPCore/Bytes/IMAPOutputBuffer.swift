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

import DequeModule

/// Encoded output backed by segments the library allocates itself.
///
/// This is the shipped ``EncoderOutputBuffer``, and the one to reach for unless the bytes have to
/// land somewhere specific. Its defining property is that **it never moves a byte it has already
/// written**: output goes into fixed-size segments, and a write that does not fit is split across the
/// end of one segment and the start of a new one rather than growing anything.
///
/// That is what a growable contiguous buffer cannot do. `ByteBuffer`, `Data` and `Array` all grow by
/// reallocating, which moves the bytes any handed-out slice refers to, so they have to copy instead.
/// Here, the bytes already handed out and the bytes still being written are disjoint ranges of the
/// same allocation, and both are correct at the same time — even on two different threads.
///
/// ## How this relates to `EncoderOutputBuffer`
///
/// ``EncoderOutputBuffer`` is the protocol an encoder appends into; this is its default conformer, and
/// what `NIOIMAP`'s handlers use. A client rarely names it, because it is the default `sink:` argument
/// of both encoders:
///
/// ```swift
/// var encoder = CommandEncodeBuffer(options: options, loggingMode: false)   // sink: IMAPOutputBuffer()
/// ```
///
/// The alternative is `NIOIMAP`'s `ByteBufferOutput`, which wins on traffic dominated by large
/// payloads and loses on traffic made of many small writes; see that type.
/// Callers whose bytes have to land in storage neither type describes — a file, shared
/// memory — conform to the protocol themselves rather than reaching for this.
///
/// ## Getting the bytes out
///
/// ``takeFirst(_:)`` hands back an ``IMAPBufferList``, which converts to whatever the caller needs:
/// ``IMAPBufferList/makeDispatchData()``, which donates large regions and copies short ones,
/// `makeByteBuffers()` (in `NIOIMAP`) with one copy per region, or ``IMAPBufferList/copiedBytes()`` to
/// coalesce.
///
/// ## Value semantics
///
/// This is a `struct` with value semantics, implemented with copy-on-write. Copying it is cheap;
/// writing to a copy is nearly so. On the first write after a copy, the segment that was open for
/// writing is *sealed* rather than duplicated — the copy opens a fresh segment and neither writes into
/// the other's memory — which costs one extra segment per copy and never a byte of copying.
public struct IMAPOutputBuffer: EncoderOutputBuffer {
    /// One entry in the pending list: either bytes written into a segment, or a region belonging to
    /// somebody else that was appended by reference.
    ///
    /// The two are interleaved freely, and a single segment can back several non-adjacent `owned`
    /// entries. That is deliberate: it means appending a caller's payload by reference does not force
    /// everything written after it into a fresh allocation.
    internal enum Region {
        /// A range of a segment this buffer wrote into. Monotonic within any one segment.
        case owned(OutputSegment, Range<Int>)
        /// A region belonging to somebody else, kept by reference rather than copied.
        case foreign(IMAPBuffer)

        internal var count: Int {
            switch self {
            case .owned(_, let range): return range.count
            case .foreign(let buffer): return buffer.count
            }
        }

        /// Splits into the first `k` bytes and the rest, by range arithmetic alone.
        internal func split(at k: Int) -> (Region, Region) {
            switch self {
            case .owned(let segment, let range):
                let middle = range.lowerBound + k
                return (.owned(segment, range.lowerBound..<middle), .owned(segment, middle..<range.upperBound))
            case .foreign(let buffer):
                return (.foreign(buffer.prefix(k)), .foreign(buffer.dropFirst(k)))
            }
        }
    }

    /// A trivially-copyable description of the segment currently open for writing.
    ///
    /// This is what keeps the write path free of reference counting. ``Storage/tail`` is a strong
    /// reference, and reading a strong reference out of a class costs a retain and a release — which,
    /// for the handful of bytes a typical `write*` call appends, is the entire cost of the call. So the
    /// segment's address and extent are cached here as plain integers and a pointer, and the segment
    /// object itself is touched only when a region opens or closes.
    ///
    /// The memory stays alive because ``Storage/tail`` holds the segment for exactly as long as this
    /// describes it.
    private struct OpenTail {
        /// The segment's allocation.
        var base: UnsafeMutableRawPointer
        /// The size of that allocation.
        var capacity: Int
        /// How many of its bytes are written. Authoritative — ``OutputSegment/used`` is brought up to
        /// date from this when the region closes.
        var used: Int
        /// Where, within the segment, the region currently being accumulated begins.
        var regionStart: Int

        var available: Int { capacity - used }
    }

    /// Every piece of mutable state, in one box, so that copy-on-write can be detected.
    ///
    /// - Note: The uniqueness check has to be on this box and cannot be on a segment. A segment is
    ///   reachable from both `tail` and `pending`, so its reference count is never 1 and the check
    ///   would report "shared" on every single write. And copying the enclosing struct bumps *this*
    ///   box's count, not any segment's, so a check on a segment could not see the copy that matters
    ///   in the first place.
    ///
    /// - Note: The mutable properties are `@exclusivity(unchecked)`: the runtime check runs on every
    ///   write and costs a few percent of encoding. Skipping it is safe because the class is private,
    ///   `IMAPOutputBuffer` is not `Sendable`, and every write first checks that this box is uniquely
    ///   referenced, so nothing an access calls into — a released region's `deinit` included — can
    ///   reach the box to start an overlapping one.
    private final class Storage {
        /// Regions that have been closed, oldest first, and not yet handed out.
        ///
        /// The region currently being written is deliberately **not** here — see `open`. Adding to a
        /// `Deque` of enums carrying a class reference costs reference counting, so a run of writes
        /// accumulates into one region and joins the deque once, when it ends.
        @exclusivity(unchecked) var pending: Deque<Region> = []
        /// The segment still open for writing, if there is one.
        ///
        /// `nil` after a fork, so that the next write opens a fresh segment rather than writing into
        /// memory another `Storage` may also be writing into.
        @exclusivity(unchecked) var tail: OutputSegment?
        /// `tail`'s address and extent, or `nil` when there is no open segment.
        @exclusivity(unchecked) var open: OpenTail?
        /// The number of bytes pending hand-out, including the region still being written.
        @exclusivity(unchecked) var pendingByteCount: Int = 0
        /// How big the next segment will be. Doubles up to `maximumSegmentSize`.
        @exclusivity(unchecked) var nextSegmentSize: Int
        /// The ceiling on `nextSegmentSize`.
        let maximumSegmentSize: Int

        init(nextSegmentSize: Int, maximumSegmentSize: Int) {
            self.nextSegmentSize = nextSegmentSize
            self.maximumSegmentSize = maximumSegmentSize
        }

        /// The region being accumulated, if any bytes have gone into it.
        ///
        /// Bringing the segment's own `used` up to date is part of producing the region, because
        /// everything downstream — sealing, the hand-out assertions — reads it from the segment.
        func makeOpenRegion() -> Region? {
            guard let tail, let open, open.used > open.regionStart else { return nil }
            tail.markUsed(open.used)
            return .owned(tail, open.regionStart..<open.used)
        }

        /// Moves the region being accumulated into `pending`.
        ///
        /// The segment stays open afterwards: the next write continues in it, as a new region. That is
        /// what lets one segment back several non-adjacent regions.
        func closeOpenRegion() {
            guard let region = makeOpenRegion() else { return }
            pending.append(region)
            // `makeOpenRegion` returning a region means there is an open tail.
            let used = open!.used
            open!.regionStart = used
        }

        /// The state a copy starts from: the same regions, and no open segment.
        ///
        /// - Important: The open segment is **not** copied, and its bytes are **not** duplicated. The
        ///   original may already have handed out ranges of it, and the invariant that keeps all of
        ///   this sound is that a segment is written by at most one `Storage`. Sealing it costs one
        ///   extra segment; copying it would cost correctness.
        func forked() -> Storage {
            let copy = Storage(nextSegmentSize: nextSegmentSize, maximumSegmentSize: maximumSegmentSize)
            copy.pending = pending
            // The region still being written belongs to the copy as well, so it is closed *into the
            // copy* rather than in place — the original keeps writing into its own.
            if let region = makeOpenRegion() {
                copy.pending.append(region)
            }
            copy.pendingByteCount = pendingByteCount
            return copy
        }
    }

    private var storage: Storage

    /// Creates an output buffer with the default segment sizing.
    public init() {
        self.init(
            initialSegmentSize: Self.defaultInitialSegmentSize,
            maximumSegmentSize: Self.defaultMaximumSegmentSize
        )
    }

    /// Creates an output buffer with explicit segment sizing.
    ///
    /// - Parameters:
    ///   - initialSegmentSize: The size of the first segment.
    ///   - maximumSegmentSize: The ceiling that segment sizes double up to.
    internal init(initialSegmentSize: Int, maximumSegmentSize: Int) {
        precondition(initialSegmentSize > 0, "segments need a positive size, not \(initialSegmentSize)")
        precondition(
            maximumSegmentSize >= initialSegmentSize,
            "a maximum segment size of \(maximumSegmentSize) is below the initial size \(initialSegmentSize)"
        )
        self.storage = Storage(nextSegmentSize: initialSegmentSize, maximumSegmentSize: maximumSegmentSize)
    }

    /// The size of the first segment allocated.
    ///
    /// About the size of a command line, so that a client command is one segment and one output
    /// region while a 20-byte `NOOP` does not `malloc` 64 KB. Anything that needs more grows into it
    /// by doubling, and a long-lived encoder keeps the segment it has reached across messages.
    ///
    /// This decides how many *bytes* a small message allocates and nothing else: run time and
    /// allocation *count* do not depend on it. So it should be as small as a typical message allows.
    internal static let defaultInitialSegmentSize = 256

    /// The ceiling that segment sizes double up to.
    ///
    /// This matters more than the initial size. Every region a chunk is split into costs real work
    /// downstream — an allocation-bearing concatenation into a `DispatchData`, a separate `writev`
    /// vector, a separate write on the NIO path — while a segment costs one allocation however big it
    /// is. So: big segments, few regions. A long-lived encoder settles into refilling one segment of
    /// this size.
    ///
    /// - Note: This caps how large segments *grow to*, not how large a single one may be. A write
    ///   bigger than this gets one segment sized to hold it, because one 4 MB segment is cheaper than
    ///   64 segments of 64 KB — and cheaper downstream too, being one region instead of 64.
    internal static let defaultMaximumSegmentSize = 64 * 1024

    // MARK: - EncoderOutputBuffer

    /// How many bytes are waiting to be handed out.
    ///
    /// - Complexity: O(1).
    public var byteCount: Int { storage.pendingByteCount }

    /// Copies bytes onto the end.
    ///
    /// If they do not all fit in the open segment, the part that fits is written there and the rest
    /// goes into a fresh segment. Nothing already written is moved.
    ///
    /// - Parameter bytes: The bytes to append.
    public mutating func append(_ bytes: UnsafeRawBufferPointer) {
        guard let source = bytes.baseAddress, !bytes.isEmpty else { return }
        ensureUnique()

        var offset = 0
        while offset < bytes.count {
            if storage.open == nil || storage.open!.available == 0 {
                openFreshSegment(fitting: bytes.count - offset)
            }
            let take = Swift.min(storage.open!.available, bytes.count - offset)
            storage.open!.base.advanced(by: storage.open!.used)
                .copyMemory(from: source.advanced(by: offset), byteCount: take)
            storage.open!.used += take
            offset += take
        }
        storage.pendingByteCount += bytes.count
    }

    /// Appends a region, by reference when it is big enough to be worth it.
    ///
    /// At or above ``IMAPBuffer/copyThreshold`` the region is kept as-is and nothing is copied, which
    /// is what lets a proxy forward a multi-megabyte literal for free. Below it, the bytes are copied
    /// into a segment, because a short region is not worth the bookkeeping of a separate output
    /// region.
    ///
    /// The open segment stays open either way, so bytes appended after a by-reference region continue
    /// in the same segment as the bytes before it — as a separate region of it.
    ///
    /// - Parameter region: The region to append.
    public mutating func append(_ region: IMAPBuffer) {
        guard !region.isEmpty else { return }
        guard region.count >= IMAPBuffer.copyThreshold else {
            region.withUnsafeBytes { self.append($0) }
            return
        }
        ensureUnique()
        storage.closeOpenRegion()
        storage.pending.append(.foreign(region))
        storage.pendingByteCount += region.count
    }

    /// Removes the first `byteCount` pending bytes and returns them, in order.
    ///
    /// Whole regions are handed over as they are; the region straddling the boundary is divided by
    /// range arithmetic, and the segment behind it is **not** sealed off — the encoder carries on
    /// appending above the split while the bytes below it are on their way to the network.
    ///
    /// - Parameter byteCount: How many bytes to take. Must not exceed ``byteCount``.
    /// - Returns: The bytes taken.
    public mutating func takeFirst(_ byteCount: Int) -> IMAPBufferList {
        precondition(
            byteCount >= 0 && byteCount <= self.byteCount,
            "cannot take \(byteCount) bytes from an IMAPOutputBuffer holding \(self.byteCount)"
        )
        guard byteCount > 0 else { return IMAPBufferList() }
        ensureUnique()
        storage.closeOpenRegion()

        // The common case by a wide margin: everything being taken lies in the first region. Handling
        // it without the intermediate arrays the general path needs is worth a special case, because
        // this runs once per message.
        if let first = storage.pending.first, first.count >= byteCount {
            storage.pendingByteCount -= byteCount
            if first.count == byteCount {
                storage.pending.removeFirst()
                return IMAPBufferList(Self.makeBuffer(first))
            }
            let (head, rest) = first.split(at: byteCount)
            storage.pending[storage.pending.startIndex] = rest
            return IMAPBufferList(Self.makeBuffer(head))
        }

        var taken: [Region] = []
        var remaining = byteCount
        while remaining > 0, let first = storage.pending.first {
            if first.count <= remaining {
                storage.pending.removeFirst()
                remaining -= first.count
                taken.append(first)
            } else {
                let (head, rest) = first.split(at: remaining)
                storage.pending[storage.pending.startIndex] = rest
                taken.append(head)
                remaining = 0
            }
        }
        assert(remaining == 0, "the precondition above guarantees there are enough bytes")
        storage.pendingByteCount -= byteCount

        return Self.makeBufferList(taken)
    }

    /// Calls the given closure with the pending regions, in order.
    ///
    /// - Note: Cold path. This materialises an array of ``IMAPBuffer``, so it allocates — which is
    ///   fine where it is used, since equality, hashing and debug descriptions all walk every byte
    ///   anyway. Building a `Span` without the array would mean reconstructing one from a temporary
    ///   allocation, which is an unsafe assertion this does not need to make.
    ///
    /// - Parameter body: A closure that receives the pending regions.
    /// - Returns: Whatever `body` returns.
    public func withPendingRegions<R>(_ body: (Span<IMAPBuffer>) -> R) -> R {
        // `ContiguousArray`, not `Array`: an `Array` may be a bridged `NSArray`, so `Array.span` has to
        // check for that and copy the elements out first, which is also why it was gated at macOS 26
        // while `ContiguousArray.span` back-deploys as far as `Span` itself. The package now declares
        // that floor, so this is a preference rather than a requirement — but it is still the cheaper
        // of the two, and a cold read-back path is not the place to pay for a check it cannot need.
        var buffers: ContiguousArray<IMAPBuffer> = []
        buffers.reserveCapacity(storage.pending.count + 1)
        for region in storage.pending {
            buffers.append(Self.makeBuffer(region))
        }
        // The region still being written is pending too, even though it is not in the deque yet.
        if let open = storage.makeOpenRegion() {
            buffers.append(Self.makeBuffer(open))
        }
        return body(buffers.span)
    }

    /// Discards everything pending and releases the segments backing it.
    ///
    /// The segment currently open for writing is the one exception: it is kept, and the next message
    /// continues in whatever room is left in it. Dropping it as well would make a long-lived encoder —
    /// a server handler drains one of these after every response — allocate a fresh segment for every
    /// message, which is the allocation pattern the segmented design exists to avoid; keeping anything
    /// more than it would mean never releasing memory at all. So what is held after this returns is at
    /// most one segment.
    ///
    /// A segment that a handed-out region still refers to stays alive until that region goes away;
    /// everything else is freed here. Bytes already handed out are unaffected: the open segment is
    /// written above them, never rewound.
    ///
    /// The segment *sizing* is kept too, so a buffer that has learned it needs large segments does not
    /// re-climb the growth curve.
    public mutating func removeAll() {
        guard isKnownUniquelyReferenced(&storage) else {
            // Shared: the other owner keeps the segments, and this copy must not write into the one
            // that was open, so it starts over with nothing.
            storage = Storage(
                nextSegmentSize: storage.nextSegmentSize,
                maximumSegmentSize: storage.maximumSegmentSize
            )
            return
        }
        // `keepingCapacity`, because this runs once per message on a long-lived buffer and letting the
        // deque's storage go means allocating it again for the next one. On a streamed literal that is
        // one allocation per network read of body.
        storage.pending.removeAll(keepingCapacity: true)
        storage.pendingByteCount = 0
        if let open = storage.open, open.available > 0 {
            storage.open!.regionStart = open.used
        } else {
            storage.tail = nil
            storage.open = nil
        }
    }

    // MARK: - Writing

    /// Forks the state box if it is shared, so that no two copies ever write into one segment.
    private mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.forked()
        }
    }

    /// Opens a fresh segment, closing the region that was being written into the old one.
    ///
    /// - Parameter byteCount: How many bytes are about to be written. The segment is made at least
    ///   this big, so a single large write costs one allocation rather than a run of them.
    private mutating func openFreshSegment(fitting byteCount: Int) {
        storage.closeOpenRegion()
        let segment = OutputSegment(capacity: Swift.max(storage.nextSegmentSize, byteCount))
        storage.tail = segment
        storage.open = OpenTail(
            base: segment.storage.baseAddress!,
            capacity: segment.storage.count,
            used: 0,
            regionStart: 0
        )
        storage.nextSegmentSize = Swift.min(storage.nextSegmentSize * 2, storage.maximumSegmentSize)
    }

    // MARK: - Handing out

    /// Turns a pending region into an ``IMAPBuffer``, pinning the segment's extent as it goes.
    private static func makeBuffer(_ region: Region) -> IMAPBuffer {
        switch region {
        case .owned(let segment, let range):
            assert(
                range.upperBound <= segment.used,
                "handing out \(range) of a segment with only \(segment.used) bytes written"
            )
            // The range is the pin: it is fixed here, and the buffer will never look beyond it however
            // far the encoder writes afterwards. Handing over a bare segment instead would expose a
            // byte count that moves, and memory above `used` that has never been written.
            return IMAPBuffer(segment: segment, range: range)
        case .foreign(let buffer):
            return buffer
        }
    }

    /// Turns the regions taken by ``takeFirst(_:)`` into a list.
    private static func makeBufferList(_ regions: [Region]) -> IMAPBufferList {
        IMAPBufferList(regions.map(makeBuffer))
    }
}

// MARK: - Sendability

/// `IMAPOutputBuffer` is deliberately **not** `Sendable`, and this states it rather than leaving it to
/// be inferred.
///
/// It owns `malloc`'d memory that it is actively writing into, so sharing one across threads would be
/// a data race. It does not need to be shared: an output buffer belongs to one encoder, which belongs
/// to one connection handler. What crosses a thread is a chunk that has been handed out — an
/// ``IMAPBufferList`` — whose bytes are frozen at hand-out and therefore disjoint from anything the
/// encoder writes next. That is where `Sendable` belongs, and where it is.
@available(*, unavailable)
extension IMAPOutputBuffer: Sendable {}

// MARK: - Debugging

extension IMAPOutputBuffer {
    /// The pending regions, oldest first, including the one still being written.
    ///
    /// This exposes the internal split between segment-backed and by-reference regions, which is the
    /// only way to check properties the public API deliberately hides — that consecutive writes share
    /// one segment, that a by-reference append does not close the open segment, that a copy sealed the
    /// tail rather than duplicating it. Tests use it; nothing else should.
    internal var pendingRegions: [Region] {
        var regions = Array(storage.pending)
        if let open = storage.makeOpenRegion() {
            regions.append(open)
        }
        return regions
    }

    /// The segment currently open for writing, if there is one.
    internal var openSegment: OutputSegment? { storage.tail }
}

extension IMAPOutputBuffer: CustomDebugStringConvertible {
    /// A description showing what is pending.
    public var debugDescription: String {
        let regions = storage.pending.count + (storage.makeOpenRegion() == nil ? 0 : 1)
        return "IMAPOutputBuffer(\(byteCount) bytes pending in \(regions) region\(regions == 1 ? "" : "s"))"
    }
}
