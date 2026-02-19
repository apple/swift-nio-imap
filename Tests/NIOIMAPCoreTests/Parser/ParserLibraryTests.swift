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

import NIO
import Testing

@Suite("ParserLibrary")
struct ParserLibraryTests {}

// MARK: - parseOptional

extension ParserLibraryTests {
    @Test("parseOptional throws incomplete message when buffer is empty")
    func parseOptionalThrowsIncompleteMessageWhenBufferIsEmpty() {
        var buffer = TestUtilities.makeParseBuffer(for: "")
        #expect(throws: IncompleteMessage.self) {
            try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
            }
        }
    }

    @Test("parseOptional succeeds when element is present")
    func parseOptionalSucceedsWhenElementIsPresent() throws {
        var buffer = TestUtilities.makeParseBuffer(for: "x")
        try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
        }
    }

    @Test("parseOptional succeeds when element is not present")
    func parseOptionalSucceedsWhenElementIsNotPresent() throws {
        var buffer = TestUtilities.makeParseBuffer(for: "y")
        try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
        }
        #expect(buffer.readableBytes == 1)
    }

    @Test("parseOptional resets buffer correctly for composite parsers with incomplete input")
    func parseOptionalResetsBufferCorrectlyForCompositeParsersWithIncompleteInput() {
        var buffer = TestUtilities.makeParseBuffer(for: "x")
        #expect(throws: IncompleteMessage.self) {
            try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("y", buffer: &buffer, tracker: tracker)
            }
        }
        #expect(buffer.readableBytes == 1)
    }

    @Test("parseOptional resets buffer correctly for composite parsers with non-matching input")
    func parseOptionalResetsBufferCorrectlyForCompositeParsersWithNonMatchingInput() throws {
        var buffer = TestUtilities.makeParseBuffer(for: "xz")
        try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("y", buffer: &buffer, tracker: tracker)
        }
        #expect(buffer.readableBytes == 2)
    }
}

// MARK: - parseFixedString

extension ParserLibraryTests {
    @Test("parseFixedString with case sensitive matching")
    func parseFixedStringWithCaseSensitiveMatching() throws {
        var buffer = TestUtilities.makeParseBuffer(for: "fooFooFOO")

        try PL.parseFixedString(
            "fooFooFOO",
            caseSensitive: true,
            buffer: &buffer,
            tracker: .testTracker
        )

        buffer = TestUtilities.makeParseBuffer(for: "fooFooFOO")
        #expect(throws: ParserError.self) {
            try PL.parseFixedString(
                "foofoofoo",
                caseSensitive: true,
                buffer: &buffer,
                tracker: .testTracker
            )
        }

        buffer = TestUtilities.makeParseBuffer(for: "foo")
        #expect(throws: IncompleteMessage.self) {
            try PL.parseFixedString(
                "fooFooFOO",
                caseSensitive: true,
                buffer: &buffer,
                tracker: .testTracker
            )
        }
    }

    @Test("parseFixedString with case insensitive matching")
    func parseFixedStringWithCaseInsensitiveMatching() throws {
        var buffer = TestUtilities.makeParseBuffer(for: "fooFooFOO")

        try PL.parseFixedString(
            "fooFooFOO",
            buffer: &buffer,
            tracker: .testTracker
        )

        buffer = TestUtilities.makeParseBuffer(for: "fooFooFOO")
        try PL.parseFixedString(
            "foofoofoo",
            buffer: &buffer,
            tracker: .testTracker
        )

        buffer = TestUtilities.makeParseBuffer(for: "foo")
        #expect(throws: IncompleteMessage.self) {
            try PL.parseFixedString(
                "fooFooFOO",
                buffer: &buffer,
                tracker: .testTracker
            )
        }
    }

    @Test("parseFixedString rejects non-ASCII characters")
    func parseFixedStringRejectsNonAsciiCharacters() {
        var buffer = TestUtilities.makeParseBuffer(for: "fooFooFOÖ")
        #expect(throws: ParserError.self) {
            try PL.parseFixedString(
                "fooFooFOO",
                caseSensitive: true,
                buffer: &buffer,
                tracker: .testTracker
            )
        }
    }

    @Test("parseFixedString with leading spaces")
    func parseFixedStringWithLeadingSpaces() throws {
        var buffer = TestUtilities.makeParseBuffer(for: String(repeating: " ", count: 500) + "fooFooFOO")
        try PL.parseFixedString(
            "fooFooFOO",
            caseSensitive: true,
            allowLeadingSpaces: true,
            buffer: &buffer,
            tracker: .testTracker
        )
    }
}

