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

import Dispatch
import IMAPCorpus
import NIO
import NIOIMAP

import NIOIMAPCore

// The "after" half: the client this library is designed for. Received regions are appended to an
// `IMAPInputBuffer` and parsed where they landed; encoded bytes are written into segments the encoder
// owns and then donated to a `DispatchData`, or copied into it when shorter than
// `IMAPBuffer.dispatchDonationThreshold`. Nothing on either path copies a payload.
//
// Every function here has a same-signature twin in `DispatchClient+Legacy.swift`. Keep them in step:
// the comparison is only meaningful if the two configurations do the same work in the same order, and
// nothing but the review of these two files enforces that.
extension DispatchClient {
    /// Receives `reads` and parses everything in them.
    ///
    /// One `IMAPInputBuffer` for the connection. Each read is appended whole, its regions walked in place:
    /// retained if at least `IMAPBuffer.copyThreshold` (1 KiB), as MTU-sized reads are, otherwise (e.g. a
    /// corpus's last read) copied into a tail. A message straddling two reads is parsed across them, so there is no
    /// accumulator to compact and no remainder to move.
    ///
    /// Payloads are held until the message they belong to finishes, which is what a client assembling
    /// a message in memory does. The `IMAPBuffer` the parser handed over refers to the received bytes,
    /// so holding it copies nothing; it does keep that read's region alive, which is the documented
    /// trade and the reason `IMAPInputBuffer.count` counts live bytes rather than allocated ones.
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
        var input = IMAPInputBuffer()
        var message: [IMAPBuffer] = []
        var count = 0
        for read in reads {
            input.append(contentsOf: read)
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
        return count
    }

    /// Asserts that a payload parsed out of `reads` refers to the received bytes.
    ///
    /// The zero-copy claim, made self-checking: it compares the address the parser handed over against
    /// the addresses the reads occupy, so a change that quietly starts copying payloads fails the
    /// benchmark's own registration rather than showing up as an unexplained shift in
    /// `mallocBytesCount`. The legacy twin asserts the opposite, because on `main` the copy is the only
    /// option.
    ///
    /// What is asserted is the documented rule rather than "nothing is ever copied": an extraction
    /// below `IMAPBuffer.copyThreshold` *is* copied, deliberately, so that a small leftover does not
    /// pin a whole received buffer. At MTU reads a 1 MB literal arrives as ~700 extractions of ~1448
    /// bytes and one short remainder, so the check is that every copy was one of those small ones and
    /// that essentially all the bytes came by reference.
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
        // A remainder below the threshold per literal is expected; a percent of the payload is not.
        precondition(
            copiedBytes * 100 < referencedBytes,
            "\(copiedBytes) of \(referencedBytes + copiedBytes) payload bytes were copied, which is more "
                + "than the sub-threshold remainders can account for"
        )
    }

    /// Encodes `commands` and hands each chunk to a `DispatchData` transport.
    ///
    /// One `DispatchData` per chunk: a Dispatch transport wants the whole chunk as a single value where
    /// a `Channel` wants a payload written on its own. Large regions are *donated* rather than copied;
    /// each run of short ones is copied into one.
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
            var encodeBuffer = CommandEncodeBuffer(sink: IMAPOutputBuffer(), options: options, loggingMode: false)
            encodeBuffer.writeCommand(command)
            byteCount += drain(&encodeBuffer, write: write)
        }
        return byteCount
    }

    /// Encodes `responses` through one long-lived buffer, handing each one to a `DispatchData`
    /// transport.
    ///
    /// The server's side of the same transport. It is here because this is where encoding is
    /// expensive — a `BODYSTRUCTURE` response is hundreds of small writes, which is the traffic the
    /// segment sink was chosen for — and because one buffer reused across responses is what exercises
    /// the `removeAll`-keeps-its-segment behaviour.
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
            sink: IMAPOutputBuffer(),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        var byteCount = 0
        for response in responses {
            encodeBuffer.writeResponse(response)
            let data = encodeBuffer.readBytes().makeDispatchData()
            byteCount += data.count
            write(data)
        }
        return byteCount
    }

    /// The command stream parts for an `APPEND` of `payload`.
    ///
    /// Built once, outside the measured region, so that what the append cases measure is encoding and
    /// handing over — not the cost of getting the caller's bytes into the library's model. That cost is
    /// itself asymmetric (wrapping an array here, copying it into a `ByteBuffer` on `main`) and
    /// charging it per iteration would fold a second effect into the same number.
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
            // Wrapped, not copied. The array promises a fixed address, so the region survives being
            // donated to a `DispatchData` later.
            .append(.messageBytes(IMAPBuffer(payload))),
            .append(.endMessage),
            .append(.finish),
        ]
    }

    /// Encodes an `APPEND` and hands each chunk to a `DispatchData` transport.
    ///
    /// The payload is never copied: it reaches the output by reference, and because an array promises a
    /// fixed address the donation to `DispatchData` keeps it that way. So the bytes the caller already
    /// held reach the transport without being copied once — which is the claim, and it is why this case
    /// reports `mallocBytesCount` that does not scale with the payload.
    ///
    /// - Parameters:
    ///   - parts: The parts from ``appendParts(payload:)``.
    ///   - options: The encoding options. With `.rfc3501` the payload is a synchronizing literal, so
    ///     this produces a chunk boundary the client may not cross without a continuation request.
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
            var encodeBuffer = CommandEncodeBuffer(sink: IMAPOutputBuffer(), options: options, loggingMode: false)
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
        while let chunk = encodeBuffer.nextChunk() {
            let data = chunk.bytes.makeDispatchData()
            byteCount += data.count
            write(data)
        }
        return byteCount
    }
}

#endif
