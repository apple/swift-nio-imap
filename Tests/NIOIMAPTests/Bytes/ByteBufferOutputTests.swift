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
import Testing

@_spi(NIOIMAPInternal) @testable import NIOIMAP
@_spi(NIOIMAPInternal) import NIOIMAPCore

extension ByteBufferOutput {
    /// Appends bytes, spelled for readability in tests.
    fileprivate mutating func appendBytes(_ bytes: [UInt8]) {
        bytes.withUnsafeBytes { append($0) }
    }

    /// A run of `count` distinct-ish bytes, so that a misplaced range shows up as wrong content.
    fileprivate static func pattern(_ count: Int, seed: UInt8 = 0) -> [UInt8] {
        (0..<count).map { UInt8(truncatingIfNeeded: $0 &* 7 &+ Int(seed)) }
    }
}

extension IMAPBufferList {
    fileprivate var string: String { String(decoding: copiedBytes(), as: UTF8.self) }
}

/// The address of a region's first byte — the only way to see whether bytes were shared or copied.
private func address(of region: IMAPBuffer) -> UInt {
    region.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
}

/// The address of a `ByteBuffer`'s first readable byte.
private func address(of buffer: ByteBuffer) -> UInt {
    buffer.withUnsafeReadableBytes { UInt(bitPattern: $0.baseAddress) }
}

@Suite("ByteBufferOutput")
struct ByteBufferOutputTests {

    // MARK: - Appending and byteCount

    @Test("a fresh buffer holds nothing and has allocated nothing")
    func fresh() {
        let buffer = ByteBufferOutput()
        #expect(buffer.byteCount == 0)
        #expect(buffer.pendingRegionCount == 0)
        #expect(buffer.writeBufferIdentity.capacity == 0, "creating a sink must not allocate")
    }

    @Test("appending nothing allocates nothing")
    func appendEmpty() {
        var buffer = ByteBufferOutput()
        buffer.appendBytes([])
        buffer.append(IMAPBuffer())
        #expect(buffer.byteCount == 0)
        #expect(buffer.pendingRegionCount == 0)
        #expect(buffer.writeBufferIdentity.capacity == 0)
    }

    @Test("consecutive writes coalesce into one region")
    func coalescing() {
        var buffer = ByteBufferOutput()
        buffer.append("A001 SELECT ")
        buffer.append("INBOX")
        buffer.append("\r\n")
        #expect(buffer.byteCount == 19)
        // A command written as many small writes is one region, hence one write to the network.
        #expect(buffer.pendingRegionCount == 1)
        #expect(buffer.takeFirst(19).string == "A001 SELECT INBOX\r\n")
    }

    @Test("byteCount counts pending bytes and goes down as they are handed out")
    func byteCountIsPending() {
        var buffer = ByteBufferOutput()
        buffer.append("0123456789")
        #expect(buffer.byteCount == 10)
        _ = buffer.takeFirst(4)
        #expect(buffer.byteCount == 6)
        buffer.append("abc")
        #expect(buffer.byteCount == 9)
        _ = buffer.takeFirst(9)
        #expect(buffer.byteCount == 0)
    }

    @Test("a write larger than the buffer grows it in one step")
    func largeWrite() {
        var buffer = ByteBufferOutput()
        let bytes = ByteBufferOutput.pattern(100_000)
        buffer.appendBytes(bytes)
        #expect(buffer.pendingRegionCount == 1)
        #expect(buffer.takeFirst(100_000).copiedBytes() == bytes)
    }

    @Test("appending a string with no contiguous UTF-8 still appends its bytes")
    func appendForeignString() {
        var buffer = ByteBufferOutput()
        let name = "Ünïcødé Mailbox 📬"
        let written = buffer.append(name)
        #expect(written == name.utf8.count)
        #expect(buffer.takeFirst(buffer.byteCount).copiedBytes() == Array(name.utf8))
    }

    // MARK: - Handing out

    @Test("a handed-out region is a slice of the buffer it was written into, not a copy")
    func handOutIsZeroCopy() {
        var buffer = ByteBufferOutput()
        buffer.append("A001 NOOP\r\n")
        let written = buffer.writeBufferIdentity.address

        let chunk = buffer.takeFirst(buffer.byteCount)
        #expect(chunk.regionCount == 1)
        #expect(address(of: chunk.regions[0]) == written, "the chunk should point at the encoded bytes")

        // ...and recovering a `ByteBuffer` from it shares that storage too, which is the whole point:
        // the bytes are copied once, on their way in, and never again.
        let recovered = chunk.regions[0].byteBuffer
        #expect(address(of: recovered) == written)
        #expect(String(buffer: recovered) == "A001 NOOP\r\n")
    }

