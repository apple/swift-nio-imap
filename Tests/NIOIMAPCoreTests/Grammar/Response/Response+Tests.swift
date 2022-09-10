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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class Response_Tests: EncodeTestClass {}

// MARK: - Encoding

extension Response_Tests {
    func testEncode_response() {
        let inputs: [(Response, String, UInt)] = [
            (.idleStarted, "+ idling\r\n", #line),
            (.authenticationChallenge("hello"), "+ aGVsbG8=\r\n", #line),
            (.fatal(.init(text: "Oh no you're dead")), "* BYE Oh no you're dead\r\n", #line),
            (.tagged(.init(tag: "A1", state: .ok(.init(text: "NOOP complete")))), "A1 OK NOOP complete\r\n", #line),
            (.untagged(.id([:])), "* ID NIL\r\n", #line),
            (.fetch(.start(1)), "* 1 FETCH (", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            var encoder = ResponseEncodeBuffer(buffer: self.testBuffer.buffer, options: ResponseEncodingOptions(), loggingMode: false)
            let size = encoder.writeResponse(test)
            self.testBuffer = EncodeBuffer.serverEncodeBuffer(buffer: encoder.readBytes(), options: ResponseEncodingOptions(), loggingMode: false)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_fetchResponse_multiple() {
        let inputs: [([NIOIMAPCore.FetchResponse], String, UInt)] = [
            ([.start(1), .simpleAttribute(.rfc822Size(123)), .finish], "* 1 FETCH (RFC822.SIZE 123)\r\n", #line),
            ([.start(2), .simpleAttribute(.uid(123)), .simpleAttribute(.rfc822Size(456)), .finish], "* 2 FETCH (UID 123 RFC822.SIZE 456)\r\n", #line),
            (
                [.start(3), .simpleAttribute(.uid(123)), .streamingBegin(kind: .rfc822Text, byteCount: 0), .streamingEnd, .simpleAttribute(.uid(456)), .finish],
                "* 3 FETCH (UID 123 RFC822.TEXT {0}\r\n UID 456)\r\n",
                #line
            ),
            (
                [.start(3), .simpleAttribute(.uid(123)), .streamingBegin(kind: .rfc822Header, byteCount: 0), .streamingEnd, .simpleAttribute(.uid(456)), .finish],
                "* 3 FETCH (UID 123 RFC822.HEADER {0}\r\n UID 456)\r\n",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            var encoder = ResponseEncodeBuffer(buffer: self.testBuffer.buffer, options: ResponseEncodingOptions(), loggingMode: false)
            let size = test.reduce(into: 0) { (size, response) in
                size += encoder.writeFetchResponse(response)
            }
            self.testBuffer = EncodeBuffer.serverEncodeBuffer(buffer: encoder.readBytes(), options: ResponseEncodingOptions(), loggingMode: false)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension Response_Tests {
    func testCustomDebugStringConvertible_StreamingKind() {
        let inputs: [(StreamingKind, String, UInt)] = [
            (.body(section: .init(), offset: nil), "BODY[]", #line),
            (.body(section: .init(), offset: 1234), "BODY[]<1234>", #line),
            (.body(section: .init(part: [2, 3], kind: .header), offset: 1234), "BODY[2.3.HEADER]<1234>", #line),
            (.rfc822, "RFC822", #line),
            (.rfc822Text, "RFC822.TEXT", #line),
            (.rfc822Header, "RFC822.HEADER", #line),
        ]
        inputs.forEach { (part, expected, line) in
            XCTAssertEqual("\(part)", expected, line: line)
        }
    }
}
