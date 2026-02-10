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
import NIO
import NIOIMAPCore
import Testing

@Suite("Response Streaming")
struct ResponseStreamingTests {
    struct FetchResponseFixture: Sendable, CustomTestStringConvertible {
        var name: String
        var input: String
        var expectation: [Response]

        var testDescription: String { name }
    }

    @Test(arguments: [
        FetchResponseFixture(
            name: "Body streaming with offset and flags",
            input: "* 1 FETCH (BODY[TEXT]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
            expectation: [
                .fetch(.start(1)),
                .fetch(.streamingBegin(kind: .body(section: .text, offset: 4), byteCount: 3)),
                .fetch(.streamingBytes("abc")),
                .fetch(.streamingEnd),
                .fetch(.simpleAttribute(.flags([.seen, .answered]))),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "UID fetch with flags and body",
            input: "* 2 UIDFETCH (FLAGS (\\deleted) BODY[TEXT] {3}\r\ndef)\r\n",
            expectation: [
                .fetch(.startUID(2)),
                .fetch(.simpleAttribute(.flags([.deleted]))),
                .fetch(.streamingBegin(kind: .body(section: .text, offset: nil), byteCount: 3)),
                .fetch(.streamingBytes("def")),
                .fetch(.streamingEnd),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "Simple body streaming",
            input: "* 3 FETCH (BODY[TEXT] {3}\r\nghi)\r\n",
            expectation: [
                .fetch(.start(3)),
                .fetch(.streamingBegin(kind: .body(section: .text, offset: nil), byteCount: 3)),
                .fetch(.streamingBytes("ghi")),
                .fetch(.streamingEnd),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "Body with MIME header section as NIL",
            input: "* 3 FETCH (BODY[5.2.MIME] NIL)\r\n",
            expectation: [
                .fetch(.start(3)),
                .fetch(
                    .simpleAttribute(.nilBody(.body(section: .init(part: [5, 2], kind: .MIMEHeader), offset: nil)))
                ),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "NIL body with UID attribute",
            input: "* 3 FETCH (BODY[3] NIL UID 456)\r\n",
            expectation: [
                .fetch(.start(3)),
                .fetch(.simpleAttribute(.nilBody(.body(section: .init(part: [3]), offset: nil)))),
                .fetch(.simpleAttribute(.uid(456))),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "Binary section streaming",
            input: "* 3 FETCH (BINARY[4] {3}\r\nghi)\r\n",
            expectation: [
                .fetch(.start(3)),
                .fetch(.streamingBegin(kind: .binary(section: [4], offset: nil), byteCount: 3)),
                .fetch(.streamingBytes("ghi")),
                .fetch(.streamingEnd),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "Binary section as NIL",
            input: "* 3 FETCH (BINARY[4] NIL)\r\n",
            expectation: [
                .fetch(.start(3)),
                .fetch(.simpleAttribute(.nilBody(.binary(section: [4], offset: nil)))),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "Body with text section and offset",
            input: "* 4 FETCH (BODY[4.TEXT]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
            expectation: [
                .fetch(.start(4)),
                .fetch(
                    .streamingBegin(kind: .body(section: .init(part: [4], kind: .text), offset: 4), byteCount: 3)
                ),
                .fetch(.streamingBytes("abc")),
                .fetch(.streamingEnd),
                .fetch(.simpleAttribute(.flags([.seen, .answered]))),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "Body with text section using quoted string",
            input: "* 5 FETCH (BODY[5.TEXT]<4> \"asdf\" FLAGS (\\seen \\answered))\r\n",
            expectation: [
                .fetch(.start(5)),
                .fetch(
                    .streamingBegin(kind: .body(section: .init(part: [5], kind: .text), offset: 4), byteCount: 4)
                ),
                .fetch(.streamingBytes("asdf")),
                .fetch(.streamingEnd),
                .fetch(.simpleAttribute(.flags([.seen, .answered]))),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "Body with multi-part section",
            input: "* 6 FETCH (BODY[5.2]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
            expectation: [
                .fetch(.start(6)),
                .fetch(
                    .streamingBegin(
                        kind: .body(section: .init(part: [5, 2], kind: .complete), offset: 4),
                        byteCount: 3
                    )
                ),
                .fetch(.streamingBytes("abc")),
                .fetch(.streamingEnd),
                .fetch(.simpleAttribute(.flags([.seen, .answered]))),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "Body with header section",
            input: "* 7 FETCH (BODY[5.2.HEADER]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
            expectation: [
                .fetch(.start(7)),
                .fetch(
                    .streamingBegin(
                        kind: .body(section: .init(part: [5, 2], kind: .header), offset: 4),
                        byteCount: 3
                    )
                ),
                .fetch(.streamingBytes("abc")),
                .fetch(.streamingEnd),
                .fetch(.simpleAttribute(.flags([.seen, .answered]))),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "RFC822.TEXT streaming",
            input: "* 8 FETCH (RFC822.TEXT {3}\r\nabc)\r\n",
            expectation: [
                .fetch(.start(8)),
                .fetch(.streamingBegin(kind: .rfc822Text, byteCount: 3)),
                .fetch(.streamingBytes("abc")),
                .fetch(.streamingEnd),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "RFC822.HEADER streaming",
            input: "* 9 FETCH (RFC822.HEADER {3}\r\nabc)\r\n",
            expectation: [
                .fetch(.start(9)),
                .fetch(.streamingBegin(kind: .rfc822Header, byteCount: 3)),
                .fetch(.streamingBytes("abc")),
                .fetch(.streamingEnd),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "Binary empty section",
            input: "* 1 FETCH (BINARY[] {4}\r\n1234)\r\n",
            expectation: [
                .fetch(.start(1)),
                .fetch(.streamingBegin(kind: .binary(section: [], offset: nil), byteCount: 4)),
                .fetch(.streamingBytes("1234")),
                .fetch(.streamingEnd),
                .fetch(.finish),
            ]
        ),
        FetchResponseFixture(
            name: "UID fetch with binary and offset",
            input: "* 2 UIDFETCH (BINARY[1.2]<77> {4}\r\n1234)\r\n",
            expectation: [
                .fetch(.startUID(2)),
                .fetch(.streamingBegin(kind: .binary(section: [1, 2], offset: 77), byteCount: 4)),
                .fetch(.streamingBytes("1234")),
                .fetch(.streamingEnd),
                .fetch(.finish),
            ]
        ),
    ])
    func `parse fetch responses`(_ fixture: FetchResponseFixture) throws {
        var buffer = ByteBuffer(string: fixture.input)
        var parser = ResponseParser()

        for expected in fixture.expectation {
            let actual = try parser.parseResponseStream(buffer: &buffer)
            #expect(actual == .response(expected), "Mismatch in response sequence")
        }

        #expect(buffer.readableBytes == 0, "All bytes should be consumed")
    }
}
