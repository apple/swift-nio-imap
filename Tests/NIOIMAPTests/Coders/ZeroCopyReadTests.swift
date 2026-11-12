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
import Testing

@_spi(NIOIMAPInternal) import NIOIMAPCore

/// The address range a `ByteBuffer`'s readable bytes occupy. A payload whose first byte lies inside one
/// of these came out of that read; anything else is a copy.
private func storageRange(of buffer: ByteBuffer) -> Range<UInt> {
    buffer.withUnsafeReadableBytes { bytes in
        let base = UInt(bitPattern: bytes.baseAddress)
        return base..<(base + UInt(bytes.count))
    }
}

private func address(of payload: IMAPBuffer) -> UInt {
    payload.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
}

/// What the handlers hand *up* for a large payload: the bytes the network delivered, not a copy of them.
///
/// This is the receive-side twin of `ZeroCopyWriteTests`, and it is the property that only holds because
/// the handlers accumulate into an `IMAPInputBuffer`: a read of at least 1 KiB is kept as it arrived, so
/// the parser can deliver a literal as a reference into it. Copied bytes are still the right bytes, so nothing else in
/// the suite notices if this stops working.
@Suite("Zero-copy payload reads")
struct ZeroCopyReadTests {
    private static let payloadSize = 1_024 * 1_024

    private static func parserOptions() -> ResponseParser.Options {
        var options = ResponseParser.Options()
        options.literalSizeLimit = 4 * payloadSize
        return options
    }

    @Test("a FETCH literal arriving over the decoder is delivered as the bytes that were received")
    func streamedLiteralIsNotCopied() throws {
        let channel = EmbeddedChannel(handler: IMAPClientHandler(parserOptions: Self.parserOptions()))
        channel.pipeline.fireChannelActive()
        defer { _ = try? channel.finish() }

        let head = ByteBuffer(string: "* 1 FETCH (RFC822.TEXT {\(Self.payloadSize)}\r\n")
        let body = ByteBuffer(repeating: UInt8(ascii: "x"), count: Self.payloadSize)
        let tail = ByteBuffer(string: ")\r\n")
        let bodyStorage = storageRange(of: body)

        for read in [head, body, tail] {
            try channel.writeInbound(read)
        }

        var payloads: [IMAPBuffer] = []
        while let response = try channel.readInbound(as: Response.self) {
            guard case .fetch(.streamingBytes(let bytes)) = response else { continue }
            payloads.append(bytes)
        }

        #expect(payloads.reduce(0) { $0 + $1.count } == Self.payloadSize)
        #expect(payloads.allSatisfy { bodyStorage.contains(address(of: $0)) })
    }

    @Test("a delivered literal converts to DispatchData by donating the received bytes")
    func streamedLiteralDonatesToDispatchData() throws {
        let channel = EmbeddedChannel(handler: IMAPClientHandler(parserOptions: Self.parserOptions()))
        channel.pipeline.fireChannelActive()
        defer { _ = try? channel.finish() }

        let head = ByteBuffer(string: "* 1 FETCH (RFC822.TEXT {\(Self.payloadSize)}\r\n")
        let body = ByteBuffer(repeating: UInt8(ascii: "x"), count: Self.payloadSize)
        let tail = ByteBuffer(string: ")\r\n")
        let bodyStorage = storageRange(of: body)
        for read in [head, body, tail] {
            try channel.writeInbound(read)
        }

        var payloads: [IMAPBuffer] = []
        while let response = try channel.readInbound(as: Response.self) {
            guard case .fetch(.streamingBytes(let bytes)) = response else { continue }
            payloads.append(bytes)
        }

        #expect(payloads.reduce(0) { $0 + $1.count } == Self.payloadSize)
        for payload in payloads {
            var leaves: [UInt] = []
            payload.makeDispatchData().enumerateBytes { bytes, _, _ in
                leaves.append(UInt(bitPattern: bytes.baseAddress))
            }
            #expect(leaves.count == 1)
            #expect(leaves.allSatisfy { bodyStorage.contains($0) })
        }
    }

    @Test("a literal split across reads is delivered as each read, with nothing joined up")
    func splitLiteralIsNotCopied() throws {
        let channel = EmbeddedChannel(handler: IMAPClientHandler(parserOptions: Self.parserOptions()))
        channel.pipeline.fireChannelActive()
        defer { _ = try? channel.finish() }

        // The head read deliberately ends part-way into the literal, so the payload arrives as three
        // pieces and the second one starts at a region boundary. A buffer that coalesced its reads would
        // still produce the right bytes here — from a copy.
        let firstPiece = 4_096
        let head = ByteBuffer(
            string: "* 1 FETCH (RFC822.TEXT {\(Self.payloadSize)}\r\n"
                + String(repeating: "y", count: firstPiece)
        )
        let rest = ByteBuffer(repeating: UInt8(ascii: "y"), count: Self.payloadSize - firstPiece)
        let tail = ByteBuffer(string: ")\r\n")
        let ranges = [storageRange(of: head), storageRange(of: rest)]

        for read in [head, rest, tail] {
            try channel.writeInbound(read)
        }

        var payloads: [IMAPBuffer] = []
        while let response = try channel.readInbound(as: Response.self) {
            guard case .fetch(.streamingBytes(let bytes)) = response else { continue }
            payloads.append(bytes)
        }

        #expect(payloads.count >= 2, "expected the literal to be delivered in pieces")
        #expect(payloads.reduce(0) { $0 + $1.count } == Self.payloadSize)
        for payload in payloads where payload.count >= IMAPBuffer.copyThreshold {
            #expect(ranges.contains { $0.contains(address(of: payload)) })
        }
    }
}
