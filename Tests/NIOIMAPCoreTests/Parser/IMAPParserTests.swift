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
import NIOTestUtils
import XCTest

extension StackTracker {
    static var testTracker: StackTracker {
        StackTracker(maximumParserStackDepth: 30)
    }
}

let CR = UInt8(ascii: "\r")
let LF = UInt8(ascii: "\n")
let CRLF = String(decoding: [CR, LF], as: Unicode.UTF8.self)

protocol _ParserTestHelpers {
    
}

final class ParserUnitTests: XCTestCase, _ParserTestHelpers {}

extension _ParserTestHelpers {
    private func iterateTestInputs_generic<T: Equatable>(_ inputs: [(String, String, T, UInt)], testFunction: (inout ByteBuffer, StackTracker) throws -> T) {
        for (input, terminator, expected, line) in inputs {
            TestUtilities.withBuffer(input, terminator: terminator, shouldRemainUnchanged: false, file: (#file), line: line) { (buffer) in
                let testValue = try testFunction(&buffer, .testTracker)
                XCTAssertEqual(testValue, expected, line: line)
            }
        }
    }

    private func iterateInvalidTestInputs_ParserError_generic<T: Equatable>(_ inputs: [(String, String, UInt)], testFunction: (inout ByteBuffer, StackTracker) throws -> T) {
        for (input, terminator, line) in inputs {
            TestUtilities.withBuffer(input, terminator: terminator, shouldRemainUnchanged: true, file: (#file), line: line) { (buffer) in
                XCTAssertThrowsError(try testFunction(&buffer, .testTracker), line: line) { e in
                    XCTAssertTrue(e is ParserError, "Expected ParserError, got \(e)", line: line)
                }
            }
        }
    }

    private func iterateInvalidTestInputs_IncompleteMessage_generic<T: Equatable>(_ inputs: [(String, String, UInt)], testFunction: (inout ByteBuffer, StackTracker) throws -> T) {
        for (input, terminator, line) in inputs {
            TestUtilities.withBuffer(input, terminator: terminator, shouldRemainUnchanged: true, file: (#file), line: line) { (buffer) in
                XCTAssertThrowsError(try testFunction(&buffer, .testTracker), line: line) { e in
                    XCTAssertTrue(e is _IncompleteMessage, "Expected IncompleteMessage, got \(e)", line: line)
                }
            }
        }
    }

    private func iterateTestInputs(_ inputs: [(String, String, UInt)], testFunction: (inout ByteBuffer, StackTracker) throws -> Void) {
        for (input, terminator, line) in inputs {
            TestUtilities.withBuffer(input, terminator: terminator, shouldRemainUnchanged: false, file: (#file), line: line) { (buffer) in
                try testFunction(&buffer, .testTracker)
            }
        }
    }

    private func iterateInvalidTestInputs_ParserError(_ inputs: [(String, String, UInt)], testFunction: (inout ByteBuffer, StackTracker) throws -> Void) {
        for (input, terminator, line) in inputs {
            TestUtilities.withBuffer(input, terminator: terminator, shouldRemainUnchanged: true, file: (#file), line: line) { (buffer) in
                XCTAssertThrowsError(try testFunction(&buffer, .testTracker), line: line) { e in
                    XCTAssertTrue(e is ParserError, "Expected ParserError, got \(e)", line: line)
                }
            }
        }
    }

    private func iterateInvalidTestInputs_IncompleteMessage(_ inputs: [(String, String, UInt)], testFunction: (inout ByteBuffer, StackTracker) throws -> Void) {
        for (input, terminator, line) in inputs {
            TestUtilities.withBuffer(input, terminator: terminator, shouldRemainUnchanged: true, file: (#file), line: line) { (buffer) in
                XCTAssertThrowsError(try testFunction(&buffer, .testTracker), line: line) { e in
                    XCTAssertTrue(e is _IncompleteMessage, "Expected IncompleteMessage, got \(e)", line: line)
                }
            }
        }
    }

    /// Convenience function to run a variety of happy and non-happy tests.
    /// - parameter testFunction: The function to be tested, inputs will be provided to this function.
    /// - parameter validInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should succeed.
    /// - parameter parserErrorInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should fail by throwing a `ParserError`.
    /// - parameter incompleteMessageInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should fail by throwing an `_IncompleteMessage`.
    func iterateTests<T: Equatable>(
        testFunction: (inout ByteBuffer, StackTracker) throws -> T,
        validInputs: [(String, String, T, UInt)],
        parserErrorInputs: [(String, String, UInt)],
        incompleteMessageInputs: [(String, String, UInt)]
    ) {
        self.iterateTestInputs_generic(validInputs, testFunction: testFunction)
        self.iterateInvalidTestInputs_ParserError_generic(parserErrorInputs, testFunction: testFunction)
        self.iterateInvalidTestInputs_IncompleteMessage_generic(incompleteMessageInputs, testFunction: testFunction)
    }

    /// Convenience function to run a variety of happy and non-happy tests.
    /// - parameter testFunction: The function to be tested, inputs will be provided to this function.
    /// - parameter validInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should succeed.
    /// - parameter parserErrorInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should fail by throwing a `ParserError`.
    /// - parameter incompleteMessageInputs: An array of (Input, Terminator, ExectedResult, Line). These inputs should fail by throwing an `_IncompleteMessage`.
    func iterateTests(
        testFunction: (inout ByteBuffer, StackTracker) throws -> Void,
        validInputs: [(String, String, UInt)],
        parserErrorInputs: [(String, String, UInt)],
        incompleteMessageInputs: [(String, String, UInt)]
    ) {
        self.iterateTestInputs(validInputs, testFunction: testFunction)
        self.iterateInvalidTestInputs_ParserError(parserErrorInputs, testFunction: testFunction)
        self.iterateInvalidTestInputs_IncompleteMessage(incompleteMessageInputs, testFunction: testFunction)
    }
}

// MARK: - General usage tests

extension ParserUnitTests {
    func testCommandToStreamToCommand() {
        // 1 NOOP
        // 2 APPEND INBOX {10}\r\n01234567890
        // 3 NOOP
        var buffer: ByteBuffer = "1 NOOP\r\n2 APPEND INBOX {10}\r\n0123456789\r\n3 NOOP\r\n"

        var parser = CommandParser()
        do {
            let c1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            let c3 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c1, PartialCommandStream(.command(TaggedCommand(tag: "1", command: .noop)), numberOfSynchronisingLiterals: 1))
            XCTAssertEqual(c2_1, PartialCommandStream(.append(.start(tag: "2", appendingTo: .inbox))))
            XCTAssertEqual(c2_2, PartialCommandStream(.append(.beginMessage(message: .init(options: .init(flagList: [], extensions: []), data: .init(byteCount: 10))))))
            XCTAssertEqual(c2_3, PartialCommandStream(.append(.messageBytes("0123456789"))))
            XCTAssertEqual(c2_4, PartialCommandStream(.append(.endMessage)))
            XCTAssertEqual(c2_5, PartialCommandStream(.append(.finish)))
            XCTAssertEqual(c3, PartialCommandStream(.command(TaggedCommand(tag: "3", command: .noop))))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testCommandToStreamToCommand_catenateExampleOne() {
        var buffer: ByteBuffer = ByteBuffer(string: #"1 NOOP\#r\#n"# +
            #"A003 APPEND Drafts (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {42}\#r\#n"# +
            #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME" "# +
            #"URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1" TEXT {42}\#r\#n"# +
            #"\#r\#n--------------030308070208000400050907\#r\#n"# +
            #" URL "/Drafts;UIDVALIDITY=385759045/;UID=30" TEXT {44}\#r\#n"# +
            #"\#r\#n--------------030308070208000400050907--\#r\#n)\#r\#n"#)

        var parser = CommandParser()
        do {
            let c1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            let c2_6 = try parser.parseCommandStream(buffer: &buffer)
            let c2_7 = try parser.parseCommandStream(buffer: &buffer)
            let c2_8 = try parser.parseCommandStream(buffer: &buffer)
            let c2_9 = try parser.parseCommandStream(buffer: &buffer)
            let c2_10 = try parser.parseCommandStream(buffer: &buffer)
            let c2_11 = try parser.parseCommandStream(buffer: &buffer)
            let c2_12 = try parser.parseCommandStream(buffer: &buffer)
            let c2_13 = try parser.parseCommandStream(buffer: &buffer)
            let c2_14 = try parser.parseCommandStream(buffer: &buffer)
            let c2_15 = try parser.parseCommandStream(buffer: &buffer)
            let c2_16 = try parser.parseCommandStream(buffer: &buffer)
            let c2_17 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c1, PartialCommandStream(.command(TaggedCommand(tag: "1", command: .noop)), numberOfSynchronisingLiterals: 3))
            XCTAssertEqual(c2_1, PartialCommandStream(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
            XCTAssertEqual(c2_2, PartialCommandStream(.append(.beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [])))))
            XCTAssertEqual(c2_3, PartialCommandStream(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER"))))
            XCTAssertEqual(c2_4, PartialCommandStream(.append(.catenateData(.begin(size: 42)))))
            XCTAssertEqual(c2_5, PartialCommandStream(.append(.catenateData(.bytes("\r\n--------------030308070208000400050907\r\n")))))
            XCTAssertEqual(c2_6, PartialCommandStream(.append(.catenateData(.end))))
            XCTAssertEqual(c2_7, PartialCommandStream(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME"))))
            XCTAssertEqual(c2_8, PartialCommandStream(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1"))))
            XCTAssertEqual(c2_9, PartialCommandStream(.append(.catenateData(.begin(size: 42)))))
            XCTAssertEqual(c2_10, PartialCommandStream(.append(.catenateData(.bytes("\r\n--------------030308070208000400050907\r\n")))))
            XCTAssertEqual(c2_11, PartialCommandStream(.append(.catenateData(.end))))
            XCTAssertEqual(c2_12, PartialCommandStream(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=30"))))
            XCTAssertEqual(c2_13, PartialCommandStream(.append(.catenateData(.begin(size: 44)))))
            XCTAssertEqual(c2_14, PartialCommandStream(.append(.catenateData(.bytes("\r\n--------------030308070208000400050907--\r\n")))))
            XCTAssertEqual(c2_15, PartialCommandStream(.append(.catenateData(.end))))
            XCTAssertEqual(c2_16, PartialCommandStream(.append(.endCatenate)))
            XCTAssertEqual(c2_17, PartialCommandStream(.append(.finish)))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testCommandToStreamToCommand_catenateShortExample() {
        var buffer: ByteBuffer = ByteBuffer(string: #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#)

        var parser = CommandParser()
        do {
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c2_1, PartialCommandStream(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
            XCTAssertEqual(c2_2, PartialCommandStream(.append(.beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [])))))
            XCTAssertEqual(c2_3, PartialCommandStream(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER"))))
            XCTAssertEqual(c2_4, PartialCommandStream(.append(.endCatenate)))
            XCTAssertEqual(c2_5, PartialCommandStream(.append(.finish)))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testCatenate_failsToParseWithExtraSpace() {
        var buffer: ByteBuffer = ByteBuffer(string: #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE ( URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#)

        var parser = CommandParser()
        XCTAssertNoThrow(try parser.parseCommandStream(buffer: &buffer)) // .append(.start)
        XCTAssertNoThrow(try parser.parseCommandStream(buffer: &buffer)) // .append(.beginCatenate)
        XCTAssertThrowsError(try parser.parseCommandStream(buffer: &buffer))
    }

    func testCommandToStreamToCommand_catenateAndOptions() {
        var buffer: ByteBuffer = ByteBuffer(string: #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) EXTENSION (extdata) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#)

        var parser = CommandParser()
        do {
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c2_1, PartialCommandStream(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
            XCTAssertEqual(c2_2, PartialCommandStream(.append(.beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [TaggedExtension(label: "EXTENSION", value: .comp(["extdata"]))])))))
            XCTAssertEqual(c2_3, PartialCommandStream(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER"))))
            XCTAssertEqual(c2_4, PartialCommandStream(.append(.endCatenate)))
            XCTAssertEqual(c2_5, PartialCommandStream(.append(.finish)))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testCommandToStreamToCommand_catenateAndOptions_weirdCasing() {
        var buffer: ByteBuffer = ByteBuffer(string: #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) EXTENSION (extdata) cAtEnAtE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#)

        var parser = CommandParser()
        do {
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c2_1, PartialCommandStream(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
            XCTAssertEqual(c2_2, PartialCommandStream(.append(.beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [TaggedExtension(label: "EXTENSION", value: .comp(["extdata"]))])))))
            XCTAssertEqual(c2_3, PartialCommandStream(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER"))))
            XCTAssertEqual(c2_4, PartialCommandStream(.append(.endCatenate)))
            XCTAssertEqual(c2_5, PartialCommandStream(.append(.finish)))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testIdle() {
        // 1 NOOP
        // 2 IDLE\r\nDONE\r\n
        // 3 NOOP
        var buffer: ByteBuffer = "1 NOOP\r\n2 IDLE\r\nDONE\r\n3 NOOP\r\n"

        var parser = CommandParser()
        do {
            let c1 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c1, PartialCommandStream(.command(TaggedCommand(tag: "1", command: .noop))))
            XCTAssertEqual(parser.mode, .lines)

            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c2_1, PartialCommandStream(.command(TaggedCommand(tag: "2", command: .idleStart))))
            XCTAssertEqual(parser.mode, .idle)

            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c2_2, PartialCommandStream(CommandStream.idleDone))
            XCTAssertEqual(parser.mode, .lines)

            let c3 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c3, PartialCommandStream(.command(TaggedCommand(tag: "3", command: .noop))))
            XCTAssertEqual(parser.mode, .lines)
        } catch {
            XCTFail("\(error)")
        }
    }
}

// MARK: - address parseAddress

extension ParserUnitTests {
    func testAddress_valid() {
        self.iterateTests(
            testFunction: GrammarParser.parseAddress,
            validInputs: [
                ("(NIL NIL NIL NIL)", "", .init(name: nil, adl: nil, mailbox: nil, host: nil), #line),
                (#"("a" "b" "c" "d")"#, "", .init(name: "a", adl: "b", mailbox: "c", host: "d"), #line),
            ],
            parserErrorInputs: [
                ("(NIL NIL NIL NIL ", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("(NIL ", "", #line),
            ]
        )
    }
}

// MARK: - append

extension ParserUnitTests {}

// MARK: - parseAppendData

extension ParserUnitTests {
    func testParseAppendData() {
        self.iterateTests(
            testFunction: GrammarParser.parseAppendData,
            validInputs: [
                ("{123}\r\n", "hello", .init(byteCount: 123), #line),
                ("~{456}\r\n", "hello", .init(byteCount: 456, withoutContentTransferEncoding: true), #line),
                ("{0}\r\n", "hello", .init(byteCount: 0), #line),
                ("~{\(Int.max)}\r\n", "hello", .init(byteCount: .max, withoutContentTransferEncoding: true), #line),
                ("{123+}\r\n", "hello", .init(byteCount: 123), #line),
                ("~{456+}\r\n", "hello", .init(byteCount: 456, withoutContentTransferEncoding: true), #line),
                ("{0+}\r\n", "hello", .init(byteCount: 0), #line),
                ("~{\(Int.max)+}\r\n", "hello", .init(byteCount: .max, withoutContentTransferEncoding: true), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testNegativeAppendDataDoesNotParse() {
        TestUtilities.withBuffer("{-1}\r\n", shouldRemainUnchanged: true) { buffer in
            XCTAssertThrowsError(try GrammarParser.parseAppendData(buffer: &buffer, tracker: .testTracker)) { error in
                XCTAssertNotNil(error as? ParserError)
            }
        }
    }

    func testHugeAppendDataDoesNotParse() {
        let oneAfterMaxInt = "\(UInt(Int.max) + 1)"
        TestUtilities.withBuffer("{\(oneAfterMaxInt)}\r\n", shouldRemainUnchanged: true) { buffer in
            XCTAssertThrowsError(try GrammarParser.parseAppendData(buffer: &buffer, tracker: .testTracker)) { error in
                XCTAssertNotNil(error as? ParserError)
            }
        }
    }
}

// MARK: - parseAppendMessage

extension ParserUnitTests {
    // NOTE: Spec is ambiguous when parsing `append-data`, which may contain `append-data-ext`, which is the same as `append-ext`, which is inside `append-opts`
    func testParseMessage() {
        self.iterateTests(
            testFunction: GrammarParser.parseAppendMessage,
            validInputs: [
                (
                    " (\\Answered) {123}\r\n",
                    "test",
                    .init(options: .init(flagList: [.answered], internalDate: nil, extensions: []), data: .init(byteCount: 123)),
                    #line
                ),
                (
                    " (\\Answered) ~{456}\r\n",
                    "test",
                    .init(options: .init(flagList: [.answered], internalDate: nil, extensions: []), data: .init(byteCount: 456, withoutContentTransferEncoding: true)),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMetadataOption

extension ParserUnitTests {
    func testParseMetadataOption() {
        self.iterateTests(
            testFunction: GrammarParser.parseMetadataOption,
            validInputs: [
                ("MAXSIZE 123", "\r", .maxSize(123), #line),
                ("DEPTH 1", "\r", .scope(.one), #line),
                ("param", "\r", .other(.init(name: "param")), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMetadataOptions

extension ParserUnitTests {
    func testParseMetadataOptions() {
        self.iterateTests(
            testFunction: GrammarParser.parseMetadataOptions,
            validInputs: [
                ("(MAXSIZE 123)", "\r", [.maxSize(123)], #line),
                ("(DEPTH 1 MAXSIZE 123)", "\r", [.scope(.one), .maxSize(123)], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMetadatResponse

extension ParserUnitTests {
    func testParseMetadataResponse() {
        self.iterateTests(
            testFunction: GrammarParser.parseMetadataResponse,
            validInputs: [
                ("METADATA INBOX \"a\"", "\r", .list(list: ["a"], mailbox: .inbox), #line),
                ("METADATA INBOX \"a\" \"b\" \"c\"", "\r", .list(list: ["a", "b", "c"], mailbox: .inbox), #line),
                ("METADATA INBOX (\"a\" NIL)", "\r", .values(values: [.init(name: "a", value: .init(nil))], mailbox: .inbox), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMetadataValue

extension ParserUnitTests {
    func testParseMetadataValue() {
        self.iterateTests(
            testFunction: GrammarParser.parseMetadataValue,
            validInputs: [
                ("NIL", "\r", .init(nil), #line),
                ("\"a\"", "\r", .init("a"), #line),
                ("{1}\r\na", "\r", .init("a"), #line),
                ("~{1}\r\na", "\r", .init("a"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseAppendOptions

extension ParserUnitTests {
    func testParseAppendOptions() throws {
        let components = InternalDate.Components(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, timeZoneMinutes: 0)
        let date = InternalDate(components!)

        self.iterateTests(
            testFunction: GrammarParser.parseAppendOptions,
            validInputs: [
                ("", "\r", .init(flagList: [], internalDate: nil, extensions: []), #line),
                (" (\\Answered)", "\r", .init(flagList: [.answered], internalDate: nil, extensions: []), #line),
                (
                    " \"25-jun-1994 01:02:03 +0000\"",
                    "\r",
                    .init(flagList: [], internalDate: date, extensions: []),
                    #line
                ),
                (
                    " name1 1:2",
                    "\r",
                    .init(flagList: [], internalDate: nil, extensions: [.init(label: "name1", value: .sequence(SequenceSet(1 ... 2)))]),
                    #line
                ),
                (
                    " name1 1:2 name2 2:3 name3 3:4",
                    "\r",
                    .init(flagList: [], internalDate: nil, extensions: [
                        .init(label: "name1", value: .sequence(SequenceSet(1 ... 2))),
                        .init(label: "name2", value: .sequence(SequenceSet(2 ... 3))),
                        .init(label: "name3", value: .sequence(SequenceSet(3 ... 4))),
                    ]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - atom parseAtom

extension ParserUnitTests {
    func testAtom_valid() {
        TestUtilities.withBuffer("hello", terminator: " ") { (buffer) in
            let atom = try GrammarParser.parseAtom(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(atom, "hello")
        }
    }

    func testAtom_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "hello")
        XCTAssertThrowsError(try GrammarParser.parseAtom(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage)
        }
    }

    func testAtom_invalid_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: " ")
        XCTAssertThrowsError(try GrammarParser.parseAtom(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - atom parseAttributeFlag

extension ParserUnitTests {
    func testParseAttributeFlag() {
        self.iterateTests(
            testFunction: GrammarParser.parseAttributeFlag,
            validInputs: [
                ("\\\\Answered", " ", .answered, #line),
                ("some", " ", .init("some"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseAuthIMAPURL

extension ParserUnitTests {
    func testParseAuthIMAPURL() {
        self.iterateTests(
            testFunction: GrammarParser.parseAuthIMAPURL,
            validInputs: [
                ("imap://localhost/test/;UID=123", " ", .init(server: .init(host: "localhost"), messagePart: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123))), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseAuthIMAPURLFull

extension ParserUnitTests {
    func testParseAuthIMAPURLFull() {
        self.iterateTests(
            testFunction: GrammarParser.parseAuthIMAPURLFull,
            validInputs: [
                (
                    "imap://localhost/test/;UID=123;URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901",
                    " ",
                    .init(imapURL: .init(server: .init(host: "localhost"), messagePart: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123))), urlAuth: .init(auth: .init(access: .anonymous), verifier: .init(uAuthMechanism: .internal, encodedURLAuth: .init(data: "01234567890123456789012345678901")))),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseAuthIMAPURLRump

extension ParserUnitTests {
    func testParseAuthIMAPURLRump() {
        self.iterateTests(
            testFunction: GrammarParser.parseAuthIMAPURLRump,
            validInputs: [
                (
                    "imap://localhost/test/;UID=123;URLAUTH=anonymous",
                    " ",
                    .init(imapURL: .init(server: .init(host: "localhost"), messagePart: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123))), authRump: .init(access: .anonymous)),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseBase64

extension ParserUnitTests {
    func testParseBase64Terminal_valid_short() {
        TestUtilities.withBuffer("YWFh", terminator: " ") { (buffer) in
            let result = try GrammarParser.parseBase64(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, "aaa")
        }
    }

    func testParseBase64Terminal_valid_short_terminal() {
        TestUtilities.withBuffer("YQ==", terminator: " ") { (buffer) in
            let result = try GrammarParser.parseBase64(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, "a")
        }
    }
}

// MARK: - capability parseCapability

extension ParserUnitTests {
    func testParseCapability() {
        self.iterateTests(
            testFunction: GrammarParser.parseCapability,
            validInputs: [
                ("CONDSTORE", " ", .condStore, #line),
                ("AUTH=PLAIN", " ", .auth(.plain), #line),
                ("SPECIAL-USE", " ", .specialUse, #line),
                ("XSPECIAL", " ", .init("XSPECIAL"), #line),
                ("SPECIAL", " ", .init("SPECIAL"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testCapability_invalid_empty() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertTrue(error is _IncompleteMessage)
        }
    }
}

// MARK: - capability parseCapabilityData

extension ParserUnitTests {
    func testParseCapabilityData() {
        self.iterateTests(
            testFunction: GrammarParser.parseCapabilityData,
            validInputs: [
                ("CAPABILITY IMAP4rev1", "\r", [.imap4rev1], #line),
                ("CAPABILITY IMAP4 IMAP4rev1", "\r", [.imap4, .imap4rev1], #line),
                ("CAPABILITY FILTERS IMAP4", "\r", [.filters, .imap4], #line),
                ("CAPABILITY FILTERS IMAP4rev1 ENABLE", "\r", [.filters, .imap4rev1, .enable], #line),
                ("CAPABILITY FILTERS IMAP4rev1 ENABLE IMAP4", "\r", [.filters, .imap4rev1, .enable, .imap4], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseCharset

extension ParserUnitTests {
    func testParseCharset() {
        self.iterateTests(
            testFunction: GrammarParser.parseCharset,
            validInputs: [
                ("UTF8", " ", "UTF8", #line),
                ("\"UTF8\"", " ", "UTF8", #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseChangedSinceModifier

extension ParserUnitTests {
    func testParseChangedSinceModifier() {
        self.iterateTests(
            testFunction: GrammarParser.parseChangedSinceModifier,
            validInputs: [
                ("CHANGEDSINCE 1", " ", .init(modificationSequence: 1), #line),
                ("changedsince 1", " ", .init(modificationSequence: 1), #line),
            ],
            parserErrorInputs: [
                ("TEST", "", #line),
                ("CHANGEDSINCE a", "", #line),
            ],
            incompleteMessageInputs: [
                ("CHANGEDSINCE 1", "", #line),
            ]
        )
    }
}

// MARK: - parseUnchangedSinceModifier

extension ParserUnitTests {
    func testParseUnchangedSinceModifier() {
        self.iterateTests(
            testFunction: GrammarParser.parseUnchangedSinceModifier,
            validInputs: [
                ("UNCHANGEDSINCE 1", " ", .init(modificationSequence: 1), #line),
                ("unchangedsince 1", " ", .init(modificationSequence: 1), #line),
            ],
            parserErrorInputs: [
                ("TEST", "", #line),
                ("UNCHANGEDSINCE a", "", #line),
            ],
            incompleteMessageInputs: [
                ("UNCHANGEDSINCE 1", "", #line),
            ]
        )
    }
}

// MARK: - testParseContinuationRequest

extension ParserUnitTests {
    func testParseContinuationRequest() {
        self.iterateTests(
            testFunction: GrammarParser.parseContinuationRequest,
            validInputs: [
                ("+ OK\r\n", " ", .responseText(.init(code: nil, text: "OK")), #line),
                ("+ YQ==\r\n", " ", .data("a"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - create parseCreate

extension ParserUnitTests {
    func testParseCreate() {
        self.iterateTests(
            testFunction: GrammarParser.parseCreate,
            validInputs: [
                ("CREATE inbox", "\r", .create(.inbox, []), #line),
                ("CREATE inbox (some)", "\r", .create(.inbox, [.labelled(.init(name: "some", value: nil))]), #line),
                ("CREATE inbox (USE (\\All))", "\r", .create(.inbox, [.attributes([.all])]), #line),
                ("CREATE inbox (USE (\\All \\Flagged))", "\r", .create(.inbox, [.attributes([.all, .flagged])]), #line),
                (
                    "CREATE inbox (USE (\\All \\Flagged) some1 2 USE (\\Sent))",
                    "\r",
                    .create(.inbox, [.attributes([.all, .flagged]), .labelled(.init(name: "some1", value: .sequence([2]))), .attributes([.sent])]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: [
                ("CREATE inbox", "", #line),
                ("CREATE inbox (USE", "", #line),
            ]
        )
    }

    func testCreate_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "CREATE ")
        XCTAssertThrowsError(try GrammarParser.parseCreate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parseCreateParameter

extension ParserUnitTests {
    func testParseCreateParameter() {
        self.iterateTests(
            testFunction: GrammarParser.parseCreateParameter,
            validInputs: [
                ("param", "\r", .labelled(.init(name: "param")), #line),
                ("param 1", "\r", .labelled(.init(name: "param", value: .sequence([1]))), #line),
                ("USE (\\All)", "\r", .attributes([.all]), #line),
                ("USE (\\All \\Sent \\Drafts)", "\r", .attributes([.all, .sent, .drafts]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: [
                ("param", "", #line),
                ("param 1", "", #line),
                ("USE (\\Test", "", #line),
                ("USE (\\All ", "", #line),
            ]
        )
    }
}

// MARK: - parseCreateParameters

extension ParserUnitTests {
    func testParseCreateParameters() {
        self.iterateTests(
            testFunction: GrammarParser.parseCreateParameters,
            validInputs: [
                (" (param1 param2)", "\r", [.labelled(.init(name: "param1")), .labelled(.init(name: "param2"))], #line),
            ],
            parserErrorInputs: [
                (" (param1", "\r", #line),
            ],
            incompleteMessageInputs: [
                (" (param1", "", #line),
            ]
        )
    }
}

// MARK: - useAttribute parseUseAttribute

extension ParserUnitTests {
    func testParseUseAttribute() {
        self.iterateTests(
            testFunction: GrammarParser.parseUseAttribute,
            validInputs: [
                ("\\All", "", .all, #line),
                ("\\Archive", "", .archive, #line),
                ("\\Flagged", "", .flagged, #line),
                ("\\Trash", "", .trash, #line),
                ("\\Sent", "", .sent, #line),
                ("\\Drafts", "", .drafts, #line),
                ("\\Other", " ", .init("\\Other"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - condstore-param parseConditionalStoreParameter

extension ParserUnitTests {
    func testParseConditionalStoreParameter() {
        let inputs: [(String, UInt)] = [
            ("condstore", #line),
            ("CONDSTORE", #line),
            ("condSTORE", #line),
        ]

        for (input, line) in inputs {
            TestUtilities.withBuffer(input, terminator: " ") { (buffer) in
                XCTAssertNoThrow(try GrammarParser.parseConditionalStoreParameter(buffer: &buffer, tracker: .testTracker), line: line)
            }
        }
    }
}

// MARK: - Parse Continuation Request

extension ParserUnitTests {
    func testContinuationRequest_valid() {
        let inputs: [(String, String, ContinuationRequest, UInt)] = [
            ("+ Ready for additional command text\r\n", "", .responseText(.init(text: "Ready for additional command text")), #line),
            ("+ \r\n", "", .responseText(.init(text: "")), #line),
            ("+\r\n", "", .responseText(.init(text: "")), #line), // This is not standard conformant, but we’re allowing this.
        ]
        self.iterateTests(
            testFunction: GrammarParser.parseContinuationRequest,
            validInputs: inputs,
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - copy parseCopy

extension ParserUnitTests {
    func testCopy_valid() {
        TestUtilities.withBuffer("COPY 1,2,3 inbox", terminator: " ") { (buffer) in
            let copy = try GrammarParser.parseCopy(buffer: &buffer, tracker: .testTracker)
            let expectedSequence = SequenceSet([1, 2, 3])!
            let expectedMailbox = MailboxName.inbox
            XCTAssertEqual(copy, Command.copy(expectedSequence, expectedMailbox))
        }
    }

    func testCopy_invalid_missing_mailbox() {
        var buffer = TestUtilities.createTestByteBuffer(for: "COPY 1,2,3,4 ")
        XCTAssertThrowsError(try GrammarParser.newline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

    func testCopy_invalid_missing_set() {
        var buffer = TestUtilities.createTestByteBuffer(for: "COPY inbox ")
        XCTAssertThrowsError(try GrammarParser.newline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }
}

// MARK: - delete parseDelete

extension ParserUnitTests {
    func testDelete_valid() {
        TestUtilities.withBuffer("DELETE inbox", terminator: "\n") { (buffer) in
            let commandType = try GrammarParser.parseDelete(buffer: &buffer, tracker: .testTracker)
            guard case Command.delete(let mailbox) = commandType else {
                XCTFail("Didn't parse delete")
                return
            }
            XCTAssertEqual(mailbox, MailboxName("inbox"))
        }
    }

    func testDelete_valid_mixedCase() {
        TestUtilities.withBuffer("DELete inbox", terminator: "\n") { (buffer) in
            let commandType = try GrammarParser.parseDelete(buffer: &buffer, tracker: .testTracker)
            guard case Command.delete(let mailbox) = commandType else {
                XCTFail("Didn't parse delete")
                return
            }
            XCTAssertEqual(mailbox, MailboxName("inbox"))
        }
    }

    func testDelete_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "DELETE ")
        XCTAssertThrowsError(try GrammarParser.parseDelete(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parseInitialClientResponse

extension ParserUnitTests {
    func testParseInitialClientResponse() {
        self.iterateTests(
            testFunction: GrammarParser.parseInitialClientResponse,
            validInputs: [
                ("=", " ", .empty, #line),
                ("YQ==", " ", .data("a"), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - IAuth

extension ParserUnitTests {
    func testParseIAuth() {
        self.iterateTests(
            testFunction: GrammarParser.parseIAuth,
            validInputs: [
                (";AUTH=*", " ", .any, #line),
                (";AUTH=test", " ", .type(.init(authType: "test")), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseIRelativePath

extension ParserUnitTests {
    func testParseIRelativePath() {
        self.iterateTests(
            testFunction: GrammarParser.parseIRelativePath,
            validInputs: [
                ("test", " ", .list(.init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")))), #line),
                (";PARTIAL=1.2", " ", .messageOrPartial(.partialOnly(.init(range: .init(offset: 1, length: 2)))), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - IAbsolutePath

extension ParserUnitTests {
    func testParseIAbsolutePath() {
        self.iterateTests(
            testFunction: GrammarParser.parseIAbsolutePath,
            validInputs: [
                ("/", " ", .init(command: nil), #line),
                ("/test", " ", .init(command: .messageList(.init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test"))))), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - ICommand

extension ParserUnitTests {
    func testParseICommand() {
        self.iterateTests(
            testFunction: GrammarParser.parseICommand,
            validInputs: [
                ("test", " ", .messageList(.init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")))), #line),
                ("test/;UID=123", " ", .messagePart(part: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123)), urlAuth: nil), #line),
                ("test/;UID=123;URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901", " ", .messagePart(part: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123)), urlAuth: .init(auth: .init(access: .anonymous), verifier: .init(uAuthMechanism: .internal, encodedURLAuth: .init(data: "01234567890123456789012345678901")))), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - IUID

extension ParserUnitTests {
    func testParseIUID() {
        self.iterateTests(
            testFunction: GrammarParser.parseIUID,
            validInputs: [
                ("/;UID=1", " ", try! .init(uid: 1), #line),
                ("/;UID=12", " ", try! .init(uid: 12), #line),
                ("/;UID=123", " ", try! .init(uid: 123), #line),
            ],
            parserErrorInputs: [
                ("a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("/;UID=1", "", #line),
            ]
        )
    }
}

// MARK: - IUIDOnly

extension ParserUnitTests {
    func testParseIUIDOnly() {
        self.iterateTests(
            testFunction: GrammarParser.parseIUIDOnly,
            validInputs: [
                (";UID=1", " ", try! .init(uid: 1), #line),
                (";UID=12", " ", try! .init(uid: 12), #line),
                (";UID=123", " ", try! .init(uid: 123), #line),
            ],
            parserErrorInputs: [
                ("a", " ", #line),
            ],
            incompleteMessageInputs: [
                (";UID=1", "", #line),
            ]
        )
    }
}

// MARK: - IURLAuth

extension ParserUnitTests {
    func testParseIURLAuth() {
        self.iterateTests(
            testFunction: GrammarParser.parseIURLAuth,
            validInputs: [
                (";URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901", " ", .init(auth: .init(access: .anonymous), verifier: .init(uAuthMechanism: .internal, encodedURLAuth: .init(data: "01234567890123456789012345678901"))), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - IURLAuthRump

extension ParserUnitTests {
    func testParseIURLAuthRump() {
        self.iterateTests(
            testFunction: GrammarParser.parseIURLAuthRump,
            validInputs: [
                (";URLAUTH=anonymous", " ", .init(access: .anonymous), #line),
                (
                    ";EXPIRE=1234-12-23T12:34:56;URLAUTH=anonymous",
                    " ",
                    .init(expire: .init(dateTime: .init(date: .init(year: 1234, month: 12, day: 23), time: .init(hour: 12, minute: 34, second: 56))), access: .anonymous),
                    #line
                ),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - IUAVerifier

extension ParserUnitTests {
    func testParseIUAVerifier() {
        self.iterateTests(
            testFunction: GrammarParser.parseIUAVerifier,
            validInputs: [
                (":INTERNAL:01234567890123456789012345678901", " ", .init(uAuthMechanism: .internal, encodedURLAuth: .init(data: "01234567890123456789012345678901")), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - IUserInfo

extension ParserUnitTests {
    func testParseIUserInfo() {
        self.iterateTests(
            testFunction: GrammarParser.parseIUserInfo,
            validInputs: [
                (";AUTH=*", " ", .init(encodedUser: nil, iAuth: .any), #line),
                ("test", " ", .init(encodedUser: .init(data: "test"), iAuth: nil), #line),
                ("test;AUTH=*", " ", .init(encodedUser: .init(data: "test"), iAuth: .any), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - enable-data parseEnableData

extension ParserUnitTests {
    func testParseEnableData() {
        self.iterateTests(
            testFunction: GrammarParser.parseEnableData,
            validInputs: [
                ("ENABLED", "\r", [], #line),
                ("ENABLED ENABLE", "\r", [.enable], #line),
                ("ENABLED ENABLE CONDSTORE", "\r", [.enable, .condStore], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEItemVendorTag

extension ParserUnitTests {
    func testParseEItemVendorTag() {
        self.iterateTests(
            testFunction: GrammarParser.parseEitemVendorTag,
            validInputs: [
                ("token-atom", " ", EItemVendorTag(token: "token", atom: "atom"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEncodedAuthenticationType

extension ParserUnitTests {
    func testParseEncodedAuthenticationType() {
        self.iterateTests(
            testFunction: GrammarParser.parseEncodedAuthenticationType,
            validInputs: [
                ("hello%FF", " ", .init(authType: "hello%FF"), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseEncodedMailbox

extension ParserUnitTests {
    func testParseEncodedMailbox() {
        self.iterateTests(
            testFunction: GrammarParser.parseEncodedMailbox,
            validInputs: [
                ("hello%FF", " ", .init(mailbox: "hello%FF"), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseINetworkPath

extension ParserUnitTests {
    func testParseINetworkPath() {
        self.iterateTests(
            testFunction: GrammarParser.parseINetworkPath,
            validInputs: [
                ("//localhost/", " ", .init(server: .init(host: "localhost"), query: .init(command: nil)), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseEncodedSearch

extension ParserUnitTests {
    func testParseEncodedSearch() {
        self.iterateTests(
            testFunction: GrammarParser.parseEncodedSearch,
            validInputs: [
                ("query%FF", " ", .init(query: "query%FF"), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseEncodedSection

extension ParserUnitTests {
    func testParseEncodedSection() {
        self.iterateTests(
            testFunction: GrammarParser.parseEncodedSection,
            validInputs: [
                ("query%FF", " ", .init(section: "query%FF"), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseEncodedUser

extension ParserUnitTests {
    func testParseEncodedUser() {
        self.iterateTests(
            testFunction: GrammarParser.parseEncodedUser,
            validInputs: [
                ("query%FF", " ", .init(data: "query%FF"), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseEncodedURLAuth

extension ParserUnitTests {
    func testParseEncodedURLAuth() {
        self.iterateTests(
            testFunction: GrammarParser.parseEncodedURLAuth,
            validInputs: [
                ("0123456789abcdef01234567890abcde", "", .init(data: "0123456789abcdef01234567890abcde"), #line),
            ],
            parserErrorInputs: [
                ("0123456789zbcdef01234567890abcde", "", #line),
            ],
            incompleteMessageInputs: [
                ("0123456789", "", #line),
            ]
        )
    }
}

// MARK: - parseEnvelope

extension ParserUnitTests {
    func testParseEnvelopeTo_valid() {
        TestUtilities.withBuffer(#"("date" "subject" (("name1" "adl1" "mailbox1" "host1")) (("name2" "adl2" "mailbox2" "host2")) (("name3" "adl3" "mailbox3" "host3")) (("name4" "adl4" "mailbox4" "host4")) (("name5" "adl5" "mailbox5" "host5")) (("name6" "adl6" "mailbox6" "host6")) "someone" "messageid")"#) { (buffer) in
            let envelope = try GrammarParser.parseEnvelope(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(envelope.date, "date")
            XCTAssertEqual(envelope.subject, "subject")
            XCTAssertEqual(envelope.from, [.init(name: "name1", adl: "adl1", mailbox: "mailbox1", host: "host1")])
            XCTAssertEqual(envelope.sender, [.init(name: "name2", adl: "adl2", mailbox: "mailbox2", host: "host2")])
            XCTAssertEqual(envelope.reply, [.init(name: "name3", adl: "adl3", mailbox: "mailbox3", host: "host3")])
            XCTAssertEqual(envelope.to, [.init(name: "name4", adl: "adl4", mailbox: "mailbox4", host: "host4")])
            XCTAssertEqual(envelope.cc, [.init(name: "name5", adl: "adl5", mailbox: "mailbox5", host: "host5")])
            XCTAssertEqual(envelope.bcc, [.init(name: "name6", adl: "adl6", mailbox: "mailbox6", host: "host6")])
            XCTAssertEqual(envelope.inReplyTo, "someone")
            XCTAssertEqual(envelope.messageID, "messageid")
        }
    }
}

// MARK: - parseEsearchResponse

extension ParserUnitTests {
    func testParseEsearchResponse() {
        self.iterateTests(
            testFunction: GrammarParser.parseEsearchResponse,
            validInputs: [
                ("ESEARCH", "\r", .init(correlator: nil, uid: false, returnData: []), #line),
                ("ESEARCH UID", "\r", .init(correlator: nil, uid: true, returnData: []), #line),
                ("ESEARCH (TAG \"col\") UID", "\r", .init(correlator: SearchCorrelator(tag: "col"), uid: true, returnData: []), #line),
                ("ESEARCH (TAG \"col\") UID COUNT 2", "\r", .init(correlator: SearchCorrelator(tag: "col"), uid: true, returnData: [.count(2)]), #line),
                ("ESEARCH (TAG \"col\") UID MIN 1 MAX 2", "\r", .init(correlator: SearchCorrelator(tag: "col"), uid: true, returnData: [.min(1), .max(2)]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - examine parseExamine

extension ParserUnitTests {
    func testParseExamine() {
        self.iterateTests(
            testFunction: GrammarParser.parseExamine,
            validInputs: [
                ("EXAMINE inbox", "\r", .examine(.inbox, []), #line),
                ("examine inbox", "\r", .examine(.inbox, []), #line),
                ("EXAMINE inbox (number)", "\r", .examine(.inbox, [.init(name: "number", value: nil)]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testExamine_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "EXAMINE ")
        XCTAssertThrowsError(try GrammarParser.parseExamine(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parseExpire

extension ParserUnitTests {
    func testParseExpire() {
        self.iterateTests(
            testFunction: GrammarParser.parseExpire,
            validInputs: [
                (
                    ";EXPIRE=1234-12-20T12:34:56",
                    "\r",
                    Expire(dateTime: FullDateTime(date: FullDate(year: 1234, month: 12, day: 20), time: FullTime(hour: 12, minute: 34, second: 56))),
                    #line
                ),
                (
                    ";EXPIRE=1234-12-20t12:34:56",
                    "\r",
                    Expire(dateTime: FullDateTime(date: FullDate(year: 1234, month: 12, day: 20), time: FullTime(hour: 12, minute: 34, second: 56))),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - filter-name parseFilterName

extension ParserUnitTests {
    func testParseFilterName() {
        self.iterateTests(
            testFunction: GrammarParser.parseFilterName,
            validInputs: [
                ("a", " ", "a", #line),
                ("abcdefg", " ", "abcdefg", #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFlag

extension ParserUnitTests {
    func testParseFlag() {
        self.iterateTests(
            testFunction: GrammarParser.parseFlag,
            validInputs: [
                ("\\answered", " ", .answered, #line),
                ("\\flagged", " ", .flagged, #line),
                ("\\deleted", " ", .deleted, #line),
                ("\\seen", " ", .seen, #line),
                ("\\draft", " ", .draft, #line),
                ("keyword", " ", .keyword(Flag.Keyword("keyword")), #line),
                ("\\extension", " ", .extension("\\extension"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFullDateTime

extension ParserUnitTests {
    func testParseFullDateTime() {
        self.iterateTests(
            testFunction: GrammarParser.parseFullDateTime,
            validInputs: [
                (
                    "1234-12-20T11:22:33",
                    " ",
                    .init(date: .init(year: 1234, month: 12, day: 20), time: .init(hour: 11, minute: 22, second: 33)),
                    #line
                ),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseFullDate

extension ParserUnitTests {
    func testParseFullDate() {
        self.iterateTests(
            testFunction: GrammarParser.parseFullDate,
            validInputs: [
                ("1234-12-23", " ", .init(year: 1234, month: 12, day: 23), #line),
            ],
            parserErrorInputs: [
                ("a", "", #line),
            ],
            incompleteMessageInputs: [
                ("1234", "", #line),
            ]
        )
    }
}

// MARK: - parseFullTime

extension ParserUnitTests {
    func testParseFullTime() {
        self.iterateTests(
            testFunction: GrammarParser.parseFullTime,
            validInputs: [
                ("12:34:56", " ", .init(hour: 12, minute: 34, second: 56), #line),
                ("12:34:56.123456", " ", .init(hour: 12, minute: 34, second: 56, fraction: 123456), #line),
            ],
            parserErrorInputs: [
                ("a", "", #line),
                ("1234:56:12", "", #line),
            ],
            incompleteMessageInputs: [
                ("1234", "", #line),
            ]
        )
    }
}

// MARK: - parseFlagExtension

extension ParserUnitTests {
    func testParseFlagExtension_valid() {
        TestUtilities.withBuffer("\\Something", terminator: " ") { (buffer) in
            let flagExtension = try GrammarParser.parseFlagExtension(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flagExtension, "\\Something")
        }
    }

    func testParseFlagExtension_invalid_noSlash() {
        var buffer = "Something " as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseFlagExtension(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - parseFlagKeyword

extension ParserUnitTests {
    func testParseFlagKeyword_valid() {
        TestUtilities.withBuffer("keyword", terminator: " ") { (buffer) in
            let flagExtension = try GrammarParser.parseFlagKeyword(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flagExtension, Flag.Keyword("keyword"))
        }
    }
}

// MARK: - parseHeaderList

extension ParserUnitTests {
    func testHeaderList_valid_one() {
        TestUtilities.withBuffer(#"("field")"#) { (buffer) in
            let array = try GrammarParser.parseHeaderList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(array[0], "field")
        }
    }

    func testHeaderList_valid_many() {
        TestUtilities.withBuffer(#"("first" "second" "third")"#) { (buffer) in
            let array = try GrammarParser.parseHeaderList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(array[0], "first")
            XCTAssertEqual(array[1], "second")
            XCTAssertEqual(array[2], "third")
        }
    }

    func testHeaderList_invalid_none() {
        var buffer = #"()"# as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseHeaderList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - id (parseID, parseIDResponse, parseIDParamsList)

extension ParserUnitTests {
    func testParseIDParamsList() {
        self.iterateTests(
            testFunction: GrammarParser.parseIDParamsList,
            validInputs: [
                ("NIL", " ", [], #line),
                (#"("key1" "value1")"#, "", [.init(key: "key1", value: "value1")], #line),
                (
                    #"("key1" "value1" "key2" "value2" "key3" "value3")"#,
                    "",
                    [
                        .init(key: "key1", value: "value1"),
                        .init(key: "key2", value: "value2"),
                        .init(key: "key3", value: "value3"),
                    ],
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseIPartial

extension ParserUnitTests {
    func testParseIPartial() {
        self.iterateTests(
            testFunction: GrammarParser.parseIPartial,
            validInputs: [
                ("/;PARTIAL=1", " ", .init(range: .init(offset: 1, length: nil)), #line),
                ("/;PARTIAL=1.2", " ", .init(range: .init(offset: 1, length: 2)), #line),
            ],
            parserErrorInputs: [
                ("/;PARTIAL=a", " ", #line),
                ("PARTIAL=a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("/;PARTIAL=1", "", #line),
            ]
        )
    }
}

// MARK: - parseIPartialOnly

extension ParserUnitTests {
    func testParseIPartialOnly() {
        self.iterateTests(
            testFunction: GrammarParser.parseIPartialOnly,
            validInputs: [
                (";PARTIAL=1", " ", .init(range: .init(offset: 1, length: nil)), #line),
                (";PARTIAL=1.2", " ", .init(range: .init(offset: 1, length: 2)), #line),
            ],
            parserErrorInputs: [
                (";PARTIAL=a", " ", #line),
                ("PARTIAL=a", " ", #line),
            ],
            incompleteMessageInputs: [
                (";PARTIAL=1", "", #line),
            ]
        )
    }
}

// MARK: - parseIPathQuery

extension ParserUnitTests {
    func testParseIPathQuery() {
        self.iterateTests(
            testFunction: GrammarParser.parseIPathQuery,
            validInputs: [
                ("/", " ", .init(command: nil), #line),
                ("/test", " ", .init(command: .messageList(.init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test"))))), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseISection

extension ParserUnitTests {
    func testParseISection() {
        self.iterateTests(
            testFunction: GrammarParser.parseISection,
            validInputs: [
                ("/;SECTION=a", " ", ISection(encodedSection: .init(section: "a")), #line),
                ("/;SECTION=abc", " ", ISection(encodedSection: .init(section: "abc")), #line),
            ],
            parserErrorInputs: [
                ("SECTION=a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("/;SECTION=1", "", #line),
            ]
        )
    }
}

// MARK: - parseISectionOnly

extension ParserUnitTests {
    func testParseISectionOnly() {
        self.iterateTests(
            testFunction: GrammarParser.parseISectionOnly,
            validInputs: [
                (";SECTION=a", " ", ISection(encodedSection: .init(section: "a")), #line),
                (";SECTION=abc", " ", ISection(encodedSection: .init(section: "abc")), #line),
            ],
            parserErrorInputs: [
                ("SECTION=a", " ", #line),
            ],
            incompleteMessageInputs: [
                (";SECTION=1", "", #line),
            ]
        )
    }
}

// MARK: - parseIServer

extension ParserUnitTests {
    func testParseIServer() {
        self.iterateTests(
            testFunction: GrammarParser.parseIServer,
            validInputs: [
                ("localhost", " ", .init(userInfo: nil, host: "localhost", port: nil), #line),
                (";AUTH=*@localhost", " ", .init(userInfo: .init(encodedUser: nil, iAuth: .any), host: "localhost", port: nil), #line),
                ("localhost:1234", " ", .init(userInfo: nil, host: "localhost", port: 1234), #line),
                (";AUTH=*@localhost:1234", " ", .init(userInfo: .init(encodedUser: nil, iAuth: .any), host: "localhost", port: 1234), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseIMailboxReference

extension ParserUnitTests {
    func testParseIMailboxReference() {
        self.iterateTests(
            testFunction: GrammarParser.parseIMailboxReference,
            validInputs: [
                ("abc", " ", .init(encodeMailbox: .init(mailbox: "abc"), uidValidity: nil), #line),
                ("abc;UIDVALIDITY=123", " ", .init(encodeMailbox: .init(mailbox: "abc"), uidValidity: 123), #line),
            ],
            parserErrorInputs: [
                ("¢", " ", #line),
            ],
            incompleteMessageInputs: [
                ("abc", "", #line),
                ("abc123", "", #line),
            ]
        )
    }
}

// MARK: - parseIMapURL

extension ParserUnitTests {
    func testParseIMAPURL() {
        self.iterateTests(
            testFunction: GrammarParser.parseIMAPURL,
            validInputs: [
                ("imap://localhost/", " ", .init(server: .init(host: "localhost"), query: .init(command: nil)), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseURLRumpMechanism

extension ParserUnitTests {
    func testParseURLRumpMechanism() {
        self.iterateTests(
            testFunction: GrammarParser.parseURLRumpMechanism,
            validInputs: [
                ("test INTERNAL", " ", .init(urlRump: "test", mechanism: .internal), #line),
                ("\"test\" INTERNAL", " ", .init(urlRump: "test", mechanism: .internal), #line),
                ("{4}\r\ntest INTERNAL", " ", .init(urlRump: "test", mechanism: .internal), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseURLFetchData

extension ParserUnitTests {
    func testParseURLFetchData() {
        self.iterateTests(
            testFunction: GrammarParser.parseURLFetchData,
            validInputs: [
                ("url NIL", " ", .init(url: "url", data: nil), #line),
                ("url \"data\"", " ", .init(url: "url", data: "data"), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseIMapURLRel

extension ParserUnitTests {
    func testParseIMAPURLRel() {
        self.iterateTests(
            testFunction: GrammarParser.parseRelativeIMAPURL,
            validInputs: [
                ("/test", " ", .absolutePath(.init(command: .messageList(.init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")))))), #line),
                ("//localhost/", " ", .networkPath(.init(server: .init(host: "localhost"), query: .init(command: nil))), #line),
                ("test", " ", .relativePath(.list(.init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test"))))), #line),
                ("", " ", .empty, #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseIMessageList

extension ParserUnitTests {
    func testParseIMessageList() {
        self.iterateTests(
            testFunction: GrammarParser.parseIMessageList,
            validInputs: [
                ("test", " ", .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test"), uidValidity: nil)), #line),
                ("test?query", " ", .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test"), uidValidity: nil), encodedSearch: .init(query: "query")), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseIMessageOrPart

extension ParserUnitTests {
    func testParseIMessageOrPartial() {
        self.iterateTests(
            testFunction: GrammarParser.parseIMessageOrPartial,
            validInputs: [
                (
                    ";PARTIAL=1.2",
                    " ",
                    .partialOnly(.init(range: .init(offset: 1, length: 2))),
                    #line
                ),
                (
                    ";SECTION=test",
                    " ",
                    .sectionPartial(section: .init(encodedSection: .init(section: "test")), partial: nil),
                    #line
                ),
                (
                    ";SECTION=test/;PARTIAL=1.2",
                    " ",
                    .sectionPartial(section: .init(encodedSection: .init(section: "test")), partial: .init(range: .init(offset: 1, length: 2))),
                    #line
                ),
                (
                    ";UID=123",
                    " ",
                    .uidSectionPartial(uid: try! .init(uid: 123), section: nil, partial: nil),
                    #line
                ),
                (
                    ";UID=123/;SECTION=test",
                    " ",
                    .uidSectionPartial(uid: try! .init(uid: 123), section: .init(encodedSection: .init(section: "test")), partial: nil),
                    #line
                ),
                (
                    ";UID=123/;PARTIAL=1.2",
                    " ",
                    .uidSectionPartial(uid: try! .init(uid: 123), section: nil, partial: .init(range: .init(offset: 1, length: 2))),
                    #line
                ),
                (
                    ";UID=123/;SECTION=test/;PARTIAL=1.2",
                    " ",
                    .uidSectionPartial(uid: try! .init(uid: 123), section: .init(encodedSection: .init(section: "test")), partial: .init(range: .init(offset: 1, length: 2))),
                    #line
                ),
                (
                    "test;UID=123",
                    " ",
                    .refUidSectionPartial(ref: .init(encodeMailbox: .init(mailbox: "test")), uid: try! .init(uid: 123), section: nil, partial: nil),
                    #line
                ),
                (
                    "test;UID=123/;SECTION=section",
                    " ",
                    .refUidSectionPartial(ref: .init(encodeMailbox: .init(mailbox: "test")), uid: try! .init(uid: 123), section: .init(encodedSection: .init(section: "section")), partial: nil),
                    #line
                ),
                (
                    "test;UID=123/;PARTIAL=1.2",
                    " ",
                    .refUidSectionPartial(ref: .init(encodeMailbox: .init(mailbox: "test")), uid: try! .init(uid: 123), section: nil, partial: .init(range: .init(offset: 1, length: 2))),
                    #line
                ),
                (
                    "test;UID=123/;SECTION=section/;PARTIAL=1.2",
                    " ",
                    .refUidSectionPartial(ref: .init(encodeMailbox: .init(mailbox: "test")), uid: try! .init(uid: 123), section: .init(encodedSection: .init(section: "section")), partial: .init(range: .init(offset: 1, length: 2))),
                    #line
                ),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseIMessagePart

extension ParserUnitTests {
    func testParseIMessagePart() {
        self.iterateTests(
            testFunction: GrammarParser.parseIMessagePart,
            validInputs: [
                (
                    "test/;UID=123",
                    " ",
                    .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123), iSection: nil, iPartial: nil),
                    #line
                ),
                (
                    "test/;UID=123/;SECTION=section",
                    " ",
                    .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123), iSection: .init(encodedSection: .init(section: "section")), iPartial: nil),
                    #line
                ),
                (
                    "test/;UID=123/;PARTIAL=1.2",
                    " ",
                    .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123), iSection: nil, iPartial: .init(range: .init(offset: 1, length: 2))),
                    #line
                ),
                (
                    "test/;UID=123/;SECTION=section/;PARTIAL=1.2",
                    " ",
                    .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123), iSection: .init(encodedSection: .init(section: "section")), iPartial: .init(range: .init(offset: 1, length: 2))),
                    #line
                ),
                (
                    "test/;UIDVALIDITY=123/;UID=123/;SECTION=section/;PARTIAL=1.2",
                    " ",
                    .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test/"), uidValidity: 123), iUID: try! .init(uid: 123), iSection: .init(encodedSection: .init(section: "section")), iPartial: .init(range: .init(offset: 1, length: 2))),
                    #line
                ),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseMediaBasic

extension ParserUnitTests {
    func testParseMediaBasic_valid_match() {
        var buffer = #""APPLICATION" "multipart/mixed""# as ByteBuffer
        do {
            let mediaBasic = try GrammarParser.parseMediaBasic(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(mediaBasic, Media.Basic(kind: .application, subtype: .mixed))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseMediaBasic_valid_string() {
        var buffer = #""STRING" "multipart/related""# as ByteBuffer
        do {
            let mediaBasic = try GrammarParser.parseMediaBasic(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(mediaBasic, Media.Basic(kind: .init("STRING"), subtype: .related))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseMediaBasic_valid_invalidString() {
        var buffer = #"hey "something""# as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseMediaBasic(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - media-message parseMediaMessage

extension ParserUnitTests {
    func testMediaMessage_valid_rfc() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"MESSAGE\" \"RFC822\"")
        XCTAssertNoThrow(try GrammarParser.parseMediaMessage(buffer: &buffer, tracker: .testTracker))
    }

    func testMediaMessage_valid_mixedCase() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"messAGE\" \"RfC822\"")
        XCTAssertNoThrow(try GrammarParser.parseMediaMessage(buffer: &buffer, tracker: .testTracker))
    }

    func testMediaMessage_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abcdefghijklmnopqrstuvwxyz\n")
        XCTAssertThrowsError(try GrammarParser.parseMediaMessage(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testMediaMessage_invalid_partial() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"messAGE\"")
        XCTAssertThrowsError(try GrammarParser.parseMediaMessage(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - media-text parseMediaText

extension ParserUnitTests {
    func testMediaText_valid() {
        TestUtilities.withBuffer(#""TEXT" "something""#, terminator: "\n") { (buffer) in
            let media = try GrammarParser.parseMediaText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(media, "something")
        }
    }

    func testMediaText_valid_mixedCase() {
        TestUtilities.withBuffer(#""TExt" "something""#, terminator: "\n") { (buffer) in
            let media = try GrammarParser.parseMediaText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(media, "something")
        }
    }

    func testMediaText_invalid_missingQuotes() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"TEXT "something"\n"#)
        XCTAssertThrowsError(try GrammarParser.parseMediaText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testMediaText_invalid_missingSubtype() {
        var buffer = TestUtilities.createTestByteBuffer(for: #""TEXT""#)
        XCTAssertThrowsError(try GrammarParser.parseMediaText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parseMessageAttribute

extension ParserUnitTests {
    func testParseMessageAttribute() throws {
        let components = InternalDate.Components(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, timeZoneMinutes: 0)
        let date = InternalDate(components!)

        self.iterateTests(
            testFunction: GrammarParser.parseMessageAttribute,
            validInputs: [
                ("UID 1234", " ", .uid(1234), #line),
                ("RFC822.SIZE 1234", " ", .rfc822Size(1234), #line),
                ("BINARY.SIZE[3] 4", " ", .binarySize(section: [3], size: 4), #line),
                ("BINARY[3] \"hello\"", " ", .binary(section: [3], data: "hello"), #line),
                (#"INTERNALDATE "25-jun-1994 01:02:03 +0000""#, " ", .internalDate(date), #line),
                (
                    #"ENVELOPE ("date" "subject" (("from1" "from2" "from3" "from4")) (("sender1" "sender2" "sender3" "sender4")) (("reply1" "reply2" "reply3" "reply4")) (("to1" "to2" "to3" "to4")) (("cc1" "cc2" "cc3" "cc4")) (("bcc1" "bcc2" "bcc3" "bcc4")) "inreplyto" "messageid")"#,
                    " ",
                    .envelope(Envelope(
                        date: "date",
                        subject: "subject",
                        from: [.init(name: "from1", adl: "from2", mailbox: "from3", host: "from4")],
                        sender: [.init(name: "sender1", adl: "sender2", mailbox: "sender3", host: "sender4")],
                        reply: [.init(name: "reply1", adl: "reply2", mailbox: "reply3", host: "reply4")],
                        to: [.init(name: "to1", adl: "to2", mailbox: "to3", host: "to4")],
                        cc: [.init(name: "cc1", adl: "cc2", mailbox: "cc3", host: "cc4")],
                        bcc: [.init(name: "bcc1", adl: "bcc2", mailbox: "bcc3", host: "bcc4")],
                        inReplyTo: "inreplyto",
                        messageID: "messageid"
                    )),
                    #line
                ),
                ("MODSEQ (3)", " ", .fetchModificationResponse(.init(modifierSequenceValue: 3)), #line),
                ("X-GM-MSGID 1278455344230334865", " ", .gmailMessageID(1278455344230334865), #line),
                ("X-GM-THRID 1278455344230334865", " ", .gmailThreadID(1278455344230334865), #line),
                ("X-GM-LABELS (\\Inbox \\Sent Important \"Muy Importante\")", " ", .gmailLabels([GmailLabel("\\Inbox"), GmailLabel("\\Sent"), GmailLabel("Important"), GmailLabel("Muy Importante")]), #line),
                ("X-GM-LABELS (foo)", " ", .gmailLabels([GmailLabel("foo")]), #line),
                ("X-GM-LABELS ()", " ", .gmailLabels([]), #line),
                ("X-GM-LABELS (\\Drafts)", " ", .gmailLabels([GmailLabel("\\Drafts")]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMessageData

extension ParserUnitTests {
    func testParseMessageData() {
        self.iterateTests(
            testFunction: GrammarParser.parseMessageData,
            validInputs: [
                ("3 EXPUNGE", "\r", .expunge(3), #line),
                ("VANISHED *", "\r", .vanished(.all), #line),
                ("VANISHED (EARLIER) *", "\r", .vanishedEarlier(.all), #line),
                ("GENURLAUTH test", "\r", .genURLAuth(["test"]), #line),
                ("GENURLAUTH test1 test2", "\r", .genURLAuth(["test1", "test2"]), #line),
                ("URLFETCH url NIL", "\r", .urlFetch([.init(url: "url", data: nil)]), #line),
                (
                    "URLFETCH url1 NIL url2 NIL url3 \"data\"",
                    "\r",
                    .urlFetch([.init(url: "url1", data: nil), .init(url: "url2", data: nil), .init(url: "url3", data: "data")]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - mod-sequence-value parseModifierSequenceValue

extension ParserUnitTests {
    func testParseModifierSequenceValue() {
        self.iterateTests(
            testFunction: GrammarParser.parseModificationSequenceValue,
            validInputs: [
                ("1", " ", 1, #line),
                ("123", " ", 123, #line),
                ("12345", " ", 12345, #line),
                ("1234567", " ", 1234567, #line),
                ("123456789", " ", 123456789, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - mod-sequence-valzer parseModifierSequenceValueZero

extension ParserUnitTests {
    func testParseModifierSequenceValueZero() {
        self.iterateTests(
            testFunction: GrammarParser.parseModificationSequenceValue,
            validInputs: [
                ("0", " ", .zero, #line),
                ("123", " ", 123, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - move parseMove

extension ParserUnitTests {
    func testParseMove() {
        self.iterateTests(
            testFunction: GrammarParser.parseMove,
            validInputs: [
                ("MOVE * inbox", " ", .move(.all, .inbox), #line),
                ("MOVE 1:2,4:5 test", " ", .move(SequenceSet([SequenceRange(1 ... 2), SequenceRange(4 ... 5)])!, .init("test")), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMechanismBase64

extension ParserUnitTests {
    func testParseMechanismBase64() {
        self.iterateTests(
            testFunction: GrammarParser.parseMechanismBase64,
            validInputs: [
                ("INTERNAL", " ", .init(mechanism: .internal, base64: nil), #line),
                ("INTERNAL=YQ==", " ", .init(mechanism: .internal, base64: "a"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseNamespaceCommand

extension ParserUnitTests {
    func testParseNamespaceCommand() {
        self.iterateTests(
            testFunction: GrammarParser.parseNamespaceCommand,
            validInputs: [
                ("NAMESPACE", " ", .namespace, #line),
                ("nameSPACE", " ", .namespace, #line),
                ("namespace", " ", .namespace, #line),
            ],
            parserErrorInputs: [
                ("something", " ", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("name", "", #line),
            ]
        )
    }
}

// MARK: - Namespace-Desc parseNamespaceResponse

extension ParserUnitTests {
    func testParseNamespaceDescription() {
        self.iterateTests(
            testFunction: GrammarParser.parseNamespaceDescription,
            validInputs: [
                ("(\"str1\" NIL)", " ", .init(string: "str1", char: nil, responseExtensions: []), #line),
                ("(\"str\" \"a\")", " ", .init(string: "str", char: "a", responseExtensions: []), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseNamespaceResponse

extension ParserUnitTests {
    func testParseNamespaceResponse() {
        self.iterateTests(
            testFunction: GrammarParser.parseNamespaceResponse,
            validInputs: [
                ("NAMESPACE nil nil nil", " ", .init(userNamespace: [], otherUserNamespace: [], sharedNamespace: []), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseNamespaceResponseExtension

extension ParserUnitTests {
    func testParseNamespaceResponseExtension() {
        self.iterateTests(
            testFunction: GrammarParser.parseNamespaceResponseExtension,
            validInputs: [
                (" \"str1\" (\"str2\")", " ", .init(string: "str1", array: ["str2"]), #line),
                (" \"str1\" (\"str2\" \"str3\" \"str4\")", " ", .init(string: "str1", array: ["str2", "str3", "str4"]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseNewline

extension ParserUnitTests {
    func testParseNewline() {
        self.iterateTests(
            testFunction: GrammarParser.newline,
            validInputs: [
                ("\n", "", #line),
                ("\r\n", "", #line),
            ],
            parserErrorInputs: [
                ("\\", " ", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("\r", "", #line),
            ]
        )
    }
}

// MARK: - parseNil

extension ParserUnitTests {
    func testParseNil() {
        self.iterateTests(
            testFunction: GrammarParser.parseNil,
            validInputs: [
                ("NIL", "", #line),
                ("nil", "", #line),
                ("NiL", "", #line),
            ],
            parserErrorInputs: [
                ("NIT", " ", #line),
                ("\"NIL\"", " ", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("N", "", #line),
                ("NI", "", #line),
            ]
        )
    }
}

// MARK: - nstring parseNString

extension ParserUnitTests {
    func testParseNString() {
        self.iterateTests(
            testFunction: GrammarParser.parseNString,
            validInputs: [
                ("NIL", "", nil, #line),
                ("{3}\r\nabc", "", "abc", #line),
                ("{3+}\r\nabc", "", "abc", #line),
                ("\"abc\"", "", "abc", #line),
            ],
            parserErrorInputs: [
                ("abc", " ", #line),
            ],
            incompleteMessageInputs: [
                ("\"", "", #line),
                ("NI", "", #line),
                ("{1}\r\n", "", #line),
            ]
        )
    }
}

// MARK: - number parseNumber

extension ParserUnitTests {
    func testNumber_valid() {
        self.iterateTests(
            testFunction: GrammarParser.parseNumber,
            validInputs: [
                ("1234", " ", 1234, #line),
                ("10", " ", 10, #line),
                ("0", " ", 0, #line),
            ],
            parserErrorInputs: [
                ("abcd", " ", #line),
            ],
            incompleteMessageInputs: [
                ("1234", "", #line),
            ]
        )
    }
}

// MARK: - nz-number parseNZNumber

extension ParserUnitTests {
    func testNZNumber() {
        self.iterateTests(
            testFunction: GrammarParser.parseNZNumber,
            validInputs: [
                ("1234", " ", 1234, #line),
                ("10", " ", 10, #line),
            ],
            parserErrorInputs: [
                ("0123", " ", #line),
                ("0000", " ", #line),
                ("abcd", " ", #line),
            ],
            incompleteMessageInputs: [
                ("1234", "", #line),
            ]
        )
    }
}

// MARK: - parsePartial

extension ParserUnitTests {
    func testParsePartial() {
        self.iterateTests(
            testFunction: GrammarParser.parsePartial,
            validInputs: [
                ("<0.1000000000>", " ", ClosedRange(uncheckedBounds: (0, 999_999_999)), #line),
                ("<0.4294967290>", " ", ClosedRange(uncheckedBounds: (0, 4_294_967_289)), #line),
                ("<1.2>", " ", ClosedRange(uncheckedBounds: (1, 2)), #line),
                ("<4294967290.2>", " ", ClosedRange(uncheckedBounds: (4294967290, 4294967291)), #line),
            ],
            parserErrorInputs: [
                ("<0.0>", " ", #line),
                ("<654.0>", " ", #line),
                ("<4294967296.2>", " ", #line),
                ("<4294967294.2>", " ", #line),
                ("<2.4294967294>", " ", #line),
                ("<4294967000.4294967000>", " ", #line),
                ("<2200000000.2200000000>", " ", #line),
            ],
            incompleteMessageInputs: [
                ("<", "", #line),
                ("<111111111", "", #line),
                ("<1.", "", #line),
                ("<1.22222222", "", #line),
            ]
        )
    }
}

// MARK: - parsePartialRange

extension ParserUnitTests {
    func testParsePartialRange() {
        self.iterateTests(
            testFunction: GrammarParser.parsePartialRange,
            validInputs: [
                ("1", " ", .init(offset: 1, length: nil), #line),
                ("1.2", " ", .init(offset: 1, length: 2), #line),
            ],
            parserErrorInputs: [
                ("a.1", " ", #line),
            ],
            incompleteMessageInputs: [
                ("1", "", #line),
                ("1.2", "", #line),
                ("1.", "", #line),
            ]
        )
    }
}

// MARK: - search parseScopeOption

extension ParserUnitTests {
    func testParseScopeOption() {
        self.iterateTests(
            testFunction: GrammarParser.parseScopeOption,
            validInputs: [
                ("DEPTH 0", "\r", .zero, #line),
                ("DEPTH 1", "\r", .one, #line),
                ("DEPTH infinity", "\r", .infinity, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseSection

extension ParserUnitTests {
    func testParseSection() {
        self.iterateTests(
            testFunction: GrammarParser.parseSection,
            validInputs: [
                ("[]", "", .complete, #line),
                ("[HEADER]", "", SectionSpecifier(kind: .header), #line),
            ],
            parserErrorInputs: [
                ("[", " ", #line),
                ("[HEADER", " ", #line),
            ],
            incompleteMessageInputs: [
                ("[", "", #line),
                ("[HEADER", "", #line),
            ]
        )
    }
}

// MARK: - parseSectionBinary

extension ParserUnitTests {
    func testParseSectionBinary() {
        self.iterateTests(
            testFunction: GrammarParser.parseSectionBinary,
            validInputs: [
                ("[]", "\r", [], #line),
                ("[1]", "\r", [1], #line),
                ("[1.2.3]", "\r", [1, 2, 3], #line),
            ],
            parserErrorInputs: [
                ("[", "\r", #line),
                ("1.2", "\r", #line),
                ("[1.2", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("[", "", #line),
                ("[1.2", "", #line),
                ("[1.2.", "", #line),
            ]
        )
    }
}

// MARK: - parseSectionPart

extension ParserUnitTests {
    func testParseSectionPart() {
        self.iterateTests(
            testFunction: GrammarParser.parseSectionPart,
            validInputs: [
                ("1", "\r", [1], #line),
                ("1.2", "\r", [1, 2], #line),
                ("1.2.3.4.5", "\r", [1, 2, 3, 4, 5], #line),
            ],
            parserErrorInputs: [
                ("", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("1.", "", #line),
            ]
        )
    }
}

// MARK: - parseSectionSpecifier

extension ParserUnitTests {
    func testParseSectionSpecifier() {
        self.iterateTests(
            testFunction: GrammarParser.parseSectionSpecifier,
            validInputs: [
                ("HEADER", "\r", .init(kind: .header), #line),
                ("1.2.3", "\r", .init(part: [1, 2, 3], kind: .complete), #line),
                ("1.2.3.HEADER", "\r", .init(part: [1, 2, 3], kind: .header), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: [
                ("", "", #line),
                ("1", "", #line),
                ("1.", "", #line),
            ]
        )
    }
}

// MARK: - parseSectionSpecifierKind

extension ParserUnitTests {
    func testParseSectionSpecifierKind() {
        self.iterateTests(
            testFunction: GrammarParser.parseSectionSpecifierKind,
            validInputs: [
                ("MIME", " ", .MIMEHeader, #line),
                ("HEADER", " ", .header, #line),
                ("TEXT", " ", .text, #line),
                ("HEADER.FIELDS (f1)", " ", .headerFields(["f1"]), #line),
                ("HEADER.FIELDS (f1 f2 f3)", " ", .headerFields(["f1", "f2", "f3"]), #line),
                ("HEADER.FIELDS.NOT (f1)", " ", .headerFieldsNot(["f1"]), #line),
                ("HEADER.FIELDS.NOT (f1 f2 f3)", " ", .headerFieldsNot(["f1", "f2", "f3"]), #line),
                ("", " ", .complete, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: [
                ("HEADER.FIELDS ", "", #line),
                ("HEADER.FIELDS (f1 f2 f3 ", "", #line),
            ]
        )
    }
}

// MARK: - select parseSelect

extension ParserUnitTests {
    func testParseSelect() {
        self.iterateTests(
            testFunction: GrammarParser.parseSelect,
            validInputs: [
                ("SELECT inbox", "\r", .select(.inbox, []), #line),
                ("SELECT inbox (some1)", "\r", .select(.inbox, [.basic(.init(name: "some1", value: nil))]), #line),
            ],
            parserErrorInputs: [
                ("SELECT ", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("SELECT ", "", #line),
            ]
        )
    }
}

// MARK: - parseSelectParameter

extension ParserUnitTests {
    func testParseSelectParameter() {
        self.iterateTests(
            testFunction: GrammarParser.parseSelectParameter,
            validInputs: [
                ("test 1", "\r", .basic(.init(name: "test", value: .sequence([1]))), #line),
                ("QRESYNC (1 1)", "\r", .qresync(.init(uidValiditiy: 1, modificationSequenceValue: 1, knownUids: nil, sequenceMatchData: nil)), #line),
                ("QRESYNC (1 1 1:2)", "\r", .qresync(.init(uidValiditiy: 1, modificationSequenceValue: 1, knownUids: [1 ... 2], sequenceMatchData: nil)), #line),
                ("QRESYNC (1 1 1:2 (* *))", "\r", .qresync(.init(uidValiditiy: 1, modificationSequenceValue: 1, knownUids: [1 ... 2], sequenceMatchData: .init(knownSequenceSet: .all, knownUidSet: .all))), #line),
            ],
            parserErrorInputs: [
                ("1", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("test ", "", #line),
                ("QRESYNC (", "", #line),
                ("QRESYNC (1 1", "", #line),
            ]
        )
    }
}

// MARK: - seq-number parseSequenceNumber

extension ParserUnitTests {
    func testParseSequenceNumber() {
        self.iterateTests(
            testFunction: GrammarParser.parseSequenceNumber,
            validInputs: [
                ("1", " ", 1, #line),
                ("10", " ", 10, #line),
            ],
            parserErrorInputs: [
                ("*", "", #line),
                ("0", "", #line),
                ("012", "", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("111", "", #line),
            ]
        )
    }
}

// MARK: - SequenceRange

extension ParserUnitTests {
    func testParseSequenceRange() {
        self.iterateTests(
            testFunction: GrammarParser.parseSequenceRange,
            validInputs: [
                ("*", "\r\n", SequenceRange.all, #line),
                ("1:*", "\r\n", SequenceRange.all, #line),
                ("12:34", "\r\n", SequenceRange(12 ... 34), #line),
                ("12:*", "\r\n", SequenceRange(12 ... (.max)), #line),
                ("1:34", "\r\n", SequenceRange((.min) ... 34), #line),
            ],
            parserErrorInputs: [
                ("a", "", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("111", "", #line),
            ]
        )
    }
}

// MARK: - sequence-set parseSequenceSet

extension ParserUnitTests {
    func testSequenceSet() {
        self.iterateTests(
            testFunction: GrammarParser.parseSequenceSet,
            validInputs: [
                ("765", " ", [765], #line),
                ("1,2:5,7,9:*", " ", [SequenceRange(1), SequenceRange(2 ... 5), SequenceRange(7), SequenceRange(9...)], #line),
                ("*", "\r", [.all], #line),
                ("1:2", "\r", [1 ... 2], #line),
                ("1:2,2:3,3:4", "\r", [1 ... 2, 2 ... 3, 3 ... 4], #line),
                ("$", "\r", .lastCommand, #line),
            ],
            parserErrorInputs: [
                ("a", " ", #line),
                (":", "", #line),
                (":2", "", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("1,", "", #line),
                ("1111", "", #line),
                ("1111:2222", "", #line),
            ]
        )
    }
}

// MARK: - status parseStatus

extension ParserUnitTests {
    func testParseStatus() {
        self.iterateTests(
            testFunction: GrammarParser.parseStatus,
            validInputs: [
                ("STATUS inbox (messages unseen)", "\r\n", .status(.inbox, [.messageCount, .unseenCount]), #line),
                ("STATUS Deleted (messages unseen HIGHESTMODSEQ)", "\r\n", .status(MailboxName("Deleted"), [.messageCount, .unseenCount, .highestModificationSequence]), #line),
            ],
            parserErrorInputs: [
                ("STATUS inbox (messages unseen", "\r\n", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("STATUS Deleted (messages ", "", #line),
            ]
        )
    }
}

// MARK: - status-att parseStatusAttribute

extension ParserUnitTests {
    func testStatusAttribute_valid_all() {
        for att in MailboxAttribute.AllCases() {
            do {
                var buffer = TestUtilities.createTestByteBuffer(for: att.rawValue)
                let parsedAtt = try GrammarParser.parseStatusAttribute(buffer: &buffer, tracker: .testTracker)
                XCTAssertEqual(att, parsedAtt)
            } catch {
                XCTFail()
                return
            }
        }
    }

    func testStatusAttribute_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "a")
        XCTAssertThrowsError(try GrammarParser.parseStatusAttribute(buffer: &buffer, tracker: .testTracker)) { _ in
        }
    }

    func testStatusAttribute_invalid_noMatch() {
        var buffer = TestUtilities.createTestByteBuffer(for: "a ")
        XCTAssertThrowsError(try GrammarParser.parseStatusAttribute(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }
}

// MARK: - status-att-list parseMailboxStatus

extension ParserUnitTests {
    func testStatusAttributeList_valid_single() {
        self.iterateTests(
            testFunction: GrammarParser.parseMailboxStatus,
            validInputs: [
                ("MESSAGES 1", "\r", .init(messageCount: 1), #line),
                ("MESSAGES 1 RECENT 2 UIDNEXT 3 UIDVALIDITY 4 UNSEEN 5 SIZE 6 HIGHESTMODSEQ 7", "\r", .init(messageCount: 1, recentCount: 2, nextUID: 3, uidValidity: 4, unseenCount: 5, size: 6, highestModificationSequence: 7), #line),
            ],
            parserErrorInputs: [
                ("MESSAGES UNSEEN 3 RECENT 4", "\r", #line),
                ("2 UNSEEN 3 RECENT 4", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("MESSAGES 2 UNSEEN ", "", #line),
            ]
        )
    }
}

// MARK: - parseStore

extension ParserUnitTests {
    func testParseStore() {
        self.iterateTests(
            testFunction: GrammarParser.parseStore,
            validInputs: [
                ("STORE 1 +FLAGS \\answered", "\r", .store([1], [], .add(silent: false, list: [.answered])), #line),
                ("STORE 1 (label) -FLAGS \\seen", "\r", .store([1], [.other(.init(name: "label", value: nil))], .remove(silent: false, list: [.seen])), #line),
            ],
            parserErrorInputs: [
                ("STORE +FLAGS \\answered", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("STORE ", "", #line),
                ("STORE 1 ", "", #line),
            ]
        )
    }
}

// MARK: - parseStoreModifier

extension ParserUnitTests {
    func testParseStoreModifier() {
        self.iterateTests(
            testFunction: GrammarParser.parseStoreModifier,
            validInputs: [
                ("UNCHANGEDSINCE 2", " ", .unchangedSince(.init(modificationSequence: 2)), #line),
                ("test", "\r", .other(.init(name: "test")), #line),
                ("test 1", " ", .other(.init(name: "test", value: .sequence([1]))), #line),
            ],
            parserErrorInputs: [
                ("1", " ", #line),
            ],
            incompleteMessageInputs: [
                ("UNCHANGEDSINCE 1", "", #line),
                ("test 1", "", #line),
            ]
        )
    }
}

// MARK: - parseStoreAttributeFlags

extension ParserUnitTests {
    func testParseStoreAttributeFlags() {
        self.iterateTests(
            testFunction: GrammarParser.parseStoreAttributeFlags,
            validInputs: [
                ("+FLAGS ()", "\r", .add(silent: false, list: []), #line),
                ("-FLAGS ()", "\r", .remove(silent: false, list: []), #line),
                ("FLAGS ()", "\r", .replace(silent: false, list: []), #line),
                ("+FLAGS.SILENT ()", "\r", .add(silent: true, list: []), #line),
                ("+FLAGS.SILENT (\\answered \\seen)", "\r", .add(silent: true, list: [.answered, .seen]), #line),
                ("+FLAGS.SILENT \\answered \\seen", "\r", .add(silent: true, list: [.answered, .seen]), #line),
            ],
            parserErrorInputs: [
                ("FLAGS.SILEN \\answered", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("+FLAGS ", "", #line),
                ("-FLAGS ", "", #line),
                ("FLAGS ", "", #line),
            ]
        )
    }
}

// MARK: - subscribe parseSubscribe

extension ParserUnitTests {
    func testParseSubscribe() {
        self.iterateTests(
            testFunction: GrammarParser.parseSubscribe,
            validInputs: [
                ("SUBSCRIBE inbox", "\r\n", .subscribe(.inbox), #line),
                ("SUBScribe INBOX", "\r\n", .subscribe(.inbox), #line),
            ],
            parserErrorInputs: [
                ("SUBSCRIBE ", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("SUBSCRIBE ", "", #line),
            ]
        )
    }
}

// MARK: - parseRename

extension ParserUnitTests {
    func testParseRename() {
        self.iterateTests(
            testFunction: GrammarParser.parseRename,
            validInputs: [
                ("RENAME box1 box2", "\r", .rename(from: .init("box1"), to: .init("box2"), params: []), #line),
                ("rename box3 box4", "\r", .rename(from: .init("box3"), to: .init("box4"), params: []), #line),
                ("RENAME box5 box6 (test)", "\r", .rename(from: .init("box5"), to: .init("box6"), params: [.init(name: "test", value: nil)]), #line),
            ],
            parserErrorInputs: [
                ("RENAME box1 ", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("RENAME box1 ", "", #line),
            ]
        )
    }
}

// MARK: - parseSequenceMatchData

extension ParserUnitTests {
    func testParseSequenceMatchData() {
        self.iterateTests(
            testFunction: GrammarParser.parseSequenceMatchData,
            validInputs: [
                ("(* *)", "\r", .init(knownSequenceSet: .all, knownUidSet: .all), #line),
                ("(1,2 3,4)", "\r", .init(knownSequenceSet: [1, 2], knownUidSet: [3, 4]), #line),
            ],
            parserErrorInputs: [
                ("()", "", #line),
                ("(* )", "", #line),
            ],
            incompleteMessageInputs: [
                ("(1", "", #line),
                ("(1111:2222", "", #line),
            ]
        )
    }
}

// MARK: - tag parseTag

extension ParserUnitTests {
    func testTag() {
        self.iterateTests(
            testFunction: GrammarParser.parseTag,
            validInputs: [
                ("abc", "\r", "abc", #line),
                ("abc", "+", "abc", #line),
            ],
            parserErrorInputs: [
                ("+", "", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
            ]
        )
    }
}

// MARK: - parseTaggedResponse

extension ParserUnitTests {
    func testParseTaggedResponse() {
        self.iterateTests(
            testFunction: GrammarParser.parseTaggedResponse,
            validInputs: [
                (
                    "15.16 OK Fetch completed (0.001 + 0.000 secs).\r\n",
                    "",
                    .init(tag: "15.16", state: .ok(.init(text: "Fetch completed (0.001 + 0.000 secs)."))),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("1+5.16 OK Fetch completed (0.001 \r\n", "", #line),
            ],
            incompleteMessageInputs: [
                ("15.16 ", "", #line),
                ("15.16 OK Fetch completed (0.001 + 0.000 secs).", "", #line),
            ]
        )
    }
}

// MARK: - parseTaggedExtension

extension ParserUnitTests {
    func testParseTaggedExtension() {
        self.iterateTests(
            testFunction: GrammarParser.parseTaggedExtension,
            validInputs: [
                ("label 1", "\r\n", .init(label: "label", value: .sequence([1])), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - tagged-extension-comp parseTaggedExtensionComplex

extension ParserUnitTests {
    func testParseTaggedExtensionComplex() {
        self.iterateTests(
            testFunction: GrammarParser.parseTaggedExtensionComplex,
            validInputs: [
                ("test", "\r\n", ["test"], #line),
                ("(test)", "\r\n", ["test"], #line),
                ("(test1 test2)", "\r\n", ["test1", "test2"], #line),
                ("test1 test2", "\r\n", ["test1", "test2"], #line),
                ("test1 test2 (test3 test4) test5", "\r\n", ["test1", "test2", "test3", "test4", "test5"], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseText

extension ParserUnitTests {
    func testParseText() {
        let invalid: Set<UInt8> = [UInt8(ascii: "\r"), .init(ascii: "\n"), 0]
        let valid = Array(Set((UInt8.min ... UInt8.max)).subtracting(invalid).subtracting(128 ... UInt8.max))
        let validString = String(decoding: valid, as: UTF8.self)
        self.iterateTests(
            testFunction: GrammarParser.parseText,
            validInputs: [
                (validString, "\r", ByteBuffer(string: validString), #line),
            ],
            parserErrorInputs: [
                ("\r", "", #line),
                ("\n", "", #line),
                (String(decoding: (UInt8(128) ... UInt8.max), as: UTF8.self), " ", #line),
            ],
            incompleteMessageInputs: [
                ("a", "", #line),
            ]
        )
    }
}

// MARK: - parseUchar

extension ParserUnitTests {
    func testParseUchar() {
        self.iterateTests(
            testFunction: GrammarParser.parseUChar,
            validInputs: [
                ("%00", "", [UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "0")], #line),
                ("%0A", "", [UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "A")], #line),
                ("%1F", "", [UInt8(ascii: "%"), UInt8(ascii: "1"), UInt8(ascii: "F")], #line),
                ("%FF", "", [UInt8(ascii: "%"), UInt8(ascii: "F"), UInt8(ascii: "F")], #line),
            ],
            parserErrorInputs: [
                ("%GG", " ", #line),
            ],
            incompleteMessageInputs: [
                ("%", "", #line),
            ]
        )
    }
}

// MARK: - parseAchar

extension ParserUnitTests {
    func testParseAchar() {
        self.iterateTests(
            testFunction: GrammarParser.parseAChar,
            validInputs: [
                ("%00", "", [UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "0")], #line),
                ("&", "", [UInt8(ascii: "&")], #line),
                ("=", "", [UInt8(ascii: "=")], #line),
            ],
            parserErrorInputs: [
                ("£", " ", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
            ]
        )
    }
}

// MARK: - parseAccess

extension ParserUnitTests {
    func testParseAccess() {
        self.iterateTests(
            testFunction: GrammarParser.parseAccess,
            validInputs: [
                ("authuser", "", .authUser, #line),
                ("anonymous", "", .anonymous, #line),
                ("submit+abc", " ", .submit(.init(data: "abc")), #line),
                ("user+abc", " ", .user(.init(data: "abc")), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - parseBchar

extension ParserUnitTests {
    func testParseBchar() {
        self.iterateTests(
            testFunction: GrammarParser.parseBChar,
            validInputs: [
                ("%00", "", [UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "0")], #line),
                ("@", "", [UInt8(ascii: "@")], #line),
                (":", "", [UInt8(ascii: ":")], #line),
                ("/", "", [UInt8(ascii: "/")], #line),
            ],
            parserErrorInputs: [
                ("£", " ", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
            ]
        )
    }
}

// MARK: - parseUAuthMechanism

extension ParserUnitTests {
    func testParseUAuthMechanism() {
        self.iterateTests(
            testFunction: GrammarParser.parseUAuthMechanism,
            validInputs: [
                ("INTERNAL", " ", .internal, #line),
                ("abcdEFG0123456789", " ", .init("abcdEFG0123456789"), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                ]
        )
    }
}

// MARK: - uniqueID parseUID

extension ParserUnitTests {
    func testUniqueID() {
        self.iterateTests(
            testFunction: GrammarParser.parseUID,
            validInputs: [
                ("1", " ", 1, #line),
                ("123", " ", 123, #line),
            ],
            parserErrorInputs: [
                ("0", " ", #line),
                ("0123", " ", #line),
            ],
            incompleteMessageInputs: [
                ("123", "", #line),
            ]
        )
    }
}

// MARK: - unsubscribe parseUnsubscribe

extension ParserUnitTests {
    func testParseUnsubscribe() {
        self.iterateTests(
            testFunction: GrammarParser.parseUnsubscribe,
            validInputs: [
                ("UNSUBSCRIBE inbox", "\r\n", .unsubscribe(.inbox), #line),
                ("UNSUBScribe INBOX", "\r\n", .unsubscribe(.inbox), #line),
            ],
            parserErrorInputs: [
                ("UNSUBSCRIBE \r", " ", #line),
            ],
            incompleteMessageInputs: [
                ("UNSUBSCRIBE", " ", #line),
            ]
        )
    }
}

// MARK: - parseUserId

extension ParserUnitTests {
    func testParseUserId() {
        self.iterateTests(
            testFunction: GrammarParser.parseUserId,
            validInputs: [
                ("test", " ", "test", #line),
                ("{4}\r\ntest", " ", "test", #line),
                ("{4+}\r\ntest", " ", "test", #line),
                ("\"test\"", " ", "test", #line),
            ],
            parserErrorInputs: [
                ("\\\\", "", #line),
            ],
            incompleteMessageInputs: [
                ("aaa", "", #line),
                ("{1}\r\n", "", #line),
            ]
        )
    }
}

// MARK: - vendor-token

extension ParserUnitTests {
    func testParseVendorToken() {
        self.iterateTests(
            testFunction: GrammarParser.parseVendorToken,
            validInputs: [
                ("token", "-atom ", "token", #line),
                ("token", " ", "token", #line),
            ],
            parserErrorInputs: [
                ("1a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("token", "", #line),
            ]
        )
    }
}

// MARK: - 2DIGIT

extension ParserUnitTests {
    func test2digit() {
        self.iterateTests(
            testFunction: GrammarParser.parse2Digit,
            validInputs: [
                ("12", " ", 12, #line),
            ],
            parserErrorInputs: [
                ("ab", " ", #line),
                ("1a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("1", "", #line),
            ]
        )
    }
}

// MARK: - 4DIGIT

extension ParserUnitTests {
    func test4digit() {
        self.iterateTests(
            testFunction: GrammarParser.parse4Digit,
            validInputs: [
                ("1234", " ", 1234, #line),
            ],
            parserErrorInputs: [
                ("abcd", " ", #line),
                ("12ab", " ", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("1", "", #line),
                ("12", "", #line),
                ("123", "", #line),
            ]
        )
    }
}

// MARK: RFC 2087 - Quota

extension ParserUnitTests {
    func testSetQuota() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandQuota,
            validInputs: [
                (
                    "SETQUOTA \"\" (STORAGE 512)",
                    "\r",
                    Command.setQuota(QuotaRoot(""), [QuotaLimit(resourceName: "STORAGE", limit: 512)]),
                    #line
                ),
                (
                    "SETQUOTA \"MASSIVE_POOL\" (STORAGE 512)",
                    "\r",
                    Command.setQuota(QuotaRoot("MASSIVE_POOL"), [QuotaLimit(resourceName: "STORAGE", limit: 512)]),
                    #line
                ),
                (
                    "SETQUOTA \"MASSIVE_POOL\" (STORAGE 512 BEANS 50000)",
                    "\r",
                    Command.setQuota(QuotaRoot("MASSIVE_POOL"), [QuotaLimit(resourceName: "STORAGE", limit: 512),
                                                                 QuotaLimit(resourceName: "BEANS", limit: 50000)]),
                    #line
                ),
                (
                    "SETQUOTA \"MASSIVE_POOL\" ()",
                    "\r",
                    Command.setQuota(QuotaRoot("MASSIVE_POOL"), []),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("SETQUOTA \"MASSIVE_POOL\" (STORAGE BEANS)", "\r", #line),
                ("SETQUOTA \"MASSIVE_POOL\" (STORAGE 40M)", "\r", #line),
                ("SETQUOTA \"MASSIVE_POOL\" (STORAGE)", "\r", #line),
                ("SETQUOTA \"MASSIVE_POOL\" (", "\r", #line),
                ("SETQUOTA \"MASSIVE_POOL\"", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testGetQuota() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandQuota,
            validInputs: [
                ("GETQUOTA \"\"", "\r", Command.getQuota(QuotaRoot("")), #line),
                ("GETQUOTA \"MASSIVE_POOL\"", "\r", Command.getQuota(QuotaRoot("MASSIVE_POOL")), #line),
            ],
            parserErrorInputs: [
                ("GETQUOTA", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testGetQuotaRoot() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandQuota,
            validInputs: [
                ("GETQUOTAROOT INBOX", "\r", Command.getQuotaRoot(MailboxName("INBOX")), #line),
                ("GETQUOTAROOT Other", "\r", Command.getQuotaRoot(MailboxName("Other")), #line),
            ],
            parserErrorInputs: [
                ("GETQUOTAROOT", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testResponsePayload_quotaRoot() {
        self.iterateTests(
            testFunction: GrammarParser.parseResponsePayload_quotaRoot,
            validInputs: [
                ("QUOTAROOT INBOX \"Root\"", "\r", .quotaRoot(.init("INBOX"), .init("Root")), #line),
            ],
            parserErrorInputs: [
                ("QUOTAROOT", "\r", #line),
                ("QUOTAROOT INBOX", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testResponsePayload_quota() {
        self.iterateTests(
            testFunction: GrammarParser.parseResponsePayload_quota,
            validInputs: [
                (
                    "QUOTA \"Root\" (STORAGE 10 512)", "\r",
                    .quota(.init("Root"), [QuotaResource(resourceName: "STORAGE", usage: 10, limit: 512)]),
                    #line
                ),
                (
                    "QUOTA \"Root\" (STORAGE 10 512 BEANS 50 100)", "\r",
                    .quota(.init("Root"), [QuotaResource(resourceName: "STORAGE", usage: 10, limit: 512),
                                           QuotaResource(resourceName: "BEANS", usage: 50, limit: 100)]),
                    #line
                ),
                (
                    "QUOTA \"Root\" ()", "\r",
                    .quota(.init("Root"), []),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("QUOTA", "\r", #line),
                ("QUOTA \"Root\"", "\r", #line),
                ("QUOTA \"Root\" (", "\r", #line),
                ("QUOTA \"Root\" (STORAGE", "\r", #line),
                ("QUOTA \"Root\" (STORAGE)", "\r", #line),
                ("QUOTA \"Root\" (STORAGE 10", "\r", #line),
                ("QUOTA \"Root\" (STORAGE 10)", "\r", #line),
                ("QUOTA \"Root\" (STORAGE 10 512 BEANS)", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }
}

// MARK: RFC 6237 & required part of RFC 5465

extension ParserUnitTests {
    func testParseOneOrMoreMailbox() {
        self.iterateTests(
            testFunction: GrammarParser.parseOneOrMoreMailbox,
            validInputs: [
                (
                    "\"box1\"", "\r",
                    Mailboxes([.init("box1")])!,
                    #line
                ),
                (
                    "(\"box1\")", "\r",
                    Mailboxes([.init("box1")])!,
                    #line
                ),
                (
                    "(\"box1\" \"box2\")", "\r",
                    Mailboxes([.init("box1"), .init("box2")]),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("()", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testParseFilterMailboxes() {
        self.iterateTests(
            testFunction: GrammarParser.parseFilterMailboxes,
            validInputs: [
                (
                    "inboxes", " ",
                    .inboxes,
                    #line
                ),
                (
                    "personal", " ",
                    .personal,
                    #line
                ),
                (
                    "subscribed", " ",
                    .subscribed,
                    #line
                ),
                (
                    "selected", " ",
                    .selected,
                    #line
                ),
                (
                    "selected-delayed", " ",
                    .selectedDelayed,
                    #line
                ),
                (
                    "subtree \"box1\"", " ",
                    .subtree(Mailboxes([.init("box1")])!),
                    #line
                ),
                (
                    "subtree-one \"box1\"", " ",
                    .subtreeOne(Mailboxes([.init("box1")])!),
                    #line
                ),
                (
                    "mailboxes \"box1\"", " ",
                    .mailboxes(Mailboxes([.init("box1")])!),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("subtree ", "\r", #line),
                ("subtree-one", "\r", #line),
                ("mailboxes", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testParseESearchScopeOptions() {
        self.iterateTests(
            testFunction: GrammarParser.parseESearchScopeOptions,
            validInputs: [
                (
                    "name", "\r",
                    ESearchScopeOptions([.init(name: "name")])!,
                    #line
                ),
                (
                    "name $", "\r",
                    ESearchScopeOptions([.init(name: "name", value: .sequence(.lastCommand))]),
                    #line
                ),
                (
                    "name name2", "\r",
                    ESearchScopeOptions([.init(name: "name"), .init(name: "name2")])!,
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseEsearchSourceOptions() {
        self.iterateTests(
            testFunction: GrammarParser.parseEsearchSourceOptions,
            validInputs: [
                (
                    "IN (inboxes)", "\r",
                    ESearchSourceOptions(sourceMailbox: [.inboxes]),
                    #line
                ),
                (
                    "IN (inboxes personal)", "\r",
                    ESearchSourceOptions(sourceMailbox: [.inboxes, .personal]),
                    #line
                ),
                (
                    "IN (inboxes (name))", "\r",
                    ESearchSourceOptions(sourceMailbox: [.inboxes],
                                         scopeOptions: ESearchScopeOptions([.init(name: "name")])!),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("IN (inboxes ())", "\r", #line),
                ("IN ((name))", "\r", #line),
                ("IN (inboxes (name)", "\r", #line),
                ("IN (inboxes (name", "\r", #line),
                ("IN (inboxes (", "\r", #line),
                ("IN (inboxes )", "\r", #line),
                ("IN (", "\r", #line),
                ("IN", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testParseEsearchOptions() {
        self.iterateTests(
            testFunction: GrammarParser.parseEsearchOptions,
            validInputs: [
                (
                    " ALL", "\r",
                    ESearchOptions(key: .all),
                    #line
                ),
                (
                    " RETURN (MIN) ALL", "\r",
                    ESearchOptions(key: .all, returnOptions: [.min]),
                    #line
                ),
                (
                    " CHARSET Alien ALL", "\r",
                    ESearchOptions(key: .all, charset: "Alien"),
                    #line
                ),
                (
                    " IN (inboxes) ALL", "\r",
                    ESearchOptions(key: .all, sourceOptions: ESearchSourceOptions(sourceMailbox: [.inboxes])),
                    #line
                ),
                (
                    " IN (inboxes) CHARSET Alien ALL", "\r",
                    ESearchOptions(key: .all,
                                   charset: "Alien",
                                   sourceOptions: ESearchSourceOptions(sourceMailbox: [.inboxes])),
                    #line
                ),
                (
                    " IN (inboxes) RETURN (MIN) ALL", "\r",
                    ESearchOptions(key: .all,
                                   returnOptions: [.min],
                                   sourceOptions: ESearchSourceOptions(sourceMailbox: [.inboxes])),
                    #line
                ),
                (
                    " RETURN (MIN) CHARSET Alien ALL", "\r",
                    ESearchOptions(key: .all,
                                   charset: "Alien",
                                   returnOptions: [.min]),
                    #line
                ),
                (
                    " IN (inboxes) RETURN (MIN) CHARSET Alien ALL", "\r",
                    ESearchOptions(key: .all,
                                   charset: "Alien",
                                   returnOptions: [.min],
                                   sourceOptions: ESearchSourceOptions(sourceMailbox: [.inboxes])),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}
