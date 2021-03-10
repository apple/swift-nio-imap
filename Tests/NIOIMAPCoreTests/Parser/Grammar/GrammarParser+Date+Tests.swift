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
import XCTest

class GrammarParser_Date_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - date

extension GrammarParser_Date_Tests {
    func testDate_valid_plain() {
        TestUtilities.withBuffer("25-Jun-1994", terminator: " ") { (buffer) in
            let day = try GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, IMAPDate(year: 1994, month: 6, day: 25))
        }
    }

    func testDate_valid_quoted() {
        TestUtilities.withBuffer("\"25-Jun-1994\"") { (buffer) in
            let day = try GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, IMAPDate(year: 1994, month: 6, day: 25))
        }
    }

    func testDate_invalid_quoted_missing_end_quote() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"25-Jun-1994 ")
        XCTAssertThrowsError(try GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testDate_invalid_quoted_missing_date() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"\"")
        XCTAssertThrowsError(try GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - date-day

extension GrammarParser_Date_Tests {
    func testDateDay_valid_single() {
        TestUtilities.withBuffer("1", terminator: "\r") { (buffer) in
            let day = try GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, 1)
        }
    }

    func testDateDay_valid_double() {
        TestUtilities.withBuffer("12", terminator: "\r") { (buffer) in
            let day = try GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, 12)
        }
    }

    func testDateDay_valid_single_followon() {
        TestUtilities.withBuffer("1", terminator: "a") { (buffer) in
            let day = try GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, 1)
        }
    }

    func testDateDay_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "a")
        XCTAssertThrowsError(try GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testDateDay_invalid_long() {
        var buffer = TestUtilities.createTestByteBuffer(for: "1234 ")
        XCTAssertThrowsError(try GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - date-month

extension GrammarParser_Date_Tests {
    func testDateMonth_valid() {
        TestUtilities.withBuffer("jun", terminator: " ") { (buffer) in
            let month = try GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(month, 6)
        }
    }

    func testDateMonth_valid_mixedCase() {
        TestUtilities.withBuffer("JUn", terminator: " ") { (buffer) in
            let month = try GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(month, 6)
        }
    }

    func testDateMonth_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "ju")
        XCTAssertThrowsError(try GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage)
        }
    }

    func testDateMonth_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "aaa ")
        XCTAssertThrowsError(try GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - date-text

extension GrammarParser_Date_Tests {
    func testDateText_valid() {
        TestUtilities.withBuffer("25-Jun-1994", terminator: " ") { (buffer) in
            let date = try GrammarParser.parseDateText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(date, IMAPDate(year: 1994, month: 6, day: 25))
        }
    }

    func testDateText_invalid_missing_year() {
        var buffer = TestUtilities.createTestByteBuffer(for: "25-Jun-")
        XCTAssertThrowsError(try GrammarParser.parseDateText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage)
        }
    }
}

// MARK: - parseInternalDate

extension GrammarParser_Date_Tests {
    // NOTE: Only a few sample failure cases tested, more will be handled by the `ByteToMessageDecoder`

    func testparseInternalDate_valid() {
        TestUtilities.withBuffer(#""25-Jun-1994 01:02:03 +1020""#) { (buffer) in
            let internalDate = try GrammarParser.parseInternalDate(buffer: &buffer, tracker: .testTracker)
            let c = internalDate.components
            XCTAssertEqual(c.year, 1994)
            XCTAssertEqual(c.month, 6)
            XCTAssertEqual(c.day, 25)
            XCTAssertEqual(c.hour, 1)
            XCTAssertEqual(c.minute, 2)
            XCTAssertEqual(c.second, 3)
            XCTAssertEqual(c.zoneMinutes, 620)
        }
        TestUtilities.withBuffer(#""01-Jan-1900 00:00:00 -1559""#) { (buffer) in
            let internalDate = try GrammarParser.parseInternalDate(buffer: &buffer, tracker: .testTracker)
            let c = internalDate.components
            XCTAssertEqual(c.year, 1900)
            XCTAssertEqual(c.month, 1)
            XCTAssertEqual(c.day, 1)
            XCTAssertEqual(c.hour, 0)
            XCTAssertEqual(c.minute, 0)
            XCTAssertEqual(c.second, 0)
            XCTAssertEqual(c.zoneMinutes, -959)
        }
        TestUtilities.withBuffer(#""31-Dec-2579 23:59:59 +1559""#) { (buffer) in
            let internalDate = try GrammarParser.parseInternalDate(buffer: &buffer, tracker: .testTracker)
            let c = internalDate.components
            XCTAssertEqual(c.year, 2579)
            XCTAssertEqual(c.month, 12)
            XCTAssertEqual(c.day, 31)
            XCTAssertEqual(c.hour, 23)
            XCTAssertEqual(c.minute, 59)
            XCTAssertEqual(c.second, 59)
            XCTAssertEqual(c.zoneMinutes, 959)
        }
    }

    func testparseInternalDate__invalid_incomplete() {
        var buffer = #""25-Jun-1994 01"# as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseInternalDate(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertTrue(error is _IncompleteMessage)
        }
    }

    func testparseInternalDate__invalid_missing_space() {
        var buffer = #""25-Jun-199401:02:03+1020""# as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseInternalDate(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

    func testparseInternalDate__invalid_timeZone() {
        var buffer = TestUtilities.createTestByteBuffer(for: #""25-Jun-1994 01:02:03 +12345678\n""#)
        XCTAssertThrowsError(try GrammarParser.parseInternalDate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
        buffer = TestUtilities.createTestByteBuffer(for: #""25-Jun-1994 01:02:03 +12""#)
        XCTAssertThrowsError(try GrammarParser.parseInternalDate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
        buffer = TestUtilities.createTestByteBuffer(for: #""25-Jun-1994 01:02:03 abc""#)
        XCTAssertThrowsError(try GrammarParser.parseInternalDate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }
}
