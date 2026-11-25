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

#if !IMAP_LEGACY_BUFFERS

import IMAPCorpus
import NIO
import NIOIMAP
import NIOIMAPCore

// The "after" half: the client this library is designed for, as `IMAPClientHandler` is written.
// Received `ByteBuffer`s are appended to an `IMAPInputBuffer` and parsed where they landed; encoded
// bytes are written into `IMAPOutputBuffer` segments and handed to the channel with
// `IMAPBufferList.makeOutboundBuffers()`. Nothing on either path copies a payload.
//
// Every function here has a same-signature twin in `ByteBufferClient+Legacy.swift`. Keep them in step:
// the comparison is only meaningful if the two configurations do the same work in the same order.
extension ByteBufferClient {
    /// Receives `reads` and parses everything in them.
    ///
    /// One `IMAPInputBuffer` for the connection. Each read is appended whole: retained if at least
    /// `IMAPBuffer.copyThreshold` (1 KiB), otherwise copied into a tail. A message straddling two reads
    /// is parsed across them, so there is no accumulator to compact.
    ///
    /// Payloads are held until the message they belong to finishes, as a client assembling a message in
    /// memory would. Holding one keeps that read's storage alive, the documented trade.
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
        var input = IMAPInputBuffer()
        var message: [IMAPBuffer] = []
        var count = 0
        for read in reads {
            input.append(read)
            while let event = try parser.parseResponseStream(buffer: &input) {
                switch event {
                case .response(.fetch(.streamingBytes(let payload))):
                    message.append(payload)
                case .response(.fetch(.finish)):
                    message.removeAll(keepingCapacity: true)
                default:
                    break
                }
                sink(event)
                count += 1
            }
        }
        precondition(input.isEmpty, "\(input.count) bytes left unparsed")
        return count
    }

    /// Asserts that a payload parsed out of `reads` refers to the received bytes.
    ///
    /// The zero-copy claim, made self-checking: a change that quietly starts copying payloads fails the
    /// benchmark's registration rather than showing up as an unexplained shift in `mallocBytesCount`.
    /// Extractions below `IMAPBuffer.copyThreshold` are copied deliberately, so the check is that every
    /// copy was a small one and that essentially all the bytes came by reference. See the twin in
    /// `DispatchClient+Current.swift`.
    ///
    /// - Parameter reads: A corpus containing at least one literal payload.
    public static func checkPayloadDelivery(_ reads: [ByteBuffer]) {
        let received = receivedRanges(reads)
        var referencedBytes = 0
        var copiedBytes = 0
        var oversizedCopy: Int? = nil
        try! receiveResponses(reads, options: streamingOptions()) { event in
            guard case .response(.fetch(.streamingBytes(let payload))) = event else { return }
            let address = payload.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
            if received.contains(where: { $0.contains(address) }) {
                referencedBytes += payload.count
            } else {
                copiedBytes += payload.count
                if payload.count >= IMAPBuffer.copyThreshold {
                    oversizedCopy = payload.count
                }
            }
        }

        precondition(referencedBytes > 0, "expected at least one payload, and expected it by reference")
        precondition(
            oversizedCopy == nil,
            "a payload of \(oversizedCopy ?? 0) bytes was copied, and anything at or above "
                + "copyThreshold (\(IMAPBuffer.copyThreshold)) should have been delivered by reference"
        )
        precondition(
            copiedBytes * 100 < referencedBytes,
            "\(copiedBytes) of \(referencedBytes + copiedBytes) payload bytes were copied, which is more "
                + "than the sub-threshold remainders can account for"
        )
    }

    /// Encodes `commands` and writes each chunk to a `ByteBuffer` transport.
    ///
    /// - Parameters:
    ///   - commands: The commands to send, in order.
    ///   - options: The encoding options.
    ///   - write: Called with each buffer, in order, as a channel write would be.
    /// - Returns: The number of bytes handed over.
    @discardableResult
    public static func sendCommands(
        _ commands: [TaggedCommand],
        options: CommandEncodingOptions = .rfc3501,
        write: (ByteBuffer) -> Void
    ) -> Int {
        var byteCount = 0
        for command in commands {
            var encodeBuffer = CommandEncodeBuffer(sink: IMAPOutputBuffer(), options: options, loggingMode: false)
            encodeBuffer.writeCommand(command)
            byteCount += drain(&encodeBuffer, write: write)
        }
        return byteCount
    }

    /// Encodes `responses` through one long-lived buffer, writing each one to a `ByteBuffer` transport.
    ///
    /// - Parameters:
    ///   - responses: The responses to send, in order.
    ///   - write: Called with each buffer, in order.
    /// - Returns: The number of bytes handed over.
    @discardableResult
    public static func sendResponses(
        _ responses: [Response],
        write: (ByteBuffer) -> Void
    ) -> Int {
        var encodeBuffer = ResponseEncodeBuffer(
            sink: IMAPOutputBuffer(),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        var byteCount = 0
        for response in responses {
            encodeBuffer.writeResponse(response)
            byteCount += writeAsHandler(encodeBuffer.readBytes(), write: write)
        }
        return byteCount
    }

    /// The command stream parts for an `APPEND` of `payload`.
    ///
    /// Built once, outside the measured region. The payload is `ByteBuffer`-backed, as a `ByteBuffer`
    /// client's would be: that is what lets `makeOutboundBuffers()` hand it to the channel as a slice.
    /// An array-backed payload would be copied on the way out. The `main` twin's copy into a
    /// `ByteBuffer` is likewise kept out of the measurement.
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
            .append(.messageBytes(IMAPBuffer(ByteBuffer(bytes: payload)))),
            .append(.endMessage),
            .append(.finish),
        ]
    }

    /// Encodes an `APPEND` and writes each chunk to a `ByteBuffer` transport.
    ///
    /// The payload is never copied: the encoder keeps it by reference, and `makeOutboundBuffers()`
    /// yields it as a `ByteBuffer` of its own, so a channel gathers it into a `writev`.
    ///
    /// - Parameters:
    ///   - parts: The parts from `appendParts(payload:)`.
    ///   - options: The encoding options.
    ///   - write: Called with each buffer, in order.
    /// - Returns: The number of bytes handed over.
    @discardableResult
    public static func sendAppend(
        parts: [CommandStreamPart],
        options: CommandEncodingOptions = .rfc3501,
        write: (ByteBuffer) -> Void
    ) -> Int {
        var byteCount = 0
        for part in parts {
            var encodeBuffer = CommandEncodeBuffer(sink: IMAPOutputBuffer(), options: options, loggingMode: false)
            encodeBuffer.writeCommandStream(part)
            byteCount += drain(&encodeBuffer, write: write)
        }
        return byteCount
    }

    /// Writes every chunk the encoder has ready.
    ///
    /// Writes nothing for a part that encodes to nothing, where the legacy twin writes one empty chunk:
    /// write-call counts differ between the two, allocations do not.
    private static func drain(
        _ encodeBuffer: inout CommandEncodeBuffer,
        write: (ByteBuffer) -> Void
    ) -> Int {
        var byteCount = 0
        while let chunk = encodeBuffer.nextChunk() {
            byteCount += writeAsHandler(chunk.bytes, write: write)
        }
        return byteCount
    }

    /// Hands a chunk to `write` exactly the way `IMAPClientHandler` does: one region is written without
    /// building an array, and only a chunk carrying a by-reference payload takes the general path.
    private static func writeAsHandler(_ bytes: IMAPBufferList, write: (ByteBuffer) -> Void) -> Int {
        switch bytes.regionCount {
        case 0:
            write(ByteBuffer())
            return 0
        case 1:
            let buffer = bytes.regions[0].byteBuffer
            write(buffer)
            return buffer.readableBytes
        default:
            var total = 0
            for buffer in bytes.makeOutboundBuffers() {
                total += buffer.readableBytes
                write(buffer)
            }
            return total
        }
    }
}

#endif