    @Test("takeFirst splits the pending bytes and the remainder is still correct")
    func takeFirstSplits() {
        var buffer = ByteBufferOutput()
        buffer.append("HELLO WORLD")

        let first = buffer.takeFirst(5)
        #expect(first.string == "HELLO")
        #expect(buffer.byteCount == 6)

        let second = buffer.takeFirst(6)
        #expect(second.string == " WORLD")
        #expect(buffer.byteCount == 0)
        #expect(first.string == "HELLO", "the first chunk must not have moved underneath")
    }

    @Test("takeFirst of nothing is an empty list, and does not touch what is pending")
    func takeFirstZero() {
        var buffer = ByteBufferOutput()
        buffer.append("XYZ")
        let chunk = buffer.takeFirst(0)
        #expect(chunk.byteCount == 0)
        #expect(chunk.regionCount == 0)
        #expect(buffer.byteCount == 3)
    }

    @Test("bytes already handed out do not change as encoding continues")
    func handedOutBytesAreImmutable() {
        var buffer = ByteBufferOutput()
        buffer.append("A001 APPEND ")
        let chunk = buffer.takeFirst(buffer.byteCount)
        #expect(chunk.string == "A001 APPEND ")

        buffer.append("INBOX {3}\r\n")
        buffer.append("abc")
        #expect(buffer.takeFirst(buffer.byteCount).string == "INBOX {3}\r\nabc")

        #expect(chunk.string == "A001 APPEND ")
    }

    @Test("the synchronizing-literal shape: hand out a prefix, keep writing, hand out the rest")
    func synchronizingLiteralShape() {
        var buffer = ByteBufferOutput()
        buffer.append("A001 LOGIN {4}\r\n")
        buffer.append("user")  // written before the first chunk goes out, and handed out after it
        let first = buffer.takeFirst(16)
        #expect(first.string == "A001 LOGIN {4}\r\n")
        #expect(buffer.byteCount == 4)

        buffer.append(" {4}\r\n")
        let second = buffer.takeFirst(buffer.byteCount)
        #expect(second.string == "user {4}\r\n")
        #expect(first.string == "A001 LOGIN {4}\r\n")
        // The bytes carried over joined the ones written after them, rather than staying a region of
        // their own.
        #expect(second.regionCount == 1)
    }

    @Test("a chunk keeps its bytes alive after the sink has gone away")
    func chunkOutlivesTheSink() {
        var chunk = IMAPBufferList()
        do {
            var buffer = ByteBufferOutput()
            buffer.append("kept alive")
            chunk = buffer.takeFirst(buffer.byteCount)
            buffer.removeAll()
        }
        #expect(chunk.string == "kept alive")
    }

    // MARK: - Recycling

    @Test("the buffer is reused once the bytes handed out of it have been released")
    func reusesTheBufferWhenNothingRefersToIt() {
        var buffer = ByteBufferOutput()
        buffer.append("first response\r\n")
        let first = buffer.writeBufferIdentity.address
        // Take the chunk and drop it immediately, as a channel does once the write has completed.
        #expect(buffer.takeFirst(buffer.byteCount).byteCount == 16)
        buffer.removeAll()

        buffer.append("second response\r\n")
        #expect(buffer.writeBufferIdentity.address == first, "a drained buffer should be written again")
        #expect(buffer.takeFirst(buffer.byteCount).string == "second response\r\n")
    }

    @Test("a buffer whose bytes are still in flight is not written into again")
    func doesNotWriteIntoBytesStillInFlight() {
        var buffer = ByteBufferOutput()
        buffer.append("in flight\r\n")
        let first = buffer.writeBufferIdentity.address
        let chunk = buffer.takeFirst(buffer.byteCount)

        buffer.append("next\r\n")
        #expect(buffer.writeBufferIdentity.address != first)
        #expect(chunk.string == "in flight\r\n", "the bytes in flight must be untouched")
        #expect(buffer.takeFirst(buffer.byteCount).string == "next\r\n")
    }

