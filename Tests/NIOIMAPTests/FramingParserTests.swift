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
@_spi(NIOIMAPInternal) import NIOIMAP
import NIOTestUtils
import XCTest

final class FramingParserTests: XCTestCase {
    var parser = FramingParser()

    // The parser has a state so we need to recreate with every test
    // as some tests may intentionally have leftovers.
    override func setUp() {
        self.parser = FramingParser()
    }
}

extension FramingParserTests {
    func testEmptyBuffer() {
        var buffer: ByteBuffer = ""
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [])
    }

    func testSimpleCommand() {
        var buffer: ByteBuffer = "A1 NOOP\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 NOOP\r\n")])
    }

    func testCommandWithQuoted() {
        var buffer: ByteBuffer = "A1 LOGIN \"foo\" \"bar\"\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN \"foo\" \"bar\"\r\n")])
    }

    func testCommandWithQuotedContinuationLike_1() {
        var buffer: ByteBuffer = #"A1 LOGIN "aa{2}bb" "bar"\#r\#n"#
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete(#"A1 LOGIN "aa{2}bb" "bar"\#r\#n"#)])
    }

    func testCommandWithQuotedContinuationLike_2() {
        var buffer: ByteBuffer = #"A1 LOGIN "aa{}bb" "bar"\#r\#n"#
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete(#"A1 LOGIN "aa{}bb" "bar"\#r\#n"#)])
    }

    func testCommandWithQuotedContinuationLikeAndEscapedQuote_1() {
        var buffer: ByteBuffer = #"A1 LOGIN "a\"a{2}bb" "bar"\#r\#n"#
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete(#"A1 LOGIN "a\"a{2}bb" "bar"\#r\#n"#)])
    }

    func testCommandWithQuotedContinuationLikeAndEscapedQuote_2() {
        var buffer: ByteBuffer = #"A1 LOGIN "a\"a\\a{2}bb" "bar"\#r\#n"#
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete(#"A1 LOGIN "a\"a\\a{2}bb" "bar"\#r\#n"#)])
    }

    // Shows that we don't need a CR to complete a frame
    // as some IMAP implementations don't bother with them.
    func testSimpleCommandNoCR() {
        var buffer: ByteBuffer = "A1 NOOP\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 NOOP\n")])
    }

    // Shows that we can send a frame as soon as we've got the CR, and can then
    // ignore the next byte if it's a LF.
    func testSimpleCommandNoLF() {
        var buffer: ByteBuffer = "A1 NOOP\r"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 NOOP\r")])

        buffer = "\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = "A2 NOOP\r"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A2 NOOP\r")])
    }

    func testTwoCommandsAcrossMultipleBuffers() {
        var buffer: ByteBuffer = "* OK IMAP4rev1"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = " Service Ready\r"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("* OK IMAP4rev1 Service Ready\r")])

        buffer = "\n* SEARCH"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = " 2\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("* SEARCH 2\r\n")])
    }

    func testSimpleCommandTimes2() {
        var buffer: ByteBuffer = "A1 NOOP\r\nA2 NOOP\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 NOOP\r\n"), .complete("A2 NOOP\r\n")])
    }

    // Note that we don't jump the gun when we see a \r, we wait until
    // we've also examined the next byte to see if we should also have
    // consumed a \n.
    func testDripfeeding() {
        var buffer: ByteBuffer = "A"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = "1"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = " "
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = "N"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = "O"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = "O"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = "P"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = "\r"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 NOOP\r")])

        buffer = "\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])
    }

    // Note this isn't strictly a valid login command, but it doesn't matter.
    // Remember that the framing parser is just there to look for frames.
    func testParsingLiteral() {
        var buffer: ByteBuffer = "A1 LOGIN {3}\r\nhey\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN {3}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    func testParsingLiteralNoLF() {
        var buffer: ByteBuffer = "A1 LOGIN {3}\rhey\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN {3}\r"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    func testParsingLiteralNoCR() {
        var buffer: ByteBuffer = "A1 LOGIN {3}\nhey\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN {3}\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    func testParsingLiteralNoCRLF() {
        var buffer: ByteBuffer = "A1 LOGIN {3}hey\r\n"
        let results = try! self.parser.appendAndFrameBuffer(&buffer)
        XCTAssertEqual(results, [.invalid("A1 LOGIN {3}h"), .complete("ey\r\n")])
    }

    func testParsingQuotedFollowedByLiteral() {
        var buffer: ByteBuffer = #"A1 LOGIN "foobar" {3}\#r\#nhey\#r\#n"#
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete(#"A1 LOGIN "foobar" {3}\#r\#n"#), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    func testParsingQuotedWithEscapedQuoteFollowedByLiteral() {
        var buffer: ByteBuffer = #"A1 LOGIN "foo\"bar" {3}\#r\#nhey\#r\#n"#
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete(#"A1 LOGIN "foo\"bar" {3}\#r\#n"#), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    func testParsingBinaryLiteral() {
        var buffer: ByteBuffer = "A1 LOGIN {~3}\r\nhey\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN {~3}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    func testParsingLiteralPlus() {
        var buffer: ByteBuffer = "A1 LOGIN {3+}\r\nhey\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN {3+}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    func testParsingLiteralIntegerOverflow() {
        var buffer: ByteBuffer = "A1 LOGIN {99999999999999999999999999999999999999999999999999999999999999"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.invalid("A1 LOGIN {999999999999999999999"), .incomplete(2)])
    }

    func testParsingLiteralMinus() {
        var buffer: ByteBuffer = "A1 LOGIN {3-}\r\nhey\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN {3-}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    func testParsingBinaryLiteralPlus() {
        var buffer: ByteBuffer = "A1 LOGIN {~3+}\r\nhey\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN {~3+}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    // full command "A1 LOGIN {3}\r\n123 test\r\n
    func testDripfeedingLiteral() {
        var buffer: ByteBuffer = "A1 LOGIN {3"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(3)])

        buffer = "}"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = "\r"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN {3}\r")])

        buffer = "\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(1)])

        buffer = "1"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.insideLiteral("1", remainingBytes: 2)])

        buffer = "2"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.insideLiteral("2", remainingBytes: 1)])

        buffer = "3"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.insideLiteral("3", remainingBytes: 0)])

        buffer = " test\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete(" test\r\n")])
    }

    func testDripfeedingLiteralPlus() {
        var buffer: ByteBuffer = "A1 LOGIN {3+"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(3)])

        buffer = "}"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(2)])

        buffer = "\r"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete("A1 LOGIN {3+}\r")])

        buffer = "\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.incomplete(1)])

        buffer = "1"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.insideLiteral("1", remainingBytes: 2)])

        buffer = "2"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.insideLiteral("2", remainingBytes: 1)])

        buffer = "3"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.insideLiteral("3", remainingBytes: 0)])

        buffer = " test\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.complete(" test\r\n")])
    }

    func testInvalidLiteral() {
        // Invalid CRLF
        var parser = FramingParser()
        var b1: ByteBuffer = "A1 LOGIN {3}aaa"
        XCTAssertEqual(try parser.appendAndFrameBuffer(&b1), [.invalid("A1 LOGIN {3}a"), .incomplete(2)])

        // Invalid binary flag
        parser = FramingParser()
        var b2: ByteBuffer = "A1 LOGIN {a3}\r\n"
        XCTAssertEqual(try parser.appendAndFrameBuffer(&b2), [.invalid("A1 LOGIN {a"), .complete("3}\r\n")])

        // Invalid literal+/literal-extension
        parser = FramingParser()
        var b3: ByteBuffer = "A1 LOGIN {3a}\r\n"
        XCTAssertEqual(try parser.appendAndFrameBuffer(&b3), [.invalid("A1 LOGIN {3a"), .complete("}\r\n")])
    }

    func testShowWeCanSkipPastInvalidFrames() {
        var buffer: ByteBuffer = "A1 LOGIN {a\r\nA1 NOOP\r\n"
        XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [.invalid("A1 LOGIN {a"), .complete("\r\n"), .complete("A1 NOOP\r\n")])
    }
}
