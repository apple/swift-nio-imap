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

/// Returns one message per entry of `steps`, consuming that many bytes for it, then `nil`.
private struct ScriptedDecoder: IMAPMessageDecoder {
    var steps: [Int]

    mutating func decode(input: inout IMAPInputBuffer) throws -> Int? {
        guard let bytes = steps.first, input.count >= bytes else { return nil }
        steps.removeFirst()
        input.discardFirst(bytes)
        return bytes
    }
}

/// Wraps a real decoder and records the longest run of messages it returned without consuming.
private struct ProgressRecorder<Wrapped: IMAPMessageDecoder>: IMAPMessageDecoder {
    var wrapped: Wrapped
    var run = 0
    var longestRun = 0

    mutating func decode(input: inout IMAPInputBuffer) throws -> Wrapped.InboundOut? {
        let before = input.count
        guard let message = try wrapped.decode(input: &input) else { return nil }
        run = input.count < before ? 0 : run + 1
        longestRun = max(longestRun, run)
        return message
    }
}

private typealias Scripted = IMAPInputProcessor<ScriptedDecoder>
private let limit = Scripted.maximumMessagesWithoutProgress

/// How a test splits its input into reads. Internal, not private: test arguments need it.
enum ReadSplit: CaseIterable, Sendable {
    /// Everything in one read.
    case whole
    /// One read per line, the way `FramingParser` hands commands to the server's decoder.
    case perLine
    /// One byte per read, which the client side has to cope with: it has no framing.
    case perByte

    func reads(of text: String) -> [[UInt8]] {
        let bytes = Array(text.utf8)
        switch self {
        case .whole:
            return [bytes]
        case .perLine:
            return bytes.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
                .dropLast()
                .map { Array($0) + [UInt8(ascii: "\n")] }
        case .perByte:
            return bytes.map { [$0] }
        }
    }
}

/// Feeds `text` through a processor wrapping `decoder` and returns the longest run of messages
/// without progress.
private func longestRunWithoutProgress<D: IMAPMessageDecoder>(
    _ decoder: D,
    _ text: String,
    split: ReadSplit
) throws -> Int {
    let reads = split.reads(of: text)
    var recorder = ProgressRecorder(wrapped: decoder)
    var input = IMAPInputBuffer()
    for read in reads {
        input.append(ByteBuffer(bytes: read))
        while try recorder.decode(input: &input) != nil {}
    }
    #expect(input.count == 0, "everything should parse")
    return recorder.longestRun
}

@Suite("IMAPInputProcessor")
struct IMAPInputProcessorTests {
    @Test("a decoder that keeps returning messages without consuming is an error, not a hang")
    func noProgressThrows() {
        // Far more than the limit, but finite: without the guard this ends instead of hanging.
        let processor = Scripted(ScriptedDecoder(steps: Array(repeating: 0, count: 100 * limit)))
        var received = 0
        #expect {
            try processor.process(buffer: ByteBuffer(string: "x")) { _ in received += 1 }
        } throws: { error in
            (error as? IMAPDecoderError)?.parserError is NoForwardProgress
        }
        #expect(received == limit)
        #expect(processor.bufferedByteCount == 0)
    }

    @Test("up to the limit of messages without progress in a row is allowed")
    func messagesWithoutProgressUpToTheLimit() throws {
        let processor = Scripted(ScriptedDecoder(steps: Array(repeating: 0, count: limit)))
        var received = 0
        try processor.process(buffer: ByteBuffer(string: "x")) { _ in received += 1 }
        #expect(received == limit)
    }

    @Test("one past the limit in a row is an error")
    func onePastTheLimitThrows() {
        let processor = Scripted(ScriptedDecoder(steps: Array(repeating: 0, count: limit + 1)))
        #expect(throws: IMAPDecoderError.self) {
            try processor.process(buffer: ByteBuffer(string: "x")) { _ in }
        }
    }

    @Test("consuming a byte resets the count")
    func progressResetsTheCount() throws {
        // Runs of `limit` messages without progress, each followed by one that consumes a byte.
        let rounds = 3
        let steps = Array(repeating: Array(repeating: 0, count: limit) + [1], count: rounds).flatMap { $0 }
        let processor = Scripted(ScriptedDecoder(steps: steps))
        var received = 0
        try processor.process(buffer: ByteBuffer(repeating: 0, count: rounds)) { _ in received += 1 }
        #expect(received == steps.count)
    }

    /// The limit is only safe while the real parsers stay well under it. These are the longest chains
    /// of results without progress the state machines allow; a change that lengthens one fails here.
    @Test(
        "the command parser returns at most two results in a row without progress",
        arguments: [
            // MULTIAPPEND of empty messages: `messageBytes` (empty), then `endMessage`, per message.
            "A APPEND box {0+}\r\n {0+}\r\n ~{0+}\r\n\r\n",
            // CATENATE with empty TEXT parts: `catenateData(.bytes)` (empty), then `.end`, per part.
            "B APPEND box CATENATE (TEXT {0+}\r\n TEXT {0+}\r\n URL \"/a\" TEXT {0+}\r\n)\r\n",
        ],
        [ReadSplit.whole, .perLine]
    )
    func commandRun(text: String, split: ReadSplit) throws {
        #expect(try longestRunWithoutProgress(CommandDecoder(), text, split: split) == 2)
    }

    @Test(
        "the response parser returns at most one result in a row without progress",
        arguments: [
            // Every streamed attribute ends in `streamingEnd`, which consumes nothing.
            "* 1 FETCH (BODY[1] {0}\r\n BODY[2] {0}\r\n BODY[3] \"\" BINARY[4] ~{0}\r\n BODY[5] {0}\r\n)\r\n"
        ],
        ReadSplit.allCases
    )
    func responseRun(text: String, split: ReadSplit) throws {
        #expect(try longestRunWithoutProgress(ResponseDecoder(), text, split: split) == 1)
    }

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
