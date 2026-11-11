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
@testable import NIOIMAPCore
import Testing

@Suite("ResponseEncodeBuffer")
struct ResponseEncodeBufferTests {
    @Test("correctly streams many simple attributes with spaces")
    func correctlyStreamsManySimpleAttributesWithSpaces() {
        // Previously had a bug where spaces weren't inserted between attributes
        var buffer = ResponseEncodeBuffer(options: .rfc3501, loggingMode: false)
        buffer.writeFetchResponse(.start(1))
        buffer.writeFetchResponse(.simpleAttribute(.flags([.answered])))
        buffer.writeFetchResponse(.simpleAttribute(.uid(999)))
        buffer.writeFetchResponse(.simpleAttribute(.binarySize(section: [1], size: 665)))
        buffer.writeFetchResponse(.finish)

        let outputString = String(buffer: buffer.readBytes())
        #expect(outputString == "* 1 FETCH (FLAGS (\\Answered) UID 999 BINARY.SIZE[1] 665)\r\n")
    }

    @Test("correctly handles fetch streaming with literal data")
    func correctlyHandlesFetchStreamingWithLiteralData() {
        var buffer = ResponseEncodeBuffer(options: .rfc3501, loggingMode: false)
        buffer.writeFetchResponse(.start(1))
        buffer.writeFetchResponse(.streamingBegin(kind: .body(section: .complete, offset: nil), byteCount: 10))
        buffer.writeFetchResponse(.streamingBytes(ByteBuffer(string: "0123456789")))
        buffer.writeFetchResponse(.streamingEnd)
        buffer.writeFetchResponse(.finish)

        let outputString = String(buffer: buffer.readBytes())
        #expect(outputString == "* 1 FETCH (BODY[] {10}\r\n0123456789)\r\n")
    }

    @Test("init with capabilities")
    func initWithCapabilities() {
        var buffer = ResponseEncodeBuffer(capabilities: [.imap4rev1], loggingMode: false)
        buffer.writeFetchResponse(.start(1))
        buffer.writeFetchResponse(.finish)
        let outputString = String(buffer: buffer.readBytes())
        #expect(outputString == "* 1 FETCH ()\r\n")
    }

    @Test("correctly streams binary attribute")
    func correctlyStreamsBinaryAttribute() {
        var buffer = ResponseEncodeBuffer(options: .rfc3501, loggingMode: false)
        buffer.writeFetchResponse(.start(1))
        buffer.writeFetchResponse(.streamingBegin(kind: .binary(section: [], offset: nil), byteCount: 5))
        buffer.writeFetchResponse(.streamingBytes(ByteBuffer(string: "hello")))
        buffer.writeFetchResponse(.streamingEnd)
        buffer.writeFetchResponse(.finish)
        let outputString = String(buffer: buffer.readBytes())
        #expect(outputString == "* 1 FETCH (BINARY {5}\r\nhello)\r\n")
    }

    /// A server handler keeps one of these for the whole connection and drains it after every
    /// response, so anything `readBytes()` fails to release accumulates for the life of the
    /// connection. The bytes it already handed out have to survive that, which they do because a
    /// handed-out region keeps its own storage alive.
    @Test("readBytes drains the buffer without disturbing what it handed out")
    func readBytesDrains() {
        var buffer = ResponseEncodeBuffer(options: .rfc3501, loggingMode: false)
        buffer.writeResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "first")))))
        let first = buffer.readBytes()
        #expect(buffer.readBytes().byteCount == 0)

        buffer.writeResponse(.tagged(.init(tag: "A2", state: .ok(.init(text: "second")))))
        let second = buffer.readBytes()

        #expect(String(buffer: first) == "A1 OK first\r\n")
        #expect(String(buffer: second) == "A2 OK second\r\n")
    }

    @Test("the encoder writes into a sink the caller supplies")
    func customSink() {
        var buffer = ResponseEncodeBuffer(
            sink: IMAPOutputBuffer(initialSegmentSize: 4, maximumSegmentSize: 4),
            options: .rfc3501,
            loggingMode: false
        )
        // Longer than the encoder stages before appending (`EncodeBuffer.stagingCapacity`, SPI, so
        // spelled here), so the sink gets several appends; four-byte segments leave no room to merge
        // them, so the response arrives as several regions rather than one — and reads back the same
        // either way.
        let longerThanStaging = 512
        let text = String(repeating: "x", count: longerThanStaging)
        buffer.writeResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: text)))))
        let bytes = buffer.readBytes()
        #expect(bytes.regionCount > 1)
        #expect(String(buffer: bytes) == "A1 OK \(text)\r\n")
    }
}
