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

@Suite("ResponseParser")
struct ResponseParserTests {
    @Test("CommandParser uses default buffer size")
    func commandParserUsesDefaultBufferSize() {
        let parser = CommandParser()
        #expect(parser.bufferLimit == 8_192)
    }

    @Test("CommandParser uses custom buffer size")
    func commandParserUsesCustomBufferSize() {
        let parser = CommandParser(bufferLimit: 80_000)
        #expect(parser.bufferLimit == 80_000)
    }

    @Test("attempt to stream bytes from empty buffer")
    func attemptToStreamBytesFromEmptyBuffer() throws {
        var parser = ResponseParser()
        var buffer: ByteBuffer = ""

        // set up getting ready to stream a response
        buffer = "* 1 FETCH (BODY[TEXT]<4> {10}\r\n"
        #expect(try parser.parseResponseStream(buffer: &buffer) != nil)
        #expect(try parser.parseResponseStream(buffer: &buffer) != nil)

        // now send an empty buffer for parsing, expect nil
        buffer = ""
        #expect(try parser.parseResponseStream(buffer: &buffer) == nil)
        #expect(try parser.parseResponseStream(buffer: &buffer) == nil)
        #expect(try parser.parseResponseStream(buffer: &buffer) == nil)
        #expect(try parser.parseResponseStream(buffer: &buffer) == nil)

        // send some bytes to make sure it's worked
        buffer = "0123456789"
        #expect(
            try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.streamingBytes("0123456789")))
        )
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.streamingEnd)))
    }

    @Test("parse incomplete invalid body structure")
    func parseIncompleteInvalidBodyStructure() throws {
        //
        // When parsing an incomplete buffer, parseInvalidBody() will throw an
        // IncompleteMessage error. This needs to _not_ fail the parsing, but instead
        // bubble up to parseResponseStream() which will then wait for more data.
        //
        var buffer = ByteBuffer(
            string: #"""
                * 61785 FETCH (UID 127139 BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 71399 1519 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 659725 9831 NIL NIL NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "H9eubHenuyTiQAAAABJRU5ErkJggg==.png") "<5079C210-D42C-49F4-A942-2BA779C88A96>" NIL "BASE64" 104028 NIL ("INLINE" ("FILENAME" "H9eubHenuyTiQAAAABJRU5ErkJggg==.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "IAEJCABCUhAAhKQgAQkIAEJSEACEpCABCQgAQlIQAISkIAEJNAKAQMdW8HsSSQgAQlIQAISkIAEJCABCUhAAhKQgAQkIAEJSEACEpCABCQgAQlIQAISkIAEJCABCUhAA") "<23E8CC74-836D-4B45-8B1E-1CF023182729>" NIL "BASE64" 55168 NIL ("INLINE" ("FILENAME" {4138}\#r\#naaaaaaaa
                """#
        )
        var parser = ResponseParser()
        let results = try {
            var results: [ResponseOrContinuationRequest] = []
            while buffer.readableBytes > 0 {
                guard let resp = try parser.parseResponseStream(buffer: &buffer) else { break }
                results.append(resp)
            }
            return results
        }()
        #expect(
            results == [
                .response(.fetch(.start(617_85))),
                .response(.fetch(.simpleAttribute(.uid(127_139)))),
            ]
        )
    }

    @Test("attribute limit fails on streaming")
    func attributeLimitFailsOnStreaming() throws {
        var parser = ResponseParser(
            options: ResponseParser.Options(
                bufferLimit: 1000,
                messageAttributeLimit: 3
            )
        )
        var buffer: ByteBuffer = "* 999 FETCH (FLAGS (\\Seen) UID 1 RFC822.SIZE 123 RFC822.TEXT {3}\r\n "

        // limit is 3, so let's parse the first 3
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.start(999))))
        #expect(
            try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.simpleAttribute(.flags([.seen]))))
        )
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.simpleAttribute(.uid(1)))))
        #expect(
            try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.simpleAttribute(.rfc822Size(123))))
        )

        // the limit is 3, so the fourth should fail
        #expect(throws: ExceededMaximumMessageAttributesError.self) {
            try parser.parseResponseStream(buffer: &buffer)
        }
    }

    @Test("attribute limit fails on simple")
    func attributeLimitFailsOnSimple() throws {
        var parser = ResponseParser(
            options: ResponseParser.Options(
                bufferLimit: 1000,
                messageAttributeLimit: 3
            )
        )
        var buffer: ByteBuffer = "* 999 FETCH (FLAGS (\\Seen) UID 1 RFC822.SIZE 123 UID 2 "

        // limit is 3, so let's parse the first 3
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.start(999))))
        #expect(
            try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.simpleAttribute(.flags([.seen]))))
        )
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.simpleAttribute(.uid(1)))))
        #expect(
            try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.simpleAttribute(.rfc822Size(123))))
        )

        // the limit is 3, so the fourth should fail
        #expect(throws: ExceededMaximumMessageAttributesError.self) {
            try parser.parseResponseStream(buffer: &buffer)
        }
    }

    @Test("reject large bodies")
    func rejectLargeBodies() throws {
        var parser = ResponseParser(
            options: ResponseParser.Options(
                bufferLimit: 1000,
                bodySizeLimit: 10
            )
        )
        var buffer: ByteBuffer = "* 999 FETCH (RFC822.TEXT {3}\r\n123 RFC822.HEADER {11}\r\n "
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.start(999))))
        #expect(
            try parser.parseResponseStream(buffer: &buffer)
                == .response(
                    .fetch(.streamingBegin(kind: .rfc822Text, byteCount: 3))
                )
        )
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.streamingBytes("123"))))
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.streamingEnd)))

        #expect(throws: ExceededMaximumBodySizeError.self) {
            try parser.parseResponseStream(buffer: &buffer)
        }
    }

    @Test("parse without string cache")
    func parseWithoutStringCache() throws {
        var parser = ResponseParser(
            options: ResponseParser.Options(
                bufferLimit: 1000,
                bodySizeLimit: 10
            )
        )
        var buffer: ByteBuffer = "* 999 FETCH (FLAGS (\\Seen))\r\n"
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.start(999))))
        #expect(
            try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.simpleAttribute(.flags([.seen]))))
        )
    }

    @Test("parse with string cache")
    func parseWithStringCache() throws {
        // The flag "seen" should be given to our cache closure
        // which will replace it with "nees", and therefore our
        // parse result should contain the flag "nees".
        var parser = ResponseParser(
            options: ResponseParser.Options(
                bufferLimit: 1000,
                bodySizeLimit: 10,
                parsedStringCache: { string in
                    #expect(string.lowercased() == "seen")
                    return "nees"
                }
            )
        )
        var buffer: ByteBuffer = "* 999 FETCH (FLAGS (\\Seen))\r\n"
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.start(999))))
        #expect(
            try parser.parseResponseStream(buffer: &buffer)
                == .response(
                    .fetch(.simpleAttribute(.flags([.init("\\nees")])))
                )
        )
    }

    @Test("separate literal size limit")
    func separateLiteralSizeLimit() throws {
        // Even with a `literalSizeLimit` of 1 parsing a RFC822.TEXT should _not_ fail
        // if the `bodySizeLimit` is large enough.
        var parser = ResponseParser(
            options: ResponseParser.Options(
                bufferLimit: 1000,
                bodySizeLimit: 10,
                literalSizeLimit: 1
            )
        )
        var buffer: ByteBuffer = "* 999 FETCH (RFC822.TEXT {3}\r\n123 RFC822.HEADER {11}\r\n "
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.start(999))))
        #expect(
            try parser.parseResponseStream(buffer: &buffer)
                == .response(
                    .fetch(.streamingBegin(kind: .rfc822Text, byteCount: 3))
                )
        )
    }

    @Test("state is enforced")
    func stateIsEnforced() throws {
        var parser = ResponseParser()
        var input = ByteBuffer(string: "* 1 FETCH (* 2 FETCH \n")

        #expect(try parser.parseResponseStream(buffer: &input) == .response(.fetch(.start(1))))
        #expect(throws: (any Error).self) {
            try parser.parseResponseStream(buffer: &input)
        }
    }

    @Test("parse untagged non-fetch response")
    func parseUntaggedNonFetchResponse() throws {
        // An EXISTS response is not a FETCH, so parseResponse_fetch fails and
        // parseResponse_normal succeeds, exercising the .untaggedResponse branch.
        var parser = ResponseParser()
        var buffer: ByteBuffer = "* 5 EXISTS\r\n"
        let result = try parser.parseResponseStream(buffer: &buffer)
        #expect(result == .response(.untagged(.mailboxData(.exists(5)))))
    }
}

