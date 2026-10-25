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

// The `ByteBuffer` round trip, both directions. `ByteBuffer`'s conformance to the input protocols is
// next door in `ByteBuffer+ParserInput.swift`.

extension IMAPBuffer {
    /// Wraps a `ByteBuffer`'s readable bytes without copying them.
    ///
    /// The buffer's storage is retained for as long as the resulting ``IMAPBuffer`` lives. Copy-on-write
    /// makes that safe: any write to the original `ByteBuffer` copies its storage rather than
    /// mutating bytes this value refers to.
    ///
    /// - Parameter buffer: The bytes to wrap. Only the readable bytes are exposed.
    public init(_ buffer: ByteBuffer) {
        self.init(IMAPByteStorage(buffer))
    }

    /// These bytes as a `ByteBuffer`.
    ///
    /// This is zero-copy when the bytes are backed by a `ByteBuffer` — the result is a slice sharing
    /// the same storage. Otherwise the bytes are copied once, which is the honest cost of asking for
    /// a representation the backing cannot produce.
    public var byteBuffer: ByteBuffer {
        if let backing = backingRegion(as: ByteBuffer.self) {
            // The range indexes the readable bytes, so it is relative to the reader index. `getSlice`
            // shares storage rather than copying.
            return backing.region.getSlice(
                at: backing.region.readerIndex + backing.range.lowerBound,
                length: backing.range.count
            )!
        }
        return withUnsafeBytes { ByteBuffer(bytes: $0) }
    }
}

extension IMAPBufferList {
    /// The regions as `ByteBuffer`s, in order — one per region.
    ///
    /// Each region converts by ``IMAPBuffer/byteBuffer``'s rules: zero-copy where the region is
    /// backed by a `ByteBuffer`, one copy otherwise. Writing these to a `Channel` in order lets NIO
    /// gather them into a single `writev`.
    ///
    /// - Complexity: O(``IMAPBufferList/regionCount``), plus a copy of any region that is not
    ///   `ByteBuffer`-backed.
    /// - Returns: One `ByteBuffer` per region.
    public func makeByteBuffers() -> [ByteBuffer] {
        regions.map { $0.byteBuffer }
    }

    /// All of the bytes as a single `ByteBuffer`.
    ///
    /// Zero-copy when there is exactly one region and that region is `ByteBuffer`-backed; otherwise
    /// the bytes are copied once. Prefer ``makeOutboundBuffers()`` for writing to a `Channel`.
    ///
    /// - Complexity: O(``IMAPBufferList/byteCount``) in the general case.
    public func makeByteBuffer() -> ByteBuffer {
        switch regionCount {
        case 0: return ByteBuffer()
        case 1: return regions[0].byteBuffer
        default: return ByteBuffer(bytes: copiedBytes())
        }
    }

    /// The buffers to write to a `Channel` for these bytes, in order.
    ///
    /// Writing each of these in turn lets NIO gather them into one `writev`, and is the way to write a
    /// chunk without copying a large payload:
    ///
    /// ```swift
    /// for buffer in chunk.bytes.makeOutboundBuffers() {
    ///     context.write(self.wrapOutboundOut(buffer), promise: nil)
    /// }
    /// ```
    ///
    /// This is **not** one buffer per region. A region boundary can mean two different things: either a
    /// payload the encoder kept by reference, which is worth a write of its own because writing it
    /// separately is what keeps it uncopied — or an accident of where one output segment ended and the
    /// next began, which is worth nothing at all, and which turns a single message into two outbound
    /// writes that anything below this handler can see. So a run of small regions is coalesced into one
    /// buffer, and a region big enough that copying it would cost more than an extra write —
    /// ``IMAPBuffer``'s own copy threshold, the same number a sink decides by-reference appends with —
    /// is written on its own.
    ///
    /// - Complexity: O(``IMAPBufferList/byteCount``) in the bytes of the small regions, and O(1) in the
    ///   bytes of the large ones.
    /// - Returns: The buffers to write, in order. Empty only when there are no regions.
    public func makeOutboundBuffers() -> [ByteBuffer] {
        var result: [ByteBuffer] = []
        result.reserveCapacity(regionCount)
        // Regions waiting to be written together, and how many bytes they hold.
        var run: [IMAPBuffer] = []
        var runByteCount = 0

        func flushRun() {
            defer {
                run.removeAll(keepingCapacity: true)
                runByteCount = 0
            }
            switch run.count {
            case 0:
                return
            case 1:
                // On its own, a small region needs no copy either: `byteBuffer` slices where it can.
                result.append(run[0].byteBuffer)
            default:
                var coalesced = ByteBuffer()
                coalesced.reserveCapacity(runByteCount)
                for region in run {
                    region.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Void in
                        coalesced.writeBytes(bytes)
                    }
                }
                result.append(coalesced)
            }
        }

        for region in regions {
            guard region.count >= IMAPBuffer.copyThreshold else {
                run.append(region)
                runByteCount += region.count
                continue
            }
            flushRun()
            result.append(region.byteBuffer)
        }
        flushRun()
        return result
    }
}
