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

    @Test("isStreamingAppend is false for non-streaming modes")
    func isStreamingAppendIsFalseForNonStreamingModes() {
        #expect(!CommandParser.Mode.lines.isStreamingAppend)
        #expect(!CommandParser.Mode.idle.isStreamingAppend)
        #expect(!CommandParser.Mode.waitingForMessage.isStreamingAppend)
        #expect(!CommandParser.Mode.streamingEnd.isStreamingAppend)
        #expect(!CommandParser.Mode.waitingForCatenatePart(seenPreviousPart: false).isStreamingAppend)
        #expect(!CommandParser.Mode.streamingCatenateBytes(1).isStreamingAppend)
        #expect(!CommandParser.Mode.streamingCatenateEnd.isStreamingAppend)
    }

    @Test("isStreamingAppend is true only for streamingBytes mode")
    func isStreamingAppendIsTrueOnlyForStreamingBytesMode() {
        #expect(CommandParser.Mode.streamingBytes(1).isStreamingAppend)
    }

    // MARK: - Integration Tests

    @Test("stray spaces before the CRLF are tolerated up to a cap")
    func straySpacesBeforeCRLF() throws {
        var parser = CommandParser()
        var input = IMAPInputBuffer("tag NOOP" + String(repeating: " ", count: ParseInput.maximumStraySpaces) + "\r\n")
        #expect(try parser.parseCommandStream(buffer: &input) != nil)
    }

    @Test("an excessive run of stray spaces before the CRLF is a parser error")
    func excessiveSpacesBeforeCRLF() {
        var parser = CommandParser(bufferLimit: 1_000_000)
        let spaces = String(repeating: " ", count: ParseInput.maximumStraySpaces + 1)
        var input = IMAPInputBuffer("tag NOOP" + spaces + "\r\n")
        #expect(throws: ParserError.self) {
            try parser.parseCommandStream(buffer: &input)
        }
    }

    /// Regression pin. Each `(` of a SEARCH costs one `composite` frame (the `parseOneOf` alternative);
    /// the rest of the 100-frame budget (`StackTracker.makeNewDefault`) goes to the productions above it.
    /// Leaf parsers cost no frame. If depth tracking changes, update this deliberately.
    private static let deepestParsableSearchNesting = 90

    @Test("SEARCH nesting is cut off at a pinned depth")
    func searchNestingDepthBoundary() throws {
        func parse(nesting: Int) throws -> SynchronizedCommand? {
            var parser = CommandParser(bufferLimit: 1_000_000)
            let open = String(repeating: "(", count: nesting)
            let close = String(repeating: ")", count: nesting)
            var input = IMAPInputBuffer("tag SEARCH \(open)ALL\(close)\r\n")
            return try parser.parseCommandStream(buffer: &input)
        }
        #expect(try parse(nesting: Self.deepestParsableSearchNesting) != nil)
        #expect(throws: TooMuchRecursion.self) {
            try parse(nesting: Self.deepestParsableSearchNesting + 1)
        }
    }

    @Test("parse empty input for APPEND does not return empty bytes")
    func parseEmptyInputForAppendDoesNotReturnEmptyBytes() throws {
        // Test that we don't just get returned an empty byte case if
        // we haven't yet received any literal data from the network
        var input = IMAPInputBuffer("1 APPEND INBOX {5}\r\n")  // everything except the literal data
        var parser = CommandParser()
        #expect(try parser.parseCommandStream(buffer: &input) != nil)
        #expect(try parser.parseCommandStream(buffer: &input) != nil)

        // At this point we should have parsed off all the metadata
        // so should be ready for the literal
        var literalBuffer = IMAPInputBuffer("")
        #expect(try parser.parseCommandStream(buffer: &literalBuffer) == nil)
    }

    @Test("parse with LF missing from newline")
    func parseWithLfMissingFromNewline() throws {
        // The FramingParser might split the CRLF newline into CR only (LF in the "next frame").
        // We thus need to be able to parse this:
        var inputA = IMAPInputBuffer("A26 UID FETCH 1:10002 (UID FLAGS MODSEQ)\r")
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
        var inputB = IMAPInputBuffer("A27 UID FETCH 2:22 (UID FLAGS)\r")
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
        var input = IMAPInputBuffer("")
        var parser = CommandParser()

        #expect(try parser.parseCommandStream(buffer: &input) == nil)

        input = "1 NOOP\r\n"
        #expect(
            try parser.parseCommandStream(buffer: &input)
                == .init(.tagged(.init(tag: "1", command: .noop)), numberOfSynchronisingLiterals: 0)
        )
        #expect(input.remainingText == "")

        input = "2 LOGIN {0}\r\n {0}\r\n\r\n"
        #expect(
            try parser.parseCommandStream(buffer: &input)
                == .init(
                    .tagged(.init(tag: "2", command: .login(username: "", password: ""))),
                    numberOfSynchronisingLiterals: 2
                )
        )
        #expect(input.remainingText == "")

        input = "3 APPEND INBOX {3+}\r\n123 {3+}\r\n456 {3+}\r\n789\r\n"
        #expect(
            try parser.parseCommandStream(buffer: &input)
                == .init(.append(.start(tag: "3", appendingTo: .inbox)), numberOfSynchronisingLiterals: 0)
        )
        #expect(input.remainingText == " {3+}\r\n123 {3+}\r\n456 {3+}\r\n789\r\n")
    }

    @Test(
        "random data does not crash parser",
        arguments: [
            Array("+000000000000000000000000000000000000000000000000000000000}\n".utf8),
            Array("eSequence468117eY SEARCH 4:1 000,0\n000059?000000600=)O".utf8),
            [
                0x41, 0x5D, 0x20, 0x55, 0x49, 0x44, 0x20, 0x43, 0x4F, 0x50, 0x59, 0x20, 0x35, 0x2C, 0x35, 0x3A, 0x34,
                0x00, 0x3D, 0x0C, 0x0A, 0x43, 0x20, 0x22, 0xE8,
            ],
        ]
    )
    func randomDataDoesNotCrashParser(input: [UInt8]) {
        var parser = CommandParser()
        do {
            var buffer = IMAPInputBuffer(input)
            var lastRemaining = buffer.count
            var newRemaining = 0
            while newRemaining < lastRemaining {
                lastRemaining = buffer.count
                _ = try parser.parseCommandStream(buffer: &buffer)
                newRemaining = buffer.count
            }
        } catch {
            // Parser may throw errors on invalid input, which is expected
        }
    }

    // MARK: - Grammar Parser Tests

    @Test(
        "parseString parses quoted and literal strings",
        arguments: [
            ParseFixture.string(#""foo""#, " ", expected: .success("foo")),
            ParseFixture.string(#""f\"oo""#, " ", expected: .success(#"f"oo"#)),
            ParseFixture.string(#""f\\oo""#, " ", expected: .success(#"f\oo"#)),
            ParseFixture.string("{3}\r\nfoo", " ", expected: .success("foo")),
            ParseFixture.string(#""aäb""#, " ", expected: .success("aäb")),
            ParseFixture.string(#"foo"#, " ", expected: .failure),
            ParseFixture.string(#" "foo""#, " ", expected: .failure),
            ParseFixture.string(
                "{\(IMAPDefaults.literalSizeLimit + 1)}\r\n",
                " ",
                expected: .failureThrowing(ExceededLiteralSizeLimitError.self)
            ),
        ]
    )
    func parseStringParsesQuotedAndLiteralStrings(_ fixture: ParseFixture<[UInt8]>) {
        fixture.checkParsing()
    }

    @Test(
        "parseLiteralLength enforces the literal size limit",
        arguments: [
            ParseFixture.literalLength(
                "\(IMAPDefaults.literalSizeLimit)",
                "}",
                expected: .success(IMAPDefaults.literalSizeLimit)
            ),
            // Throws after consuming the digits; callers restore.
            ParseFixture.literalLength(
                "\(IMAPDefaults.literalSizeLimit + 1)",
                "}",
                expected: .failureIgnoringBufferModificationsThrowing(ExceededLiteralSizeLimitError.self)
            ),
        ]
    )
    func parseLiteralLengthEnforcesLimit(_ fixture: ParseFixture<Int>) {
        fixture.checkParsing()
    }

    @Test(
        "parseStringAllowingNonASCII parses strings with non-ASCII characters",
        arguments: [
            ParseFixture.stringAllowingNonASCII(#""foo""#, " ", expected: .success("foo")),
            ParseFixture.stringAllowingNonASCII(#""äø""#, " ", expected: .success("äø")),
            ParseFixture.stringAllowingNonASCII(#""ä\"ø""#, " ", expected: .success(#"ä"ø"#)),
            ParseFixture.stringAllowingNonASCII(#""ä\\ø""#, " ", expected: .success(#"ä\ø"#)),
            ParseFixture.stringAllowingNonASCII("{3}\r\nfoo", " ", expected: .success("foo")),
        ]
    )
    func parseStringAllowingNonAsciiParsesStringsWithNonAsciiCharacters(_ fixture: ParseFixture<[UInt8]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension ParseFixture<[UInt8]> {
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

extension ParseFixture<Int> {
    fileprivate static func literalLength(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseLiteralLength
        )
    }
}
