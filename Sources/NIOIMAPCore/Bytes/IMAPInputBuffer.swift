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

/// Received bytes, waiting to be parsed.
///
/// This is what a connection accumulates into: it appends whatever a read produced, parses as many
/// messages out of the front as have arrived, and never moves a byte in between.
///
/// ```swift
/// var buffer = IMAPInputBuffer()
/// buffer.append(bytesFromTheNetwork)
/// while let response = try parser.parseResponseStream(buffer: &buffer) { … }
/// ```
///
/// ## How this relates to `ParserInputBuffer`
///
/// ``ParserInputBuffer`` is the protocol the parser reads through; this is the conformer to use for a
/// connection, and the one ``CommandParser/parseCommandStream(buffer:)`` and
/// ``ResponseParser/parseResponseStream(buffer:)`` are written for. Other types conform too, but only
/// some of them can be passed to those entry points, which need a ``ConsumableParserInputBuffer``:
/// `DispatchData` and `NIOIMAP`'s `ByteBuffer` can, while `Data` and the array types deliberately
/// cannot, because trimming them moves the remaining bytes. Bytes held in one of those reach the parser
/// by being appended here, which copies an array only if it is small (a `Data` always; see below) — so
/// this is both the streaming answer and the one-shot answer, and the alternatives are for a caller
/// that already has a `ByteBuffer` or a `DispatchData` in hand.
///
/// Two properties are the reason to use this rather than an array or a `Data`:
///
/// - **Appending never moves appended bytes, and never copies a large read at a fixed address.** Such
///   a read, of at least ``IMAPBuffer/copyThreshold`` bytes, is kept as-is, so a message that straddles
///   two reads is parsed across them instead of being memmoved into one buffer. A smaller read is
///   copied into a shared fixed-capacity *tail*, so a peer sending a byte per read pins 1 KiB tails,
///   not a receive buffer and an object per byte.
/// - **Consuming is O(1) in the bytes consumed.** The read head is an offset into the first run, and
///   runs are dropped whole once they are used up. A buffer that moved the remainder down instead
///   pays per byte moved, and pays it again on every message.
///
/// It is also the only input type that lets the parser hand out large payloads *without copying
/// them*: because it owns the runs it was given, a multi-megabyte literal can be delivered as a
/// reference to the received bytes. A payload delivered that way keeps its run alive for as long as
/// the caller holds it, even after the buffer has moved past it — which is the point, and is why
/// ``count`` counts bytes waiting to be parsed rather than bytes still allocated.
///
/// - Important: A region kept by reference must not change for as long as this buffer or any payload
///   extracted from it refers to it. Only a large region whose address is known to be fixed is kept:
///   a ``StableAddressByteRegion`` — the stdlib arrays, NIO's `ByteBuffer` — or an ``IMAPBuffer``
///   over one. Any other region, `Data` and `DispatchData.Region` included, is copied whatever its
///   size: one exact-size array for a large one, the tail for a small one. For a `DispatchData`, use
///   ``append(contentsOf:)``, which keeps large regions without copying.
public struct IMAPInputBuffer: Sendable {
    /// One run of bytes in the queue.
    fileprivate enum Chunk: Sendable {
        /// A read of at least ``IMAPBuffer/copyThreshold`` bytes: kept as received if its address is
        /// fixed, otherwise copied into an array. Either way its storage has a stable address.
        case received(IMAPByteStorage)
        /// Small reads copied together. Its `used` is the run's length.
        ///
        /// Invariants: only the last chunk (or `spareTail`) is written into, only past `used`, and only
        /// while this buffer holds the sole reference — so no struct copy, ``Regions`` view or
        /// ``IMAPBuffer`` can see a write. The allocation is never resized, so bytes keep their address.
        case tail(OutputSegment)

        var count: Int {
            switch self {
            case .received(let storage): storage.count
            case .tail(let segment): segment.used
            }
        }
    }

    /// The appended runs, oldest first, each one boxed so that a payload can outlive its place in the
    /// queue. Fully consumed runs are dropped from the front.
    private var chunks: Deque<Chunk>

    /// How many bytes of `chunks.first` have already been consumed.
    ///
    /// Always less than that run's length: a run that is used up is dropped rather than left at
    /// offset `count`, which is what keeps `chunks.first` meaningful and the head region non-empty.
    private var headOffset: Int

    /// The last tail, used up and dropped while it still had room, kept so that the next small read into
    /// an empty buffer continues past its end instead of allocating. Not a region: nothing exposes it.
    /// Reused only while this is its sole reference.
    private var spareTail: OutputSegment?

    /// The number of bytes waiting to be parsed.
    ///
    /// This counts *live* bytes, not allocated ones. A run that has been consumed is no longer
    /// counted even if a payload extracted from it is keeping it alive.
    public private(set) var count: Int

    /// Capacity of a fresh tail: `copyThreshold`, so a full tail is as large as the smallest read kept by
    /// reference.
    internal static let minimumTailCapacity = IMAPBuffer.copyThreshold

