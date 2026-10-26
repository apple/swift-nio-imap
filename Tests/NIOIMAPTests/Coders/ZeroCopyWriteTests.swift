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
import NIOIMAP
import NIOIMAPCore
import Testing

/// The address of a `ByteBuffer`'s first readable byte. Two buffers reporting the same address share
/// storage, which is the only way to tell a slice from a copy from the outside.
private func address(of buffer: ByteBuffer) -> UInt {
    buffer.withUnsafeReadableBytes { UInt(bitPattern: $0.baseAddress) }
}

/// What the handlers write for a large payload: the caller's own memory, not a copy of it.
///
/// The client sends an `APPEND` message and the server a `FETCH` literal, and in both directions the
/// bytes should reach the channel as a slice of the buffer the caller handed in. These are the tests
/// behind "a multi-megabyte payload is encoded and written with zero bytes copied"; a regression here
/// is invisible in every other test, because copied bytes are still the *right* bytes.
@Suite("Zero-copy payload writes")
struct ZeroCopyWriteTests {
    private static let payloadSize = 1_024 * 1_024

    @Test("an APPEND payload reaches the channel as the caller's own memory")
    func clientAppendPayloadIsNotCopied() throws {
        let payload = ByteBuffer(repeating: UInt8(ascii: "x"), count: Self.payloadSize)
        let channel = EmbeddedChannel(handler: IMAPClientHandler())
        channel.pipeline.fireChannelActive()
        defer { _ = try? channel.finish() }

        // `writeAndFlush` rather than `writeOutbound`, and no waiting on the futures: the write that
        // ends at a literal header is deliberately left pending until the server allows the payload
        // through, so waiting for it here would wait forever.
        let start = channel.writeAndFlush(
            IMAPClientHandler.Message.part(.append(.start(tag: "A1", appendingTo: .inbox)))
        )
        let begin = channel.writeAndFlush(
            IMAPClientHandler.Message.part(
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: Self.payloadSize))))
            )
        )
        // Everything up to the literal header goes out immediately; the payload waits for the server's
        // continuation request.
        #expect(try channel.readOutbound(as: ByteBuffer.self) != nil)
        #expect(try channel.readOutbound(as: ByteBuffer.self) != nil)

        let sent = channel.writeAndFlush(
            IMAPClientHandler.Message.part(.append(.messageBytes(IMAPBuffer(payload))))
        )
        #expect(try channel.readOutbound(as: ByteBuffer.self) == nil, "the payload must wait for a continuation")

        try channel.writeInbound(ByteBuffer(string: "+ OK\r\n"))
        let written = try channel.readOutbound(as: ByteBuffer.self)
        #expect(written?.readableBytes == Self.payloadSize)
        #expect(
            written.map(address(of:)) == address(of: payload),
            "the payload should be written as a slice of the caller's buffer, not a copy of it"
        )
        for future in [start, begin, sent] {
            #expect(throws: Never.self) { try future.wait() }
        }
    }

    @Test("a streamed FETCH literal reaches the channel as the caller's own memory")
    func serverStreamedLiteralIsNotCopied() throws {
        let payload = ByteBuffer(repeating: UInt8(ascii: "y"), count: Self.payloadSize)
        let channel = EmbeddedChannel(handler: IMAPServerHandler())
        channel.pipeline.fireChannelActive()
        defer { _ = try? channel.finish() }

        try channel.writeOutbound(Response.fetch(.start(1)))
        try channel.writeOutbound(
            Response.fetch(.streamingBegin(kind: .rfc822, byteCount: Self.payloadSize))
        )
        #expect(try channel.readOutbound(as: ByteBuffer.self) != nil)
        #expect(try channel.readOutbound(as: ByteBuffer.self) != nil)

        try channel.writeOutbound(Response.fetch(.streamingBytes(IMAPBuffer(payload))))
        let written = try channel.readOutbound(as: ByteBuffer.self)
        #expect(written?.readableBytes == Self.payloadSize)
        #expect(
            written.map(address(of:)) == address(of: payload),
            "a streamed literal should be written as a slice of the caller's buffer"
        )

        try channel.writeOutbound(Response.fetch(.finish))
        #expect((try channel.readOutbound(as: ByteBuffer.self)).map { String(buffer: $0) } == ")\r\n")
    }

    @Test("a short payload is copied, and the bytes are still right")
    func shortPayloadIsCopiedCorrectly() throws {
        // Below the copy threshold nothing is kept by reference — a region of its own would cost more
        // than the copy. The point of the test is that the two paths agree on the bytes.
        let payload = ByteBuffer(string: "a short message")
        let channel = EmbeddedChannel(handler: IMAPServerHandler())
        channel.pipeline.fireChannelActive()
        defer { _ = try? channel.finish() }

        try channel.writeOutbound(Response.fetch(.streamingBytes(IMAPBuffer(payload))))
        let written = try channel.readOutbound(as: ByteBuffer.self)
        #expect(written.map { String(buffer: $0) } == "a short message")
        #expect(written.map(address(of:)) != address(of: payload))
    }
}
