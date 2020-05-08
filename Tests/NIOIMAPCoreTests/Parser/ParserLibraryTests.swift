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

import XCTest

final class ParserLibraryTests: XCTestCase {}

// MARK: - parseOptional

extension ParserLibraryTests {
    func test_parseOptionalWorksForNothing() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try ParserLibrary.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
        }) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
    }

    func test_parseOptionalWorks() {
        var buffer = TestUtilities.createTestByteBuffer(for: "x")
        XCTAssertNoThrow(try ParserLibrary.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
        })
    }

    func test_parseOptionalWorksIfNotPresent() {
        var buffer = TestUtilities.createTestByteBuffer(for: "y")
        XCTAssertNoThrow(try ParserLibrary.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
        })
        XCTAssertEqual(1, buffer.readableBytes)
    }

    func test_parseOptionalCorrectlyResetsForCompositesIfNotEnough() {
        var buffer = TestUtilities.createTestByteBuffer(for: "x")
        XCTAssertThrowsError(try ParserLibrary.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("y", buffer: &buffer, tracker: tracker)
        }) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
        XCTAssertEqual(1, buffer.readableBytes)
    }

    func test_parseOptionalCorrectlyResetsForCompositesIfNotMatching() {
        var buffer = TestUtilities.createTestByteBuffer(for: "xz")
        XCTAssertNoThrow(try ParserLibrary.parseOptional(buffer: &buffer, tracker: StackTracker.testTracker) { buffer, tracker in
            try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
            try ParserLibrary.parseFixedString("y", buffer: &buffer, tracker: tracker)
        })
        XCTAssertEqual(2, buffer.readableBytes)
    }
}

// MARK: - parseFixedString

extension ParserLibraryTests {
    func test_fixedStringCaseSensitively() {
        var buffer = TestUtilities.createTestByteBuffer(for: "fooFooFOO")

        XCTAssertNoThrow(try ParserLibrary.parseFixedString("fooFooFOO",
                                                            caseSensitive: true,
                                                            buffer: &buffer,
                                                            tracker: .testTracker))

        buffer = TestUtilities.createTestByteBuffer(for: "fooFooFOO")
        XCTAssertThrowsError(try ParserLibrary.parseFixedString("foofoofoo",
                                                                caseSensitive: true,
                                                                buffer: &buffer,
                                                                tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }

        buffer = TestUtilities.createTestByteBuffer(for: "foo")
        XCTAssertThrowsError(try ParserLibrary.parseFixedString("fooFooFOO",
                                                                caseSensitive: true,
                                                                buffer: &buffer,
                                                                tracker: .testTracker)) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
    }

    func test_fixedStringCaseInsensitively() {
        var buffer = TestUtilities.createTestByteBuffer(for: "fooFooFOO")

        XCTAssertNoThrow(try ParserLibrary.parseFixedString("fooFooFOO",
                                                            buffer: &buffer,
                                                            tracker: .testTracker))

        buffer = TestUtilities.createTestByteBuffer(for: "fooFooFOO")
        XCTAssertNoThrow(try ParserLibrary.parseFixedString("foofoofoo",
                                                            buffer: &buffer,
                                                            tracker: .testTracker))

        buffer = TestUtilities.createTestByteBuffer(for: "foo")
        XCTAssertThrowsError(try ParserLibrary.parseFixedString("fooFooFOO",
                                                                buffer: &buffer,
                                                                tracker: .testTracker)) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
    }

    func test_fixedStringNonASCII() {
        var buffer = TestUtilities.createTestByteBuffer(for: "fooFooFOO")

        buffer = TestUtilities.createTestByteBuffer(for: "fooFooFOÖ")
        XCTAssertThrowsError(try ParserLibrary.parseFixedString("fooFooFOO",
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
        TestUtilities.withBuffer("", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([],
                                            try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }

    func test_parseZeroOrMoreParsesNothingNoData() {
        TestUtilities.withBuffer("") { buffer in
            XCTAssertThrowsError(try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
            }) { error in
                XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
            }
        }
    }

    func test_parseZeroOrMoreParsesOneItemAndThereIsMore() {
        TestUtilities.withBuffer("xx", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([1],
                                            try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }

    func test_parseZeroOrMoreParsesTwoItemsAndThereIsMore() {
        TestUtilities.withBuffer("xxxx", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([1, 1],
                                            try ParserLibrary.parseZeroOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }
}

// MARK: - parseOneOrMore

extension ParserLibraryTests {
    func test_parseOneOrMoreParsesNothingButThereIsData() {
        TestUtilities.withBuffer("", terminator: "xy") { buffer in
            XCTAssertThrowsError(try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
            }) { error in
                XCTAssert(error is ParserError)
            }
        }
    }

    func test_parseOneOrMoreParsesNothingNoData() {
        TestUtilities.withBuffer("") { buffer in
            XCTAssertThrowsError(try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker in
                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
            }) { error in
                XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
            }
        }
    }

    func test_parseOneOrMoreParsesOneItemAndThereIsMore() {
        TestUtilities.withBuffer("xx", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([1],
                                            try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }

    func test_parseOneOrMoreParsesTwoItemsAndThereIsMore() {
        TestUtilities.withBuffer("xxxx", terminator: "xy") { buffer in
            XCTAssertNoThrow(XCTAssertEqual([1, 1],
                                            try ParserLibrary.parseOneOrMore(buffer: &buffer, tracker: .testTracker) { buffer, tracker -> Int in
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                try ParserLibrary.parseFixedString("x", buffer: &buffer, tracker: tracker)
                                                return 1
                                            }))
        }
    }
}