// MARK: - parseZeroOrMore

extension ParserLibraryTests {
    @Test("parseZeroOrMore parses nothing when no match but data present")
    func parseZeroOrMoreParsesNothingWhenNoMatchButDataPresent() throws {
        TestUtilities.withParseBuffer("", terminator: "xy") { buffer in
            let result = try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                return 1
            }
            #expect(result == [])
        }
    }

    @Test("parseZeroOrMore throws incomplete message when no data")
    func parseZeroOrMoreThrowsIncompleteMessageWhenNoData() throws {
        TestUtilities.withParseBuffer("") { buffer in
            #expect(throws: IncompleteMessage.self) {
                try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                }
            }
        }
    }

    @Test("parseZeroOrMore parses one item when more data present")
    func parseZeroOrMoreParsesOneItemWhenMoreDataPresent() throws {
        TestUtilities.withParseBuffer("xx", terminator: "xy") { buffer in
            let result = try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                return 1
            }
            #expect(result == [1])
        }
    }

    @Test("parseZeroOrMore parses two items when more data present")
    func parseZeroOrMoreParsesTwoItemsWhenMoreDataPresent() throws {
        TestUtilities.withParseBuffer("xxxx", terminator: "xy") { buffer in
            let result = try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                return 1
            }
            #expect(result == [1, 1])
        }
    }
}

// MARK: - parseOneOrMore

extension ParserLibraryTests {
    @Test("parseOneOrMore throws parser error when no match but data present")
    func parseOneOrMoreThrowsParserErrorWhenNoMatchButDataPresent() throws {
        TestUtilities.withParseBuffer("", terminator: "xy") { buffer in
            #expect(throws: ParserError.self) {
                try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                }
            }
        }
    }

    @Test("parseOneOrMore throws incomplete message when no data")
    func parseOneOrMoreThrowsIncompleteMessageWhenNoData() throws {
        TestUtilities.withParseBuffer("") { buffer in
            #expect(throws: IncompleteMessage.self) {
                try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                }
            }
        }
    }

    @Test("parseOneOrMore parses one item when more data present")
    func parseOneOrMoreParsesOneItemWhenMoreDataPresent() throws {
        TestUtilities.withParseBuffer("xx", terminator: "xy") { buffer in
            let result = try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                return 1
            }
            #expect(result == [1])
        }
    }

    @Test("parseOneOrMore parses two items when more data present")
    func parseOneOrMoreParsesTwoItemsWhenMoreDataPresent() throws {
        TestUtilities.withParseBuffer("xxxx", terminator: "xy") { buffer in
            let result = try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                return 1
            }
            #expect(result == [1, 1])
        }
    }
}

// MARK: - parseSpace

extension ParserLibraryTests {
    @Test("parseSpaces consumes leading spaces", arguments: [
        (" a", "a"),
        ("       a", "a"),
        ("  a  ", "a  "),
    ])
    func parseSpacesConsumesLeadingSpaces(input: String, expectedRemaining: String) throws {
        var buffer = ParseBuffer(ByteBuffer(string: input))
        let remaining = ParseBuffer(ByteBuffer(string: expectedRemaining))
        try PL.parseSpaces(buffer: &buffer, tracker: .makeNewDefault)
        #expect(buffer == remaining)
    }
}

// MARK: - parseUInt64

