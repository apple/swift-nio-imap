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

#if IMAP_LEGACY_BUFFERS

import NIO
import NIOIMAP

// Builds against `main`, whose `CommandEncodeBuffer.buffer` and `EncodeBuffer` (used to drain chunks) are SPI.
@_spi(NIOIMAPInternal) import NIOIMAPCore

// The "before" half: the same client, written against the library as it was on `main`, where the
// parser reads a `ByteBuffer` and the encoder writes one. Compiled only when `IMAP_IMPL=main` points
// the package's path dependency at a worktree of that library.
//
// The best client that API allows, by the same three choices as `DispatchClient+Legacy.swift`: capacity
// reserved once, amortised compaction, and each payload copied out of the accumulator instead of
// sliced from it. What remains unavoidable is that every received byte is copied into the accumulator,
// and every payload byte once more out of it. There is no Dispatch conversion on either side of this
// client, so unlike `DispatchClient` the write path hands the encoder's own `ByteBuffer` to the
// transport.
extension ByteBufferClient {
    /// How many bytes the accumulator reserves up front.
    ///
    /// Generous on purpose — a 64 KB read fits, and so does a body-structure message several times
    /// over — so that this side is not charged for growth it could have avoided.
    private static var accumulatorCapacity: Int { Size.accumulatorCapacity }

    /// Receives `reads` and parses everything in them.
    ///
    /// - Parameters:
    ///   - reads: The input, one `ByteBuffer` per socket read.
    ///   - options: The parser options.
    ///   - sink: Called once per parsed event.
    /// - Returns: The number of events parsed.
    /// - Throws: Whatever `ResponseParser` throws; a malformed corpus fails the benchmark.
    @discardableResult
    public static func receiveResponses(
        _ reads: [ByteBuffer],
        options: ResponseParser.Options = ResponseParser.Options(),
        sink: (ResponseOrContinuationRequest) -> Void
    ) throws -> Int {
        var parser = ResponseParser(options: options)
        var accumulator = ByteBuffer()
        accumulator.reserveCapacity(accumulatorCapacity)
        var message: [ByteBuffer] = []
        var count = 0
        for var read in reads {
            // The copy this API forces: the parser consumes from one accumulating buffer, so every
            // received byte is moved into it.
            accumulator.writeBuffer(&read)
            while let event = try parser.parseResponseStream(buffer: &accumulator) {
                switch event {
                case .response(.fetch(.streamingBytes(let payload))):
                    // Copied out, not retained. See `DispatchClient+Legacy.swift`.
                    message.append(ByteBuffer(buffer: payload))
                case .response(.fetch(.finish)):
                    message.removeAll(keepingCapacity: true)
                default:
                    break
                }
                sink(event)
                count += 1
            }
            // Amortised compaction: move the remainder down only once the parsed prefix is worth more
            // than the move costs.
            if accumulator.readerIndex > accumulator.writerIndex / 2 {
                accumulator.discardReadBytes()
            }
        }
        precondition(accumulator.readableBytes == 0, "\(accumulator.readableBytes) bytes left unparsed")
        return count
    }

    /// Asserts that a payload parsed out of `reads` is a copy of the received bytes.
    ///
    /// The twin of the current implementation's check, asserting the opposite: on `main` a payload
    /// cannot be delivered by reference, so this side proves it is measuring the copy.
    ///
    /// - Parameter reads: A corpus containing at least one literal payload.
    public static func checkPayloadDelivery(_ reads: [ByteBuffer]) {
        let received = receivedRanges(reads)
        var payloads = 0
        var referenced = 0
        try! receiveResponses(reads, options: streamingOptions()) { event in
            guard case .response(.fetch(.streamingBytes(let payload))) = event else { return }
            payloads += 1
            let address = payload.withUnsafeReadableBytes { UInt(bitPattern: $0.baseAddress) }
            if received.contains(where: { $0.contains(address) }) {
                referenced += 1
            }
        }

        precondition(payloads > 0, "expected at least one payload")
        precondition(
            referenced == 0,
            "\(referenced) of \(payloads) payloads pointed into the received bytes, which this library "
                + "cannot do — the accumulator copy must have been skipped"
        )
    }

