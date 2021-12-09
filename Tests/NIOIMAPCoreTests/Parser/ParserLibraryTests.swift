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
import XCTest

final class ParserLibraryTests: XCTestCase {}

// MARK: - parseOptional

extension ParserLibraryTests {
    func test_parseOptionalWorksForNothing() {
        var buffer = TestUtilities.makeParseBuffer(for: "")
        XCTAssertThrowsError(try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
        }) { error in
            XCTAssertTrue(error is IncompleteMessage)
        }
    }

    func test_parseOptionalWorks() {
        var buffer = TestUtilities.makeParseBuffer(for: "x")
        XCTAssertNoThrow(try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
        })
    }

    func test_parseOptionalWorksIfNotPresent() {
        var buffer = TestUtilities.makeParseBuffer(for: "y")
        XCTAssertNoThrow(try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
        })
        XCTAssertEqual(1, buffer.readableBytes)
    }

    func test_parseOptionalCorrectlyResetsForCompositesIfNotEnough() {
        var buffer = TestUtilities.makeParseBuffer(for: "x")
        XCTAssertThrowsError(try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("y", buffer: &buffer, tracker: tracker)
        }) { error in
            XCTAssertTrue(error is IncompleteMessage)
        }
        XCTAssertEqual(1, buffer.readableBytes)
    }

    func test_parseOptionalCorrectlyResetsForCompositesIfNotMatching() {
        var buffer = TestUtilities.makeParseBuffer(for: "xz")
        XCTAssertNoThrow(try PL.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
            try PL.parseFixedString("y", buffer: &buffer, tracker: tracker)
        })
        XCTAssertEqual(2, buffer.readableBytes)
    }
}

// MARK: - parseFixedString

