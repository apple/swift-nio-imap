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
@testable import NIOIMAP
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
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))
    }

    func testSimpleCommand() {
        var buffer: ByteBuffer = "A1 NOOP\r"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 NOOP\r"]))
    }

    // Shows that we don't need a CR to complete a frame
    // as some IMAP implementations don't bother with them.
    func testSimpleCommandNoCR() {
        var buffer: ByteBuffer = "A1 NOOP\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 NOOP\n"]))
    }

    // Shows that we can send a frame as soon as we've got the CR, and can then
    // ignore the next byte if it's a LF.
    func testSimpleCommandNoLF() {
        var buffer: ByteBuffer = "A1 NOOP\r"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 NOOP\r"]))

        buffer = "\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "A2 NOOP\r"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A2 NOOP\r"]))
    }

    func testSimpleCommandTimes2() {
        var buffer: ByteBuffer = "A1 NOOP\r\nA2 NOOP\r\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 NOOP\r\n", "A2 NOOP\r\n"]))
    }

    // Note that we don't jump the gun when we see a \r, we wait until
    // we've also examined the next byte to see if we should also have
    // consumed a \n.
    func testDripfeeding() {
        var buffer: ByteBuffer = "A"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "1"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = " "
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "N"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "O"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "O"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "P"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "\r"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 NOOP\r"]))

        buffer = "\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))
    }

    // Note this isn't strictly a valid login command, but it doesn't matter.
    // Rememeber that the framing parser is just there to look for frames.
    func testParsingLiteral() {
        var buffer: ByteBuffer = "A1 LOGIN {3}\r\nhey\r\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3}\r\n", "hey", "\r\n"]))
    }

    func testParsingBinaryLiteral() {
        var buffer: ByteBuffer = "A1 LOGIN {~3}\r\nhey\r\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {~3}\r\n", "hey", "\r\n"]))
    }

    func testParsingLiteralPlus() {
        var buffer: ByteBuffer = "A1 LOGIN {3+}\r\nhey\r\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3+}\r\n", "hey", "\r\n"]))
    }

    func testParsingLiteralIntegerOverflow() {
        var buffer: ByteBuffer = "A1 LOGIN {99999999999999999999999999999999999999999999999999999999999999}\r\nhey\r\n"
        XCTAssertThrowsError(try self.parser.appendAndFrameBuffer(&buffer)) { e in
            XCTAssertTrue(e is LiteralSizeParsingError)
        }
    }

    func testParsingLiteralMinus() {
        var buffer: ByteBuffer = "A1 LOGIN {3-}\r\nhey\r\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3-}\r\n", "hey", "\r\n"]))
    }

    func testParsingBinaryLiteralPlus() {
        var buffer: ByteBuffer = "A1 LOGIN {~3+}\r\nhey\r\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {~3+}\r\n", "hey", "\r\n"]))
    }

    // full command "A1 LOGIN {3}\r\n123 test\r\n
    func testDripfeedingLiteral() {
        var buffer: ByteBuffer = "A1 LOGIN {3"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "}"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "\r"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3}\r\n"]))

        buffer = "1"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["1"]))

        buffer = "2"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["2"]))

        buffer = "3"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["3"]))

        buffer = " test\r\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [" test\r\n"]))
    }

    func testDripfeedingLiteralPlus() {
        var buffer: ByteBuffer = "A1 LOGIN {3+"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "}"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "\r"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), []))

        buffer = "\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3+}\r\n"]))

        buffer = "1"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["1"]))

        buffer = "2"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["2"]))

        buffer = "3"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), ["3"]))

        buffer = " test\r\n"
        XCTAssertNoThrow(XCTAssertEqual(try self.parser.appendAndFrameBuffer(&buffer), [" test\r\n"]))
    }

    func testInvalidLiteralThrowsError() {
        // Invalid CRLF
        var b1: ByteBuffer = "A1 LOGIN {3}aaa"
        XCTAssertThrowsError(try self.parser.appendAndFrameBuffer(&b1)) { e in
            XCTAssertTrue(e is InvalidFrame)
        }

        // Invalid binary flag
        var b2: ByteBuffer = "A1 LOGIN {a3}\r\n"
        XCTAssertThrowsError(try self.parser.appendAndFrameBuffer(&b2)) { e in
            XCTAssertTrue(e is InvalidFrame)
        }

        // Invalid literal+/literal-extension
        var b3: ByteBuffer = "A1 LOGIN {3a}\r\n"
        XCTAssertThrowsError(try self.parser.appendAndFrameBuffer(&b3)) { e in
            XCTAssertTrue(e is InvalidFrame)
        }
    }
}
