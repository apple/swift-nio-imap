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

import Dispatch
import NIO
import NIOIMAP

// For `CommandEncodeBuffer.buffer`, which is SPI.
@_spi(NIOIMAPInternal) import NIOIMAPCore

// The client, written against a library where the parser reads a `ByteBuffer` and the encoder
// writes one.
//
// It is the *best* client that API allows, not a transcription of `ByteToMessageDecoder`. Three
// choices make it so, and each one costs this side less than the obvious alternative:
//
// - **Capacity is reserved once**, so appending a read does not reallocate in steady state.
// - **Compaction is amortised**, triggered when the parsed prefix passes half the buffer, rather than
//   after every parse round. Each byte is therefore moved at most once per half-buffer consumed,
//   instead of once per read.
// - **A payload is copied out of the accumulator** rather than held as a slice of it. A slice would
//   leave the accumulator's storage multiply-referenced, so the next append would copy the whole
//   thing on write — more bytes, and at an unpredictable moment. Paying one payload copy is what a
//   careful engineer does here, and it is the honest floor: this API has no way to hand over a
//   payload without copying it, because a `ByteBuffer` the parser was handed may be reassigned by its owner
//   the instant the call returns.
//
// What remains unavoidable is the first copy: every byte the transport delivers is copied out of its
// `DispatchData` region into the accumulator, because that is the only thing this parser reads.
extension DispatchClient {
    /// How many bytes the accumulator reserves up front.
    ///
    /// Generous on purpose — a 64 KB read fits, and so does a body-structure message several times
    /// over — so that this side is not charged for growth it could have avoided.
    private static var accumulatorCapacity: Int { 64 * 1_024 }

    /// Receives `reads` and parses everything in them.
    ///
    /// - Parameters:
    ///   - reads: The input, one `DispatchData` per socket read.
    ///   - options: The parser options.
    ///   - sink: Called once per parsed event.
    /// - Returns: The number of events parsed.
    /// - Throws: Whatever `ResponseParser` throws; a malformed corpus fails the benchmark.
    @discardableResult
    public static func receiveResponses(
        _ reads: [DispatchData],
        options: ResponseParser.Options = ResponseParser.Options(),
        sink: (ResponseOrContinuationRequest) -> Void
    ) throws -> Int {
        var parser = ResponseParser(options: options)
        var accumulator = ByteBuffer()
        accumulator.reserveCapacity(accumulatorCapacity)
        var message: [ByteBuffer] = []
        var count = 0
        for read in reads {
            // The copy this API forces: the parser reads a `ByteBuffer`, so every received byte is
            // moved out of its Dispatch region into one.
            read.enumerateBytes { region, _, _ in
                accumulator.writeBytes(region)
            }
            while let event = try parser.parseResponseStream(buffer: &accumulator) {
                switch event {
                case .response(.fetch(.streamingBytes(let payload))):
                    // Copied out, not retained. See the note at the top of this file.
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
    /// A payload cannot be delivered by reference through this API, so this proves the benchmarks
    /// measure the copy rather than having quietly avoided it.
    ///
    /// - Parameter reads: A corpus containing at least one literal payload.
    public static func checkPayloadDelivery(_ reads: [DispatchData]) {
        var received: [Range<UInt>] = []
        for read in reads {
            read.enumerateBytes { region, _, _ in
                guard let base = region.baseAddress else { return }
                let start = UInt(bitPattern: base)
                received.append(start..<(start + UInt(region.count)))
            }
        }

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

    /// Encodes `commands` and hands each chunk to a `DispatchData` transport.
    ///
    /// - Parameters:
    ///   - commands: The commands to send, in order.
    ///   - options: The encoding options.
    ///   - write: Called with each chunk, in order, as a transport write would be.
    /// - Returns: The number of bytes handed over.
    @discardableResult
    public static func sendCommands(
        _ commands: [TaggedCommand],
        options: CommandEncodingOptions = .rfc3501,
        write: (DispatchData) -> Void
    ) -> Int {
        var byteCount = 0
        for command in commands {
            var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: options, loggingMode: false)
            encodeBuffer.writeCommand(command)
            byteCount += drain(&encodeBuffer, write: write)
        }
        return byteCount
    }

    /// Encodes `responses` through one long-lived buffer, handing each one to a `DispatchData`
    /// transport.
    ///
    /// - Parameters:
    ///   - responses: The responses to send, in order.
    ///   - write: Called with each response's bytes, in order.
    /// - Returns: The number of bytes handed over.
    @discardableResult
    public static func sendResponses(
        _ responses: [Response],
        write: (DispatchData) -> Void
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
            let data = bytes.withUnsafeReadableBytes { DispatchData(bytes: $0) }
            byteCount += data.count
            write(data)
        }
        return byteCount
    }

    /// The command stream parts for an `APPEND` of `payload`.
    ///
    /// Built once, outside the measured region — charging the `ByteBuffer` this copies the caller's
    /// array into per iteration would fold it into a number that is about encoding. A client whose
    /// message is not already in a `ByteBuffer` therefore pays *one more* payload copy than these cases
    /// report.
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

    /// Encodes an `APPEND` and hands each chunk to a `DispatchData` transport.
    ///
    /// Two copies of the payload, neither avoidable through this API: the model's `ByteBuffer` into the
    /// encoder's own, and the encoder's into the `DispatchData`. A `ByteBuffer` can only be filled in
    /// place and a `DispatchData` can only adopt memory whose ownership it takes, so neither end of
    /// this path can be donated to the other.
    ///
    /// - Parameters:
    ///   - parts: The parts from ``appendParts(payload:)``.
    ///   - options: The encoding options.
    ///   - write: Called with each chunk, in order.
    /// - Returns: The number of bytes handed over.
    @discardableResult
    public static func sendAppend(
        parts: [CommandStreamPart],
        options: CommandEncodingOptions = .rfc3501,
        write: (DispatchData) -> Void
    ) -> Int {
        var byteCount = 0
        for part in parts {
            var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: options, loggingMode: false)
            encodeBuffer.writeCommandStream(part)
            byteCount += drain(&encodeBuffer, write: write)
        }
        return byteCount
    }

    private static func drain(
        _ encodeBuffer: inout CommandEncodeBuffer,
        write: (DispatchData) -> Void
    ) -> Int {
        var byteCount = 0
        while true {
            let chunk = encodeBuffer.buffer.nextChunk()
            let data = chunk.bytes.withUnsafeReadableBytes { DispatchData(bytes: $0) }
            byteCount += data.count
            write(data)
            guard chunk.waitForContinuation else { return byteCount }
        }
    }
}
