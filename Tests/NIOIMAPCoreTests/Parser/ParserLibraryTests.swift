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
    @Test func `parseOptional throws incomplete message when buffer is empty`() {
        var buffer = TestUtilities.makeParseBuffer(for: "")
        #expect(throws: IncompleteMessage.self) {
            try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
            }
        }
    }

    @Test func `parseOptional succeeds when element is present`() throws {
        var buffer = TestUtilities.makeParseBuffer(for: "x")
        try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
        }
    }

    @Test func `parseOptional succeeds when element is not present`() throws {
        var buffer = TestUtilities.makeParseBuffer(for: "y")
        try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
        }
        #expect(buffer.readableBytes == 1)
    }

    @Test func `parseOptional resets buffer correctly for composite parsers with incomplete input`() {
        var buffer = TestUtilities.makeParseBuffer(for: "x")
        #expect(throws: IncompleteMessage.self) {
            try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("y", buffer: &buffer, tracker: tracker)
            }
        }
        #expect(buffer.readableBytes == 1)
    }

    @Test func `parseOptional resets buffer correctly for composite parsers with non-matching input`() throws {
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
    @Test func `parseFixedString with case sensitive matching`() throws {
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

    @Test func `parseFixedString with case insensitive matching`() throws {
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

    @Test func `parseFixedString rejects non-ASCII characters`() {
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

    @Test func `parseFixedString with leading spaces`() throws {
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
    @Test func `parseZeroOrMore parses nothing when no match but data present`() throws {
        TestUtilities.withParseBuffer("", terminator: "xy") { buffer in
            let result = try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                return 1
            }
            #expect(result == [])
        }
    }

    @Test func `parseZeroOrMore throws incomplete message when no data`() throws {
        TestUtilities.withParseBuffer("") { buffer in
            #expect(throws: IncompleteMessage.self) {
                try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                }
            }
        }
    }

    @Test func `parseZeroOrMore parses one item when more data present`() throws {
        TestUtilities.withParseBuffer("xx", terminator: "xy") { buffer in
            let result = try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                return 1
            }
            #expect(result == [1])
        }
    }

    @Test func `parseZeroOrMore parses two items when more data present`() throws {
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
    @Test func `parseOneOrMore throws parser error when no match but data present`() throws {
        TestUtilities.withParseBuffer("", terminator: "xy") { buffer in
            #expect(throws: ParserError.self) {
                try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                }
            }
        }
    }

    @Test func `parseOneOrMore throws incomplete message when no data`() throws {
        TestUtilities.withParseBuffer("") { buffer in
            #expect(throws: IncompleteMessage.self) {
                try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                    try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                }
            }
        }
    }

    @Test func `parseOneOrMore parses one item when more data present`() throws {
        TestUtilities.withParseBuffer("xx", terminator: "xy") { buffer in
            let result = try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                return 1
            }
            #expect(result == [1])
        }
    }

    @Test func `parseOneOrMore parses two items when more data present`() throws {
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
    @Test(arguments: [
        (" a", "a"),
        ("       a", "a"),
        ("  a  ", "a  "),
    ])
    func `parseSpaces consumes leading spaces`(input: String, expectedRemaining: String) throws {
        var buffer = ParseBuffer(ByteBuffer(string: input))
        let remaining = ParseBuffer(ByteBuffer(string: expectedRemaining))
        try PL.parseSpaces(buffer: &buffer, tracker: .makeNewDefault)
        #expect(buffer == remaining)
    }
}

// MARK: - parseUInt64

extension ParserLibraryTests {
    @Test(arguments: [
        ("12345\r", 12345, 5),
        ("18446744073709551615\r", UInt64.max, 20),
        ("12345 a", 12345, 5),
        ("18446744073709551615b", UInt64.max, 20),
    ])
    func `parseUnsignedInt64 parses numbers correctly`(
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
    @Test func `parseBufferAsUTF8 with ASCII string`() throws {
        let test1 = ByteBuffer(string: "hello, world")
        #expect(try ParserLibrary.parseBufferAsUTF8(test1) == "hello, world")
    }

    @Test func `parseBufferAsUTF8 with multi-byte UTF-8 characters`() throws {
        let test2 = ByteBuffer(bytes: [0xE2, 0x9A, 0xA1, 0xE2, 0x9A, 0xA2, 0xE2, 0x9A, 0xA3, 0xE2, 0x9A, 0xA4])
        #expect(try ParserLibrary.parseBufferAsUTF8(test2) == "⚡⚢⚣⚤")
    }

    @Test func `parseBufferAsUTF8 with incomplete UTF-8 sequence`() throws {
        let test3 = ByteBuffer(bytes: [0xC2])
        #expect(throws: (any Error).self) {
            try ParserLibrary.parseBufferAsUTF8(test3)
        }
    }

    @Test func `parseBufferAsUTF8 with truncated multi-byte sequence`() throws {
        let test4 = ByteBuffer(bytes: [0xE1, 0x80])
        #expect(throws: (any Error).self) {
            try ParserLibrary.parseBufferAsUTF8(test4)
        }
    }
}

// MARK: - parseNewline

extension ParserLibraryTests {
    @Test(arguments: [
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
    func `parseNewline handles various newline formats`(newline: String) throws {
        var buffer = TestUtilities.makeParseBuffer(for: newline + "hello, world")
        try ParserLibrary.parseNewline(buffer: &buffer, tracker: StackTracker.makeNewDefault)
        try ParserLibrary.parseFixedString(
            "hello, world",
            buffer: &buffer,
            tracker: StackTracker.makeNewDefault
        )
    }

    @Test func `parseNewline with acceptable recursion depth`() throws {
        var buffer = TestUtilities.makeParseBuffer(for: String(repeating: " ", count: 80) + "\r\nhello, world")
        try ParserLibrary.parseNewline(buffer: &buffer, tracker: StackTracker(maximumParserStackDepth: 100))
        try ParserLibrary.parseFixedString(
            "hello, world",
            buffer: &buffer,
            tracker: StackTracker.makeNewDefault
        )
    }

    @Test func `parseNewline throws when exceeding recursion limit`() {
        var buffer = TestUtilities.makeParseBuffer(for: String(repeating: " ", count: 200) + "\r\nhello, world")
        #expect(throws: (any Error).self) {
            try ParserLibrary.parseNewline(buffer: &buffer, tracker: StackTracker(maximumParserStackDepth: 100))
        }
    }
}