extension ParserLibraryTests {
    @Test("parseUnsignedInt64 parses numbers correctly", arguments: [
        ("12345\r", 12345, 5),
        ("18446744073709551615\r", UInt64.max, 20),
        ("12345 a", 12345, 5),
        ("18446744073709551615b", UInt64.max, 20),
    ])
    func parseUnsignedInt64ParsesNumbersCorrectly(
        input: String,
        expectedResult: UInt64,
        expectedConsumed: Int
    ) throws {
        var buffer = ParseBuffer(ByteBuffer(string: input))
        let (id, actualConsumed) = try PL.parseUnsignedInt64(
            buffer: &buffer,
            tracker: .makeNewDefault
        )
        #expect(actualConsumed == expectedConsumed)
        #expect(id == expectedResult)
    }
}

// MARK: - parseBufferAsUTF8

extension ParserLibraryTests {
    @Test("parseBufferAsUTF8 with ASCII string")
    func parseBufferAsUtf8WithAsciiString() throws {
        let test1 = ByteBuffer(string: "hello, world")
        #expect(try ParserLibrary.parseBufferAsUTF8(test1) == "hello, world")
    }

    @Test("parseBufferAsUTF8 with multi-byte UTF-8 characters")
    func parseBufferAsUtf8WithMultiByteUtf8Characters() throws {
        let test2 = ByteBuffer(bytes: [0xE2, 0x9A, 0xA1, 0xE2, 0x9A, 0xA2, 0xE2, 0x9A, 0xA3, 0xE2, 0x9A, 0xA4])
        #expect(try ParserLibrary.parseBufferAsUTF8(test2) == "⚡⚢⚣⚤")
    }

    @Test("parseBufferAsUTF8 with incomplete UTF-8 sequence")
    func parseBufferAsUtf8WithIncompleteUtf8Sequence() throws {
        let test3 = ByteBuffer(bytes: [0xC2])
        #expect(throws: (any Error).self) {
            try ParserLibrary.parseBufferAsUTF8(test3)
        }
    }

    @Test("parseBufferAsUTF8 with truncated multi-byte sequence")
    func parseBufferAsUtf8WithTruncatedMultiByteSequence() throws {
        let test4 = ByteBuffer(bytes: [0xE1, 0x80])
        #expect(throws: (any Error).self) {
            try ParserLibrary.parseBufferAsUTF8(test4)
        }
    }
}

// MARK: - parseNewline

extension ParserLibraryTests {
    @Test("parseNewline handles various newline formats", arguments: [
        "\r\n",
        "\n",
        "\r",
        " \r\n",
        " \n",
        " \r",
        "      \r\n",
        "      \n",
        "      \r",
    ])
    func parseNewlineHandlesVariousNewlineFormats(newline: String) throws {
        var buffer = TestUtilities.makeParseBuffer(for: newline + "hello, world")
        try ParserLibrary.parseNewline(buffer: &buffer, tracker: StackTracker.makeNewDefault)
        try ParserLibrary.parseFixedString(
            "hello, world",
            buffer: &buffer,
            tracker: StackTracker.makeNewDefault
        )
    }

    @Test("parseNewline with acceptable recursion depth")
    func parseNewlineWithAcceptableRecursionDepth() throws {
        var buffer = TestUtilities.makeParseBuffer(for: String(repeating: " ", count: 80) + "\r\nhello, world")
        try ParserLibrary.parseNewline(buffer: &buffer, tracker: StackTracker(maximumParserStackDepth: 100))
        try ParserLibrary.parseFixedString(
            "hello, world",
            buffer: &buffer,
            tracker: StackTracker.makeNewDefault
        )
    }

    @Test("parseNewline throws when exceeding recursion limit")
    func parseNewlineThrowsWhenExceedingRecursionLimit() {
        var buffer = TestUtilities.makeParseBuffer(for: String(repeating: " ", count: 200) + "\r\nhello, world")
        #expect(throws: (any Error).self) {
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: StackTracker(maximumParserStackDepth: 100))
        }
    }
}
