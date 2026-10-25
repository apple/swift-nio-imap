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

import NIO
import NIOIMAPCore

/// Encoded output written straight into a `ByteBuffer`.
///
/// This is the ``EncoderOutputBuffer`` to consider when the bytes are going to a NIO `Channel` and the
/// traffic is dominated by large payloads. Every byte of a command or response is copied exactly once —
/// into the buffer as it is encoded — and handing a chunk out costs no copy at all: the regions
/// ``takeFirst(_:)`` returns are slices of that same buffer, so `IMAPBufferList.makeByteBuffers()`
/// recovers them without touching a byte.
///
/// ## Choosing between this and `IMAPOutputBuffer`
///
/// Pass it as the `sink:` argument of a ``CommandEncodeBuffer`` or ``ResponseEncodeBuffer``:
///
/// ```swift
/// var encoder = CommandEncodeBuffer(sink: ByteBufferOutput(), options: options, loggingMode: false)
/// ```
///
/// It is deliberately *not* the default, and ``IMAPClientHandler`` and ``IMAPServerHandler`` do not use
/// it: ``IMAPOutputBuffer`` is faster wherever bytes are written rather than referred
/// to, because every `ByteBuffer` write pays a uniqueness check and a non-inlined capacity call where a
/// segment write goes through cached trivial fields — and a `BODYSTRUCTURE` response is hundreds of
/// small writes. This sink allocates fewer bytes and wins on payload-heavy traffic, so it ships as
/// a caller's choice. `Examples/PerformanceTester` has the numbers.
///
/// ``IMAPOutputBuffer`` also has one structural advantage: it can keep writing into a segment it has
/// already handed part of out, which this cannot. A `ByteBuffer` grows by reallocating, and writing into
/// storage that a handed-out slice still refers to would copy the whole buffer — so once bytes have been
/// handed out, this starts a fresh buffer instead. When the previous one has already been written to the
/// network, and its slice released, that is free; when it has not, it costs one allocation and still no
/// copy.
///
/// ## Large payloads
///
/// A payload appended as an ``IMAPBuffer`` — an `APPEND` message, a forwarded `FETCH` literal — is
/// kept by reference rather than copied once it is big enough to be worth a separate region, exactly
/// as ``IMAPOutputBuffer`` does. The chunk then has more than one region, and a caller that writes one
/// `ByteBuffer` per region lets NIO gather them into a single `writev` rather than coalescing them
/// itself. That is what makes forwarding a multi-megabyte literal free.
public struct ByteBufferOutput: EncoderOutputBuffer, Sendable {
    /// One entry in the pending list.
    ///
    /// Only regions that have been *closed* are held as values; the run of bytes currently being
    /// written is described by ``openRegionStart`` and the buffer's writer index instead, so that the
    /// common case — a message of nothing but written bytes — needs no list at all.
    private enum Region: Sendable {
        /// A range of ``buffer``.
        case owned(Range<Int>)
        /// A region belonging to somebody else, kept by reference rather than copied.
        case foreign(IMAPBuffer)

        var count: Int {
            switch self {
            case .owned(let range): return range.count
            case .foreign(let buffer): return buffer.count
            }
        }

        /// Splits into the first `k` bytes and the rest, by range arithmetic alone.
        func split(at k: Int) -> (Region, Region) {
            switch self {
            case .owned(let range):
                let middle = range.lowerBound + k
                return (.owned(range.lowerBound..<middle), .owned(middle..<range.upperBound))
            case .foreign(let buffer):
                return (.foreign(buffer.prefix(k)), .foreign(buffer.dropFirst(k)))
            }
        }
    }

    /// The bytes written so far.
    ///
    /// The reader index never moves — nothing reads from this buffer, it is only ever written to and
    /// sliced — so an index into it is also an offset from its first readable byte, which is what the
    /// ranges in ``closed`` and ``openRegionStart`` are.
    private var buffer: ByteBuffer

