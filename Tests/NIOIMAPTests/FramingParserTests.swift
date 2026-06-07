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

    // MARK: - Bare CR at a segment boundary

    // When a bare CR is the *last* byte of a segment, the parser completes the frame but can't yet
    // tell whether the matching LF will follow in the next segment. It therefore enters the
    // `.ignoreFirst` line-feed strategy: skip a *leading* LF next, but otherwise treat the byte
    // stream normally.
    //
    // The bug these tests guard against: if the next segment contained a non-LF byte followed by a
    // *bare* LF (no preceding CR — e.g. a Unix-style terminator), the `.ignoreFirst` strategy was
    // not reset, so that LF reached `processLineBreakByte_state` with `frameLength > 1` and tripped
    // a `precondition`, aborting the whole process. The tests below pin down every continuation of
    // a bare CR.
    //
    // (Note: a continuation ending in CRLF does *not* trigger the bug — the CR completes the frame
    // and `readByte_state_foundCR` consumes the trailing LF — so the crash repros below all use a
    // bare LF terminator.)

    // The original crash: `CR` (end of segment), then a command terminated by a bare LF. Pre-fix
    // this aborted the process; it must now frame cleanly.
    @Test("bare CR then a command terminated by a bare LF")
    func bareCRThenCommandTerminatedByBareLF() {
        var parser = self.parser

        var buffer: ByteBuffer = "A1 NOOP\r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 NOOP\r")])

        // The next segment is a fresh command with a Unix-style bare LF terminator. It must frame
        // normally rather than trip the precondition.
        buffer = "A2 NOOP\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A2 NOOP\n")])
    }

    // The minimal repro, drip-fed one byte per segment: `\r`, then `X`, then `\n`.
    @Test("bare CR then byte then LF drip-fed")
    func bareCRThenByteThenLFDripFed() {
        var parser = self.parser

        var buffer: ByteBuffer = "\r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("\r")])

        // A non-LF byte after the bare CR begins a new frame, so `.ignoreFirst` must be dropped.
        buffer = "X"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])

        // The LF now terminates the "X" frame instead of being mistaken for the CR's partner.
        buffer = "\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("X\n")])
    }

    // The legitimate `.ignoreFirst` case: when the LF *is* the first byte of the next segment, it
    // is the CR's partner and must be silently consumed (not emitted as an empty frame).
    @Test("bare CR then leading LF is ignored")
    func bareCRThenLeadingLFIsIgnored() {
        var parser = self.parser

        var buffer: ByteBuffer = "A1 NOOP\r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 NOOP\r")])

        // Leading LF (the CR's partner) is swallowed, and the following command frames normally.
        buffer = "\nA2 NOOP\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A2 NOOP\r\n")])
    }

    // A bare CR followed by a non-LF byte and *another* bare CR: the second frame is itself
    // CR-terminated and the parser must re-enter `.ignoreFirst` for the next segment.
    @Test("bare CR then a frame also ending in a bare CR")
    func bareCRThenFrameAlsoEndingInBareCR() {
        var parser = self.parser

        var buffer: ByteBuffer = "A1\r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1\r")])

        buffer = "B2\r"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("B2\r")])

        // Still in `.ignoreFirst`; a lone trailing LF is the second CR's partner and is ignored.
        buffer = "\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.incomplete(2)])
    }

    // A bare CR immediately followed by `CR LF` in the next segment: the leading CR opens an empty
    // line, and because its LF *is* present it is folded into a single empty `\r\n` frame.
    @Test("bare CR then CRLF empty line")
    func bareCRThenCRLFEmptyLine() {
        var parser = self.parser

        var buffer: ByteBuffer = "A1\r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1\r")])

        buffer = "\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("\r\n")])
    }

    // After a bare CR, a `{` must still open a literal header (the `.ignoreFirst` strategy applies
    // only to a leading LF, never to other bytes).
    @Test("bare CR then literal header")
    func bareCRThenLiteralHeader() {
        var parser = self.parser

        var buffer: ByteBuffer = "A1 LOGIN \r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN \r")])

        buffer = "{3}\r\nhey\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("{3}\r\n"), .insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    // After a bare CR, a `"` must still open a quoted string.
    @Test("bare CR then quoted string")
    func bareCRThenQuotedString() {
        var parser = self.parser

        var buffer: ByteBuffer = "A1 LOGIN \r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN \r")])

        buffer = "\"foo\"\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("\"foo\"\r\n")])
    }

    // Several bare CRs each ending their own segment must not desync the state machine: each one
    // simply completes a frame and re-arms `.ignoreFirst`.
    @Test("repeated bare CRs across segments")
    func repeatedBareCRsAcrossSegments() {
        var parser = self.parser
        for _ in 0..<3 {
            var buffer: ByteBuffer = "\r"
            var result: [FramingResult]?
            #expect(throws: Never.self) {
                result = try parser.appendAndFrameBuffer(&buffer)
            }
            #expect(result == [.complete("\r")])
        }
    }

    // MARK: - Literal-header CRLF split across a segment boundary

    // The literal-body path uses the *same* `.ignoreFirst` strategy when a literal header's CRLF
    // is split (`…{3}\r` ends a segment). A following non-LF byte must begin the literal body
    // directly...
    @Test("literal header CR split then body without LF")
    func literalHeaderCRSplitThenBodyWithoutLF() {
        var parser = self.parser

        var buffer: ByteBuffer = "A1 LOGIN {3}\r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN {3}\r")])

        buffer = "hey\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
    }

    // ...while a following LF (the CR's partner) is skipped before the literal body begins.
    @Test("literal header CR split then leading LF before body")
    func literalHeaderCRSplitThenLeadingLFBeforeBody() {
        var parser = self.parser

        var buffer: ByteBuffer = "A1 LOGIN {3}\r"
        var result: [FramingResult]?
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.complete("A1 LOGIN {3}\r")])

        buffer = "\nhey\r\n"
        #expect(throws: Never.self) {
            result = try parser.appendAndFrameBuffer(&buffer)
        }
        #expect(result == [.insideLiteral("hey", remainingBytes: 0), .complete("\r\n")])
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
