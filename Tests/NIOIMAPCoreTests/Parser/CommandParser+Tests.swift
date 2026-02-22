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

@Suite("CommandParser")
struct CommandParserTests {
    // MARK: - Initialization

    @Test("default buffer size is 8192")
    func defaultBufferSizeIs8192() {
        let parser = CommandParser()
        #expect(parser.bufferLimit == 8_192)
    }

    @Test("custom buffer size is respected")
    func customBufferSizeIsRespected() {
        let parser = CommandParser(bufferLimit: 80_000)
        #expect(parser.bufferLimit == 80_000)
    }

    // MARK: - Integration Tests

    @Test("parse empty byte buffer for APPEND does not return empty bytes")
    func parseEmptyByteBufferForAppendDoesNotReturnEmptyBytes() throws {
        // Test that we don't just get returned an empty byte case if
        // we haven't yet received any literal data from the network
        var input = ByteBuffer("1 APPEND INBOX {5}\r\n")  // everything except the literal data
        var parser = CommandParser()
        #expect(try parser.parseCommandStream(buffer: &input) != nil)
        #expect(try parser.parseCommandStream(buffer: &input) != nil)

        // At this point we should have parsed off all the metadata
        // so should be ready for the literal
        var literalBuffer = ByteBuffer(string: "")
        #expect(try parser.parseCommandStream(buffer: &literalBuffer) == nil)
    }

    @Test("parse with LF missing from newline")
    func parseWithLfMissingFromNewline() throws {
        // The FramingParser might split the CRLF newline into CR only (LF in the "next frame").
        // We thus need to be able to parse this:
        var inputA = ByteBuffer("A26 UID FETCH 1:10002 (UID FLAGS MODSEQ)\r")
        var parser = CommandParser()

        #expect(
            try parser.parseCommandStream(buffer: &inputA)
                == .init(
                    .tagged(
                        .init(
                            tag: "A26",
                            command: .uidFetch(
                                messages: UIDSet([1...10002]),
                                attributes: [.uid, .flags, .modificationSequence],
                                modifiers: []
                            )!
                        )
                    ),
                    numberOfSynchronisingLiterals: 0
                )
        )

        // Send in another line:
        var inputB = ByteBuffer("A27 UID FETCH 2:22 (UID FLAGS)\r")
        #expect(
            try parser.parseCommandStream(buffer: &inputB)
                == .init(
                    .tagged(
                        .init(
                            tag: "A27",
                            command: .uidFetch(messages: UIDSet([2...22]), attributes: [.uid, .flags], modifiers: [])!
                        )
                    ),
                    numberOfSynchronisingLiterals: 0
                )
        )
    }

    @Test("normal usage parses commands correctly")
    func normalUsageParsesCommandsCorrectly() throws {
        var input = ByteBuffer("")
        var parser = CommandParser()

        #expect(try parser.parseCommandStream(buffer: &input) == nil)

        input = "1 NOOP\r\n"
        #expect(
            try parser.parseCommandStream(buffer: &input)
                == .init(.tagged(.init(tag: "1", command: .noop)), numberOfSynchronisingLiterals: 0)
        )
        #expect(input == "")

        input = "2 LOGIN {0}\r\n {0}\r\n\r\n"
        #expect(
            try parser.parseCommandStream(buffer: &input)
                == .init(
                    .tagged(.init(tag: "2", command: .login(username: "", password: ""))),
                    numberOfSynchronisingLiterals: 2
                )
        )
        #expect(input == "")

        input = "3 APPEND INBOX {3+}\r\n123 {3+}\r\n456 {3+}\r\n789\r\n"
        #expect(
            try parser.parseCommandStream(buffer: &input)
                == .init(.append(.start(tag: "3", appendingTo: .inbox)), numberOfSynchronisingLiterals: 0)
        )
        #expect(input == " {3+}\r\n123 {3+}\r\n456 {3+}\r\n789\r\n")
    }

    @Test(
        "random data does not crash parser",
        arguments: [
            Array("+000000000000000000000000000000000000000000000000000000000}\n".utf8),
            Array("eSequence468117eY SEARCH 4:1 000,0\n000059?000000600=)O".utf8),
            [
                0x41, 0x5D, 0x20, 0x55, 0x49, 0x44, 0x20, 0x43, 0x4F, 0x50, 0x59, 0x20, 0x35, 0x2C, 0x35, 0x3A, 0x34,
                0x00, 0x3D, 0x0C, 0x0A, 0x43, 0x20, 0x22, 0xE8
            ]
        ]
    )
    func randomDataDoesNotCrashParser(input: [UInt8]) {
        var parser = CommandParser()
        do {
            var buffer = ByteBuffer(bytes: input)
            var lastReadableBytes = buffer.readableBytes
            var newReadableBytes = 0
            while newReadableBytes < lastReadableBytes {
                lastReadableBytes = buffer.readableBytes
                _ = try parser.parseCommandStream(buffer: &buffer)
                newReadableBytes = buffer.readableBytes
            }
        } catch {
            // Parser may throw errors on invalid input, which is expected
        }
    }

    // MARK: - Grammar Parser Tests

    @Test(
        "parseString parses quoted and literal strings",
        arguments: [
            ParseFixture.string(#""foo""#, " ", expected: .success(ByteBuffer(string: "foo"))),
            ParseFixture.string(#""f\"oo""#, " ", expected: .success(ByteBuffer(string: #"f"oo"#))),
            ParseFixture.string(#""f\\oo""#, " ", expected: .success(ByteBuffer(string: #"f\oo"#))),
            ParseFixture.string("{3}\r\nfoo", " ", expected: .success(ByteBuffer(string: "foo"))),
            ParseFixture.string(#""aäb""#, " ", expected: .success(ByteBuffer(string: "aäb"))),
            ParseFixture.string(#"foo"#, " ", expected: .failure),
            ParseFixture.string(#" "foo""#, " ", expected: .failure)
        ]
    )
    func parseStringParsesQuotedAndLiteralStrings(_ fixture: ParseFixture<ByteBuffer>) {
        fixture.checkParsing()
    }

    @Test(
        "parseStringAllowingNonASCII parses strings with non-ASCII characters",
        arguments: [
            ParseFixture.stringAllowingNonASCII(#""foo""#, " ", expected: .success(ByteBuffer(string: "foo"))),
            ParseFixture.stringAllowingNonASCII(#""äø""#, " ", expected: .success(ByteBuffer(string: "äø"))),
            ParseFixture.stringAllowingNonASCII(#""ä\"ø""#, " ", expected: .success(ByteBuffer(string: #"ä"ø"#))),
            ParseFixture.stringAllowingNonASCII(#""ä\\ø""#, " ", expected: .success(ByteBuffer(string: #"ä\ø"#))),
            ParseFixture.stringAllowingNonASCII("{3}\r\nfoo", " ", expected: .success(ByteBuffer(string: "foo")))
        ]
    )
    func parseStringAllowingNonAsciiParsesStringsWithNonAsciiCharacters(_ fixture: ParseFixture<ByteBuffer>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension ParseFixture<ByteBuffer> {
    fileprivate static func string(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseString
        )
    }

    fileprivate static func stringAllowingNonASCII(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStringAllowingNonASCII
        )
    }
}