    /// Regions that have been closed and not yet handed out, oldest first.
    ///
    /// Empty unless a payload has been appended by reference, or a hand-out left bytes behind.
    private var closed: [Region] = []

    /// Where in ``buffer`` the region currently being written begins.
    private var openRegionStart: Int = 0

    /// The number of bytes pending hand-out, including the region still being written.
    private var pending: Int = 0

    /// Whether bytes have been handed out of ``buffer`` since it was started.
    ///
    /// While this is true the buffer must not be written into: something else — a `Channel` on its way
    /// to the socket — may still be reading the bytes handed out of it. What happens instead is decided
    /// at the next write rather than here, by ``startFreshBuffer()``, because by then the write may have
    /// completed and the buffer may be free to reuse.
    private var handedOut = false

    private let allocator: ByteBufferAllocator

    /// The capacity the next buffer is allocated with. Learned; see ``learn(usedCapacity:)``.
    private var nextCapacity: Int

    /// Creates an output buffer.
    ///
    /// - Parameter allocator: The allocator to take buffers from. Pass a `Channel`'s own allocator
    ///     where there is one.
    public init(allocator: ByteBufferAllocator = ByteBufferAllocator()) {
        self.allocator = allocator
        // Zero capacity allocates nothing: NIO hands back a shared empty buffer, and the first write
        // is what allocates. So an output buffer that is created and never written to is free, which
        // matters because the state machine makes one per command it might not send.
        self.buffer = allocator.buffer(capacity: 0)
        self.nextCapacity = Self.defaultCapacity
    }

    /// The capacity a buffer starts at, before anything has been learned about message sizes.
    ///
    /// About the size of a command line. Capacities round up to a power of two inside NIO, so this is
    /// also what a `NOOP` allocates.
    internal static let defaultCapacity = 256

    /// The largest capacity kept between messages.
    ///
    /// A buffer is reused across messages, and a message that needed megabytes should not make it hold
    /// megabytes for the rest of the connection. Above this, the buffer is dropped and a fresh one
    /// starts at the learned size.
    internal static let maximumRetainedCapacity = 64 * 1024

    // MARK: - EncoderOutputBuffer

    /// How many bytes are waiting to be handed out.
    ///
    /// - Complexity: O(1).
    public var byteCount: Int { pending }

    /// Copies bytes onto the end.
    ///
    /// - Parameter bytes: The bytes to append.
    public mutating func append(_ bytes: UnsafeRawBufferPointer) {
        guard !bytes.isEmpty else { return }
        if handedOut { startFreshBuffer() }
        if buffer.writableBytes < bytes.count {
            // Reserve up front rather than letting the buffer grow one write at a time: the first
            // write of a message would otherwise allocate exactly its own size and every write after
            // it would realloc.
            buffer.reserveCapacity(Swift.max(nextCapacity, buffer.writerIndex + bytes.count))
        }
        buffer.writeBytes(bytes)
        pending += bytes.count
    }

    /// Appends a region, by reference when it is big enough to be worth it.
    ///
    /// At or above ``IMAPBuffer/copyThreshold`` the region is kept as-is and nothing is copied. Below
    /// it the bytes are copied into the buffer, because a short region is not worth a separate output
    /// region — and a separate output region is a separate write to the network.
    ///
    /// - Parameter region: The region to append.
    public mutating func append(_ region: IMAPBuffer) {
        guard !region.isEmpty else { return }
        guard region.count >= IMAPBuffer.copyThreshold else {
            region.withUnsafeBytes { self.append($0) }
            return
        }
        closeOpenRegion()
        closed.append(.foreign(region))
        pending += region.count
    }

