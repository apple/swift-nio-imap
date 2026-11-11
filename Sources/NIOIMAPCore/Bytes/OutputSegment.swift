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

/// A `malloc`'d, append-only, single-writer run of bytes. One allocation, never reallocated.
///
/// This is the unit of storage the encoder writes into. `used` only ever grows and the allocation
/// never moves, which is the property that lets a chunk be handed out while encoding continues: the
/// bytes already handed out and the bytes still being written are disjoint ranges of the same
/// segment, so nothing has to be copied or moved to make room.
///
/// That is the one thing `ByteBuffer`, `Data` and `Array` cannot do. They can only grow by
/// reallocating, which moves the bytes a handed-out slice refers to, so they have to copy instead.
///
/// - Important: A segment must be written by at most one owner. Nothing here enforces that; the
///   staging type above it does, by sealing a segment rather than sharing it when its state is
///   copied. ``IMAPInputBuffer``, which uses segments as tails for small reads, writes only while it
///   holds the sole reference.
///
/// - Note: **Unsafe seam** (all are listed at the top of `ParseInput.swift`). `@unchecked Sendable` rests on the
///   disjointness above: a handed-out region exposes a range that has already been written and that
///   nothing writes into again, while the writer only ever touches bytes beyond it. So a chunk may
///   cross to another thread while encoding continues, and the mutable `used` — which only ever
///   grows, and which a handed-out region never reads — does not make that a race. It rests on that
///   invariant, not on convention.
internal final class OutputSegment: @unchecked Sendable {
    /// The allocation. Allocated once in `init`, freed once in `deinit`, never resized.
    internal let storage: UnsafeMutableRawBufferPointer

    /// How many leading bytes have been written. Only ever grows.
    internal private(set) var used: Int = 0

    /// Allocates a segment.
    ///
    /// - Parameter capacity: How many bytes to allocate. Must be greater than zero.
    internal init(capacity: Int) {
        precondition(capacity > 0, "an OutputSegment needs a positive capacity, not \(capacity)")
        self.storage = .allocate(byteCount: capacity, alignment: MemoryLayout<UInt8>.alignment)
    }

    deinit {
        storage.deallocate()
    }

    /// The total size of the allocation.
    internal var capacity: Int { storage.count }

    /// How many more bytes will fit.
    internal var availableCapacity: Int { storage.count - used }

    /// Copies as much of `bytes` as fits onto the end.
    ///
    /// A write that does not fit is *not* an error and does not grow the segment: it is short, and
    /// the caller continues into a fresh segment. That is what keeps already-written bytes from ever
    /// being moved.
    ///
    /// - Parameter bytes: The bytes to append.
    /// - Returns: How many bytes were copied, from the front of `bytes`.
    @discardableResult
    internal func append(_ bytes: UnsafeRawBufferPointer) -> Int {
        let copying = Swift.min(bytes.count, availableCapacity)
        guard copying > 0, let source = bytes.baseAddress else { return 0 }
        // `storage` is a single allocation of `capacity` bytes and `used + copying <= capacity`.
        storage.baseAddress!.advanced(by: used).copyMemory(from: source, byteCount: copying)
        used += copying
        return copying
    }

    /// Records that the first `count` bytes have been written.
    ///
    /// The counterpart to ``append(_:)`` for a caller that writes into ``storage`` itself — which
    /// ``IMAPOutputBuffer`` does, because reaching this object at all costs a retain and a release,
    /// and for a short write that is the whole cost. Such a caller keeps its own count and brings
    /// `used` up to date when it needs the segment's own view to be current: before pinning any part
    /// of it, and before letting go of it.
    ///
    /// - Parameter count: How many leading bytes are written. Must not be below the current ``used``
    ///     or above ``capacity``.
    internal func markUsed(_ count: Int) {
        precondition(
            count >= used && count <= capacity,
            "cannot mark \(count) bytes used on a segment of \(capacity) with \(used) already written"
        )
        used = count
    }
}
