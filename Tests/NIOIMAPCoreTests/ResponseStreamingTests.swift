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

import Foundation
import XCTest

import NIO
import NIOIMAPCore

class ResponseStreamingTests: XCTestCase {}

extension ResponseStreamingTests {
    func AssertFetchResponses(_ text: String, _ responses: [(Response, UInt)]) {
        var buffer = ByteBuffer(stringLiteral: "")
        buffer.writeString(text)

        var parser = ResponseParser()
        for (input, line) in responses {
            do {
                let actual = try parser.parseResponseStream(buffer: &buffer)
                XCTAssertEqual(.response(input), actual, line: line)
            } catch {
                XCTFail("\(error)", line: line)
                return
            }
        }
        XCTAssertEqual(buffer.readableBytes, 0)
    }

    func testBodyStreaming() {
        self.AssertFetchResponses("* 1 FETCH (BODY[TEXT]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n", [
            (.fetch(.start(1)), #line),
            (.fetch(.streamingBegin(kind: .body(section: .text, offset: 4), byteCount: 3)), #line),
            (.fetch(.streamingBytes("abc")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 2 FETCH (FLAGS (\\deleted) BODY[TEXT] {3}\r\ndef)\r\n", [
            (.fetch(.start(2)), #line),
            (.fetch(.simpleAttribute(.flags([.deleted]))), #line),
            (.fetch(.streamingBegin(kind: .body(section: .text, offset: nil), byteCount: 3)), #line),
            (.fetch(.streamingBytes("def")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 3 FETCH (BODY[TEXT] {3}\r\nghi)\r\n", [
            (.fetch(.start(3)), #line),
            (.fetch(.streamingBegin(kind: .body(section: .text, offset: nil), byteCount: 3)), #line),
            (.fetch(.streamingBytes("ghi")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 3 FETCH (BODY[TEXT] {3}\r\nghi)\r\n", [
            (.fetch(.start(3)), #line),
            (.fetch(.streamingBegin(kind: .body(section: .text, offset: nil), byteCount: 3)), #line),
            (.fetch(.streamingBytes("ghi")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 3 FETCH (BODY[5.2.MIME] NIL)\r\n", [
            (.fetch(.start(3)), #line),
            (.fetch(.simpleAttribute(.nilBody(.body(section: .init(part: [5, 2], kind: .MIMEHeader), offset: nil)))), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 3 FETCH (BODY[3] NIL UID 456)\r\n", [
            (.fetch(.start(3)), #line),
            (.fetch(.simpleAttribute(.nilBody(.body(section: .init(part: [3]), offset: nil)))), #line),
            (.fetch(.simpleAttribute(.uid(456))), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 3 FETCH (BINARY[4] {3}\r\nghi)\r\n", [
            (.fetch(.start(3)), #line),
            (.fetch(.streamingBegin(kind: .binary(section: [4], offset: nil), byteCount: 3)), #line),
            (.fetch(.streamingBytes("ghi")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 3 FETCH (BINARY[4] NIL)\r\n", [
            (.fetch(.start(3)), #line),
            (.fetch(.simpleAttribute(.nilBody(.binary(section: [4], offset: nil)))), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 4 FETCH (BODY[4.TEXT]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n", [
            (.fetch(.start(4)), #line),
            (.fetch(.streamingBegin(kind: .body(section: .init(part: [4], kind: .text), offset: 4), byteCount: 3)), #line),
            (.fetch(.streamingBytes("abc")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 5 FETCH (BODY[5.TEXT]<4> \"asdf\" FLAGS (\\seen \\answered))\r\n", [
            (.fetch(.start(5)), #line),
            (.fetch(.streamingBegin(kind: .body(section: .init(part: [5], kind: .text), offset: 4), byteCount: 4)), #line),
            (.fetch(.streamingBytes("asdf")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 6 FETCH (BODY[5.2]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n", [
            (.fetch(.start(6)), #line),
            (.fetch(.streamingBegin(kind: .body(section: .init(part: [5, 2], kind: .complete), offset: 4), byteCount: 3)), #line),
            (.fetch(.streamingBytes("abc")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 7 FETCH (BODY[5.2.HEADER]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n", [
            (.fetch(.start(7)), #line),
            (.fetch(.streamingBegin(kind: .body(section: .init(part: [5, 2], kind: .header), offset: 4), byteCount: 3)), #line),
            (.fetch(.streamingBytes("abc")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 8 FETCH (RFC822.TEXT {3}\r\nabc)\r\n", [
            (.fetch(.start(8)), #line),
            (.fetch(.streamingBegin(kind: .rfc822Text, byteCount: 3)), #line),
            (.fetch(.streamingBytes("abc")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 9 FETCH (RFC822.HEADER {3}\r\nabc)\r\n", [
            (.fetch(.start(9)), #line),
            (.fetch(.streamingBegin(kind: .rfc822Header, byteCount: 3)), #line),
            (.fetch(.streamingBytes("abc")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.finish), #line),
        ])
    }

    func testBinaryStreaming() {
        self.AssertFetchResponses("* 1 FETCH (BINARY[] {4}\r\n1234)\r\n", [
            (.fetch(.start(1)), #line),
            (.fetch(.streamingBegin(kind: .binary(section: [], offset: nil), byteCount: 4)), #line),
            (.fetch(.streamingBytes("1234")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.finish), #line),
        ])

        self.AssertFetchResponses("* 2 FETCH (BINARY[1.2]<77> {4}\r\n1234)\r\n", [
            (.fetch(.start(2)), #line),
            (.fetch(.streamingBegin(kind: .binary(section: [1, 2], offset: 77), byteCount: 4)), #line),
            (.fetch(.streamingBytes("1234")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.finish), #line),
        ])
    }
    
    func testStreamingStartingWithNewline() {
        self.AssertFetchResponses("\n* 1 FETCH (BODY[TEXT]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n", [
            (.fetch(.start(1)), #line),
            (.fetch(.streamingBegin(kind: .body(section: .text, offset: 4), byteCount: 3)), #line),
            (.fetch(.streamingBytes("abc")), #line),
            (.fetch(.streamingEnd), #line),
            (.fetch(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetch(.finish), #line),
        ])
    }
}
