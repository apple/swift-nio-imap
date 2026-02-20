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
import Testing

@Suite struct FramingParserTests {
    var parser = FramingParser()

    // The parser has a state so we need to recreate with every test
    // as some tests may intentionally have leftovers.
    init() {
        self.parser = FramingParser()
    }

    @Test("empty buffer")
    func emptyBuffer() {
        var parser = self.parser
        var buffer: ByteBuffer = ""
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [])
    }

    @Test("simple command")
    func simpleCommand() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 NOOP\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 NOOP\r\n")])
    }

    @Test("single quote in line")
    func singleQuoteInLine() {
        // RFC 3501 allows un-matched `"` in `text` parts, such as the text of an untagged OK response.
        //
        // Test that this:
        //
        // S: * OK Hello " foo
        // S: * NO Hello bar
        //
        // gets parsed into the corresponding two frames / lines.
        var parser = self.parser
        do {
            var buffer: ByteBuffer = "* OK Hello \" foo\r\n"
            var result: [FramingResult]?
            #expect(throws: Never.self) {
                result = try parser.appendAndFrameBuffer(&buffer)
            }
            #expect(result == [.complete("* OK Hello \" foo\r\n")])
        }
        // Check that the next line parses:
        do {
            var buffer: ByteBuffer = "* NO Hello bar\r\n"
            var result: [FramingResult]?
            #expect(throws: Never.self) {
                result = try parser.appendAndFrameBuffer(&buffer)
            }
            #expect(result == [.complete("* NO Hello bar\r\n")])
        }
    }

    @Test("single quote in line CR line break")
    func singleQuoteInLineCRLineBreak() {
        // RFC 3501 allows un-matched `"` in `text` parts, such as the text of an untagged OK response.
        //
        // Test that this:
        //
        // S: * OK Hello " foo
        // S: * NO Hello bar
        //
        // gets parsed into the corresponding two frames / lines.
        var parser = self.parser
        do {
            var buffer: ByteBuffer = "* OK Hello \" foo\r"
            var result: [FramingResult]?
            #expect(throws: Never.self) {
                result = try parser.appendAndFrameBuffer(&buffer)
            }
            #expect(result == [.complete("* OK Hello \" foo\r")])
        }
        // Check that the next line parses:
        do {
            var buffer: ByteBuffer = "* NO Hello bar\r"
            var result: [FramingResult]?
            #expect(throws: Never.self) {
                result = try parser.appendAndFrameBuffer(&buffer)
            }
            #expect(result == [.complete("* NO Hello bar\r")])
        }
    }

    @Test("command with quoted")
    func commandWithQuoted() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN \"foo\" \"bar\"\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN \"foo\" \"bar\"\r\n")])
    }

    @Test("command with quoted continuation like 1")
    func commandWithQuotedContinuationLike1() {
        var parser = self.parser
        var buffer: ByteBuffer = #"A1 LOGIN "aa{2}bb" "bar"\#r\#n"#
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete(#"A1 LOGIN "aa{2}bb" "bar"\#r\#n"#)])
    }

    @Test("command with quoted continuation like 2")
    func commandWithQuotedContinuationLike2() {
        var parser = self.parser
        var buffer: ByteBuffer = #"A1 LOGIN "aa{}bb" "bar"\#r\#n"#
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete(#"A1 LOGIN "aa{}bb" "bar"\#r\#n"#)])
    }

    @Test("command with quoted continuation like and escaped quote 1")
    func commandWithQuotedContinuationLikeAndEscapedQuote1() {
        var parser = self.parser
        var buffer: ByteBuffer = #"A1 LOGIN "a\"a{2}bb" "bar"\#r\#n"#
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete(#"A1 LOGIN "a\"a{2}bb" "bar"\#r\#n"#)])
    }

    @Test("command with quoted continuation like and escaped quote 2")
    func commandWithQuotedContinuationLikeAndEscapedQuote2() {
        var parser = self.parser
        var buffer: ByteBuffer = #"A1 LOGIN "a\"a\\a{2}bb" "bar"\#r\#n"#
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete(#"A1 LOGIN "a\"a\\a{2}bb" "bar"\#r\#n"#)])
    }

    // Shows that we don't need a CR to complete a frame
    // as some IMAP implementations don't bother with them.
    @Test("simple command no CR")
    func simpleCommandNoCR() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 NOOP\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 NOOP\n")])
    }

    // Shows that we can send a frame as soon as we've got the CR, and can then
    // ignore the next byte if it's a LF.
    @Test("simple command no LF")
    func simpleCommandNoLF() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 NOOP\r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 NOOP\r")])

        buffer = "\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = "A2 NOOP\r"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A2 NOOP\r")])
    }

    @Test("two commands across multiple buffers")
    func twoCommandsAcrossMultipleBuffers() {
        var parser = self.parser
        var buffer: ByteBuffer = "* OK IMAP4rev1"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = " Service Ready\r"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("* OK IMAP4rev1 Service Ready\r")])

        buffer = "\n* SEARCH"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = " 2\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("* SEARCH 2\r\n")])
    }

    @Test("simple command times 2")
    func simpleCommandTimes2() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 NOOP\r\nA2 NOOP\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 NOOP\r\n"), .complete("A2 NOOP\r\n")])
    }

    // Note that we don't jump the gun when we see a \r, we wait until
    // we've also examined the next byte to see if we should also have
    // consumed a \n.
    @Test("dripfeeding")
    func dripfeeding() {
        var parser = self.parser
        var buffer: ByteBuffer = "A"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = "1"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = " "
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = "N"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = "O"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = "O"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = "P"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = "\r"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 NOOP\r")])

        buffer = "\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])
    }

    // Note this isn't strictly a valid login command, but it doesn't matter.
    // Remember that the framing parser is just there to look for frames.
    @Test("parsing literal")
    func parsingLiteral() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {3}\r\nhey\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN {3}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    @Test("parsing literal no LF")
    func parsingLiteralNoLF() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {3}\rhey\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN {3}\r"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    @Test("parsing literal no CR")
    func parsingLiteralNoCR() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {3}\nhey\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN {3}\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    @Test("parsing literal no CRLF")
    func parsingLiteralNoCRLF() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {3}hey\r\n"
        var results: [FramingResult]?
        #expect(throws: Never.self) {
            results = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(results == [.invalid("A1 LOGIN {3}h"), .complete("ey\r\n")])
    }

    @Test("parsing quoted followed by literal")
    func parsingQuotedFollowedByLiteral() {
        var parser = self.parser
        var buffer: ByteBuffer = #"A1 LOGIN "foobar" {3}\#r\#nhey\#r\#n"#
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(
            result == [
                .complete(#"A1 LOGIN "foobar" {3}\#r\#n"#), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n"),
            ]
        )
    }

    @Test("parsing quoted with escaped quote followed by literal")
    func parsingQuotedWithEscapedQuoteFollowedByLiteral() {
        var parser = self.parser
        var buffer: ByteBuffer = #"A1 LOGIN "foo\"bar" {3}\#r\#nhey\#r\#n"#
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(
            result == [
                .complete(#"A1 LOGIN "foo\"bar" {3}\#r\#n"#), .insideLiteral("hey", remainingBytes: 0),
                .complete("\r\n"),
            ]
        )
    }

    @Test("parsing binary literal")
    func parsingBinaryLiteral() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {~3}\r\nhey\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(
            result == [.complete("A1 LOGIN {~3}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")]
        )
    }

    @Test("parsing literal plus")
    func parsingLiteralPlus() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {3+}\r\nhey\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(
            result == [.complete("A1 LOGIN {3+}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")]
        )
    }

    @Test("parsing literal integer overflow")
    func parsingLiteralIntegerOverflow() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {99999999999999999999999999999999999999999999999999999999999999"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.invalid("A1 LOGIN {999999999999999999999"), .incomplete(2)])
    }

    @Test("parsing literal minus")
    func parsingLiteralMinus() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {3-}\r\nhey\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(
            result == [.complete("A1 LOGIN {3-}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")]
        )
    }

    @Test("parsing binary literal plus")
    func parsingBinaryLiteralPlus() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {~3+}\r\nhey\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(
            result == [.complete("A1 LOGIN {~3+}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")]
        )
    }

    // full command "A1 LOGIN {3}\r\n123 test\r\n
    @Test("dripfeeding literal")
    func dripfeedingLiteral() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {3"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(3)])

        buffer = "}"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = "\r"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN {3}\r")])

        buffer = "\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(1)])

        buffer = "1"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.insideLiteral("1", remainingBytes: 2)])

        buffer = "2"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.insideLiteral("2", remainingBytes: 1)])

        buffer = "3"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.insideLiteral("3", remainingBytes: 0)])

        buffer = " test\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete(" test\r\n")])
    }

    @Test("dripfeeding literal plus")
    func dripfeedingLiteralPlus() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {3+"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(3)])

        buffer = "}"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        buffer = "\r"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN {3+}\r")])

        buffer = "\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(1)])

        buffer = "1"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.insideLiteral("1", remainingBytes: 2)])

        buffer = "2"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.insideLiteral("2", remainingBytes: 1)])

        buffer = "3"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.insideLiteral("3", remainingBytes: 0)])

        buffer = " test\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete(" test\r\n")])
    }

    @Test("invalid literal")
    func invalidLiteral() {
        // Invalid CRLF
        var parser = FramingParser()
        var b1: ByteBuffer = "A1 LOGIN {3}aaa"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&b1)
        }
        #expect(result == [.invalid("A1 LOGIN {3}a"), .incomplete(2)])

        // Invalid binary flag
        parser = FramingParser()
        var b2: ByteBuffer = "A1 LOGIN {a3}\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&b2)
        }
        #expect(result == [.invalid("A1 LOGIN {a"), .complete("3}\r\n")])

        // Invalid literal+/literal-extension
        parser = FramingParser()
        var b3: ByteBuffer = "A1 LOGIN {3a}\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&b3)
        }
        #expect(result == [.invalid("A1 LOGIN {3a"), .complete("}\r\n")])
    }

    @Test("show we can skip past invalid frames")
    func showWeCanSkipPastInvalidFrames() {
        var parser = self.parser
        var buffer: ByteBuffer = "A1 LOGIN {a\r\nA1 NOOP\r\n"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.invalid("A1 LOGIN {a"), .complete("\r\n"), .complete("A1 NOOP\r\n")])
    }
}
