//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
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

@testable import NIOIMAP
@_spi(NIOIMAPInternal) import NIOIMAPCore

private struct DecodeFailure: Error {}

/// Throws on every call and counts the calls.
private final class FailingDecoder: IMAPMessageDecoder {
    var calls = 0

    func decode(input: inout IMAPInputBuffer) throws -> Int? {
        calls += 1
        throw DecodeFailure()
    }
}

/// Never produces a message, and records the most regions it has seen buffered.
private final class RegionCountingDecoder: IMAPMessageDecoder {
    var mostRegions = 0

    func decode(input: inout IMAPInputBuffer) throws -> Int? {
        mostRegions = max(mostRegions, input.regionCount)
        return nil
    }
}

/// Never produces a message, so every byte stays buffered. Counts the calls.
private final class StarvingDecoder: IMAPMessageDecoder {
    var calls = 0

    func decode(input: inout IMAPInputBuffer) throws -> Int? {
        calls += 1
        return nil
    }
}

@Suite("IMAPInputProcessor")
struct IMAPInputProcessorTests {
    @Test("after a decoder error, every later read fails with it and nothing is decoded or buffered")
    func decoderErrorIsSticky() {
        let decoder = FailingDecoder()
        let processor = IMAPInputProcessor(decoder)
        #expect(throws: DecodeFailure.self) {
            try processor.process(buffer: ByteBuffer(string: "bad\r\n")) { _ in }
        }
        for _ in 0..<3 {
            #expect(throws: DecodeFailure.self) {
                try processor.process(buffer: ByteBuffer(repeating: 0, count: 1024)) { _ in }
            }
        }
        #expect(decoder.calls == 1)
        #expect(processor.bufferedByteCount == 0)
    }

    @Test("exceeding the buffer limit is sticky too, and drops what was buffered")
    func payloadTooLargeIsSticky() {
        let maximumBufferSize = 4
        let decoder = StarvingDecoder()
        let processor = IMAPInputProcessor(decoder, maximumBufferSize: maximumBufferSize)
        #expect(throws: ByteToMessageDecoderError.PayloadTooLargeError.self) {
            try processor.process(buffer: ByteBuffer(repeating: 0, count: maximumBufferSize + 1)) { _ in }
        }
        let callsAfterFailure = decoder.calls
        #expect(throws: ByteToMessageDecoderError.PayloadTooLargeError.self) {
            try processor.process(buffer: ByteBuffer(repeating: 0, count: 1)) { _ in }
        }
        #expect(decoder.calls == callsAfterFailure)
        #expect(processor.bufferedByteCount == 0)
    }

    @Test("an error thrown by the receiver is not sticky")
    func receiverErrorIsNotSticky() throws {
        let processor = IMAPInputProcessor(ResponseDecoder())
        #expect(throws: DecodeFailure.self) {
            try processor.process(buffer: ByteBuffer(string: "* 1 EXISTS\r\n")) { _ in throw DecodeFailure() }
        }
        var received = 0
        try processor.process(buffer: ByteBuffer(string: "* 2 EXISTS\r\n")) { _ in received += 1 }
        #expect(received == 1)
    }

    @Test("one-byte reads are copied into shared tails, not retained one region each")
    func oneByteReadsAreBounded() throws {
        // A peer sending a byte per read must not pin a receive buffer, an object and a region per byte.
        let readCount = 4096
        let tailCapacity = IMAPBuffer.copyThreshold
        let decoder = RegionCountingDecoder()
        let processor = IMAPInputProcessor(decoder)
        for _ in 0..<readCount {
            try processor.process(buffer: ByteBuffer(string: "x")) { _ in }
        }
        #expect(processor.bufferedByteCount == readCount)
        #expect(decoder.mostRegions == (readCount + tailCapacity - 1) / tailCapacity)
    }

    @Test("a small read's ByteBuffer is not retained")
    func smallReadIsNotRetained() throws {
        let processor = IMAPInputProcessor(RegionCountingDecoder())
        var read = ByteBuffer(string: "x")
        let before = read.withUnsafeReadableBytes { UInt(bitPattern: $0.baseAddress) }
        try processor.process(buffer: read) { _ in }
        // Writing to a buffer whose storage is shared copies it first; unshared, it writes in place.
        read.setString("y", at: read.readerIndex)
        #expect(read.withUnsafeReadableBytes { UInt(bitPattern: $0.baseAddress) } == before)
    }
}
