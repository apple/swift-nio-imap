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
import NIO
import NIOIMAP
import NIOIMAPCore
import Testing

/// The address of a `ByteBuffer`'s first readable byte — the only way to observe from the outside
/// whether a conversion shared storage or copied it.
private func readableAddress(_ buffer: ByteBuffer) -> UnsafeRawPointer? {
    buffer.withUnsafeReadableBytes { UnsafeRawPointer($0.baseAddress) }
}

@Suite("IMAPBuffer and ByteBuffer")
struct IMAPBufferByteBufferTests {
    @Test("a ByteBuffer conforms to ByteRegion over its readable bytes")
    func byteBufferIsAByteRegion() {
        var buffer = ByteBuffer(string: "discardedHELLO")
        buffer.moveReaderIndex(forwardBy: 9)
        #expect(buffer.withUnsafeBytes { Array($0) } == Array("HELLO".utf8))
    }

    @Test("wrapping a ByteBuffer does not copy it")
    func wrappingDoesNotCopy() {
        let buffer = ByteBuffer(string: "A1 OK NOOP completed\r\n")
        let wrapped = IMAPBuffer(buffer)
        #expect(wrapped.count == buffer.readableBytes)
        #expect(wrapped.withUnsafeBytes { UnsafeRawPointer($0.baseAddress) } == readableAddress(buffer))
    }

    @Test("wrapping exposes only the readable bytes")
    func wrappingRespectsTheReaderIndex() {
        var buffer = ByteBuffer(string: "discardedHELLO")
        buffer.moveReaderIndex(forwardBy: 9)
        let wrapped = IMAPBuffer(buffer)
        #expect(wrapped.count == 5)
        #expect(String(decoding: wrapped.copiedBytes(), as: UTF8.self) == "HELLO")
    }

    @Test("round-tripping a ByteBuffer shares storage rather than copying")
    func roundTripIsZeroCopy() {
        let original = ByteBuffer(string: "A1 OK NOOP completed\r\n")
        let round = IMAPBuffer(original).byteBuffer
        #expect(round == original)
        #expect(readableAddress(round) == readableAddress(original))
    }

    @Test("a sub-range of a wrapped ByteBuffer round-trips to the right slice, still without copying")
    func subRangeRoundTrip() {
        var original = ByteBuffer(string: "discardedHELLOWORLDtrailing")
        original.moveReaderIndex(forwardBy: 9)

        let slice = IMAPBuffer(original).dropFirst(5)
        #expect(String(decoding: slice.copiedBytes(), as: UTF8.self) == "WORLDtrailing")

        let round = slice.byteBuffer
        #expect(String(buffer: round) == "WORLDtrailing")
        #expect(readableAddress(round) == readableAddress(original)?.advanced(by: 5))
    }

    @Test("an IMAPBuffer over a ByteBuffer converts to DispatchData by donation, not copy")
    func dispatchDataDonatesByteBuffer() {
        // Long enough to be donated rather than copied.
        let world = String(repeating: "WORLD", count: IMAPBuffer.dispatchDonationThreshold)
        var original = ByteBuffer(string: "discardedHELLO" + world)
        original.moveReaderIndex(forwardBy: 9)

        let data = IMAPBuffer(original).dropFirst(5).makeDispatchData()
        var leaf: UnsafeRawPointer?
        data.enumerateBytes { bytes, _, _ in leaf = UnsafeRawPointer(bytes.baseAddress) }
        #expect(Array(data) == Array(world.utf8))
        #expect(leaf == readableAddress(original)?.advanced(by: 5))
    }

    @Test("a large ByteBuffer appended to an IMAPInputBuffer is retained, not copied")
    func inputBufferRetainsByteBuffer() {
        // Well above `IMAPBuffer.copyThreshold` (1 KiB).
        let largeReadByteCount = 4 * 1_024
        let read = ByteBuffer(repeating: UInt8(ascii: "r"), count: largeReadByteCount)
        var input = IMAPInputBuffer()
        input.append(read)
        #expect(input.byteRegions[0].withUnsafeBytes { UnsafeRawPointer($0.baseAddress) } == readableAddress(read))
    }