    /// Encodes `commands` and writes each chunk to a `ByteBuffer` transport.
    ///
    /// - Parameters:
    ///   - commands: The commands to send, in order.
    ///   - options: The encoding options.
    ///   - write: Called with each chunk, in order, as a channel write would be.
    /// - Returns: The number of bytes handed over.
    @discardableResult
    public static func sendCommands(
        _ commands: [TaggedCommand],
        options: CommandEncodingOptions = .rfc3501,
        write: (ByteBuffer) -> Void
    ) -> Int {
        var byteCount = 0
        for command in commands {
            var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: options, loggingMode: false)
            encodeBuffer.writeCommand(command)
            byteCount += drain(&encodeBuffer, write: write)
        }
        return byteCount
    }

    /// Encodes `responses` through one long-lived buffer, writing each one to a `ByteBuffer` transport.
    ///
    /// - Parameters:
    ///   - responses: The responses to send, in order.
    ///   - write: Called with each response's bytes, in order.
    /// - Returns: The number of bytes handed over.
    @discardableResult
    public static func sendResponses(
        _ responses: [Response],
        write: (ByteBuffer) -> Void
    ) -> Int {
        var encodeBuffer = ResponseEncodeBuffer(
            buffer: ByteBuffer(),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        var byteCount = 0
        for response in responses {
            encodeBuffer.writeResponse(response)
            let bytes = encodeBuffer.readBytes()
            byteCount += bytes.readableBytes
            write(bytes)
        }
        return byteCount
    }

    /// The command stream parts for an `APPEND` of `payload`.
    ///
    /// Built once, outside the measured region. A client whose message is not already in a
    /// `ByteBuffer` pays one more payload copy than these cases report.
    ///
    /// - Parameter payload: The message to append.
    /// - Returns: The parts, in order.
    public static func appendParts(payload: [UInt8]) -> [CommandStreamPart] {
        [
            .append(.start(tag: "A1", appendingTo: .inbox)),
            .append(
                .beginMessage(
                    message: AppendMessage(
                        options: AppendOptions(flagList: [.seen]),
                        data: AppendData(byteCount: payload.count)
                    )
                )
            ),
            .append(.messageBytes(ByteBuffer(bytes: payload))),
            .append(.endMessage),
            .append(.finish),
        ]
    }

    /// Encodes an `APPEND` and writes each chunk to a `ByteBuffer` transport.
    ///
    /// One payload copy, and only one: `EncodeBuffer.writeBuffer` copies the model's `ByteBuffer` into
    /// the encoder's own, and `nextChunk()` then yields a slice of that buffer, which the transport
    /// takes as is. There is no second region to write — the payload is part of the chunk, not beside
    /// it.
    ///
    /// - Parameters:
    ///   - parts: The parts from `appendParts(payload:)`.
    ///   - options: The encoding options.
    ///   - write: Called with each chunk, in order.
    /// - Returns: The number of bytes handed over.
    @discardableResult
    public static func sendAppend(
        parts: [CommandStreamPart],
        options: CommandEncodingOptions = .rfc3501,
        write: (ByteBuffer) -> Void
    ) -> Int {
        var byteCount = 0
        for part in parts {
            var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: options, loggingMode: false)
            encodeBuffer.writeCommandStream(part)
            byteCount += drain(&encodeBuffer, write: write)
        }
        return byteCount
    }

    /// Writes every chunk the encoder has ready.
    ///
    /// Writes one empty chunk for a part that encodes to nothing, where the current twin writes none:
    /// write-call counts differ between the two, allocations do not.
    private static func drain(
        _ encodeBuffer: inout CommandEncodeBuffer,
        write: (ByteBuffer) -> Void
    ) -> Int {
        var byteCount = 0
        while true {
            let chunk = encodeBuffer.buffer.nextChunk()
            byteCount += chunk.bytes.readableBytes
            write(chunk.bytes)
            guard chunk.waitForContinuation else { return byteCount }
        }
    }
}

#endif
