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

import NIOIMAPCore
import NIO

class ResponseStreamingTests: XCTestCase {}

extension ResponseStreamingTests {
    
    func testResponseMessageDataStreaming() {
        // first send a greeting
        // then respond to 2 LOGIN {3}\r\nabc {3}\r\nabc
        // command tag FETCH 1:3 (BODY[TEXT] FLAGS)
        // command tag FETCH 1 BINARY[]

        let lines = [
            "* OK [CAPABILITY IMAP4rev1] Ready.\r\n",
            "* PREAUTH IMAP4rev1 server logged in as Smith\r\n",
            "* BYE Autologout; idle for too long\r\n",

            "2 OK Login completed.\r\n",

            "* 1 FETCH (BODY[TEXT]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
            "* 2 FETCH (FLAGS (\\deleted) BODY[TEXT] {3}\r\ndef)\r\n",
            "* 3 FETCH (BODY[TEXT] {3}\r\nghi)\r\n",
            "* 4 FETCH (BODY[4.TEXT]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
//            "* 5 FETCH (BODY[5.TEXT]<4> \"asdf\" FLAGS (\\seen \\answered))\r\n",
            "* 6 FETCH (BODY[5.2]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
            "* 7 FETCH (BODY[5.2.HEADER]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
            "3 OK Fetch completed.\r\n",

            "* 1 FETCH (BINARY[] {4}\r\n1234)\r\n",
            "4 OK Fetch completed.\r\n",
        ]
        var buffer = ByteBuffer(stringLiteral: "")
        buffer.writeString(lines.joined())

        let expectedResults: [(Response, UInt)] = [
            (.untaggedResponse(.conditionalState(.ok(.init(code: .capability([.imap4rev1]), text: "Ready.")))), #line),
            (.untaggedResponse(.conditionalState(.preauth(.init(text: "IMAP4rev1 server logged in as Smith")))), #line),
            (.untaggedResponse(.conditionalState(.bye(.init(text: "Autologout; idle for too long")))), #line),

            (.taggedResponse(.init(tag: "2", state: .ok(.init(code: nil, text: "Login completed.")))), #line),

            (.fetchResponse(.start(1)), #line),
            (.fetchResponse(.streamingBegin(kind: .body(section: .text, offset: 4), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("abc")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetchResponse(.finish), #line),

            (.fetchResponse(.start(2)), #line),
            (.fetchResponse(.simpleAttribute(.flags([.deleted]))), #line),
            (.fetchResponse(.streamingBegin(kind: .body(section: .text, offset: nil), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("def")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.finish), #line),

            (.fetchResponse(.start(3)), #line),
            (.fetchResponse(.streamingBegin(kind: .body(section: .text, offset: nil), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("ghi")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.finish), #line),
            
            (.fetchResponse(.start(4)), #line),
            (.fetchResponse(.streamingBegin(kind: .body(section: .init(part: [4], kind: .text), offset: 4), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("abc")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetchResponse(.finish), #line),
            
            (.fetchResponse(.start(6)), #line),
            (.fetchResponse(.streamingBegin(kind: .body(section: .init(part: [5, 2], kind: .complete), offset: 4), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("abc")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetchResponse(.finish), #line),
            
            (.fetchResponse(.start(7)), #line),
            (.fetchResponse(.streamingBegin(kind: .body(section: .init(part: [5, 2], kind: .header), offset: 4), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("abc")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetchResponse(.finish), #line),
            
            (.taggedResponse(.init(tag: "3", state: .ok(.init(code: nil, text: "Fetch completed.")))), #line),
            

            (.fetchResponse(.start(1)), #line),
            (.fetchResponse(.streamingBegin(kind: .binary(section: []), byteCount: 4)), #line),
            (.fetchResponse(.streamingBytes("1234")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.finish), #line),
            (.taggedResponse(.init(tag: "4", state: .ok(.init(code: nil, text: "Fetch completed.")))), #line),
        ]

        var parser = ResponseParser()
        for (input, line) in expectedResults {
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
    
}