    @Test("an owned buffer converts to a ByteBuffer by copying, with the right bytes")
    func ownedBytesCopyOnConversion() {
        let owned = IMAPBuffer(Array("hello world".utf8))
        let converted = owned.byteBuffer
        #expect(String(buffer: converted) == "hello world")
        #expect(owned.withUnsafeBytes { UnsafeRawPointer($0.baseAddress) } != readableAddress(converted))
    }

    @Test("an empty buffer converts to an empty ByteBuffer")
    func emptyConversion() {
        #expect(IMAPBuffer().byteBuffer.readableBytes == 0)
        #expect(IMAPBuffer(ByteBuffer()).count == 0)
    }

    @Test("makeByteBuffers gives one ByteBuffer per region, in order")
    func makeByteBuffers() {
        let backing = ByteBuffer(string: "HELLOWORLD")
        let wrapped = IMAPBuffer(backing)

        let list = IMAPBufferList([
            wrapped.dropFirst(5),
            IMAPBuffer(Array(" - ".utf8)),
            IMAPBuffer(IMAPByteStorage(backing), 0..<5),
        ])

        let buffers = list.makeByteBuffers()
        #expect(buffers.count == 3)
        #expect(buffers.map { String(buffer: $0) } == ["WORLD", " - ", "HELLO"])
        #expect(buffers.reduce(0) { $0 + $1.readableBytes } == list.byteCount)

        // The two ByteBuffer-backed regions did not copy; the owned one did.
        #expect(readableAddress(buffers[0]) == readableAddress(backing)?.advanced(by: 5))
        #expect(readableAddress(buffers[2]) == readableAddress(backing))
    }

    @Test("makeByteBuffers on an empty list gives no buffers")
    func makeByteBuffersEmpty() {
        #expect(IMAPBufferList().makeByteBuffers().isEmpty)
    }

    // MARK: - Outbound buffers

    @Test("a single region becomes one buffer, without copying")
    func outboundSingleRegion() {
        let backing = ByteBuffer(string: "A1 OK NOOP completed\r\n")
        let buffers = IMAPBufferList(IMAPBuffer(backing)).makeOutboundBuffers()
        #expect(buffers.count == 1)
        #expect(readableAddress(buffers[0]) == readableAddress(backing))
    }

    @Test("small regions are coalesced into one buffer rather than written separately")
    func outboundCoalescesSmallRegions() {
        // Two regions because the encoder's segments happened to end there, which is not a reason to
        // turn one message into two writes.
        let list = IMAPBufferList([IMAPBuffer("* 1 FETCH ("), IMAPBuffer("UID 42)\r\n")])
        let buffers = list.makeOutboundBuffers()
        #expect(buffers.count == 1)
        #expect(String(buffer: buffers[0]) == "* 1 FETCH (UID 42)\r\n")
    }

    @Test("a large region is written on its own, and is not copied")
    func outboundKeepsLargeRegionsSeparate() {
        let payload = ByteBuffer(repeating: UInt8(ascii: "x"), count: 4096)
        let list = IMAPBufferList([
            IMAPBuffer("A1 APPEND \"INBOX\" {4096}\r\n"),
            IMAPBuffer(payload),
            IMAPBuffer("\r\n"),
        ])

        let buffers = list.makeOutboundBuffers()
        #expect(buffers.count == 3)
        #expect(buffers.map(\.readableBytes) == [26, 4096, 2])
        #expect(readableAddress(buffers[1]) == readableAddress(payload), "a payload must not be copied")
        #expect(buffers.reduce(0) { $0 + $1.readableBytes } == list.byteCount)
    }

    @Test("small regions on either side of a large one are coalesced within their runs")
    func outboundCoalescesRunsAroundLargeRegions() {
        let payload = ByteBuffer(repeating: UInt8(ascii: "y"), count: 2048)
        let list = IMAPBufferList([
            IMAPBuffer("one"),
            IMAPBuffer("two"),
            IMAPBuffer(payload),
            IMAPBuffer("three"),
            IMAPBuffer("four"),
        ])

        let buffers = list.makeOutboundBuffers()
        #expect(buffers.map { String(buffer: $0) } == ["onetwo", String(repeating: "y", count: 2048), "threefour"])
        #expect(readableAddress(buffers[1]) == readableAddress(payload))
    }

    @Test("an empty list produces no writes")
    func outboundEmpty() {
        #expect(IMAPBufferList().makeOutboundBuffers().isEmpty)
    }
}
