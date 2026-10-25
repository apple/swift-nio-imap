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

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

extension OutputSegment {
    @discardableResult
    fileprivate func append(_ string: String) -> Int {
        Array(string.utf8).withUnsafeBytes { append($0) }
    }

    fileprivate var writtenBytes: [UInt8] {
        Array(UnsafeRawBufferPointer(rebasing: UnsafeRawBufferPointer(storage)[0..<used]))
    }
}

@Suite("OutputSegment")
struct OutputSegmentTests {
    @Test("a fresh segment has capacity and nothing written")
    func fresh() {
        let segment = OutputSegment(capacity: 64)
        #expect(segment.capacity == 64)
        #expect(segment.used == 0)
        #expect(segment.availableCapacity == 64)
    }

    @Test("appending advances used and leaves the capacity alone")
    func append() {
        let segment = OutputSegment(capacity: 64)
        #expect(segment.append("hello") == 5)
        #expect(segment.used == 5)
        #expect(segment.availableCapacity == 59)
        #expect(segment.capacity == 64)
        #expect(segment.writtenBytes == Array("hello".utf8))

        #expect(segment.append(" world") == 6)
        #expect(segment.used == 11)
        #expect(segment.writtenBytes == Array("hello world".utf8))
    }

    @Test("a write that does not fit is short, and does not move what is already there")
    func shortWrite() {
        let segment = OutputSegment(capacity: 8)
        segment.append("abcd")
        #expect(segment.append("efghijkl") == 4)
        #expect(segment.used == 8)
        #expect(segment.availableCapacity == 0)
        #expect(segment.writtenBytes == Array("abcdefgh".utf8))

        // A full segment accepts nothing more, and reports so rather than growing.
        #expect(segment.append("z") == 0)
        #expect(segment.used == 8)
        #expect(segment.capacity == 8)
    }

    @Test("appending nothing is a no-op")
    func emptyWrite() {
        let segment = OutputSegment(capacity: 8)
        #expect(segment.append("") == 0)
        #expect(segment.used == 0)
    }
}

/// A handed-out region of a segment: an `IMAPBuffer` holding the segment and a *fixed* range of it.
///
/// The range is what makes this sound. An `IMAPBuffer` promises that its bytes never change, and a live
/// output segment cannot promise that about itself — its `used` moves, and the memory above `used` has
/// never been written. Fixing the range at hand-out is what reconciles the two, and it is why a chunk
/// can be handed out, even to another thread, while encoding continues.
@Suite("A handed-out segment region")
struct SegmentRegionTests {
    @Test("a region exposes exactly the bytes it was handed out with")
    func exposesThePinnedExtent() {
        let segment = OutputSegment(capacity: 64)
        segment.append("hello")
        let region = IMAPBuffer(segment: segment, range: 0..<segment.used)
        #expect(region.withUnsafeBytes { Array($0) } == Array("hello".utf8))
    }

    @Test("a region never yields bytes beyond its range, even as the segment grows")
    func neverYieldsAboveTheRange() {
        let segment = OutputSegment(capacity: 64)
        segment.append("hello")
        let region = IMAPBuffer(segment: segment, range: 0..<segment.used)

        // The writer carries on into the same segment, above the range.
        segment.append(" world")
        #expect(segment.used == 11)

        // The handed-out region is unmoved and unchanged. This is the property that lets a chunk be
        // handed out — even to another thread — while encoding continues.
        #expect(region.count == 5)
        #expect(string(region) == "hello")
        #expect(region.withUnsafeBytes { $0.count } == 5)
    }

    @Test("a region can cover less than has been written")
    func partialRange() {
        let segment = OutputSegment(capacity: 64)
        segment.append("hello world")
        #expect(IMAPBuffer(segment: segment, range: 0..<5).withUnsafeBytes { Array($0) } == Array("hello".utf8))
        #expect(IMAPBuffer(segment: segment, range: 6..<11).withUnsafeBytes { Array($0) } == Array("world".utf8))
    }

    @Test("an empty range yields no bytes")
    func emptyRange() {
        let segment = OutputSegment(capacity: 64)
        #expect(IMAPBuffer(segment: segment, range: 0..<0).withUnsafeBytes { $0.count } == 0)
    }

    @Test("narrowing a region cannot widen it back out")
    func narrowing() {
        let segment = OutputSegment(capacity: 64)
        segment.append("hello world")
        let region = IMAPBuffer(segment: segment, range: 0..<5)
        #expect(string(region.dropFirst(2)) == "llo")
        #expect(string(region.prefix(2)) == "he")
        // `prefix` and `dropFirst` clamp to what the region already exposes, so neither can reach the
        // bytes written after it.
        #expect(region.prefix(99).count == 5)
        #expect(region.dropFirst(99).count == 0)
    }

    @Test("a region keeps its segment alive after the writer has let go")
    func keepsTheSegmentAlive() {
        // If the segment were freed with the last direct reference, reading here would be a
        // use-after-free — which the address sanitizer would catch, and which correct bytes rule out.
        func handOut() -> IMAPBuffer {
            let segment = OutputSegment(capacity: 4096)
            segment.append("A1 OK NOOP completed\r\n")
            return IMAPBuffer(segment: segment, range: 0..<segment.used)
        }

        let region = handOut()
        #expect(string(region) == "A1 OK NOOP completed\r\n")
    }

    @Test("a handed-out region costs no allocation of its own")
    func noBoxPerRegion() {
        // The whole reason this is a case of `IMAPBuffer.Storage` rather than an `IMAPByteStorage`
        // wrapping the segment: a box per handed-out region is a class allocation per message.
        #expect(MemoryLayout<IMAPBuffer>.stride <= 4 * MemoryLayout<Int>.stride)
    }

    @Test("two non-adjacent ranges of one segment become two independent regions")
    func oneSegmentBacksSeveralRegions() {
        // The shape a chunk takes when a caller's payload is appended by reference between two runs
        // of encoder-written bytes: the deque holds .owned(seg, 0..<5), .foreign(…), .owned(seg, 5..<10).
        let segment = OutputSegment(capacity: 64)
        segment.append("HELLO")
        segment.append("WORLD")

        let first = IMAPBuffer(segment: segment, range: 0..<5)
        let second = IMAPBuffer(segment: segment, range: 5..<10)
        let list = IMAPBufferList([first, imapBuffer(" - "), second])

        #expect(list.regionCount == 3)
        #expect(list.byteCount == 13)
        #expect(String(decoding: list.copiedBytes(), as: UTF8.self) == "HELLO - WORLD")
    }
}
