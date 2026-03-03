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
        var buffer = ResponseEncodeBuffer(buffer: ByteBuffer(string: ""), options: .rfc3501, loggingMode: false)
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
        var buffer = ResponseEncodeBuffer(buffer: ByteBuffer(string: ""), options: .rfc3501, loggingMode: false)
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
        var buffer = ResponseEncodeBuffer(buffer: ByteBuffer(), capabilities: [.imap4rev1], loggingMode: false)
        buffer.writeFetchResponse(.start(1))
        buffer.writeFetchResponse(.finish)
        let outputString = String(buffer: buffer.readBytes())
        #expect(outputString == "* 1 FETCH ()\r\n")
    }

    @Test("correctly streams binary attribute")
    func correctlyStreamsBinaryAttribute() {
        var buffer = ResponseEncodeBuffer(buffer: ByteBuffer(string: ""), options: .rfc3501, loggingMode: false)
        buffer.writeFetchResponse(.start(1))
        buffer.writeFetchResponse(.streamingBegin(kind: .binary(section: [], offset: nil), byteCount: 5))
        buffer.writeFetchResponse(.streamingBytes(ByteBuffer(string: "hello")))
        buffer.writeFetchResponse(.streamingEnd)
        buffer.writeFetchResponse(.finish)
        let outputString = String(buffer: buffer.readBytes())
        #expect(outputString == "* 1 FETCH (BINARY {5}\r\nhello)\r\n")
    }
}