    /// Removes the first `byteCount` pending bytes and returns them, in order.
    ///
    /// The returned regions are slices of the buffer they were written into, so this copies nothing. It
    /// is also the point at which that buffer stops being written into — see ``startFreshBuffer()``.
    ///
    /// - Parameter byteCount: How many bytes to take. Must not exceed ``byteCount``.
    /// - Returns: The bytes taken.
    public mutating func takeFirst(_ byteCount: Int) -> IMAPBufferList {
        precondition(
            byteCount >= 0 && byteCount <= pending,
            "cannot take \(byteCount) bytes from a ByteBufferOutput holding \(pending)"
        )
        guard byteCount > 0 else { return IMAPBufferList() }

        let list: IMAPBufferList
        if closed.isEmpty {
            // The common case: everything pending is the one run of bytes being written, so the
            // hand-out is a single region and needs neither the region list nor an intermediate array.
            list = IMAPBufferList(IMAPBuffer(IMAPByteStorage(buffer), openRegionStart..<(openRegionStart + byteCount)))
            openRegionStart += byteCount
        } else if closed[0].count >= byteCount {
            // The oldest region covers the request on its own, which is what a streamed literal looks
            // like: one payload appended by reference, handed straight back out. Worth keeping off the
            // general path, which allocates an array to gather regions into.
            let head: Region
            if closed[0].count == byteCount {
                head = closed.removeFirst()
            } else {
                let (first, rest) = closed[0].split(at: byteCount)
                closed[0] = rest
                head = first
            }
            list = IMAPBufferList(makeBuffer(head))
        } else {
            list = takeAcrossRegions(byteCount)
        }
        pending -= byteCount
        handedOut = true
        learn(usedCapacity: buffer.writerIndex)
        if pending == 0, buffer.capacity > Self.maximumRetainedCapacity {
            // Nothing is left to carry over, so a buffer that grew for one large message can go now
            // rather than pinning megabytes until the next write. Costs nothing: the bytes just handed
            // out keep the memory alive for exactly as long as they need it.
            releaseBuffer()
        }
        return list
    }

    /// Calls the given closure with the pending regions, in order.
    ///
    /// - Note: Cold path — equality, hashing and debug descriptions. This materialises an array, and
    ///   it briefly shares the buffer's storage with the regions it yields, so a write immediately
    ///   afterwards may copy the buffer once. Nothing on the encode path reads bytes back.
    ///
    /// - Parameter body: A closure that receives the pending regions.
    /// - Returns: Whatever `body` returns.
    public func withPendingRegions<R>(_ body: (Span<IMAPBuffer>) -> R) -> R {
        // `ContiguousArray`, not `Array`: `Array.span` checks for a bridged `NSArray` and copies the
        // elements out if it finds one, which `ContiguousArray.span` never has to do. The macOS 26 floor
        // makes either spelling legal now; this one is the cheaper.
        var regions: ContiguousArray<IMAPBuffer> = []
        regions.reserveCapacity(closed.count + 1)
        var storage: IMAPByteStorage?
        for region in closed {
            switch region {
            case .owned(let range):
                let owner = storage ?? IMAPByteStorage(buffer)
                storage = owner
                regions.append(IMAPBuffer(owner, range))
            case .foreign(let buffer):
                regions.append(buffer)
            }
        }
        // The run still being written is pending too, even though it is not in `closed`.
        if buffer.writerIndex > openRegionStart {
            let owner = storage ?? IMAPByteStorage(buffer)
            regions.append(IMAPBuffer(owner, openRegionStart..<buffer.writerIndex))
        }
        return body(regions.span)
    }

