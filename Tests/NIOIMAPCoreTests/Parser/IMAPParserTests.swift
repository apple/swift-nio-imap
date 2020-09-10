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

final class ParserUnitTests: XCTestCase {}

extension ParserUnitTests {
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
                    XCTAssertTrue(e is ParserError, "Expected ParserError, got \(e)")
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
    fileprivate func iterateTests<T: Equatable>(
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
    fileprivate func iterateTests(
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
            XCTAssertEqual(c2_2, PartialCommandStream(.append(.beginMessage(messsage: .init(options: .init(flagList: [], extensions: []), data: .init(byteCount: 10))))))
            XCTAssertEqual(c2_3, PartialCommandStream(.append(.messageBytes("0123456789"))))
            XCTAssertEqual(c2_4, PartialCommandStream(.append(.endMessage)))
            XCTAssertEqual(c2_5, PartialCommandStream(.append(.finish)))
            XCTAssertEqual(c3, PartialCommandStream(.command(TaggedCommand(tag: "3", command: .noop))))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testResponseMessageDataStreaming() {
        // first send a greeting
        // then respond to 2 LOGIN {3}\r\nabc {3}\r\nabc
        // command tag FETCH 1:3 (BODY[TEXT] FLAGS)
        // command tag FETCH 1 BINARY[]

        let lines = [
            "* OK [CAPABILITY IMAP4rev1] Ready.\r\n",

            "2 OK Login completed.\r\n",

            "* 1 FETCH (BODY[TEXT]<4> {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
            "* 2 FETCH (FLAGS (\\deleted) BODY[TEXT] {3}\r\ndef)\r\n",
            "* 3 FETCH (BODY[TEXT] {3}\r\nghi)\r\n",
            "3 OK Fetch completed.\r\n",

            "* 1 FETCH (BINARY[] {4}\r\n1234)\r\n",
            "4 OK Fetch completed.\r\n",
        ]
        var buffer = ByteBuffer(stringLiteral: "")
        buffer.writeString(lines.joined())

        let expectedResults: [(Response, UInt)] = [
            (.untaggedResponse(.greeting(.auth(.ok(.init(code: .capability([.imap4rev1]), text: "Ready."))))), #line),
            (.taggedResponse(.init(tag: "2", state: .ok(.init(code: nil, text: "Login completed.")))), #line),

            (.fetchResponse(.start(1)), #line),
            (.fetchResponse(.streamingBegin(kind: .body(partial: 4), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("abc")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetchResponse(.finish), #line),

            (.fetchResponse(.start(2)), #line),
            (.fetchResponse(.simpleAttribute(.flags([.deleted]))), #line),
            (.fetchResponse(.streamingBegin(kind: .body(partial: nil), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("def")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.finish), #line),

            (.fetchResponse(.start(3)), #line),
            (.fetchResponse(.streamingBegin(kind: .body(partial: nil), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("ghi")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.finish), #line),
            (.taggedResponse(.init(tag: "3", state: .ok(.init(code: nil, text: "Fetch completed.")))), #line),

            (.fetchResponse(.start(1)), #line),
            (.fetchResponse(.streamingBegin(kind: .binary(section: []), byteCount: 4)), #line),
            (.fetchResponse(.streamingBytes("1234")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.finish), #line),
            (.taggedResponse(.init(tag: "4", state: .ok(.init(code: nil, text: "Fetch completed.")))), #line),
        ]

        var parser = ResponseParser()
        for (input, line) in expectedResults {
            do {
                let actual = try parser.parseResponseStream(buffer: &buffer)
                XCTAssertEqual(.response(input), actual, line: line)
            } catch {
                XCTFail("\(error)", line: line)
                return
            }
        }
        XCTAssertEqual(buffer.readableBytes, 0)
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

// MARK: - parseAppendOptions

extension ParserUnitTests {
    func testParseAppendOptions() throws {
        let date = try XCTUnwrap(InternalDate(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, zoneMinutes: 0))

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

// MARK: - parseBodyExtension

extension ParserUnitTests {
    func testParseBodyExtension() {
        self.iterateTests(
            testFunction: GrammarParser.parseBodyExtension,
            validInputs: [
                ("1", "\r", [.number(1)], #line),
                ("\"s\"", "\r", [.string("s")], #line),
                ("(1)", "\r", [.number(1)], #line),
                ("(1 \"2\" 3)", "\r", [.number(1), .string("2"), .number(3)], #line),
                ("(1 2 3 (4 (5 (6))))", "\r", [.number(1), .number(2), .number(3), .number(4), .number(5), .number(6)], #line),
                ("(((((1)))))", "\r", [.number(1)], #line), // yeh, this is valid, don't ask
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseBodyFieldDsp

extension ParserUnitTests {
    func testParseBodyFieldDsp_some() {
        TestUtilities.withBuffer(#"("astring" ("f1" "v1"))"#) { (buffer) in
            let dsp = try GrammarParser.parseBodyFieldDsp(buffer: &buffer, tracker: .testTracker)
            XCTAssertNotNil(dsp)
            XCTAssertEqual(dsp, BodyStructure.Disposition(kind: "astring", parameter: [.init(field: "f1", value: "v1")]))
        }
    }

    func testParseBodyFieldDsp_none() {
        TestUtilities.withBuffer(#"NIL"#, terminator: "") { (buffer) in
            let string = try GrammarParser.parseBodyFieldDsp(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(string, .none)
        }
    }
}

// MARK: - parseBodyEncoding

extension ParserUnitTests {
    func testParseBodyEncoding() {
        self.iterateTests(
            testFunction: GrammarParser.parseBodyEncoding,
            validInputs: [
                (#""BASE64""#, " ", .base64, #line),
                (#""BINARY""#, " ", .binary, #line),
                (#""7BIT""#, " ", .sevenBit, #line),
                (#""8BIT""#, " ", .eightBit, #line),
                (#""QUOTED-PRINTABLE""#, " ", .quotedPrintable, #line),
                (#""other""#, " ", .init("other"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseBodyEncoding_invalid_missingQuotes() {
        var buffer = TestUtilities.createTestByteBuffer(for: "other")
        XCTAssertThrowsError(try GrammarParser.parseBodyEncoding(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - parseBodyFieldLanguage

extension ParserUnitTests {
    func testParseBodyFieldLanguage() {
        self.iterateTests(
            testFunction: GrammarParser.parseBodyFieldLanguage,
            validInputs: [
                (#""english""#, " ", ["english"], #line),
                (#"("english")"#, " ", ["english"], #line),
                (#"("english" "french")"#, " ", ["english", "french"], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseBodyFieldParam

extension ParserUnitTests {
    func testParseBodyFieldParam() {
        self.iterateTests(
            testFunction: GrammarParser.parseBodyFieldParam,
            validInputs: [
                (#"NIL"#, " ", [], #line),
                (#"("f1" "v1")"#, " ", [.init(field: "f1", value: "v1")], #line),
                (#"("f1" "v1" "f2" "v2")"#, " ", [.init(field: "f1", value: "v1"), .init(field: "f2", value: "v2")], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseBodyFieldParam_invalid_oneObject() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"("p1" "#)
        XCTAssertThrowsError(try GrammarParser.parseBodyFieldParam(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage)
        }
    }
}

// MARK: - parseBodyFields

extension ParserUnitTests {
    func testParseBodyFields_valid() {
        TestUtilities.withBuffer(#"("f1" "v1") "id" "desc" "8BIT" 1234"#, terminator: " ") { (buffer) in
            let result = try GrammarParser.parseBodyFields(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.parameter, [.init(field: "f1", value: "v1")])
            XCTAssertEqual(result.id, "id")
            XCTAssertEqual(result.description, "desc")
            XCTAssertEqual(result.encoding, .eightBit)
            XCTAssertEqual(result.octetCount, 1234)
        }
    }
}

// MARK: - parseBodyTypeSinglepart

extension ParserUnitTests {
    func testParseBodyTypeSinglepart() {
        let basicInputs: [(String, String, BodyStructure.Singlepart, UInt)] = [
            (
                "\"AUDIO\" \"multipart/alternative\" NIL NIL NIL \"BASE64\" 1",
                "\r\n",
                .init(
                    type: .basic(.init(kind: .audio, subtype: .alternative)),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 1),
                    extension: nil
                ),
                #line
            ),
            (
                "\"APPLICATION\" \"multipart/mixed\" NIL \"id\" \"description\" \"7BIT\" 2",
                "\r\n",
                .init(
                    type: .basic(.init(kind: .application, subtype: .mixed)),
                    fields: .init(parameter: [], id: "id", description: "description", encoding: .sevenBit, octetCount: 2),
                    extension: nil
                ),
                #line
            ),
            (
                "\"VIDEO\" \"multipart/related\" (\"f1\" \"v1\") NIL NIL \"8BIT\" 3",
                "\r\n",
                .init(
                    type: .basic(.init(kind: .video, subtype: .related)),
                    fields: .init(parameter: [.init(field: "f1", value: "v1")], id: nil, description: nil, encoding: .eightBit, octetCount: 3),
                    extension: nil
                ),
                #line
            ),
        ]

        let messageInputs: [(String, String, BodyStructure.Singlepart, UInt)] = [
            (
                "\"MESSAGE\" \"RFC822\" NIL NIL NIL \"BASE64\" 4 (NIL NIL NIL NIL NIL NIL NIL NIL NIL NIL) (\"IMAGE\" \"multipart/related\" NIL NIL NIL \"BINARY\" 5) 8",
                "\r\n",
                .init(
                    type: .message(
                        .init(
                            message: .rfc822,
                            envelope: Envelope(date: nil, subject: nil, from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                            body: .singlepart(.init(type: .basic(.init(kind: .image, subtype: .related)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octetCount: 5))),
                            fieldLines: 8
                        )
                    ),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octetCount: 4),
                    extension: nil
                ),
                #line
            ),
        ]

        let textInputs: [(String, String, BodyStructure.Singlepart, UInt)] = [
            (
                "\"TEXT\" \"media\" NIL NIL NIL \"QUOTED-PRINTABLE\" 1 2",
                "\r\n",
                .init(
                    type: .text(.init(mediaText: "media", lineCount: 2)),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .quotedPrintable, octetCount: 1),
                    extension: nil
                ),
                #line
            ),
        ]

        let inputs = basicInputs + messageInputs + textInputs
        self.iterateTests(
            testFunction: GrammarParser.parseBodyKindSinglePart,
            validInputs: inputs,
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
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

// MARK: - parseContinueRequest

extension ParserUnitTests {
    func testParseContinueRequest() {
        self.iterateTests(
            testFunction: GrammarParser.parseContinueRequest,
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
                ("\\Other", " ", .init(rawValue: "\\Other"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseCommand

extension ParserUnitTests {
    func testParseCommand_valid_any() {
        TestUtilities.withBuffer("a1 NOOP", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.command, .noop)
        }
    }

    func testParseCommand_valid_auth() {
        TestUtilities.withBuffer("a1 CREATE \"mailbox\"", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.command, .create(MailboxName("mailbox"), []))
        }
    }

    func testParseCommand_valid_nonauth() {
        TestUtilities.withBuffer("a1 STARTTLS", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.command, .starttls)
        }
    }

    func testParseCommand_valid_select() {
        TestUtilities.withBuffer("a1 CHECK", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.command, .check)
        }
    }
}

// MARK: - CommandType parseCommandAny

extension ParserUnitTests {
    func testParseCommandAny() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandAny,
            validInputs: [
                ("CAPABILITY", " ", .capability, #line),
                ("LOGOUT", " ", .logout, #line),
                ("NOOP", " ", .noop, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - CommandType parseCommandNonAuth

extension ParserUnitTests {
    func testParseCommandNonAuth_valid_login() {
        TestUtilities.withBuffer("LOGIN david evans", terminator: " \r\n") { (buffer) in
            let result = try GrammarParser.parseCommandNonauth(buffer: &buffer, tracker: .testTracker)
            guard case .login(let username, let password) = result else {
                XCTFail("Case mixup \(result)")
                return
            }
            XCTAssertEqual(username, "david")
            XCTAssertEqual(password, "evans")
        }
    }

    func testParseCommandNonAuth_valid_authenticate() {
        TestUtilities.withBuffer("AUTHENTICATE some", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommandNonauth(buffer: &buffer, tracker: .testTracker)
            guard case .authenticate(let type, let dataArray) = result else {
                XCTFail("Case mixup \(result)")
                return
            }
            XCTAssertEqual(type, "some")

            XCTAssertEqual(dataArray, [])
        }
    }

    func testParseCommandNonAuth_valid_starttls() {
        TestUtilities.withBuffer("STARTTLS", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommandNonauth(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, .starttls)
        }
    }
}

// MARK: - CommandType parseCommandAuth

extension ParserUnitTests {
    func testParseCommandAuth() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandAuth,
            validInputs: [
                ("LSUB inbox someList", " ", .lsub(reference: .inbox, pattern: "someList"), #line),
                ("CREATE inbox (something)", " ", .create(.inbox, [.labelled(.init(name: "something", value: nil))]), #line),
                ("NAMESPACE", " ", .namespace, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - CommandType parseCommandSelect

extension ParserUnitTests {
    func testParseCommandSelect() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSelect,
            validInputs: [
                ("UNSELECT", " ", .unselect, #line),
                ("unselect", " ", .unselect, #line),
                ("UNSelect", " ", .unselect, #line),
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

// MARK: - Parse Continue Request

extension ParserUnitTests {
    func testContinueRequest_valid() {
        let inputs: [(String, UInt)] = [
            ("+ Ready for additional command text\r\n", #line),
            ("+ \r\n", #line),
            ("+\r\n", #line), // This is not standard conformant, but we’re allowing this.
        ]

        for (input, line) in inputs {
            TestUtilities.withBuffer(input, terminator: " ") { (buffer) in
                XCTAssertNoThrow(try GrammarParser.parseContinueRequest(buffer: &buffer, tracker: .testTracker), line: line)
            }
        }
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
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

    func testCopy_invalid_missing_set() {
        var buffer = TestUtilities.createTestByteBuffer(for: "COPY inbox ")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }
}

// MARK: - date

extension ParserUnitTests {
    func testDate_valid_plain() {
        TestUtilities.withBuffer("25-Jun-1994", terminator: " ") { (buffer) in
            let day = try GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, Date(year: 1994, month: 6, day: 25))
        }
    }

    func testDate_valid_quoted() {
        TestUtilities.withBuffer("\"25-Jun-1994\"") { (buffer) in
            let day = try GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, Date(year: 1994, month: 6, day: 25))
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

extension ParserUnitTests {
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

extension ParserUnitTests {
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

extension ParserUnitTests {
    func testDateText_valid() {
        TestUtilities.withBuffer("25-Jun-1994", terminator: " ") { (buffer) in
            let date = try GrammarParser.parseDateText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(date, Date(year: 1994, month: 6, day: 25))
        }
    }

    func testDateText_invalid_missing_year() {
        var buffer = TestUtilities.createTestByteBuffer(for: "25-Jun-")
        XCTAssertThrowsError(try GrammarParser.parseDateText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage)
        }
    }

    func testCreatingMax() throws {
        XCTAssertNotNil(InternalDate(year: 2567, month: 12, day: 31, hour: 24, minute: 60, second: 60, zoneMinutes: 13 * 60))
    }

    func testCreatingMin() throws {
        XCTAssertNotNil(InternalDate(year: 1900, month: 1, day: 1, hour: 0, minute: 0, second: 0, zoneMinutes: -13 * 60))
    }
}

// MARK: - parseInternalDate

extension ParserUnitTests {
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

// MARK: - entry-type-resp parseEntryTypeResponse

extension ParserUnitTests {
    func testParseEntryTypeRequest() {
        self.iterateTests(
            testFunction: GrammarParser.parseEntryKindRequest,
            validInputs: [
                ("all", " ", .all, #line),
                ("ALL", " ", .all, #line),
                ("aLL", " ", .all, #line),
                ("shared", " ", .response(.shared), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - entry-type-resp parseEntryTypeResponse

extension ParserUnitTests {
    func testParseEntryTypeResponse() {
        self.iterateTests(
            testFunction: GrammarParser.parseEntryKindResponse,
            validInputs: [
                ("priv", " ", .private, #line),
                ("PRIV", " ", .private, #line),
                ("prIV", " ", .private, #line),
                ("shared", " ", .shared, #line),
                ("SHARED", " ", .shared, #line),
                ("shaRED", " ", .shared, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
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
                ("ESEARCH (TAG \"col\") UID", "\r", .init(correlator: "col", uid: true, returnData: []), #line),
                ("ESEARCH (TAG \"col\") UID COUNT 2", "\r", .init(correlator: "col", uid: true, returnData: [.count(2)]), #line),
                ("ESEARCH (TAG \"col\") UID MIN 1 MAX 2", "\r", .init(correlator: "col", uid: true, returnData: [.min(1), .max(2)]), #line),
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

// MARK: - parseFetch

extension ParserUnitTests {
    func testParseFetch() {
        self.iterateTests(
            testFunction: GrammarParser.parseFetch,
            validInputs: [
                ("FETCH 1:3 ALL", "\r", .fetch([1 ... 3], .all, []), #line),
                ("FETCH 2:4 FULL", "\r", .fetch([2 ... 4], .full, []), #line),
                ("FETCH 3:5 FAST", "\r", .fetch([3 ... 5], .fast, []), #line),
                ("FETCH 4:6 ENVELOPE", "\r", .fetch([4 ... 6], [.envelope], []), #line),
                ("FETCH 5:7 (ENVELOPE FLAGS)", "\r", .fetch([5 ... 7], [.envelope, .flags], []), #line),
                ("FETCH 3:5 FAST (name)", "\r", .fetch([3 ... 5], .fast, [.init(name: "name", value: nil)]), #line),
                ("FETCH 1 BODY[TEXT]", "\r", .fetch([1], [.bodySection(peek: false, .init(kind: .text), nil)], []), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFetchAttribute

extension ParserUnitTests {
    func testParseFetchAttribute() {
        self.iterateTests(
            testFunction: GrammarParser.parseFetchAttribute,
            validInputs: [
                ("ENVELOPE", " ", .envelope, #line),
                ("FLAGS", " ", .flags, #line),
                ("INTERNALDATE", " ", .internalDate, #line),
                ("RFC822.HEADER", " ", .rfc822Header, #line),
                ("RFC822.SIZE", " ", .rfc822Size, #line),
                ("RFC822.TEXT", " ", .rfc822Text, #line),
                ("RFC822", " ", .rfc822, #line),
                ("BODY", " ", .bodyStructure(extensions: false), #line),
                ("BODYSTRUCTURE", " ", .bodyStructure(extensions: true), #line),
                ("UID", " ", .uid, #line),
                ("BODY[1]<1.2>", " ", .bodySection(peek: false, .init(part: [1], kind: .complete), 1 ... 2 as ClosedRange), #line),
                ("BODY[1.TEXT]", " ", .bodySection(peek: false, .init(part: [1], kind: .text), nil), #line),
                ("BODY[4.2.TEXT]", " ", .bodySection(peek: false, .init(part: [4, 2], kind: .text), nil), #line),
                ("BODY[HEADER]", " ", .bodySection(peek: false, .init(kind: .header), nil), #line),
                ("BODY.PEEK[HEADER]<3.4>", " ", .bodySection(peek: true, .init(kind: .header), 3 ... 6 as ClosedRange), #line),
                ("BODY.PEEK[HEADER]", " ", .bodySection(peek: true, .init(kind: .header), nil), #line),
                ("BINARY.PEEK[1]", " ", .binary(peek: true, section: [1], partial: nil), #line),
                ("BINARY.PEEK[1]<3.4>", " ", .binary(peek: true, section: [1], partial: 3 ... 6 as ClosedRange), #line),
                ("BINARY[2]<4.5>", " ", .binary(peek: false, section: [2], partial: 4 ... 8 as ClosedRange), #line),
                ("BINARY.SIZE[5]", " ", .binarySize(section: [5]), #line),
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

// MARK: - parseFetchResponse

extension ParserUnitTests {
    func testParseFetchResponse() {
        self.iterateTests(
            testFunction: GrammarParser.parseFetchResponse,
            validInputs: [
                ("* 1 FETCH (", " ", .start(1), #line),
                ("UID 54", " ", .simpleAttribute(.uid(54)), #line),
                ("RFC822.SIZE 40639", " ", .simpleAttribute(.rfc822Size(40639)), #line),
                (")\r\n", " ", .finish, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
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

// MARK: - parseList

extension ParserUnitTests {
    func testParseList() {
        self.iterateTests(
            testFunction: GrammarParser.parseList,
            validInputs: [
                (#"LIST "" """#, "\r", .list(nil, reference: MailboxName(""), .mailbox(""), []), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - list-wildcard parseListWildcard

extension ParserUnitTests {
    func testWildcard() {
        let valid: Set<UInt8> = [UInt8(ascii: "%"), UInt8(ascii: "*")]
        let invalid: Set<UInt8> = Set(UInt8.min ... UInt8.max).subtracting(valid)

        for v in valid {
            var buffer = TestUtilities.createTestByteBuffer(for: [v])
            do {
                let str = try GrammarParser.parseListWildcards(buffer: &buffer, tracker: .testTracker)
                XCTAssertEqual(str[str.startIndex], Character(Unicode.Scalar(v)))
            } catch {
                XCTFail("\(v) doesn't satisfy \(error)")
                return
            }
        }
        for v in invalid {
            var buffer = TestUtilities.createTestByteBuffer(for: [v])
            XCTAssertThrowsError(try GrammarParser.parseListWildcards(buffer: &buffer, tracker: .testTracker)) { e in
                XCTAssertTrue(e is ParserError)
            }
        }
    }
}

// MARK: - parseMailboxData

extension ParserUnitTests {
    func testParseMailboxData() {
        self.iterateTests(
            testFunction: GrammarParser.parseMailboxData,
            validInputs: [
                ("FLAGS (\\seen \\draft)", " ", .flags([.seen, .draft]), #line),
                (
                    "LIST (\\oflag1 \\oflag2) NIL inbox",
                    "\r\n",
                    .list(.init(attributes: [.init("\\oflag1"), .init("\\oflag2")], pathSeparator: nil, mailbox: .inbox, extensions: [])),
                    #line
                ),
                ("ESEARCH MIN 1 MAX 2", "\r\n", .esearch(.init(correlator: nil, uid: false, returnData: [.min(1), .max(2)])), #line),
                ("1234 EXISTS", "\r\n", .exists(1234), #line),
                ("5678 RECENT", "\r\n", .recent(5678), #line),
                ("STATUS INBOX ()", "\r\n", .status(.inbox, .init()), #line),
                ("STATUS INBOX (MESSAGES 2)", "\r\n", .status(.inbox, .init(messageCount: 2)), #line),
                (
                    "LSUB (\\seen \\draft) NIL inbox",
                    "\r\n",
                    .lsub(.init(attributes: [.init("\\seen"), .init("\\draft")], pathSeparator: nil, mailbox: .inbox, extensions: [])),
                    #line
                ),
                ("SEARCH", "\r\n", .search([]), #line),
                ("SEARCH 1", "\r\n", .search([1]), #line),
                ("SEARCH 1 2 3 4 5", "\r\n", .search([1, 2, 3, 4, 5]), #line),
                ("NAMESPACE NIL NIL NIL", "\r\n", .namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMailboxList

extension ParserUnitTests {
    func testParseMailboxList() {
        self.iterateTests(
            testFunction: GrammarParser.parseMailboxList,
            validInputs: [
                (
                    "() NIL inbox",
                    "\r",
                    .init(attributes: [], pathSeparator: nil, mailbox: .inbox, extensions: []),
                    #line
                ),
                (
                    "() \"d\" inbox",
                    "\r",
                    .init(attributes: [], pathSeparator: "d", mailbox: .inbox, extensions: []),
                    #line
                ),
                (
                    "(\\oflag1 \\oflag2) NIL inbox",
                    "\r",
                    .init(attributes: [.init("\\oflag1"), .init("\\oflag2")], pathSeparator: nil, mailbox: .inbox, extensions: []),
                    #line
                ),
                (
                    "(\\oflag1 \\oflag2) \"d\" inbox",
                    "\r",
                    .init(attributes: [.init("\\oflag1"), .init("\\oflag2")], pathSeparator: "d", mailbox: .inbox, extensions: []),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseMailboxList_invalid_character_incomplete() {
        var buffer = "() \"" as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseMailboxList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is _IncompleteMessage)
        }
    }

    func testParseMailboxList_invalid_character() {
        var buffer = "() \"\\\" inbox" as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseMailboxList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - parseMailboxListFlags

extension ParserUnitTests {
    func testParseMailboxListFlags() {
        self.iterateTests(
            testFunction: GrammarParser.parseMailboxListFlags,
            validInputs: [
                ("\\marked", "\r", [.marked], #line),
                ("\\marked \\remote", "\r", [.marked, .remote], #line),
                ("\\marked \\o1 \\o2", "\r", [.marked, .init("\\o1"), .init("\\o2")], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
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
            XCTAssertEqual(mediaBasic, Media.Basic(kind: .other("STRING"), subtype: .related))
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
        let date = try XCTUnwrap(InternalDate(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, zoneMinutes: 0))

        self.iterateTests(
            testFunction: GrammarParser.parseMessageAttribute,
            validInputs: [
                ("UID 1234", " ", .uid(1234), #line),
                (#"BODY[] "hello""#, " ", .bodySection(.init(kind: .complete), offset: nil, data: "hello"), #line),
                (#"BODY[TEXT] "hello""#, " ", .bodySection(.init(kind: .text), offset: nil, data: "hello"), #line),
                (#"BODY[HEADER] "string""#, " ", .bodySection(.init(kind: .header), offset: nil, data: "string"), #line),
                (#"BODY[HEADER]<12> "string""#, " ", .bodySection(.init(kind: .header), offset: 12, data: "string"), #line),
                ("RFC822.SIZE 1234", " ", .rfc822Size(1234), #line),
                (#"RFC822 "some string""#, " ", .rfc822("some string"), #line),
                (#"RFC822.HEADER "some string""#, " ", .rfc822Header("some string"), #line),
                (#"RFC822.TEXT "string""#, " ", .rfc822Text("string"), #line),
                (#"RFC822 NIL"#, " ", .rfc822(nil), #line),
                (#"RFC822.HEADER NIL"#, " ", .rfc822Header(nil), #line),
                (#"RFC822.TEXT NIL"#, " ", .rfc822Text(nil), #line),
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
            testFunction: GrammarParser.parseModifierSequenceValue,
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
            testFunction: GrammarParser.parseModifierSequenceValue,
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
            testFunction: ParserLibrary.parseNewline,
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

// MARK: - parseResponseData

extension ParserUnitTests {
    func testParseResponseData() {
        self.iterateTests(
            testFunction: GrammarParser.parseResponseData,
            validInputs: [
                ("* CAPABILITY ENABLE\r\n", " ", .capabilityData([.enable]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseResponsePayload

extension ParserUnitTests {
    func testParseResponsePayload() {
        self.iterateTests(
            testFunction: GrammarParser.parseResponsePayload,
            validInputs: [
                ("CAPABILITY ENABLE", "\r", .capabilityData([.enable]), #line),
                ("BYE test", "\r\n", .conditionalBye(.init(code: nil, text: "test")), #line),
                ("OK test", "\r\n", .conditionalState(.ok(.init(code: nil, text: "test"))), #line),
                ("1 EXISTS", "\r", .mailboxData(.exists(1)), #line),
                ("2 EXPUNGE", "\r", .messageData(.expunge(2)), #line),
                ("ENABLED ENABLE", "\r", .enableData([.enable]), #line),
                ("ID (\"key\" NIL)", "\r", .id([.init(key: "key", value: nil)]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseResponseTextCode

extension ParserUnitTests {
    func testParseResponseTextCode() {
        self.iterateTests(
            testFunction: GrammarParser.parseResponseTextCode,
            validInputs: [
                ("ALERT", "\r", .alert, #line),
                ("BADCHARSET", "\r", .badCharset([]), #line),
                ("BADCHARSET (UTF8)", "\r", .badCharset(["UTF8"]), #line),
                ("BADCHARSET (UTF8 UTF9 UTF10)", "\r", .badCharset(["UTF8", "UTF9", "UTF10"]), #line),
                ("CAPABILITY IMAP4 IMAP4rev1", "\r", .capability([.imap4, .imap4rev1]), #line),
                ("PARSE", "\r", .parse, #line),
                ("PERMANENTFLAGS ()", "\r", .permanentFlags([]), #line),
                ("PERMANENTFLAGS (\\Answered)", "\r", .permanentFlags([.flag(.answered)]), #line),
                ("PERMANENTFLAGS (\\Answered \\Seen \\*)", "\r", .permanentFlags([.flag(.answered), .flag(.seen), .wildcard]), #line),
                ("READ-ONLY", "\r", .readOnly, #line),
                ("READ-WRITE", "\r", .readWrite, #line),
                ("UIDNEXT 12", "\r", .uidNext(12), #line),
                ("UIDVALIDITY 34", "\r", .uidValidity(34), #line),
                ("UNSEEN 56", "\r", .unseen(56), #line),
                ("NAMESPACE NIL NIL NIL", "\r", .namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), #line),
                ("some", "\r", .other("some", nil), #line),
                ("some thing", "\r", .other("some", "thing"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - search parseSearch

extension ParserUnitTests {
    func testParseSearch() {
        self.iterateTests(
            testFunction: GrammarParser.parseSearch,
            validInputs: [
                ("SEARCH ALL", "\r", .search(key: .all), #line),
                ("SEARCH ALL DELETED FLAGGED", "\r", .search(key: .and([.all, .deleted, .flagged])), #line),
                ("SEARCH CHARSET UTF-8 ALL", "\r", .search(key: .all, charset: "UTF-8"), #line),
                ("SEARCH RETURN () ALL", "\r", .search(key: .all), #line),
                ("SEARCH RETURN (MIN) ALL", "\r", .search(key: .all, returnOptions: [.min]), #line),
                (
                    #"SEARCH CHARSET UTF-8 (OR FROM "me" FROM "you") (OR NEW UNSEEN)"#,
                    "\r",
                    .search(key: .and([.or(.from("me"), .from("you")), .or(.new, .unseen)]), charset: "UTF-8"),
                    #line
                ),
                (
                    #"SEARCH RETURN (MIN MAX) CHARSET UTF-8 OR (FROM "me" FROM "you") (NEW UNSEEN)"#,
                    "\r",
                    .search(key: .or(.and([.from("me"), .from("you")]), .and([.new, .unseen])), charset: "UTF-8", returnOptions: [.min, .max]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseSearchCorrelator

extension ParserUnitTests {
    func testParseSearchCorrelator() {
        self.iterateTests(
            testFunction: GrammarParser.parseSearchCorrelator,
            validInputs: [
                (" (TAG \"test1\")", "\r", "test1", #line),
                (" (tag \"test2\")", "\r", "test2", #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-criteria` parseSearchCriteria

extension ParserUnitTests {
    func testParseSearchCriteria() {
        self.iterateTests(
            testFunction: GrammarParser.parseSearchCriteria,
            validInputs: [
                ("ALL", "\r", [.all], #line),
                ("ALL ANSWERED DELETED", "\r", [.all, .answered, .deleted], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-key` parseSearchKey

extension ParserUnitTests {
    func testParseSearchKey() {
        self.iterateTests(
            testFunction: GrammarParser.parseSearchKey,
            validInputs: [
                ("ALL", "\r", .all, #line),
                ("ANSWERED", "\r", .answered, #line),
                ("DELETED", "\r", .deleted, #line),
                ("FLAGGED", "\r", .flagged, #line),
                ("NEW", "\r", .new, #line),
                ("OLD", "\r", .old, #line),
                ("RECENT", "\r", .recent, #line),
                ("SEEN", "\r", .seen, #line),
                ("UNANSWERED", "\r", .unanswered, #line),
                ("UNDELETED", "\r", .undeleted, #line),
                ("UNFLAGGED", "\r", .unflagged, #line),
                ("UNSEEN", "\r", .unseen, #line),
                ("UNDRAFT", "\r", .undraft, #line),
                ("DRAFT", "\r", .draft, #line),
                ("ON 25-jun-1994", "\r", .on(Date(year: 1994, month: 6, day: 25)!), #line),
                ("SINCE 01-jan-2001", "\r", .since(Date(year: 2001, month: 1, day: 1)!), #line),
                ("SENTON 02-jan-2002", "\r", .sentOn(Date(year: 2002, month: 1, day: 2)!), #line),
                ("SENTBEFORE 03-jan-2003", "\r", .sentBefore(Date(year: 2003, month: 1, day: 3)!), #line),
                ("SENTSINCE 04-jan-2004", "\r", .sentSince(Date(year: 2004, month: 1, day: 4)!), #line),
                ("BEFORE 05-jan-2005", "\r", .before(Date(year: 2005, month: 1, day: 5)!), #line),
                ("LARGER 1234", "\r", .messageSizeLarger(1234), #line),
                ("SMALLER 5678", "\r", .messageSizeSmaller(5678), #line),
                ("BCC data1", "\r", .bcc("data1"), #line),
                ("BODY data2", "\r", .body("data2"), #line),
                ("CC data3", "\r", .cc("data3"), #line),
                ("FROM data4", "\r", .from("data4"), #line),
                ("SUBJECT data5", "\r", .subject("data5"), #line),
                ("TEXT data6", "\r", .text("data6"), #line),
                ("TO data7", "\r", .to("data7"), #line),
                ("KEYWORD key1", "\r", .keyword(Flag.Keyword("key1")), #line),
                ("HEADER some value", "\r", .header("some", "value"), #line),
                ("UNKEYWORD key2", "\r", .unkeyword(Flag.Keyword("key2")), #line),
                ("NOT LARGER 1234", "\r", .not(.messageSizeLarger(1234)), #line),
                ("OR LARGER 6 SMALLER 4", "\r", .or(.messageSizeLarger(6), .messageSizeSmaller(4)), #line),
                ("UID 2:4", "\r", .uid(UIDSet(2 ... 4)), #line),
                ("2:4", "\r", .sequenceNumbers(SequenceSet(2 ... 4)), #line),
                ("(LARGER 1)", "\r", .messageSizeLarger(1), #line),
                ("(LARGER 1 SMALLER 5 KEYWORD hello)", "\r", .and([.messageSizeLarger(1), .messageSizeSmaller(5), .keyword(Flag.Keyword("hello"))]), #line),
                ("YOUNGER 34", "\r", .younger(34), #line),
                ("OLDER 45", "\r", .older(45), #line),
                ("FILTER something", "\r", .filter("something"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseSearchKey_array_none_invalid() {
        var buffer = "()" as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseSearchKey(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - `search-ret-data-ext` parseSearchReturnDataExtension

extension ParserUnitTests {
    // the spec is ambiguous when parsing `tagged-ext-simple`, in that a "number" is also a "sequence-set"
    // our parser gives priority to "sequence-set"
    func testParseSearchReturnDataExtension() {
        self.iterateTests(
            testFunction: GrammarParser.parseSearchReturnDataExtension,
            validInputs: [
                ("modifier 64", "\r", .init(modifier: "modifier", returnValue: .sequence([64])), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-data` parseSearchReturnData

extension ParserUnitTests {
    func testParseSearchReturnData() {
        self.iterateTests(
            testFunction: GrammarParser.parseSearchReturnData,
            validInputs: [
                ("MIN 1", "\r", .min(1), #line),
                ("MAX 2", "\r", .max(2), #line),
                ("ALL 3", "\r", .all([3]), #line),
                ("ALL 3,4,5", "\r", .all([3, 4, 5]), #line),
                ("COUNT 4", "\r", .count(4), #line),
                ("modifier 5", "\r", .dataExtension(.init(modifier: "modifier", returnValue: .sequence([5]))), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-opt` parseSearchReturnOption

extension ParserUnitTests {
    func testParseSearchReturnOption() {
        self.iterateTests(
            testFunction: GrammarParser.parseSearchReturnOption,
            validInputs: [
                ("MIN", "\r", .min, #line),
                ("min", "\r", .min, #line),
                ("mIn", "\r", .min, #line),
                ("MAX", "\r", .max, #line),
                ("max", "\r", .max, #line),
                ("mAx", "\r", .max, #line),
                ("ALL", "\r", .all, #line),
                ("all", "\r", .all, #line),
                ("AlL", "\r", .all, #line),
                ("COUNT", "\r", .count, #line),
                ("count", "\r", .count, #line),
                ("COunt", "\r", .count, #line),
                ("SAVE", "\r", .save, #line),
                ("save", "\r", .save, #line),
                ("saVE", "\r", .save, #line),
                ("modifier", "\r", .optionExtension(.init(modifierName: "modifier", params: nil)), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-opts` parseSearchReturnOptions

extension ParserUnitTests {
    func testParseSearchReturnOptions() {
        self.iterateTests(
            testFunction: GrammarParser.parseSearchReturnOptions,
            validInputs: [
                (" RETURN (ALL)", "\r", [.all], #line),
                (" RETURN (MIN MAX COUNT)", "\r", [.min, .max, .count], #line),
                (" RETURN (m1 m2)", "\r", [
                    .optionExtension(.init(modifierName: "m1", params: nil)),
                    .optionExtension(.init(modifierName: "m2", params: nil)),
                ], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-opt-ext` parseSearchReturnOptionExtension

extension ParserUnitTests {
    func testParseSearchReturnOptionExtension() {
        self.iterateTests(
            testFunction: GrammarParser.parseSearchReturnOptionExtension,
            validInputs: [
                ("modifier", "\r", .init(modifierName: "modifier", params: nil), #line),
                ("modifier 4", "\r", .init(modifierName: "modifier", params: .sequence([4])), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: [
                ("modifier ", "", #line),
            ]
        )
    }
}

// MARK: - parseSection

extension ParserUnitTests {
    func testParseSection() {
        self.iterateTests(
            testFunction: GrammarParser.parseSection,
            validInputs: [
                ("[]", "", nil, #line),
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
                ("SELECT inbox (some1)", "\r", .select(.inbox, [.init(name: "some1", value: nil)]), #line),
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
                ("12:34", "\r\n", SequenceRange(left: 12, right: 34), #line),
                ("12:*", "\r\n", SequenceRange(left: 12, right: .max), #line),
                ("1:34", "\r\n", SequenceRange(left: .min, right: 34), #line),
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
            ],
            parserErrorInputs: [
                ("a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("1,", "", #line),
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
                ("MESSAGES 1 RECENT 2 UIDNEXT 3 UIDVALIDITY 4 UNSEEN 5 SIZE 6 HIGHESTMODSEQ 7", "\r", .init(messageCount: 1, recentCount: 2, nextUID: 3, uidValidity: 4, unseenCount: 5, size: 6, modSequence: 7), #line),
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
                ("STORE 1 (label) -FLAGS \\seen", "\r", .store([1], [.init(name: "label", value: nil)], .remove(silent: false, list: [.seen])), #line),
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

// MARK: - parseSequenceSet

extension ParserUnitTests {
    func testParseSequenceSet() {
        self.iterateTests(
            testFunction: GrammarParser.parseSequenceSet,
            validInputs: [
                ("*", "\r", [.all], #line),
                ("1:2", "\r", [1 ... 2], #line),
                ("1:2,2:3,3:4", "\r", [1 ... 2, 2 ... 3, 3 ... 4], #line),
            ],
            parserErrorInputs: [
                (":", "", #line),
                (":2", "", #line),
            ],
            incompleteMessageInputs: [
                ("1111", "", #line),
                ("1111:2222", "", #line),
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

// MARK: - parseUID

extension ParserUnitTests {
    func testParseUID() {
        self.iterateTests(
            testFunction: GrammarParser.parseUid,
            validInputs: [
                ("UID EXPUNGE 1", "\r\n", .uidExpunge([1]), #line),
                ("UID COPY 1 Inbox", "\r\n", .uidCopy([1], .inbox), #line),
                ("UID FETCH 1 FLAGS", "\r\n", .uidFetch([1], [.flags], []), #line),
                ("UID SEARCH CHARSET UTF8 ALL", "\r\n", .uidSearch(key: .all, charset: "UTF8"), #line),
                ("UID STORE 1 +FLAGS (Test)", "\r\n", .uidStore([1], [], .add(silent: false, list: [.keyword(.init("Test"))])), #line),
            ],
            parserErrorInputs: [
                ("UID RENAME inbox other", " ", #line),
            ],
            incompleteMessageInputs: [
                ("UID COPY 1", " ", #line),
            ]
        )
    }
}

// MARK: - parseUIDRange

extension ParserUnitTests {
    func testUIDRange() {
        self.iterateTests(
            testFunction: GrammarParser.parseUIDRange,
            validInputs: [
                ("*", "\r\n", UIDRange.all, #line),
                ("1:*", "\r\n", UIDRange.all, #line),
                ("12:34", "\r\n", UIDRange(left: 12, right: 34), #line),
                ("12:*", "\r\n", UIDRange(left: 12, right: .max), #line),
                ("1:34", "\r\n", UIDRange(left: .min, right: 34), #line),
            ],
            parserErrorInputs: [
                ("!", " ", #line),
                ("a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("1", "", #line),
            ]
        )
    }
}

// MARK: - parseUIDSet

extension ParserUnitTests {
    func testParseUIDSet() {
        self.iterateTests(
            testFunction: GrammarParser.parseUIDSet,
            validInputs: [
                ("1234", "\r\n", UIDSet(1234), #line),
                ("12:34", "\r\n", UIDSet(UIDRange(12 ... 34)), #line),
                ("1,2,34:56,78:910,11", "\r\n", UIDSet([
                    UIDRange(1),
                    UIDRange(2),
                    UIDRange(34 ... 56),
                    UIDRange(78 ... 910),
                    UIDRange(11),
                ])!, #line),
            ],
            parserErrorInputs: [
                ("a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("1234", "", #line),
                ("", "", #line),
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

// MARK:  RFC 2087 - Quota

extension ParserUnitTests {
    func testSetQuota() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandQuota,
            validInputs: [
                (
                    "SETQUOTA \"\" (STORAGE 512)",
                    "\r",
                    Command.setQuota(QuotaRoot(""),  [QuotaLimit(resourceName: "STORAGE", limit: 512)]),
                    #line
                ),
                (
                    "SETQUOTA \"MASSIVE_POOL\" (STORAGE 512)",
                    "\r",
                    Command.setQuota(QuotaRoot("MASSIVE_POOL"),  [QuotaLimit(resourceName: "STORAGE", limit: 512)]),
                    #line
                ),
                (
                    "SETQUOTA \"MASSIVE_POOL\" (STORAGE 512 BEANS 50000)",
                    "\r",
                    Command.setQuota(QuotaRoot("MASSIVE_POOL"),  [QuotaLimit(resourceName: "STORAGE", limit: 512),
                                                                  QuotaLimit(resourceName: "BEANS", limit: 50000)]),
                    #line
                ),
                (
                    "SETQUOTA \"MASSIVE_POOL\" ()",
                    "\r",
                    Command.setQuota(QuotaRoot("MASSIVE_POOL"),  []),
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
