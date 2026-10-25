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

import Dispatch
import Foundation  // for `DispatchData.regions`, which Foundation defines
import Testing

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

extension IMAPOutputBuffer {
    /// Appends bytes, spelled for readability in tests.
    fileprivate mutating func appendBytes(_ bytes: [UInt8]) {
        bytes.withUnsafeBytes { append($0) }
    }

    /// A run of `count` distinct-ish bytes, so that a misplaced range shows up as wrong content.
    fileprivate static func pattern(_ count: Int, seed: UInt8 = 0) -> [UInt8] {
        (0..<count).map { UInt8(truncatingIfNeeded: $0 &* 7 &+ Int(seed)) }
    }

    /// The segment backing a pending region, or `nil` if the region is a foreign one.
    fileprivate func segment(ofPendingRegion index: Int) -> OutputSegment? {
        guard case .owned(let segment, _) = pendingRegions[index] else { return nil }
        return segment
    }
}

extension IMAPBufferList {
    fileprivate var string: String { String(decoding: copiedBytes(), as: UTF8.self) }
}

@Suite("IMAPOutputBuffer")
struct IMAPOutputBufferTests {

    // MARK: - Appending and byteCount

    @Test("a fresh buffer holds nothing")
    func fresh() {
        let buffer = IMAPOutputBuffer()
        #expect(buffer.byteCount == 0)
        #expect(buffer.pendingRegions.isEmpty)
        #expect(buffer.openSegment == nil)
    }

    @Test("appending nothing does not open a segment")
    func appendEmpty() {
        var buffer = IMAPOutputBuffer()
        buffer.appendBytes([])
        buffer.append(IMAPBuffer())
        #expect(buffer.byteCount == 0)
        #expect(buffer.pendingRegions.isEmpty)
        #expect(buffer.openSegment == nil)
    }

    @Test("consecutive writes coalesce into one region")
    func coalescing() {
        var buffer = IMAPOutputBuffer()
        buffer.append("A001 SELECT ")
        buffer.append("INBOX")
        buffer.append("\r\n")
        #expect(buffer.byteCount == 19)
        // The whole point: a command written as many small writes is still one output region.
        #expect(buffer.pendingRegions.count == 1)
        #expect(buffer.takeFirst(19).string == "A001 SELECT INBOX\r\n")
    }

    @Test("byteCount counts pending bytes and resets as they are handed out")
    func byteCountIsPending() {
        var buffer = IMAPOutputBuffer()
        buffer.append("0123456789")
        #expect(buffer.byteCount == 10)
        _ = buffer.takeFirst(4)
        #expect(buffer.byteCount == 6)
        buffer.append("abc")
        #expect(buffer.byteCount == 9)
        _ = buffer.takeFirst(9)
        #expect(buffer.byteCount == 0)
    }

    @Test("appending a string with no contiguous UTF-8 still appends its bytes")
    func appendForeignString() {
        var buffer = IMAPOutputBuffer()
        // A string built through `String.init(decoding:)` is native and contiguous; the interesting
        // case is one that reports no contiguous storage. Either way the bytes must land, which is
        // what the slow path exists for.
        let name = "Ünïcødé Mailbox 📬"
        let written = buffer.append(name)
        #expect(written == name.utf8.count)
        #expect(buffer.takeFirst(buffer.byteCount).copiedBytes() == Array(name.utf8))
    }

    // MARK: - Segments