    @Test("a buffer grown for one large message is not held for the rest of the connection")
    func dropsAnOversizedBuffer() {
        var buffer = ByteBufferOutput()
        buffer.appendBytes(ByteBufferOutput.pattern(4 * 1_024 * 1_024))
        #expect(buffer.writeBufferIdentity.capacity >= 4 * 1_024 * 1_024)
        _ = buffer.takeFirst(buffer.byteCount)

        #expect(
            buffer.writeBufferIdentity.capacity <= ByteBufferOutput.maximumRetainedCapacity,
            "megabytes should not be retained because one message needed them"
        )
    }

    @Test("the buffer size learned from one message is kept for the next")
    func keepsLearnedCapacity() {
        var buffer = ByteBufferOutput()
        buffer.appendBytes(ByteBufferOutput.pattern(8_000))
        _ = buffer.takeFirst(buffer.byteCount)
        buffer.removeAll()

        buffer.appendBytes([1])
        #expect(
            buffer.writeBufferIdentity.capacity >= 8_000,
            "re-climbing the growth curve inside every message would reallocate repeatedly"
        )
    }

    // MARK: - Foreign regions

    @Test("a region at or above the copy threshold is kept by reference, not copied")
    func foreignRegionRetained() {
        var buffer = ByteBufferOutput()
        let payload = IMAPBuffer(ByteBufferOutput.pattern(IMAPBuffer.copyThreshold))
        buffer.append(payload)

        #expect(buffer.byteCount == IMAPBuffer.copyThreshold)
        #expect(buffer.pendingRegionCount == 1)
        #expect(buffer.pendingRegionIsForeign(0))
        #expect(buffer.writeBufferIdentity.capacity == 0, "a by-reference append must not allocate")

        let chunk = buffer.takeFirst(buffer.byteCount)
        #expect(chunk.regionCount == 1)
        #expect(address(of: chunk.regions[0]) == address(of: payload), "the payload must not be copied")
    }

    @Test("a region below the copy threshold is copied into the buffer")
    func foreignRegionCopied() {
        var buffer = ByteBufferOutput()
        let payload = IMAPBuffer(ByteBufferOutput.pattern(IMAPBuffer.copyThreshold - 1))
        buffer.append(payload)

        #expect(buffer.byteCount == IMAPBuffer.copyThreshold - 1)
        #expect(buffer.pendingRegionCount == 1)
        #expect(buffer.pendingRegionIsForeign(0) == false)
        #expect(buffer.takeFirst(buffer.byteCount).copiedBytes() == payload.copiedBytes())
    }

    @Test("a short region copied in coalesces with the writes around it")
    func shortForeignRegionCoalesces() {
        var buffer = ByteBufferOutput()
        buffer.append("<")
        buffer.append(IMAPBuffer("short"))
        buffer.append(">")
        #expect(buffer.pendingRegionCount == 1)
        #expect(buffer.takeFirst(buffer.byteCount).string == "<short>")
    }

    @Test("bytes written around a by-reference region stay in one buffer, in order")
    func writesAroundAForeignRegion() {
        var buffer = ByteBufferOutput()
        let before = ByteBufferOutput.pattern(40, seed: 1)
        let payload = ByteBufferOutput.pattern(2048, seed: 2)
        let after = ByteBufferOutput.pattern(30, seed: 3)
        buffer.appendBytes(before)
        buffer.append(IMAPBuffer(payload))
        buffer.appendBytes(after)

        #expect(buffer.pendingRegionCount == 3)
        #expect(buffer.pendingRegionIsForeign(1))

        let chunk = buffer.takeFirst(buffer.byteCount)
        #expect(chunk.regionCount == 3)
        #expect(chunk.copiedBytes() == before + payload + after)
        // The bytes written after the payload went into the same buffer as the ones before it — one
        // allocation for the command, not one per payload.
        #expect(address(of: chunk.regions[2]) == address(of: chunk.regions[0]) + 40)
    }

    @Test("a chunk of an APPEND payload converts to ByteBuffers without copying the payload")
    func appendPayloadSurvivesAsByteBuffers() {
        var buffer = ByteBufferOutput()
        let payload = ByteBuffer(repeating: UInt8(ascii: "x"), count: 1_024 * 1_024)
        buffer.append("A1 APPEND \"INBOX\" {1048576}\r\n")
        buffer.append(IMAPBuffer(payload))
        buffer.append("\r\n")

        let chunk = buffer.takeFirst(buffer.byteCount)
        #expect(chunk.regionCount == 3)

        let buffers = chunk.makeByteBuffers()
        #expect(buffers.count == 3)
        #expect(address(of: buffers[1]) == address(of: payload), "the payload must reach the network uncopied")
        #expect(buffers[1].readableBytes == 1_024 * 1_024)
        #expect(String(buffer: buffers[0]) == "A1 APPEND \"INBOX\" {1048576}\r\n")
        #expect(String(buffer: buffers[2]) == "\r\n")
    }

    @Test("splitting a by-reference region does not copy it")
    func splitForeignRegion() {
        var buffer = ByteBufferOutput()
        let payload = ByteBufferOutput.pattern(4096)
        buffer.append(IMAPBuffer(payload))

        let first = buffer.takeFirst(1000)
        #expect(first.copiedBytes() == Array(payload[0..<1000]))
        #expect(buffer.byteCount == 3096)
        #expect(buffer.pendingRegionIsForeign(0), "the remainder should stay by-reference")
        #expect(buffer.takeFirst(3096).copiedBytes() == Array(payload[1000...]))
    }

    // MARK: - removeAll

    @Test("removeAll drops what is pending and the buffer is reusable")
    func removeAll() {
        var buffer = ByteBufferOutput()
        buffer.append("first")
        buffer.append(IMAPBuffer(ByteBufferOutput.pattern(2048)))
        buffer.removeAll()
        #expect(buffer.byteCount == 0)
        #expect(buffer.pendingRegionCount == 0)

        buffer.append("second")
        #expect(buffer.takeFirst(buffer.byteCount).string == "second")
    }

    @Test("removeAll leaves bytes already handed out alone")
    func removeAllKeepsHandedOutBytesIntact() {
        var buffer = ByteBufferOutput()
        buffer.append("first message")
        let first = buffer.takeFirst(buffer.byteCount)
        buffer.removeAll()

        buffer.append("second message")
        let second = buffer.takeFirst(buffer.byteCount)

        #expect(first.string == "first message")
        #expect(second.string == "second message")
    }

    // MARK: - Value semantics

    @Test("writing to a copy leaves the original alone, and neither corrupts the other")
    func copyOnWrite() {
        var original = ByteBufferOutput()
        original.append("SHARED ")

        var copy = original
        copy.append("copy")
        original.append("original")

        #expect(original.takeFirst(original.byteCount).string == "SHARED original")
        #expect(copy.takeFirst(copy.byteCount).string == "SHARED copy")
    }

    @Test("a copy taken before a hand-out still has all of its bytes")
    func copyIsUnaffectedByHandOut() {
        var original = ByteBufferOutput()
        original.append("A001 NOOP\r\n")
        var copy = original

        _ = original.takeFirst(original.byteCount)
        #expect(original.byteCount == 0)
        #expect(copy.byteCount == 11)
        #expect(copy.takeFirst(11).string == "A001 NOOP\r\n")
    }

    @Test("removeAll on a copy leaves the original alone")
    func removeAllIsPerCopy() {
        var original = ByteBufferOutput()
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
        var buffer = ByteBufferOutput()
        buffer.append("ABCD")
        buffer.append(IMAPBuffer(ByteBufferOutput.pattern(2048, seed: 9)))
        buffer.append("EFG")

        let counts = buffer.withPendingRegions { regions -> [Int] in
            var counts: [Int] = []
            for index in regions.indices {
                counts.append(regions[index].count)
            }
            return counts
        }
        #expect(counts == [4, 2048, 3])
        #expect(buffer.byteCount == 2055, "reading back must not consume")

        let bytes = buffer.withPendingRegions { regions -> [UInt8] in
            var all: [UInt8] = []
            for index in regions.indices {
                all += regions[index].copiedBytes()
            }
            return all
        }
        #expect(bytes == Array("ABCD".utf8) + ByteBufferOutput.pattern(2048, seed: 9) + Array("EFG".utf8))

        // And the buffer still works afterwards, even though the read-back briefly shared its storage.
        buffer.append("HI")
        #expect(buffer.takeFirst(buffer.byteCount).byteCount == 2057)
    }

    @Test("withPendingRegions on an empty buffer yields nothing")
    func withPendingRegionsEmpty() {
        let buffer = ByteBufferOutput()
        #expect(buffer.withPendingRegions { $0.count } == 0)
    }

    @Test("debugDescription reports what is pending")
    func debugDescription() {
        var buffer = ByteBufferOutput()
        #expect(buffer.debugDescription == "ByteBufferOutput(0 bytes pending in 0 regions)")
        buffer.append("abc")
        #expect(buffer.debugDescription == "ByteBufferOutput(3 bytes pending in 1 region)")
    }

    @Test("a chunk from the sink converts to a DispatchData with the right bytes")
    func dispatchData() {
        var buffer = ByteBufferOutput()
        buffer.append("A001 NOOP\r\n")
        let data = buffer.takeFirst(buffer.byteCount).makeDispatchData()
        #expect(Array(data) == Array("A001 NOOP\r\n".utf8))
    }
}