    /// Discards everything pending, and gives up the memory backing it.
    ///
    /// The buffer itself is kept where it can be — a long-lived encoder, and a server handler drains one
    /// of these after every response, then writes its next message into the same memory. Whether that is
    /// possible depends on whether the bytes last handed out have reached the network yet, so the
    /// decision is deferred to the next write. A buffer that grew past ``maximumRetainedCapacity`` for
    /// one large message is dropped rather than held for the rest of the connection.
    ///
    /// Bytes already handed out are unaffected: nothing here writes into them or frees them.
    public mutating func removeAll() {
        closed.removeAll(keepingCapacity: true)
        pending = 0
        guard !handedOut else {
            guard buffer.capacity <= Self.maximumRetainedCapacity else {
                // Oversized, and everything in it has either been handed out or just been discarded:
                // let it go now rather than holding megabytes until the next message.
                releaseBuffer()
                return
            }
            // Leave the buffer as it is and let the next write deal with it: by then the bytes handed
            // out of it may have been released, and reusing it is free. Everything up to the writer
            // index is now spoken for or discarded, so the next region starts there.
            openRegionStart = buffer.writerIndex
            return
        }
        resetBuffer()
    }

    // MARK: - Writing

    /// Moves the run of bytes being written into ``closed``.
    private mutating func closeOpenRegion() {
        guard buffer.writerIndex > openRegionStart else { return }
        closed.append(.owned(openRegionStart..<buffer.writerIndex))
        openRegionStart = buffer.writerIndex
    }

    /// Starts writing into memory nothing has been handed out of.
    ///
    /// Called before the first write after a hand-out, because the bytes handed out are slices of
    /// ``buffer`` and writing into it again would copy all of it. Deliberately *not* called at the
    /// hand-out itself: waiting until the next write is what makes reuse possible at all, since a chunk
    /// is by definition still alive at the moment it is handed over.
    ///
    /// Whatever is still pending in the buffer — the remainder of a command that stopped at a
    /// synchronizing literal — moves into the new one, and that is the only case in which this copies
    /// anything.
    private mutating func startFreshBuffer() {
        handedOut = false

        let ownedPending = closed.reduce(buffer.writerIndex - openRegionStart) { total, region in
            switch region {
            case .owned(let range): return total + range.count
            case .foreign: return total
            }
        }
        guard ownedPending > 0 else {
            resetBuffer()
            return
        }

        var fresh = allocator.buffer(capacity: Swift.max(nextCapacity, ownedPending))
        let previous = buffer
        previous.withUnsafeReadableBytes { bytes in
            for index in closed.indices {
                guard case .owned(let range) = closed[index] else { continue }
                let start = fresh.writerIndex
                fresh.writeBytes(UnsafeRawBufferPointer(rebasing: bytes[range]))
                closed[index] = .owned(start..<fresh.writerIndex)
            }
            // The run being written stays the run being written, at the end of the fresh buffer, so
            // the next write extends it rather than starting another region.
            let start = fresh.writerIndex
            fresh.writeBytes(UnsafeRawBufferPointer(rebasing: bytes[openRegionStart..<previous.writerIndex]))
            openRegionStart = start
        }
        buffer = fresh
    }

    /// Starts the buffer over from nothing, keeping its memory if that memory is free to keep.
    ///
    /// `clear` is the whole trick: it resets the indices in place when the storage is this buffer's
    /// alone, and allocates fresh storage — without copying a byte — when a handed-out slice is still
    /// reading the old bytes. So a drained encoder reuses one allocation forever when its writes have
    /// completed, and pays one allocation per message when they have not.
    private mutating func resetBuffer() {
        openRegionStart = 0
        if buffer.capacity > Self.maximumRetainedCapacity {
            releaseBuffer()
        } else {
            buffer.clear(minimumCapacity: nextCapacity)
        }
    }

    /// Lets go of the buffer's memory, so that the next write allocates a fresh one.
    ///
    /// Only for a buffer that grew far past what messages need. Whatever has been handed out of it keeps
    /// it alive for as long as it needs it, so this frees nothing that is still in use.
    private mutating func releaseBuffer() {
        // Zero capacity is NIO's shared empty buffer, so this allocates nothing of its own.
        buffer = allocator.buffer(capacity: 0)
        openRegionStart = 0
        handedOut = false
    }

    // MARK: - Handing out