    /// Creates an empty buffer.
    public init() {
        self.chunks = []
        self.headOffset = 0
        self.spareTail = nil
        self.count = 0
    }

    /// Whether there are no bytes waiting to be parsed.
    public var isEmpty: Bool { count == 0 }

    /// Adds received bytes to the end of the buffer.
    ///
    /// A region of at least ``IMAPBuffer/copyThreshold`` bytes whose address is fixed — a
    /// ``StableAddressByteRegion``, or an ``IMAPBuffer`` over one — is not copied: it is retained as-is
    /// and parsed where it lies, for one small object per call. Any other region that large — a `Data`,
    /// say — is copied once into an exact-size array, which is retained instead. A smaller one is copied
    /// into the tail, or into a fresh ``minimumTailCapacity`` tail if it does not fit, and is not
    /// retained.
    ///
    /// Appending an empty region does nothing.
    ///
    /// - Parameter region: The bytes to add. If retained, it must satisfy the immutability requirement
    ///   described on ``IMAPInputBuffer``.
    public mutating func append(_ region: some ByteRegion & Sendable) {
        guard !appendToTail(ifSmall: region) else { return }
        // `withStableRegions` lets pointers into a retained run outlive its accessor, so a run without a
        // fixed address is copied into an array, which never moves, and that is kept instead.
        var storage = IMAPByteStorage(region)
        if !storage.hasStableAddress {
            storage = IMAPByteStorage(region.withUnsafeBytes { [UInt8]($0) })
        }
        appendReceived(storage)
    }

    /// Adds received bytes whose address is fixed to the end of the buffer.
    ///
    /// The same as the overload for any region, chosen at compile time for a region type known to be a
    /// ``StableAddressByteRegion`` — NIO's `ByteBuffer`, the stdlib arrays — so keeping a large one costs
    /// no dynamic cast.
    ///
    /// - Parameter region: The bytes to add. If retained, it must satisfy the immutability requirement
    ///   described on ``IMAPInputBuffer``.
    public mutating func append(_ region: some StableAddressByteRegion & Sendable) {
        guard !appendToTail(ifSmall: region) else { return }
        appendReceived(IMAPByteStorage(region))
    }

    /// Adds an ``IMAPBuffer`` to the end of the buffer.
    ///
    /// The same as the overload for any region, without its dynamic casts: a large buffer is retained if
    /// its own bytes have a fixed address, and copied once into an array otherwise.
    ///
    /// - Parameter buffer: The bytes to add.
    public mutating func append(_ buffer: IMAPBuffer) {
        guard !appendToTail(ifSmall: buffer) else { return }
        guard buffer.hasStableAddress else {
            appendReceived(IMAPByteStorage(buffer.withUnsafeBytes { [UInt8]($0) }))
            return
        }
        appendReceived(IMAPByteStorage(buffer))
    }

    /// Copies `region` into the tail if it is shorter than ``IMAPBuffer/copyThreshold``.
    ///
    /// - Returns: Whether it was copied.
    private mutating func appendToTail(ifSmall region: some ByteRegion) -> Bool {
        region.withUnsafeBytes { bytes in
            guard bytes.count < IMAPBuffer.copyThreshold else { return false }
            appendToTail(bytes)
            return true
        }
    }

    /// Queues a run of at least ``IMAPBuffer/copyThreshold`` bytes at a fixed address.
    internal mutating func appendReceived(_ storage: IMAPByteStorage) {
        assert(storage.hasStableAddress, "a retained run must have a fixed address")
        chunks.append(.received(storage))
        count += storage.count
    }

    /// Copies `bytes` past the end of the tail, starting a new tail if the last one cannot take them.
    internal mutating func appendToTail(_ bytes: UnsafeRawBufferPointer) {
        guard !bytes.isEmpty else { return }
        let segment = writableTail(fitting: bytes.count)
        let written = segment.append(bytes)
        precondition(written == bytes.count, "a tail took \(written) of \(bytes.count) bytes")
        count += bytes.count
    }

    /// The last chunk if it is a tail with room for `byteCount` bytes that only `chunks` refers to;
    /// otherwise a new tail, appended.
    private mutating func writableTail(fitting byteCount: Int) -> OutputSegment {
        // Removed, not peeked, so the uniqueness check does not count our own reference twice.
        if case .tail? = chunks.last, case .tail(var segment) = chunks.removeLast() {
            let isWritable = isKnownUniquelyReferenced(&segment) && segment.availableCapacity >= byteCount
            chunks.append(.tail(segment))
            if isWritable { return segment }
        }
        // Nothing buffered: continue the used-up tail from its end. The bytes before it stay unexposed.
        if chunks.isEmpty, isKnownUniquelyReferenced(&spareTail), let spare = spareTail,
            spare.availableCapacity >= byteCount
        {
            spareTail = nil
            headOffset = spare.used
            chunks.append(.tail(spare))
            return spare
        }
        spareTail = nil
        let segment = OutputSegment(capacity: Swift.max(Self.minimumTailCapacity, byteCount))
        chunks.append(.tail(segment))
        return segment
    }

