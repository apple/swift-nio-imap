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
        var buffer: IMAPInputBuffer = ""

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
        var buffer = IMAPInputBuffer(
            #"""
            * 61785 FETCH (UID 127139 BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 71399 1519 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 659725 9831 NIL NIL NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "H9eubHenuyTiQAAAABJRU5ErkJggg==.png") "<5079C210-D42C-49F4-A942-2BA779C88A96>" NIL "BASE64" 104028 NIL ("INLINE" ("FILENAME" "H9eubHenuyTiQAAAABJRU5ErkJggg==.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "IAEJCABCUhAAhKQgAQkIAEJSEACEpCABCQgAQlIQAISkIAEJNAKAQMdW8HsSSQgAQlIQAISkIAEJCABCUhAAhKQgAQkIAEJSEACEpCABCQgAQlIQAISkIAEJCABCUhAA") "<23E8CC74-836D-4B45-8B1E-1CF023182729>" NIL "BASE64" 55168 NIL ("INLINE" ("FILENAME" {4138}\#r\#naaaaaaaa
            """#
        )
        var parser = ResponseParser()
        let results = try {
            var results: [ResponseOrContinuationRequest] = []
            while buffer.count > 0 {
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
        var buffer: IMAPInputBuffer = "* 999 FETCH (FLAGS (\\Seen) UID 1 RFC822.SIZE 123 RFC822.TEXT {3}\r\n "

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
        var buffer: IMAPInputBuffer = "* 999 FETCH (FLAGS (\\Seen) UID 1 RFC822.SIZE 123 UID 2 "

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
        var buffer: IMAPInputBuffer = "* 999 FETCH (RFC822.TEXT {3}\r\n123 RFC822.HEADER {11}\r\n "
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

    /// An error from untyped API the grammar calls reaches the caller as thrown.
    @Test("non-parser error is thrown unwrapped")
    func nonParserErrorIsThrownUnwrapped() {
        var parser = ResponseParser()
        // `&AA-` decodes to one byte; modified UTF-7 needs an even count.
        var buffer: IMAPInputBuffer = "* ID (\"name\" \"&AA-\")\r\n"
        #expect(throws: ModifiedUTF7.OddByteCountError.self) {
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
        var buffer: IMAPInputBuffer = "* 999 FETCH (FLAGS (\\Seen))\r\n"
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
        var buffer: IMAPInputBuffer = "* 999 FETCH (FLAGS (\\Seen))\r\n"
        #expect(try parser.parseResponseStream(buffer: &buffer) == .response(.fetch(.start(999))))
        #expect(
            try parser.parseResponseStream(buffer: &buffer)
                == .response(
                    .fetch(.simpleAttribute(.flags([#"\nees"#])))
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
        var buffer: IMAPInputBuffer = "* 999 FETCH (RFC822.TEXT {3}\r\n123 RFC822.HEADER {11}\r\n "
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
        var input = IMAPInputBuffer("* 1 FETCH (* 2 FETCH \n")

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
        var buffer: IMAPInputBuffer = "* 5 EXISTS\r\n"
        let result = try parser.parseResponseStream(buffer: &buffer)
        #expect(result == .response(.untagged(.mailboxData(.exists(5)))))
    }
}

// MARK: - Literal header CRLF split across reads

extension ResponseParserTests {
    /// Feeds each chunk to a parser as if it had just been read from the network, keeping
    /// unconsumed bytes for the next read, like `ResponseDecoder` does. Adjacent
    /// `.streamingBytes` are merged, since how they're divided depends on the chunking.
    private func parse(_ chunks: [String]) throws -> [Response] {
        try self.parse(chunks.map { Array($0.utf8) })
    }

    private func parse(_ chunks: [[UInt8]]) throws -> [Response] {
        var parser = ResponseParser()
        var buffer = IMAPInputBuffer()
        var result: [Response] = []
        for chunk in chunks {
            buffer.append(chunk)
            while let next = try parser.parseResponseStream(buffer: &buffer) {
                guard case .response(let response) = next else {
                    Issue.record("Unexpected continuation request: \(next)")
                    continue
                }
                if case .fetch(.streamingBytes(let bytes)) = response,
                    case .fetch(.streamingBytes(let merged)) = result.last
                {
                    let combined = IMAPBuffer(merged.copiedBytes() + bytes.copiedBytes())
                    result[result.count - 1] = .fetch(.streamingBytes(combined))
                } else {
                    result.append(response)
                }
            }
        }
        #expect(buffer.isEmpty)
        return result
    }

    private func fetch(_ bytes: IMAPBuffer) -> [Response] {
        [
            .fetch(.start(1)),
            .fetch(.streamingBegin(kind: .body(section: .init(), offset: nil), byteCount: bytes.count)),
            .fetch(.streamingBytes(bytes)),
            .fetch(.streamingEnd),
            .fetch(.finish),
        ]
    }

    @Test("a message isn't corrupted when the CRLF of its literal header is split across reads")
    func literalHeaderSplitDoesNotCorruptMessage() throws {
        // Messages usually end in a line feed. That one used to be silently lost, with the line
        // feed of the header taking the place of the first byte of the message.
        let message = "Subject: Hi\r\n\r\nBody\r\n"
        #expect(
            try self.parse(["* 1 FETCH (BODY[] {\(message.utf8.count)}\r", "\n\(message))\r\n"])
                == self.fetch(IMAPBuffer(Array(message.utf8)))
        )
    }

    @Test(
        "a split literal header gives the same result as an unsplit one",
        arguments: [
            "BODY[]",
            "BODY[TEXT]<4>",
            "BODY[HEADER.FIELDS (SUBJECT)]",
            "RFC822.TEXT",
            "RFC822.HEADER",
            "BINARY[1]",
            "BINARY[1]<5>",
        ],
        ["", "~"]
    )
    func splitLiteralHeaderForEachAttribute(attribute: String, literalPrefix: String) throws {
        let content = "\nHi\r\n"
        let header = "* 1 FETCH (\(attribute) \(literalPrefix){\(content.utf8.count)}\r"
        let rest = "\n\(content) UID 7)\r\n"

        let expected = try self.parse([header + rest])
        #expect(expected.contains(.fetch(.streamingBytes(IMAPBuffer(Array(content.utf8))))))
        #expect(try self.parse([header, rest]) == expected)
        #expect(try self.parse(Array((header + rest).utf8).map { [$0] }) == expected)
    }

    @Test("every way of splitting a FETCH with a literal across two reads gives the same result")
    func everySplitOfFetchWithLiteral() throws {
        let content = "\nHi\r\n\nThere\r\n"
        let wire = Array("* 1 FETCH (BODY[] {\(content.utf8.count)}\r\n\(content) UID 7)\r\n* 2 EXISTS\r\n".utf8)

        let expected = try self.parse([wire])
        #expect(expected.contains(.fetch(.streamingBytes(IMAPBuffer(Array(content.utf8))))))
        #expect(expected.last == .untagged(.mailboxData(.exists(2))))

        for cut in 1..<wire.count {
            #expect(try self.parse([Array(wire[..<cut]), Array(wire[cut...])]) == expected, "split after byte \(cut)")
        }
    }

    @Test("the line feed of a literal header can arrive on its own")
    func literalHeaderLineFeedOnItsOwn() throws {
        #expect(
            try self.parse(["* 1 FETCH (BODY[] {3}\r", "\n", "abc)\r\n"]) == self.fetch("abc")
        )
    }

    @Test("only the line feed of the literal header is skipped, not those in the literal")
    func lineFeedsInLiteralAreKept() throws {
        // First byte of the literal is a line feed, as is the first byte of a later read.
        #expect(
            try self.parse(["* 1 FETCH (BODY[] {4}\r", "\n\na", "\n", "\n)\r\n"])
                == self.fetch("\na\n\n")
        )
        // Without a split, a line feed at the start of the literal is part of the literal.
        #expect(try self.parse(["* 1 FETCH (BODY[] {2}\r\n", "\na)\r\n"]) == self.fetch("\na"))
    }

    @Test("a line feed following a literal with a split header is not skipped as well")
    func lineFeedAfterLiteralIsNotSkipped() throws {
        // The line feed of the header has been dealt with. What follows the literal is invalid,
        // and must be treated as such.
        #expect(throws: (any Error).self) {
            try self.parse(["* 1 FETCH (BODY[] {1}\r", "\na", "\n)\r\n"])
        }
    }

    @Test("a zero-length literal with a split header")
    func zeroLengthLiteralWithSplitHeader() throws {
        let expected: [Response] = [
            .fetch(.start(1)),
            .fetch(.streamingBegin(kind: .body(section: .init(), offset: nil), byteCount: 0)),
            .fetch(.streamingEnd),
            .fetch(.finish),
        ]
        #expect(try self.parse(["* 1 FETCH (BODY[] {0}\r", "\n)\r\n"]) == expected)
        #expect(try self.parse(["* 1 FETCH (BODY[] {0}\r", "\n", ")\r\n"]) == expected)
    }

    @Test("each literal in a FETCH can have a split header")
    func multipleLiteralsWithSplitHeaders() throws {
        let kind = StreamingKind.rfc822Text
        #expect(
            try self.parse(["* 1 FETCH (RFC822.TEXT {2}\r", "\nab RFC822.TEXT {2}\r", "\ncd)\r\n"])
                == [
                    .fetch(.start(1)),
                    .fetch(.streamingBegin(kind: kind, byteCount: 2)),
                    .fetch(.streamingBytes("ab")),
                    .fetch(.streamingEnd),
                    .fetch(.streamingBegin(kind: kind, byteCount: 2)),
                    .fetch(.streamingBytes("cd")),
                    .fetch(.streamingEnd),
                    .fetch(.finish),
                ]
        )
    }

    @Test("a literal header ending in a bare CR is still accepted")
    func literalHeaderEndingInBareCR() throws {
        #expect(try self.parse(["* 1 FETCH (BODY[] {3}\rabc)\r\n"]) == self.fetch("abc"))
        #expect(try self.parse(["* 1 FETCH (BODY[] {3}\r", "abc)\r\n"]) == self.fetch("abc"))
    }

    // An ENVELOPE isn't streamed, so the newline ending its literal header doesn't end a parse step.
    private static func envelope(literalHeaderNewline: String) -> String {
        "ENVELOPE (NIL {3}\(literalHeaderNewline)abc NIL NIL NIL NIL NIL NIL NIL NIL)"
    }

    @Test(
        "a line feed after a non-streamed literal with a bare CR header is not skipped",
        arguments: [" UID 1)\r\n", ")\r\n"]
    )
    func lineFeedAfterNonStreamedLiteralIsNotSkipped(rest: String) {
        // The CR doesn't end the response, so the LF is invalid, as after a CRLF header.
        for newline in ["\r\n", "\r"] {
            let start = "* 1 FETCH (\(Self.envelope(literalHeaderNewline: newline))"
            for chunks in [[start, "\n\(rest)"], [start + "\n\(rest)"]] {
                #expect(throws: ParserError.self, "\(chunks)") { try self.parse(chunks) }
            }
        }
    }

    @Test("every way of splitting a FETCH with a non-streamed literal across two reads gives the same result")
    func everySplitOfFetchWithNonStreamedLiteral() throws {
        let wire = Array("* 1 FETCH (\(Self.envelope(literalHeaderNewline: "\r")) UID 1)\r\n* 2 EXISTS\r\n".utf8)

        let expected = try self.parse([wire])
        #expect(
            expected.contains {
                guard case .fetch(.simpleAttribute(.envelope(let envelope))) = $0 else { return false }
                return envelope.subject == "abc"
            }
        )
        #expect(expected.last == .untagged(.mailboxData(.exists(2))))

        for cut in 1..<wire.count {
            #expect(try self.parse([Array(wire[..<cut]), Array(wire[cut...])]) == expected, "split after byte \(cut)")
        }
    }

    @Test("an invalid literal header is rejected")
    func invalidLiteralHeaderIsRejected() {
        #expect(throws: (any Error).self) {
            try self.parse(["* 1 FETCH (BODY[] {3}x", "abc)\r\n"])
        }
    }
}