    /// Turns one pending region into an ``IMAPBuffer``.
    ///
    /// An owned region gets a box holding the buffer it lives in: that is what keeps the bytes alive
    /// after this sink has moved on to a fresh buffer, and the range is what pins the extent, so the
    /// region can never see bytes written later.
    private func makeBuffer(_ region: Region) -> IMAPBuffer {
        switch region {
        case .owned(let range): return IMAPBuffer(IMAPByteStorage(buffer), range)
        case .foreign(let region): return region
        }
    }

    /// Takes `byteCount` bytes from the front of the pending regions.
    ///
    /// The path for a chunk that spans more than one region, which means a payload was appended by
    /// reference or a previous hand-out left bytes behind.
    private mutating func takeAcrossRegions(_ byteCount: Int) -> IMAPBufferList {
        closeOpenRegion()

        var taken: [IMAPBuffer] = []
        var storage: IMAPByteStorage?
        var remaining = byteCount
        var consumed = 0
        while remaining > 0 {
            let region = closed[consumed]
            let head: Region
            if region.count <= remaining {
                head = region
                remaining -= region.count
                consumed += 1
            } else {
                let (first, rest) = region.split(at: remaining)
                head = first
                closed[consumed] = rest
                remaining = 0
            }
            switch head {
            case .owned(let range):
                // One owner for every region taken out of the buffer, however many there are: the box
                // is what the bytes are kept alive by, and they are all kept alive by the same buffer.
                let owner = storage ?? IMAPByteStorage(buffer)
                storage = owner
                taken.append(IMAPBuffer(owner, range))
            case .foreign(let region):
                taken.append(region)
            }
        }
        closed.removeFirst(consumed)
        return IMAPBufferList(taken)
    }

    /// Records how big the last message was, so the next buffer starts big enough for it.
    ///
    /// Deliberately the *last* message rather than the largest one seen. A high-water mark is the right
    /// answer for a buffer that is reused, because it is free to keep capacity it already has — but this
    /// number is also what a buffer allocates with when it *cannot* be reused, which is what happens
    /// whenever the last message is still on its way to the network. Sizing those allocations by the
    /// high-water mark means one large response makes every small response after it allocate as if it
    /// were large too.
    private mutating func learn(usedCapacity: Int) {
        nextCapacity = Swift.min(
            Swift.max(usedCapacity, Self.defaultCapacity),
            Self.maximumRetainedCapacity
        )
    }
}

// MARK: - Debugging

extension ByteBufferOutput {
    /// How many regions are pending, including the run still being written.
    ///
    /// This exposes what the public API deliberately hides — how the pending bytes are split up — which
    /// is the only way to check that consecutive writes stay one region, that a payload appended by
    /// reference becomes its own, and that a hand-out leaves the remainder where the next write can
    /// extend it. Tests use these three; nothing else should.
    internal var pendingRegionCount: Int {
        closed.count + (buffer.writerIndex > openRegionStart ? 1 : 0)
    }

    /// Whether the pending region at `index` is one appended by reference rather than written.
    internal func pendingRegionIsForeign(_ index: Int) -> Bool {
        guard index < closed.count else { return false }
        if case .foreign = closed[index] { return true }
        return false
    }

    /// The address of the buffer being written into, and its capacity.
    ///
    /// Address identity is how "the buffer was reused rather than reallocated" is observable at all.
    /// Deliberately a non-mutating read: asking for a mutable pointer would copy the storage when it is
    /// shared, which is the very thing being observed.
    internal var writeBufferIdentity: (address: UInt, capacity: Int) {
        (buffer.withUnsafeReadableBytes { UInt(bitPattern: $0.baseAddress) }, buffer.capacity)
    }
}

extension ByteBufferOutput: CustomDebugStringConvertible {
    /// A description showing what is pending.
    public var debugDescription: String {
        let regions = pendingRegionCount
        return "ByteBufferOutput(\(pending) bytes pending in \(regions) region\(regions == 1 ? "" : "s"))"
    }
}