    /// Discards the first `k` bytes.
    ///
    /// O(1) in `k`: the read head moves, and runs it has moved past are dropped. Nothing is copied and
    /// nothing is moved.
    ///
    /// - Parameter k: How many bytes to discard. Must not exceed ``count``.
    public mutating func discardFirst(_ k: Int) {
        precondition(k >= 0, "cannot discard \(k) bytes")
        precondition(k <= count, "cannot discard \(k) bytes from a buffer holding \(count)")
        var remaining = k
        // Indexed rather than bound with `let`, so no extra reference to a tail is held while it is
        // checked for uniqueness below.
        while remaining > 0, !chunks.isEmpty {
            let available = chunks[chunks.startIndex].count - headOffset
            if remaining < available {
                headOffset += remaining
                count -= remaining
                return
            }
            // This run is used up; drop it. A received run stays alive while a large payload extracted
            // from it does — deliberately. A tail does not: payloads from it are copies. The last tail, if
            // it has room and is ours alone, is kept as `spareTail`.
            if case .tail(var segment) = chunks.removeFirst(), chunks.isEmpty, segment.availableCapacity > 0,
                isKnownUniquelyReferenced(&segment)
            {
                spareTail = segment
            }
            headOffset = 0
            count -= available
            remaining -= available
        }
    }

    /// Drops every byte, keeping the buffer usable.
    public mutating func removeAll() {
        chunks.removeAll(keepingCapacity: true)
        headOffset = 0
        spareTail = nil
        count = 0
    }
}

// MARK: - Reading

extension IMAPInputBuffer: ConsumableParserInputBuffer, StableRegionParserInputBuffer {
    /// The buffer's runs, in order, the first one starting at the read head.
    ///
    /// A view rather than an array: it allocates nothing, and it *slices* the first run rather than
    /// handing over the whole thing, which is the conformance requirement
    /// ``ParserInputBuffer/byteRegions`` states.
    public struct Regions: RandomAccessCollection, Sendable {
        fileprivate let chunks: Deque<Chunk>
        fileprivate let headOffset: Int

        public var startIndex: Int { 0 }
        public var endIndex: Int { chunks.count }

        public subscript(position: Int) -> IMAPBuffer {
            let start = position == 0 ? headOffset : 0
            switch chunks[position] {
            case .received(let storage):
                return IMAPBuffer(storage, start..<storage.count)
            case .tail(let segment):
                return IMAPBuffer(segment: segment, range: start..<segment.used)
            }
        }
    }

    public var byteRegions: Regions {
        Regions(chunks: chunks, headOffset: headOffset)
    }

    /// How many runs the buffer holds. O(1), and it needs no ``byteRegions`` view to answer.
    public var regionCount: Int { chunks.count }

    /// Fills the region table in one pass.
    ///
    /// This is where the ``StableRegionParserInputBuffer`` promise is honest rather than asserted: the
    /// runs are ours, boxed, kept alive by `self` for as long as this borrow lasts, and at a fixed
    /// address (appending copies a region that has none), so a pointer to one of them may outlive
    /// the accessor that produced it. It is also where a payload gets an owner — the box handed to
    /// ``RegionSink/append(_:owner:offset:)`` is what a large extraction refers to instead of copying.
    ///
    /// A tail passes no owner: it holds at most ``minimumTailCapacity`` bytes, so a payload from it is
    /// copied, at no more cost than the small reads it was copied from.
    public borrowing func withStableRegions(into sink: inout RegionSink) {
        for index in chunks.indices {
            let offset = index == chunks.startIndex ? headOffset : 0
            switch chunks[index] {
            case .received(let storage):
                // The pointer escapes its accessor on purpose. See the note above.
                let bytes = storage.withUnsafeBytes { $0 }
                let visible = UnsafeRawBufferPointer(rebasing: bytes[offset...])
                sink.append(visible.bindMemory(to: UInt8.self), owner: storage, offset: offset)
            case .tail(let segment):
                let written = UnsafeRawBufferPointer(segment.storage)[offset..<segment.used]
                let visible = UnsafeRawBufferPointer(rebasing: written)
                sink.append(visible.bindMemory(to: UInt8.self), owner: nil, offset: 0)
            }
        }
    }

    /// Reads through the buffer's bytes.
    ///
    /// Written out rather than inherited: a default implementation on
    /// ``StableRegionParserInputBuffer`` would satisfy the base protocol's requirement only sometimes,
    /// and the failure — quietly taking the recursive path, and quietly copying every payload — looks
    /// exactly like success.
    ///
    /// - Parameters:
    ///   - limit: The most bytes the parser may consume.
    ///   - body: A closure that reads through the cursor.
    /// - Returns: Whatever `body` returns.
    public func withParseInput<R>(limit: Int, _ body: (inout ParseInput) throws -> R) rethrows -> R {
        try _stableWithParseInput(limit: limit, body)
    }
}

extension IMAPInputBuffer: CustomStringConvertible {
    public var description: String {
        "IMAPInputBuffer(\(count) bytes in \(chunks.count) region\(chunks.count == 1 ? "" : "s"))"
    }
}