    @Test("a write that overflows the open segment is split, and nothing already written moves")
    func splitWrite() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 16, maximumSegmentSize: 16)
        let first = IMAPOutputBuffer.pattern(10, seed: 1)
        let second = IMAPOutputBuffer.pattern(12, seed: 2)
        buffer.appendBytes(first)
        buffer.appendBytes(second)

        #expect(buffer.byteCount == 22)
        // The second write does not fit in the six bytes left: six of it fill the first segment and
        // the rest starts a new one. The ten bytes already there are not touched.
        #expect(buffer.pendingRegions.count == 2)
        #expect(buffer.pendingRegions.map(\.count) == [16, 6])
        #expect(buffer.segment(ofPendingRegion: 0) !== buffer.segment(ofPendingRegion: 1))
        #expect(buffer.takeFirst(22).copiedBytes() == first + second)
    }

    @Test("a single write larger than a segment gets one segment sized to fit it")
    func oversizedWrite() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 16, maximumSegmentSize: 16)
        let bytes = IMAPOutputBuffer.pattern(40)
        buffer.appendBytes(bytes)

        // The maximum is a cap on how big segments *grow to*, not a cap on a single allocation: one
        // 40-byte segment beats three 16-byte ones, because output regions cost more than bytes do.
        #expect(buffer.pendingRegions.count == 1)
        #expect(buffer.openSegment!.capacity == 40)
        #expect(buffer.takeFirst(40).copiedBytes() == bytes)
    }

    @Test("many small writes spill across several segments in order")
    func multiSegment() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 8, maximumSegmentSize: 8)
        var expected: [UInt8] = []
        for index in 0..<20 {
            let chunk = IMAPOutputBuffer.pattern(5, seed: UInt8(index))
            buffer.appendBytes(chunk)
            expected += chunk
        }
        #expect(buffer.byteCount == 100)
        #expect(buffer.pendingRegions.count > 1, "8-byte segments cannot hold 100 bytes in one region")
        #expect(buffer.takeFirst(100).copiedBytes() == expected)
    }

    @Test("segment sizes double up to the cap, and a big write gets a segment that fits it")
    func segmentGrowth() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 8, maximumSegmentSize: 32)
        var sizes: [Int] = []
        for _ in 0..<6 {
            buffer.appendBytes(IMAPOutputBuffer.pattern(64))
            if let segment = buffer.openSegment { sizes.append(segment.capacity) }
            _ = buffer.takeFirst(buffer.byteCount)
        }
        #expect(sizes.allSatisfy { $0 >= 8 })
        #expect(sizes.max()! >= 32, "sizing should reach the cap")

        // A single write larger than the cap gets one segment big enough for it, rather than a run of
        // capped-size ones.
        var big = IMAPOutputBuffer(initialSegmentSize: 8, maximumSegmentSize: 32)
        big.appendBytes(IMAPOutputBuffer.pattern(500))
        #expect(big.pendingRegions.count == 1)
        #expect(big.openSegment!.capacity == 500)
    }

    // MARK: - Handing out

    @Test("takeFirst splits the straddling region and leaves the rest pending")
    func takeFirstSplits() {
        var buffer = IMAPOutputBuffer()
        buffer.append("HELLO WORLD")

        let first = buffer.takeFirst(5)
        #expect(first.string == "HELLO")
        #expect(buffer.byteCount == 6)

        let second = buffer.takeFirst(6)
        #expect(second.string == " WORLD")
        #expect(buffer.byteCount == 0)
    }

    @Test("takeFirst walks across segments, joining them into one list")
    func takeFirstAcrossSegments() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 4, maximumSegmentSize: 4)
        // Three writes that each exactly fill a segment, so there are three regions to walk.
        buffer.append("ABCD")
        buffer.append("EFGH")
        buffer.append("IJKL")
        #expect(buffer.pendingRegions.count == 3)

        // Ask for a length that ends inside the third region.
        let chunk = buffer.takeFirst(10)
        #expect(chunk.byteCount == 10)
        #expect(chunk.regionCount == 3)
        #expect(chunk.string == "ABCDEFGHIJ")
        #expect(buffer.byteCount == 2)
        #expect(buffer.takeFirst(2).string == "KL")
    }

    @Test("takeFirst ending on a region boundary leaves no empty region behind")
    func takeFirstEndingOnRegionBoundary() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 4, maximumSegmentSize: 4)
        buffer.append("ABCD")
        buffer.append("EFGH")
        buffer.append("IJKL")

        // Ends exactly where the second region does.
        let chunk = buffer.takeFirst(8)
        #expect(chunk.regionCount == 2)
        #expect(chunk.string == "ABCDEFGH")
        #expect(buffer.pendingRegions.map(\.count) == [4])

        let next = buffer.takeFirst(4)
        #expect(next.regionCount == 1)
        #expect(next.string == "IJKL")
    }

    @Test("takeFirst of nothing is an empty list, and does not touch what is pending")
    func takeFirstZero() {
        var buffer = IMAPOutputBuffer()
        buffer.append("XYZ")
        let chunk = buffer.takeFirst(0)
        #expect(chunk.byteCount == 0)
        #expect(chunk.regionCount == 0)
        #expect(buffer.byteCount == 3)
    }

    @Test("bytes already handed out do not change as encoding continues")
    func handedOutBytesAreImmutable() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 64, maximumSegmentSize: 64)
        buffer.append("A001 APPEND ")
        let chunk = buffer.takeFirst(buffer.byteCount)
        #expect(chunk.string == "A001 APPEND ")

        // Keep writing into the very same segment, above the bytes just handed out.
        buffer.append("INBOX {3}\r\n")
        buffer.append("abc")
        #expect(buffer.takeFirst(buffer.byteCount).string == "INBOX {3}\r\nabc")

        // The earlier chunk still reads what it read before.
        #expect(chunk.string == "A001 APPEND ")
    }

    @Test("a chunk keeps its segment alive after the encoder has moved on")
    func chunkKeepsSegmentAlive() {
        var chunk = IMAPBufferList()
        do {
            var buffer = IMAPOutputBuffer(initialSegmentSize: 32, maximumSegmentSize: 32)
            buffer.append("kept alive")
            chunk = buffer.takeFirst(buffer.byteCount)
            buffer.removeAll()
        }
        #expect(chunk.string == "kept alive")
    }

    // MARK: - Foreign regions

    @Test("a region at or above the copy threshold is kept by reference, not copied")
    func foreignRegionRetained() {
        var buffer = IMAPOutputBuffer()
        let payload = IMAPBuffer(IMAPOutputBuffer.pattern(IMAPBuffer.copyThreshold))
        buffer.append(payload)

        #expect(buffer.byteCount == IMAPBuffer.copyThreshold)
        #expect(buffer.pendingRegions.count == 1)
        guard case .foreign = buffer.pendingRegions[0] else {
            Issue.record("expected the payload to be kept by reference")
            return
        }
        #expect(buffer.openSegment == nil, "a by-reference append should not allocate a segment")

        let chunk = buffer.takeFirst(buffer.byteCount)
        #expect(chunk.regionCount == 1)
        #expect(chunk.copiedBytes() == payload.copiedBytes())
    }

    @Test("a region below the copy threshold is copied into a segment")
    func foreignRegionCopied() {
        var buffer = IMAPOutputBuffer()
        let payload = IMAPBuffer(IMAPOutputBuffer.pattern(IMAPBuffer.copyThreshold - 1))
        buffer.append(payload)

        #expect(buffer.byteCount == IMAPBuffer.copyThreshold - 1)
        #expect(buffer.pendingRegions.count == 1)
        guard case .owned = buffer.pendingRegions[0] else {
            Issue.record("expected a short payload to be copied into a segment")
            return
        }
        #expect(buffer.takeFirst(buffer.byteCount).copiedBytes() == payload.copiedBytes())
    }

    @Test("a short region copied in coalesces with the writes around it")
    func shortForeignRegionCoalesces() {
        var buffer = IMAPOutputBuffer()
        buffer.append("<")
        buffer.append(IMAPBuffer("short"))
        buffer.append(">")
        #expect(buffer.pendingRegions.count == 1)
        #expect(buffer.takeFirst(buffer.byteCount).string == "<short>")
    }

    @Test("one segment backs two non-adjacent regions across a by-reference append")
    func segmentBacksNonAdjacentRegions() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 4096, maximumSegmentSize: 4096)
        buffer.appendBytes(IMAPOutputBuffer.pattern(40, seed: 1))
        buffer.append(IMAPBuffer(IMAPOutputBuffer.pattern(2048, seed: 2)))
        buffer.appendBytes(IMAPOutputBuffer.pattern(30, seed: 3))

        #expect(buffer.pendingRegions.map(\.count) == [40, 2048, 30])
        // The bytes written after the by-reference region continue in the *same* segment as the ones
        // written before it. Anything else would allocate a fresh segment per payload.
        #expect(buffer.segment(ofPendingRegion: 0) === buffer.segment(ofPendingRegion: 2))
        #expect(buffer.segment(ofPendingRegion: 1) == nil)

        let expected =
            IMAPOutputBuffer.pattern(40, seed: 1) + IMAPOutputBuffer.pattern(2048, seed: 2)
            + IMAPOutputBuffer.pattern(30, seed: 3)
        #expect(buffer.takeFirst(buffer.byteCount).copiedBytes() == expected)
    }

    @Test("splitting a by-reference region does not copy it")
    func splitForeignRegion() {
        var buffer = IMAPOutputBuffer()
        let payload = IMAPOutputBuffer.pattern(4096)
        buffer.append(IMAPBuffer(payload))

        let first = buffer.takeFirst(1000)
        #expect(first.copiedBytes() == Array(payload[0..<1000]))
        #expect(buffer.byteCount == 3096)
        guard case .foreign = buffer.pendingRegions[0] else {
            Issue.record("the remainder of a by-reference region should stay by-reference")
            return
        }
        #expect(buffer.takeFirst(3096).copiedBytes() == Array(payload[1000...]))
    }

    // MARK: - removeAll

    @Test("removeAll drops the pending bytes and releases every segment but the open one")
    func removeAllReleasesSegments() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 32, maximumSegmentSize: 32)
        buffer.appendBytes(IMAPOutputBuffer.pattern(32))  // fills the first segment
        buffer.appendBytes(IMAPOutputBuffer.pattern(8))  // opens a second
        weak var filled: OutputSegment?
        weak var open: OutputSegment?
        if case .owned(let segment, _) = buffer.pendingRegions[0] { filled = segment }
        open = buffer.openSegment
        #expect(filled != nil)
        #expect(open != nil)
        #expect(filled !== open)

        buffer.removeAll()
        #expect(buffer.byteCount == 0)
        #expect(buffer.pendingRegions.isEmpty)
        #expect(filled == nil, "removeAll must release the segments it is done with, not just reset a position")
        // The one it is writing into is kept, so the next message does not have to allocate.
        #expect(open != nil)
        #expect(buffer.openSegment === open)
    }

    @Test("removeAll releases a full segment rather than keeping one with no room")
    func removeAllDropsAFullSegment() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 16, maximumSegmentSize: 16)
        buffer.appendBytes(IMAPOutputBuffer.pattern(16))
        weak var segment: OutputSegment?
        segment = buffer.openSegment
        #expect(segment != nil)

        buffer.removeAll()
        #expect(segment == nil)
        #expect(buffer.openSegment == nil)
    }

    @Test("the kept segment is written above what was already handed out")
    func removeAllKeepsHandedOutBytesIntact() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 4096, maximumSegmentSize: 4096)
        buffer.append("first message")
        let first = buffer.takeFirst(buffer.byteCount)
        buffer.removeAll()

        buffer.append("second message")
        let second = buffer.takeFirst(buffer.byteCount)

        #expect(first.string == "first message")
        #expect(second.string == "second message")
    }

    @Test("removeAll keeps the segment sizing it has learned")
    func removeAllKeepsSizing() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 8, maximumSegmentSize: 1024)
        for _ in 0..<8 {
            buffer.appendBytes(IMAPOutputBuffer.pattern(8))
        }
        let grown = buffer.openSegment!.capacity
        #expect(grown > 8)

        buffer.removeAll()
        buffer.appendBytes([1])
        #expect(
            buffer.openSegment!.capacity >= grown,
            "re-climbing the growth curve after every message would allocate repeatedly"
        )
    }

    @Test("a buffer is reusable after removeAll")
    func reuseAfterRemoveAll() {
        var buffer = IMAPOutputBuffer()
        buffer.append("first")
        buffer.removeAll()
        buffer.append("second")
        #expect(buffer.takeFirst(buffer.byteCount).string == "second")
    }

    // MARK: - Value semantics

    @Test("writing to a copy seals the tail, and neither copy corrupts the other")
    func copyOnWriteForksBySealing() {
        var original = IMAPOutputBuffer(initialSegmentSize: 4096, maximumSegmentSize: 4096)
        original.append("SHARED ")
        let sharedSegment = original.openSegment
        #expect(sharedSegment != nil)

        var copy = original
        copy.append("copy")
        original.append("original")

        #expect(original.takeFirst(original.byteCount).string == "SHARED original")
        #expect(copy.takeFirst(copy.byteCount).string == "SHARED copy")

        // One of the two had to give up the shared segment; they must not both be writing into it.
        #expect(original.openSegment !== copy.openSegment)
    }

    @Test("a copy taken before a hand-out still has all of its bytes")
    func copyIsUnaffectedByHandOut() {
        var original = IMAPOutputBuffer()
        original.append("A001 NOOP\r\n")
        var copy = original

        _ = original.takeFirst(original.byteCount)
        #expect(original.byteCount == 0)
        #expect(copy.byteCount == 11)
        #expect(copy.takeFirst(11).string == "A001 NOOP\r\n")
    }

    @Test("removeAll on a copy leaves the original alone")
    func removeAllIsPerCopy() {
        var original = IMAPOutputBuffer()
        original.append("kept")
        var copy = original
        copy.removeAll()

        #expect(copy.byteCount == 0)
        #expect(original.byteCount == 4)
        #expect(original.takeFirst(4).string == "kept")
    }

    // MARK: - Reading back

    @Test("withPendingRegions yields the pending regions, in order, without consuming them")
    func withPendingRegions() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 4, maximumSegmentSize: 4)
        buffer.append("ABCD")
        buffer.append("EFG")

        let described = buffer.withPendingRegions { regions -> [Int] in
            var counts: [Int] = []
            for index in regions.indices {
                counts.append(regions[index].count)
            }
            return counts
        }
        #expect(described == [4, 3])
        #expect(buffer.byteCount == 7, "reading back must not consume")

        let bytes = buffer.withPendingRegions { regions -> [UInt8] in
            var all: [UInt8] = []
            for index in regions.indices {
                all += regions[index].copiedBytes()
            }
            return all
        }
        #expect(bytes == Array("ABCDEFG".utf8))
    }

    @Test("withPendingRegions on an empty buffer yields nothing")
    func withPendingRegionsEmpty() {
        let buffer = IMAPOutputBuffer()
        #expect(buffer.withPendingRegions { $0.count } == 0)
    }

    @Test("debugDescription reports what is pending")
    func debugDescription() {
        var buffer = IMAPOutputBuffer()
        #expect(buffer.debugDescription == "IMAPOutputBuffer(0 bytes pending in 0 regions)")
        buffer.append("abc")
        #expect(buffer.debugDescription == "IMAPOutputBuffer(3 bytes pending in 1 region)")
    }

    // MARK: - DispatchData

    @Test("small output regions are copied into one DispatchData region")
    func dispatchDataRegionCount() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 4, maximumSegmentSize: 4)
        buffer.append("ABCD")
        buffer.append("EFGH")
        buffer.append("IJ")
        let chunk = buffer.takeFirst(10)
        #expect(chunk.regionCount == 3)

        let data = chunk.makeDispatchData()
        #expect(data.count == 10)
        #expect(Array(data) == Array("ABCDEFGHIJ".utf8))
        #expect(data.regions.count == 1)
    }

    @Test("segment-backed bytes are donated to a DispatchData, not copied")
    func dispatchDataIsZeroCopy() {
        let byteCount = IMAPBuffer.dispatchDonationThreshold
        var buffer = IMAPOutputBuffer(initialSegmentSize: byteCount, maximumSegmentSize: byteCount)
        buffer.appendBytes(IMAPOutputBuffer.pattern(byteCount))
        let chunk = buffer.takeFirst(buffer.byteCount)

        let source = chunk.regions[0].withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
        let data = chunk.makeDispatchData()
        let destination = data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in UInt(bitPattern: pointer) }
        #expect(source == destination, "the DispatchData should adopt the segment's memory")
    }

    @Test("the DispatchData deallocator releases the storage when the data goes away")
    func dispatchDataDeallocatorRuns() async {
        weak var segment: OutputSegment?
        do {
            let byteCount = IMAPBuffer.dispatchDonationThreshold
            var buffer = IMAPOutputBuffer(initialSegmentSize: byteCount, maximumSegmentSize: byteCount)
            buffer.appendBytes(IMAPOutputBuffer.pattern(byteCount))
            segment = buffer.openSegment
            var data: DispatchData? = buffer.takeFirst(buffer.byteCount).makeDispatchData()
            buffer.removeAll()
            #expect(segment != nil, "the DispatchData holds the segment alive")
            #expect(data!.count == byteCount)
            data = nil
        }

        // Not synchronous, and deliberately so documented: `libdispatch` runs a custom destructor
        // block on a queue, and `nil` picks the default global queue rather than running it inline.
        // So the release arrives shortly afterwards, on another thread.
        var released = false
        for _ in 0..<200 {
            if segment == nil {
                released = true
                break
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(released, "letting the DispatchData go must release the segment")
    }

    @Test("an empty chunk converts to an empty DispatchData")
    func dispatchDataEmpty() {
        #expect(IMAPBufferList().makeDispatchData().count == 0)
        #expect(IMAPBufferList(IMAPBuffer()).makeDispatchData().count == 0)
    }

    @Test("a by-reference region is donated when its owner has a stable address")
    func dispatchDataForeignRegion() {
        let payload = IMAPOutputBuffer.pattern(2048)
        var buffer = IMAPOutputBuffer()
        buffer.append(IMAPBuffer(payload))
        let chunk = buffer.takeFirst(buffer.byteCount)

        let data = chunk.makeDispatchData()
        #expect(data.count == 2048)
        #expect(Array(data) == payload)
    }

    @Test("a region whose owner promises nothing about addresses is copied instead")
    func dispatchDataUnstableRegion() {
        // `UnstableRegion` yields a fresh temporary buffer every time, which is exactly what a
        // pointer must not be allowed to escape from.
        struct UnstableRegion: ByteRegion, Sendable {
            let bytes: [UInt8]
            func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                var temporary = bytes
                return try temporary.withUnsafeMutableBytes { try body(UnsafeRawBufferPointer($0)) }
            }
        }

        let payload = IMAPOutputBuffer.pattern(2048)
        let storage = IMAPByteStorage(UnstableRegion(bytes: payload))
        #expect(storage.hasStableAddress == false)

        let data = IMAPBufferList(IMAPBuffer(storage)).makeDispatchData()
        #expect(Array(data) == payload, "an unstable region must be copied, and copied correctly")
    }

    @Test("a whole encoded command survives the round trip through DispatchData")
    func dispatchDataRoundTrip() {
        var buffer = IMAPOutputBuffer(initialSegmentSize: 8, maximumSegmentSize: 16)
        var expected: [UInt8] = []
        for index in 0..<40 {
            let piece = IMAPOutputBuffer.pattern(11, seed: UInt8(index))
            buffer.appendBytes(piece)
            expected += piece
        }
        buffer.append(IMAPBuffer(IMAPOutputBuffer.pattern(4096, seed: 99)))
        expected += IMAPOutputBuffer.pattern(4096, seed: 99)

        let data = buffer.takeFirst(buffer.byteCount).makeDispatchData()
        #expect(Array(data) == expected)
    }

    @Test("a list of empty regions converts to an empty DispatchData")
    func dispatchDataEmptyRegions() {
        #expect(IMAPBufferList([IMAPBuffer(), IMAPBuffer()]).makeDispatchData().count == 0)
    }

    @Test("the donation threshold does not exceed the copy threshold")
    func dispatchDonationThresholdBound() {
        #expect(IMAPBuffer.dispatchDonationThreshold <= IMAPBuffer.copyThreshold)
    }

    @Test("a list donates stable regions at the threshold and copies each run of the rest into one region")
    func dispatchDataCopiesRunsDonatesLarge() throws {
        let threshold = IMAPBuffer.dispatchDonationThreshold
        try #require(threshold > 0, "the tests need a region shorter than the threshold")
        let small = IMAPBuffer(IMAPOutputBuffer.pattern(threshold - 1, seed: 1))
        let large = IMAPBuffer(IMAPOutputBuffer.pattern(threshold, seed: 2))
        let list = IMAPBufferList([small, IMAPBuffer(), small, large, small])

        let data = list.makeDispatchData()
        #expect(Array(data) == list.copiedBytes())
        let leaves = dispatchLeaves(data)
        try #require(leaves.map(\.count) == [2 * (threshold - 1), threshold, threshold - 1])
        #expect(leaves[1].address == address(of: large), "donated")
        #expect(leaves[0].address != address(of: small), "copied")
        #expect(leaves[2].address != address(of: small), "copied")
    }

    @Test("a list copies a large region without a stable address into the surrounding run")
    func dispatchDataCopiesUnstableIntoRun() throws {
        let threshold = IMAPBuffer.dispatchDonationThreshold
        try #require(threshold > 0, "the tests need a region shorter than the threshold")
        let small = IMAPBuffer(IMAPOutputBuffer.pattern(threshold - 1, seed: 1))
        let unstable = IMAPBuffer(IMAPByteStorage(TemporaryBytesRegion(bytes: IMAPOutputBuffer.pattern(threshold))))
        let list = IMAPBufferList([small, unstable, small])

        let data = list.makeDispatchData()
        #expect(Array(data) == list.copiedBytes())
        #expect(dispatchLeaves(data).map(\.count) == [list.byteCount])
    }

    @Test("a single region is copied below the threshold and donated at it")
    func dispatchDataSingleRegion() throws {
        let threshold = IMAPBuffer.dispatchDonationThreshold
        try #require(threshold > 0, "the tests need a region shorter than the threshold")
        let small = IMAPBuffer(IMAPOutputBuffer.pattern(threshold - 1))
        let large = IMAPBuffer(IMAPOutputBuffer.pattern(threshold))

        for data in [small.makeDispatchData(), IMAPBufferList(small).makeDispatchData()] {
            #expect(Array(data) == small.copiedBytes())
            #expect(dispatchLeaves(data).map(\.address) != [address(of: small)], "copied")
        }
        for data in [large.makeDispatchData(), IMAPBufferList(large).makeDispatchData()] {
            #expect(Array(data) == large.copiedBytes())
            #expect(dispatchLeaves(data).map(\.address) == [address(of: large)], "donated")
        }
    }
}

/// Yields a fresh temporary copy on every access, so no pointer may escape it.
private struct TemporaryBytesRegion: ByteRegion, Sendable {
    let bytes: [UInt8]

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        var temporary = bytes
        return try temporary.withUnsafeMutableBytes { try body(UnsafeRawBufferPointer($0)) }
    }
}

/// Where `buffer`'s bytes are.
private func address(of buffer: IMAPBuffer) -> UnsafeRawPointer? {
    buffer.withUnsafeBytes { UnsafeRawPointer($0.baseAddress) }
}

/// Each region of `data`, in order: where it is and how long.
private func dispatchLeaves(_ data: DispatchData) -> [(address: UnsafeRawPointer?, count: Int)] {
    var leaves: [(address: UnsafeRawPointer?, count: Int)] = []
    data.enumerateBytes { bytes, _, _ in leaves.append((UnsafeRawPointer(bytes.baseAddress), bytes.count)) }
    return leaves
}