extension ParserLibraryTests {
    func test_fixedStringCaseSensitively() {
        var buffer = TestUtilities.makeParseBuffer(for: "fooFooFOO")

        XCTAssertNoThrow(try PL.parseFixedString("fooFooFOO",
                                                 caseSensitive: true,
                                                 buffer: &buffer,
                                                 tracker: .testTracker))

        buffer = TestUtilities.makeParseBuffer(for: "fooFooFOO")
        XCTAssertThrowsError(try PL.parseFixedString("foofoofoo",
                                                     caseSensitive: true,
                                                     buffer: &buffer,
                                                     tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }

        buffer = TestUtilities.makeParseBuffer(for: "foo")
        XCTAssertThrowsError(try PL.parseFixedString("fooFooFOO",
                                                     caseSensitive: true,
                                                     buffer: &buffer,
                                                     tracker: .testTracker)) { error in
            XCTAssertTrue(error is IncompleteMessage)
        }
    }

    func test_fixedStringCaseInsensitively() {
        var buffer = TestUtilities.makeParseBuffer(for: "fooFooFOO")

        XCTAssertNoThrow(try PL.parseFixedString("fooFooFOO",
                                                 buffer: &buffer,
                                                 tracker: .testTracker))

        buffer = TestUtilities.makeParseBuffer(for: "fooFooFOO")
        XCTAssertNoThrow(try PL.parseFixedString("foofoofoo",
                                                 buffer: &buffer,
                                                 tracker: .testTracker))

        buffer = TestUtilities.makeParseBuffer(for: "foo")
        XCTAssertThrowsError(try PL.parseFixedString("fooFooFOO",
                                                     buffer: &buffer,
                                                     tracker: .testTracker)) { error in
            XCTAssertTrue(error is IncompleteMessage)
        }
    }

    func test_fixedStringNonASCII() {
        var buffer = TestUtilities.makeParseBuffer(for: "fooFooFOO")

        buffer = TestUtilities.makeParseBuffer(for: "fooFooFOÖ")
        XCTAssertThrowsError(try PL.parseFixedString("fooFooFOO",
                                                     caseSensitive: true,
                                                     buffer: &buffer,
                                                     tracker: .testTracker)) { error in
            XCTAssert(error is ParserError, "\(error)")
        }
    }
}

// MARK: - parseZeroOrMore

extension ParserLibraryTests {
    func test_parseZeroOrMoreParsesNothingButThereIsData() {
        TestUtilities.withParseBuffer("", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([],
                                            try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }

    func test_parseZeroOrMoreParsesNothingNoData() {
        TestUtilities.withParseBuffer("") { buffer in
            XCTAssertThrowsError(try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
            }) { error in
                XCTAssertTrue(error is IncompleteMessage)
            }
        }
    }

    func test_parseZeroOrMoreParsesOneItemAndThereIsMore() {
        TestUtilities.withParseBuffer("xx", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([1],
                                            try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }

    func test_parseZeroOrMoreParsesTwoItemsAndThereIsMore() {
        TestUtilities.withParseBuffer("xxxx", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([1, 1],
                                            try PL.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }
}

// MARK: - parseOneOrMore

extension ParserLibraryTests {
    func test_parseOneOrMoreParsesNothingButThereIsData() {
        TestUtilities.withParseBuffer("", terminator: "xy") { buffer in
            XCTAssertThrowsError(try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
            }) { error in
                XCTAssert(error is ParserError)
            }
        }
    }

    func test_parseOneOrMoreParsesNothingNoData() {
        TestUtilities.withParseBuffer("") { buffer in
            XCTAssertThrowsError(try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
            }) { error in
                XCTAssertTrue(error is IncompleteMessage)
            }
        }
    }

    func test_parseOneOrMoreParsesOneItemAndThereIsMore() {
        TestUtilities.withParseBuffer("xx", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([1],
                                            try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }

    func test_parseOneOrMoreParsesTwoItemsAndThereIsMore() {
        TestUtilities.withParseBuffer("xxxx", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([1, 1],
                                            try PL.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try PL.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }
}

// MARK: - parseSpace

extension ParserLibraryTests {
    func testParseSpace() {
        let inputs: [(String, String, UInt)] = [
            (" a", "a", #line),
            ("       a", "a", #line),
            ("  a  ", "a  ", #line),
        ]
        for (string, remaining, line) in inputs {
            var string = ParseBuffer(ByteBuffer(string: string))
            let remaining = ParseBuffer(ByteBuffer(string: remaining))
            XCTAssertNoThrow(try PL.parseSpaces(buffer: &string, tracker: .makeNewDefaultLimitStackTracker), line: line)
            XCTAssertEqual(string, remaining, line: line)
        }
    }
}

// MARK: - parseUInt64

extension ParserLibraryTests {
    func testParseUInt64() {
        let inputs: [(String, UInt64, Int, UInt)] = [
            ("12345\r", 12345, 5, #line),
            ("18446744073709551615\r", UInt64.max, 20, #line),
            ("12345 a", 12345, 5, #line),
            ("18446744073709551615b", UInt64.max, 20, #line),
        ]
        for (string, result, consumed, line) in inputs {
            var string = ParseBuffer(ByteBuffer(string: string))
            var id = UInt64(0)
            var actualConsumed = 0
            XCTAssertNoThrow((id, actualConsumed) = try PL.parseUnsignedInt64(buffer: &string, tracker: .makeNewDefaultLimitStackTracker), line: line)
            XCTAssertEqual(actualConsumed, consumed, line: line)
            XCTAssertEqual(id, result, line: line)
        }
    }
}

// MARK: - parseBufferAsUTF8

extension ParserLibraryTests {
    func testParseBufferAsUTF8() {
        let test1 = ByteBuffer(string: "hello, world")
        XCTAssertEqual(try ParserLibrary.parseBufferAsUTF8(test1), "hello, world")

        let test2 = ByteBuffer(bytes: [0xE2, 0x9A, 0xA1, 0xE2, 0x9A, 0xA2, 0xE2, 0x9A, 0xA3, 0xE2, 0x9A, 0xA4])
        XCTAssertEqual(try ParserLibrary.parseBufferAsUTF8(test2), "⚡⚢⚣⚤")

        let test3 = ByteBuffer(bytes: [0xC2])
        XCTAssertThrowsError(try ParserLibrary.parseBufferAsUTF8(test3))

        let test4 = ByteBuffer(bytes: [0xE1, 0x80])
        XCTAssertThrowsError(try ParserLibrary.parseBufferAsUTF8(test4))
    }
}
