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

final class ParserUnitTests: XCTestCase {
    func iterateTestInputs<T: Equatable>(_ inputs: [(String, String, T, UInt)], testFunction: (inout ByteBuffer, StackTracker) throws -> T) {
        for (input, terminator, expected, line) in inputs {
            TestUtilities.withBuffer(input, terminator: terminator, line: line) { (buffer) in
                let testValue = try testFunction(&buffer, .testTracker)
                XCTAssertEqual(testValue, expected, line: line)
            }
        }
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
            let c3 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c1, .command(TaggedCommand(tag: "1", command: .noop)))
            XCTAssertEqual(
                c2_1,
                .command(TaggedCommand(tag: "2", command: .append(
                    to: .inbox,
                    firstMessageMetadata: .init(options: .init(flagList: [], dateTime: nil, extensions: []), data: .init(byteCount: 10))
                )))
            )
            XCTAssertEqual(c2_2, .bytes("0123456789"))
            XCTAssertEqual(c3, .command(TaggedCommand(tag: "3", command: .noop)))
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
            (.greeting(.auth(.ok(.init(code: .capability([.imap4rev1]), text: "Ready.")))), #line),
            (.taggedResponse(.init(tag: "2", state: .ok(.init(code: nil, text: "Login completed.")))), #line),

            (.fetchResponse(.start(1)), #line),
            (.fetchResponse(.streamingBegin(type: .body(partial: 4), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("abc")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.simpleAttribute(.flags([.seen, .answered]))), #line),
            (.fetchResponse(.finish), #line),

            (.fetchResponse(.start(2)), #line),
            (.fetchResponse(.simpleAttribute(.flags([.deleted]))), #line),
            (.fetchResponse(.streamingBegin(type: .body(partial: nil), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("def")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.finish), #line),

            (.fetchResponse(.start(3)), #line),
            (.fetchResponse(.streamingBegin(type: .body(partial: nil), byteCount: 3)), #line),
            (.fetchResponse(.streamingBytes("ghi")), #line),
            (.fetchResponse(.streamingEnd), #line),
            (.fetchResponse(.finish), #line),
            (.taggedResponse(.init(tag: "3", state: .ok(.init(code: nil, text: "Fetch completed.")))), #line),

            (.fetchResponse(.start(1)), #line),
            (.fetchResponse(.streamingBegin(type: .binary(section: []), byteCount: 4)), #line),
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
            XCTAssertEqual(c1, .command(TaggedCommand(tag: "1", command: .noop)))
            XCTAssertEqual(parser.mode, .lines)

            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c2_1, .command(TaggedCommand(tag: "2", command: .idleStart)))
            XCTAssertEqual(parser.mode, .idle)

            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c2_2, CommandStream.idleDone)
            XCTAssertEqual(parser.mode, .lines)

            let c3 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c3, .command(TaggedCommand(tag: "3", command: .noop)))
            XCTAssertEqual(parser.mode, .lines)
        } catch {
            XCTFail("\(error)")
        }
    }
}

// MARK: - address parseAddress

extension ParserUnitTests {
    func testAddress_valid() {
        TestUtilities.withBuffer(#"("a" "b" "c" "d")"#, terminator: "\n") { (buffer) in
            let address = try GrammarParser.parseAddress(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(address.name, "a")
            XCTAssertEqual(address.adl, "b")
            XCTAssertEqual(address.mailbox, "c")
            XCTAssertEqual(address.host, "d")
        }
    }

    func testAddress_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"("a" "b" "c""#)
        XCTAssertThrowsError(try GrammarParser.parseAddress(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
        }
    }

    func testAddress_invalid_missing_brackets() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"("a" "b" "c" "d""# + "\n")
        XCTAssertThrowsError(try GrammarParser.parseAddress(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testAddress_invalid_too_few() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"("a" "b" "c")"# + "\n")
        XCTAssertThrowsError(try GrammarParser.parseAddress(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - append

extension ParserUnitTests {}

// MARK: - parseAppendUID

extension ParserUnitTests {
    func testParseAppendUID() {
        TestUtilities.withBuffer("12", terminator: " ") { (buffer) in
            let num = try GrammarParser.parseAppendUid(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 12)
        }
    }
}

// MARK: - parseAppendData

extension ParserUnitTests {
    func testParseAppendData() {
        let inputs: [(String, String, AppendData, UInt)] = [
            ("{123}\r\n", "hello", .init(byteCount: 123), #line),
            ("~{456}\r\n", "hello", .init(byteCount: 456, needs8BitCleanTransport: true), #line),
            ("{0}\r\n", "hello", .init(byteCount: 0), #line),
            ("~{\(Int.max)}\r\n", "hello", .init(byteCount: .max, needs8BitCleanTransport: true), #line),
            ("{123+}\r\n", "hello", .init(byteCount: 123, synchronizing: false), #line),
            ("~{456+}\r\n", "hello", .init(byteCount: 456, needs8BitCleanTransport: true, synchronizing: false), #line),
            ("{0+}\r\n", "hello", .init(byteCount: 0, synchronizing: false), #line),
            ("~{\(Int.max)+}\r\n", "hello", .init(byteCount: .max, needs8BitCleanTransport: true, synchronizing: false), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseAppendData)
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

// MARK: - parseAppendDataExtension

extension ParserUnitTests {
    func testParseAppendDataExtension() {
        let inputs: [(String, String, TaggedExtension, UInt)] = [
            ("label 1:9", " ", .init(label: "label", value: .simple(.sequence([1 ... 9]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseAppendDataExtension)
    }
}

// MARK: - parseAppendExtension

extension ParserUnitTests {
    func testParseAppendExtension() {
        let inputs: [(String, String, AppendExtension, UInt)] = [
            ("name 1:9", " ", .init(name: "name", value: .simple(.sequence([1 ... 9]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseAppendExtension)
    }
}

// MARK: - parseAppendExtensionName

extension ParserUnitTests {
    func testParseAppendExtensionName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", " ", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseAppendExtensionName)
    }
}

// MARK: - parseAppendExtensionValue

extension ParserUnitTests {
    func testParseAppendExtensionValue() {
        let inputs: [(String, String, TaggedExtensionValue, UInt)] = [
            ("1:9", " ", .simple(.sequence([1 ... 9])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseAppendExtensionValue)
    }
}

// MARK: - parseAppendMessage

extension ParserUnitTests {
    // NOTE: Spec is ambiguous when parsing `append-data`, which may contain `append-data-ext`, which is the same as `append-ext`, which is inside `append-opts`
    func testParseMessage() {
        let inputs: [(String, String, AppendMessage, UInt)] = [
            (
                " (\\Answered) {123}\r\n",
                "test",
                .init(options: .init(flagList: [.answered], dateTime: nil, extensions: []), data: .init(byteCount: 123)),
                #line
            ),
            (
                " (\\Answered) ~{456}\r\n",
                "test",
                .init(options: .init(flagList: [.answered], dateTime: nil, extensions: []), data: .init(byteCount: 456, needs8BitCleanTransport: true)),
                #line
            ),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseAppendMessage)
    }
}

// MARK: - parseAppendOptions

extension ParserUnitTests {
    func testParseAppendOptions() {
        let inputs: [(String, String, AppendOptions, UInt)] = [
            ("", "\r", .init(flagList: [], dateTime: nil, extensions: []), #line),
            (" (\\Answered)", "\r", .init(flagList: [.answered], dateTime: nil, extensions: []), #line),
            (
                " \"25-jun-1994 01:02:03 +0000\"",
                "\r",
                .init(flagList: [], dateTime: .init(date: .init(day: 25, month: .jun, year: 1994), time: .init(hour: 01, minute: 02, second: 03), zone: Date.TimeZone(0)!), extensions: []),
                #line
            ),
            (
                " name1 1:2",
                "\r",
                .init(flagList: [], dateTime: nil, extensions: [.init(name: "name1", value: .simple(.sequence([1 ... 2])))]),
                #line
            ),
            (
                " name1 1:2 name2 2:3 name3 3:4",
                "\r",
                .init(flagList: [], dateTime: nil, extensions: [
                    .init(name: "name1", value: .simple(.sequence([1 ... 2]))),
                    .init(name: "name2", value: .simple(.sequence([2 ... 3]))),
                    .init(name: "name3", value: .simple(.sequence([3 ... 4]))),
                ]),
                #line
            ),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseAppendOptions)
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
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
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
        TestUtilities.withBuffer("abcd1234", terminator: " ") { (buffer) in
            let result = try GrammarParser.parseBase64(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, "abcd1234")
        }
    }

    func testParseBase64Terminal_valid_short_terminal() {
        TestUtilities.withBuffer("abcd1234++==", terminator: " ") { (buffer) in
            let result = try GrammarParser.parseBase64(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, "abcd1234++==")
        }
    }
}

// MARK: - parseBodyExtension

extension ParserUnitTests {
    func testParseBodyExtension() {
        let inputs: [(String, String, [BodyExtensionType], UInt)] = [
            ("1", "\r", [.number(1)], #line),
            ("\"s\"", "\r", [.string("s")], #line),
            ("(1)", "\r", [.number(1)], #line),
            ("(1 \"2\" 3)", "\r", [.number(1), .string("2"), .number(3)], #line),
            ("(1 2 3 (4 (5 (6))))", "\r", [.number(1), .number(2), .number(3), .number(4), .number(5), .number(6)], #line),
            ("(((((1)))))", "\r", [.number(1)], #line), // yeh, this is valid, don't ask
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseBodyExtension)
    }
}

// MARK: - parseBodyFieldDsp

extension ParserUnitTests {
    func testParseBodyFieldDsp_some() {
        TestUtilities.withBuffer(#"("astring" ("f1" "v1"))"#) { (buffer) in
            let dsp = try GrammarParser.parseBodyFieldDsp(buffer: &buffer, tracker: .testTracker)
            XCTAssertNotNil(dsp)
            XCTAssertEqual(dsp, BodyStructure.FieldDispositionData(string: "astring", parameter: [.init(field: "f1", value: "v1")]))
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
        let inputs: [(String, String, BodyStructure.Encoding, UInt)] = [
            (#""BASE64""#, " ", .base64, #line),
            (#""BINARY""#, " ", .binary, #line),
            (#""7BIT""#, " ", .sevenBit, #line),
            (#""8BIT""#, " ", .eightBit, #line),
            (#""QUOTED-PRINTABLE""#, " ", .quotedPrintable, #line),
            (#""other""#, " ", .init("other"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseBodyEncoding)
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
        let inputs: [(String, String, BodyStructure.FieldLanguage, UInt)] = [
            (#""english""#, " ", .single("english"), #line),
            (#"("english")"#, " ", .multiple(["english"]), #line),
            (#"("english" "french")"#, " ", .multiple(["english", "french"]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseBodyFieldLanguage)
    }
}

// MARK: - parseBodyFieldLines

extension ParserUnitTests {
    func testBodyFieldLines() {
        TestUtilities.withBuffer("12", terminator: " ") { (buffer) in
            let num = try GrammarParser.parseBodyFieldLines(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 12)
        }
    }
}

// MARK: - parseBodyFieldParam

extension ParserUnitTests {
    func testParseBodyFieldParam() {
        let inputs: [(String, String, [FieldParameterPair], UInt)] = [
            (#"NIL"#, " ", [], #line),
            (#"("f1" "v1")"#, " ", [.init(field: "f1", value: "v1")], #line),
            (#"("f1" "v1" "f2" "v2")"#, " ", [.init(field: "f1", value: "v1"), .init(field: "f2", value: "v2")], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseBodyFieldParam)
    }

    func testParseBodyFieldParam_invalid_oneObject() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"("p1" "#)
        XCTAssertThrowsError(try GrammarParser.parseBodyFieldParam(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
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
            XCTAssertEqual(result.octets, 1234)
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
                    type: .basic(.init(type: .audio, subtype: .alternative)),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 1),
                    extension: nil
                ),
                #line
            ),
            (
                "\"APPLICATION\" \"multipart/mixed\" NIL \"id\" \"description\" \"7BIT\" 2",
                "\r\n",
                .init(
                    type: .basic(.init(type: .application, subtype: .mixed)),
                    fields: .init(parameter: [], id: "id", description: "description", encoding: .sevenBit, octets: 2),
                    extension: nil
                ),
                #line
            ),
            (
                "\"VIDEO\" \"multipart/related\" (\"f1\" \"v1\") NIL NIL \"8BIT\" 3",
                "\r\n",
                .init(
                    type: .basic(.init(type: .video, subtype: .related)),
                    fields: .init(parameter: [.init(field: "f1", value: "v1")], id: nil, description: nil, encoding: .eightBit, octets: 3),
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
                            body: .singlepart(.init(type: .basic(.init(type: .image, subtype: .related)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octets: 5))),
                            fieldLines: 8
                        )
                    ),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 4),
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
                    type: .text(.init(mediaText: "media", lines: 2)),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .quotedPrintable, octets: 1),
                    extension: nil
                ),
                #line
            ),
        ]

        let inputs = basicInputs + messageInputs + textInputs
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseBodyTypeSinglePart)
    }
}

// MARK: - capability parseCapability

extension ParserUnitTests {
    func testParseCapability() {
        let inputs: [(String, String, Capability, UInt)] = [
            ("CONDSTORE", " ", .condStore, #line),
            ("AUTH=PLAIN", " ", .auth(.plain), #line),
            ("SPECIAL-USE", " ", .specialUse, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCapability)
    }

    func testCapability_invalid_empty() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
    }
}

// MARK: - capability parseCapabilityData

extension ParserUnitTests {
    func testParseCapabilityData() {
        let inputs: [(String, String, [Capability], UInt)] = [
            ("CAPABILITY IMAP4rev1", "\r", [.imap4rev1], #line),
            ("CAPABILITY IMAP4 IMAP4rev1", "\r", [.imap4, .imap4rev1], #line),
            ("CAPABILITY FILTERS IMAP4", "\r", [.filters, .imap4], #line),
            ("CAPABILITY FILTERS IMAP4rev1 ENABLE", "\r", [.filters, .imap4rev1, .enable], #line),
            ("CAPABILITY FILTERS IMAP4rev1 ENABLE IMAP4", "\r", [.filters, .imap4rev1, .enable, .imap4], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCapabilityData)
    }
}

// MARK: - parseCharset

extension ParserUnitTests {
    func testParseCharset() {
        let inputs: [(String, String, String, UInt)] = [
            ("UTF8", " ", "UTF8", #line),
            ("\"UTF8\"", " ", "UTF8", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCharset)
    }
}

// MARK: - parseChildMailboxFlag

extension ParserUnitTests {
    func testParseChildMailboxFlag() {
        let inputs: [(String, String, ChildMailboxFlag, UInt)] = [
            ("\\HasChildren", " ", .HasChildren, #line),
            ("\\haschildren", " ", .HasChildren, #line),
            ("\\HASCHILDREN", " ", .HasChildren, #line),
            ("\\HasNoChildren", " ", .HasNoChildren, #line),
            ("\\hasnochildren", " ", .HasNoChildren, #line),
            ("\\HASNOCHILDREN", " ", .HasNoChildren, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseChildMailboxFlag)
    }
}

// MARK: - parseContinueRequest

extension ParserUnitTests {
    func testParseContinueRequest() {
        let inputs: [(String, String, ContinueRequest, UInt)] = [
            ("+ OK\r\n", " ", .responseText(.init(code: nil, text: "OK")), #line),
            ("+ abc=\r\n", " ", .base64("abc="), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseContinueRequest)
    }
}

// MARK: - create parseCreate

extension ParserUnitTests {
    func testParseCreate() {
        let inputs: [(String, String, Command, UInt)] = [
            ("CREATE inbox", "\r", .create(.inbox, []), #line),
            ("CREATE inbox (some)", "\r", .create(.inbox, [.init(name: "some", value: nil)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCreate)
    }

    func testCreate_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "CREATE ")
        XCTAssertThrowsError(try GrammarParser.parseCreate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
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
        let inputs: [(String, String, Command, UInt)] = [
            ("CAPABILITY", " ", .capability, #line),
            ("LOGOUT", " ", .logout, #line),
            ("NOOP", " ", .noop, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCommandAny)
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
            guard case .authenticate(let type, let initial, let dataArray) = result else {
                XCTFail("Case mixup \(result)")
                return
            }
            XCTAssertNil(initial)
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
        let inputs: [(String, String, Command, UInt)] = [
            ("LSUB inbox someList", " ", .lsub(reference: .inbox, pattern: "someList"), #line),
            ("CREATE inbox (something)", " ", .create(.inbox, [.init(name: "something", value: nil)]), #line),
            ("NAMESPACE", " ", .namespace, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCommandAuth)
    }
}

// MARK: - CommandType parseCommandSelect

extension ParserUnitTests {
    func testParseCommandSelect() {
        let inputs: [(String, String, Command, UInt)] = [
            ("UNSELECT", " ", .unselect, #line),
            ("unselect", " ", .unselect, #line),
            ("UNSelect", " ", .unselect, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCommandSelect)
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

// MARK: - copy parseCopy

extension ParserUnitTests {
    func testCopy_valid() {
        TestUtilities.withBuffer("COPY 1,2,3 inbox", terminator: " ") { (buffer) in
            let copy = try GrammarParser.parseCopy(buffer: &buffer, tracker: .testTracker)
            let expectedSequence: [SequenceRange] = [1, 2, 3]
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

// MARK: - parseCreateParameter

extension ParserUnitTests {
    // NOTE: I'm not a huge fan of how a single number gets parsed as a set, we should revisit
    func testParseCreateParameter() {
        let inputs: [(String, String, CreateParameter, UInt)] = [
            ("test", "\r", .init(name: "test", value: nil), #line),
            ("some 1", "\r", .init(name: "some", value: .simple(.sequence([1]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCreateParameter)
    }
}

// MARK: - parseCreateParameter

extension ParserUnitTests {
    func testParseCreateParameters() {
        let inputs: [(String, String, [CreateParameter], UInt)] = [
            (" (test)", "\r", [.init(name: "test", value: nil)], #line),
            (" (test1 test2 test3)", "\r", [.init(name: "test1", value: nil), .init(name: "test2", value: nil), .init(name: "test3", value: nil)], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCreateParameters)
    }
}

// MARK: - parseCreateParameterName

extension ParserUnitTests {
    func testParseCreateParameterName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", "\r", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCreateParameterName)
    }
}

// MARK: - parseCreateParameterValue

extension ParserUnitTests {
    func testParseCreateParameterValue() {
        let inputs: [(String, String, TaggedExtensionValue, UInt)] = [
            ("1", "\r", .simple(.sequence([1])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseCreateParameterValue)
    }
}

// MARK: - date

extension ParserUnitTests {
    func testDate_valid_plain() {
        TestUtilities.withBuffer("25-Jun-1994", terminator: " ") { (buffer) in
            let day = try GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, Date(day: 25, month: .jun, year: 1994))
        }
    }

    func testDate_valid_quoted() {
        TestUtilities.withBuffer("\"25-Jun-1994\"") { (buffer) in
            let day = try GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, Date(day: 25, month: .jun, year: 1994))
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
            let day = try GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, .jun)
        }
    }

    func testDateMonth_valid_mixedCase() {
        TestUtilities.withBuffer("JUn", terminator: " ") { (buffer) in
            let day = try GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, .jun)
        }
    }

    func testDateMonth_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "ju")
        XCTAssertThrowsError(try GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
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
            let day = try GrammarParser.parseDateText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, Date(day: 25, month: .jun, year: 1994))
        }
    }

    func testDateText_invalid_missing_year() {
        var buffer = TestUtilities.createTestByteBuffer(for: "25-Jun-")
        XCTAssertThrowsError(try GrammarParser.parseDateText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
        }
    }
}

// MARK: - date-time parseDateTime

extension ParserUnitTests {
    // NOTE: Only a few sample failure cases tested, more will be handled by the `ByteToMessageDecoder`

    func testParseDateTime_valid() {
        TestUtilities.withBuffer(#""25-Jun-1994 01:02:03 +1020""#) { (buffer) in
            let dateTime = try GrammarParser.parseDateTime(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(dateTime.date, Date(day: 25, month: .jun, year: 1994))
            XCTAssertEqual(dateTime.time, Date.Time(hour: 01, minute: 02, second: 03))
            XCTAssertEqual(dateTime.zone, Date.TimeZone(1020)!)
        }
    }

    func testParseDateTime__invalid_incomplete() {
        var buffer = #""25-Jun-1994 01"# as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseDateTime(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
    }

    func testParseDateTime__invalid_missing_space() {
        var buffer = #""25-Jun-199401:02:03+1020""# as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseDateTime(buffer: &buffer, tracker: .testTracker)) { error in
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
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - enable-data parseEnableData

extension ParserUnitTests {
    func testParseEnableData() {
        let inputs: [(String, String, [Capability], UInt)] = [
            ("ENABLED", "\r", [], #line),
            ("ENABLED ENABLE", "\r", [.enable], #line),
            ("ENABLED ENABLE CONDSTORE", "\r", [.enable, .condStore], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseEnableData)
    }
}

// MARK: - parseEItemStandardTag

extension ParserUnitTests {
    func testParseEItemStandardTag() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", " ", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseEitemStandardTag)
    }
}

// MARK: - parseEItemVendorTag

extension ParserUnitTests {
    func testParseEItemVendorTag() {
        let inputs: [(String, String, EItemVendorTag, UInt)] = [
            ("token-atom", " ", EItemVendorTag(token: "token", atom: "atom"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseEitemVendorTag)
    }
}

// MARK: - entry-type-resp parseEntryTypeResponse

extension ParserUnitTests {
    func testParseEntryTypeRequest() {
        let inputs: [(String, String, EntryTypeRequest, UInt)] = [
            ("all", " ", .all, #line),
            ("ALL", " ", .all, #line),
            ("aLL", " ", .all, #line),
            ("shared", " ", .response(.shared), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseEntryTypeRequest)
    }
}

// MARK: - entry-type-resp parseEntryTypeResponse

extension ParserUnitTests {
    func testParseEntryTypeResponse() {
        let inputs: [(String, String, EntryTypeResponse, UInt)] = [
            ("priv", " ", .private, #line),
            ("PRIV", " ", .private, #line),
            ("prIV", " ", .private, #line),
            ("shared", " ", .shared, #line),
            ("SHARED", " ", .shared, #line),
            ("shaRED", " ", .shared, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseEntryTypeResponse)
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
        let inputs: [(String, String, ESearchResponse, UInt)] = [
            ("ESEARCH", "\r", .init(correlator: nil, uid: false, returnData: []), #line),
            ("ESEARCH UID", "\r", .init(correlator: nil, uid: true, returnData: []), #line),
            ("ESEARCH (TAG \"col\") UID", "\r", .init(correlator: "col", uid: true, returnData: []), #line),
            ("ESEARCH (TAG \"col\") UID COUNT 2", "\r", .init(correlator: "col", uid: true, returnData: [.count(2)]), #line),
            ("ESEARCH (TAG \"col\") UID MIN 1 MAX 2", "\r", .init(correlator: "col", uid: true, returnData: [.min(1), .max(2)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseEsearchResponse)
    }
}

// MARK: - examine parseExamine

extension ParserUnitTests {
    func testParseExamine() {
        let inputs: [(String, String, Command, UInt)] = [
            ("EXAMINE inbox", "\r", .examine(.inbox, []), #line),
            ("examine inbox", "\r", .examine(.inbox, []), #line),
            ("EXAMINE inbox (number)", "\r", .examine(.inbox, [.init(name: "number", value: nil)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseExamine)
    }

    func testExamine_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "EXAMINE ")
        XCTAssertThrowsError(try GrammarParser.parseExamine(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parseFetch

extension ParserUnitTests {
    func testParseFetch() {
        let inputs: [(String, String, Command, UInt)] = [
            ("FETCH 1:3 ALL", "\r", .fetch([1 ... 3], .all, []), #line),
            ("FETCH 2:4 FULL", "\r", .fetch([2 ... 4], .full, []), #line),
            ("FETCH 3:5 FAST", "\r", .fetch([3 ... 5], .fast, []), #line),
            ("FETCH 4:6 ENVELOPE", "\r", .fetch([4 ... 6], .attributes([.envelope]), []), #line),
            ("FETCH 5:7 (ENVELOPE FLAGS)", "\r", .fetch([5 ... 7], .attributes([.envelope, .flags]), []), #line),
            ("FETCH 3:5 FAST (name)", "\r", .fetch([3 ... 5], .fast, [.init(name: "name", value: nil)]), #line),
            ("FETCH 1 BODY[TEXT]", "\r", .fetch([1], .attributes([.bodySection(peek: false, .text(.text), nil)]), []), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseFetch)
    }
}

// MARK: - parseFetchAttribute

extension ParserUnitTests {
    func testParseFetchAttribute() {
        let inputs: [(String, String, FetchAttribute, UInt)] = [
            ("ENVELOPE", " ", .envelope, #line),
            ("FLAGS", " ", .flags, #line),
            ("INTERNALDATE", " ", .internalDate, #line),
            ("RFC822.HEADER", " ", .rfc822(.header), #line),
            ("RFC822", " ", .rfc822(nil), #line),
            ("BODY", " ", .bodyStructure(extensions: false), #line),
            ("BODYSTRUCTURE", " ", .bodyStructure(extensions: true), #line),
            ("UID", " ", .uid, #line),
            ("BODY[1]<1.2>", " ", .bodySection(peek: false, .part([1], text: nil), Partial(left: 1, right: 2)), #line),
            ("BODY[1.TEXT]", " ", .bodySection(peek: false, .part([1], text: .text), nil), #line),
            ("BODY[4.2.TEXT]", " ", .bodySection(peek: false, .part([4, 2], text: .text), nil), #line),
            ("BODY[HEADER]", " ", .bodySection(peek: false, .text(.header), nil), #line),
            ("BODY.PEEK[HEADER]<3.4>", " ", .bodySection(peek: true, .text(.header), Partial(left: 3, right: 4)), #line),
            ("BODY.PEEK[HEADER]", " ", .bodySection(peek: true, .text(.header), nil), #line),
            ("BINARY.PEEK[1]", " ", .binary(peek: true, section: [1], partial: nil), #line),
            ("BINARY.PEEK[1]<3.4>", " ", .binary(peek: true, section: [1], partial: .init(left: 3, right: 4)), #line),
            ("BINARY[2]<4.5>", " ", .binary(peek: false, section: [2], partial: .init(left: 4, right: 5)), #line),
            ("BINARY.SIZE[5]", " ", .binarySize(section: [5]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseFetchAttribute)
    }
}

// MARK: - parseFetchModifier

extension ParserUnitTests {
    func testParseFetchModifier() {
        let inputs: [(String, String, FetchModifier, UInt)] = [
            ("test", "\r", .init(name: "test", value: nil), #line),
            ("some 1", "\r", .init(name: "some", value: .simple(.sequence([1]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseFetchModifier)
    }
}

// MARK: - parseFetchModifiers

extension ParserUnitTests {
    func testParseFetchModifiers() {
        let inputs: [(String, String, [FetchModifier], UInt)] = [
            (" (test)", "\r", [.init(name: "test", value: nil)], #line),
            (" (test1 test2 test3)", "\r", [.init(name: "test1", value: nil), .init(name: "test2", value: nil), .init(name: "test3", value: nil)], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseFetchModifiers)
    }
}

// MARK: - parseFetchModifierName

extension ParserUnitTests {
    func testParseFetchModifierName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", "\r", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseFetchModifierName)
    }
}

// MARK: - parseFetchModifierParameter

extension ParserUnitTests {
    func testParseFetchModifierParameter() {
        let inputs: [(String, String, TaggedExtensionValue, UInt)] = [
            ("1", "\r", .simple(.sequence([1])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseFetchModifierParameter)
    }
}

// MARK: - filter-name parseFilterName

extension ParserUnitTests {
    func testParseFilterName() {
        let inputs: [(String, String, String, UInt)] = [
            ("a", " ", "a", #line),
            ("abcdefg", " ", "abcdefg", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseFilterName)
    }
}

// MARK: - parseFlag

extension ParserUnitTests {
    func testParseFlag() {
        let inputs: [(String, String, Flag, UInt)] = [
            ("\\answered", " ", .answered, #line),
            ("\\flagged", " ", .flagged, #line),
            ("\\deleted", " ", .deleted, #line),
            ("\\seen", " ", .seen, #line),
            ("\\draft", " ", .draft, #line),
            ("keyword", " ", .keyword(Flag.Keyword("keyword")), #line),
            ("\\extension", " ", .extension("\\extension"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseFlag)
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
        let inputs: [(String, String, [IDParameter], UInt)] = [
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
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseIDParamsList)
    }
}

// MARK: - parseList

extension ParserUnitTests {
    func testParseList() {
        let inputs: [(String, String, Command, UInt)] = [
            (#"LIST "" """#, "\r", .list(nil, reference: MailboxName(""), .mailbox(""), []), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseList)
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
        let inputs: [(String, String, MailboxName.Data, UInt)] = [
            ("FLAGS (\\seen \\draft)", " ", .flags([.seen, .draft]), #line),
            (
                "LIST (\\oflag1 \\oflag2) NIL inbox",
                "\r\n",
                .list(.init(attributes: .init(oFlags: [.other("\\oflag1"), .other("\\oflag2")], sFlag: nil), pathSeparator: nil, mailbox: .inbox, extensions: [])),
                #line
            ),
            ("ESEARCH MIN 1 MAX 2", "\r\n", .esearch(.init(correlator: nil, uid: false, returnData: [.min(1), .max(2)])), #line),
            ("1234 EXISTS", "\r\n", .exists(1234), #line),
            ("5678 RECENT", "\r\n", .recent(5678), #line),
            ("STATUS INBOX ()", "\r\n", .status(.inbox, []), #line),
            ("STATUS INBOX (MESSAGES 2)", "\r\n", .status(.inbox, [.messages(2)]), #line),
            (
                "LSUB (\\seen \\draft) NIL inbox",
                "\r\n",
                .lsub(.init(attributes: .init(oFlags: [.other("\\seen"), .other("\\draft")], sFlag: nil), pathSeparator: nil, mailbox: .inbox, extensions: [])),
                #line
            ),
            ("SEARCH", "\r\n", .search([]), #line),
            ("SEARCH 1", "\r\n", .search([1]), #line),
            ("SEARCH 1 2 3 4 5", "\r\n", .search([1, 2, 3, 4, 5]), #line),
            ("NAMESPACE NIL NIL NIL", "\r\n", .namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseMailboxData)
    }
}

// MARK: - parseMailboxList

extension ParserUnitTests {
    func testParseMailboxList() {
        let inputs: [(String, String, MailboxInfo, UInt)] = [
            (
                "() NIL inbox",
                "\r",
                .init(attributes: nil, pathSeparator: nil, mailbox: .inbox, extensions: []),
                #line
            ),
            (
                "() \"d\" inbox",
                "\r",
                .init(attributes: nil, pathSeparator: "d", mailbox: .inbox, extensions: []),
                #line
            ),
            (
                "(\\oflag1 \\oflag2) NIL inbox",
                "\r",
                .init(attributes: .init(oFlags: [.other("\\oflag1"), .other("\\oflag2")], sFlag: nil), pathSeparator: nil, mailbox: .inbox, extensions: []),
                #line
            ),
            (
                "(\\oflag1 \\oflag2) \"d\" inbox",
                "\r",
                .init(attributes: .init(oFlags: [.other("\\oflag1"), .other("\\oflag2")], sFlag: nil), pathSeparator: "d", mailbox: .inbox, extensions: []),
                #line
            ),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseMailboxList)
    }

    func testParseMailboxList_invalid_character_incomplete() {
        var buffer = "() \"" as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseMailboxList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
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
    func testParseMailboxListFlags_valid_oFlags_one() {
        TestUtilities.withBuffer("\\flag1", terminator: " \r\n") { (buffer) in
            let flags = try GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("\\flag1")])
            XCTAssertNil(flags.sFlag)
        }
    }

    func testParseMailboxListFlags_valid_oFlags_multiple() {
        TestUtilities.withBuffer("\\flag1 \\flag2", terminator: " \r\n") { (buffer) in
            let flags = try GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("\\flag1"), .other("\\flag2")])
            XCTAssertNil(flags.sFlag)
        }
    }

    // 1*OFlag sFlag 0*OFlag
    func testParseMailboxListFlags_valid_mixedArray1() {
        TestUtilities.withBuffer("\\oflag1 \\marked", terminator: "\r\n") { (buffer) in
            let flags = try GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("\\oflag1")])
            XCTAssertEqual(flags.sFlag, MailboxInfo.SFlag.marked)
        }
    }

    // 1*OFlag sFlag 1*OFlag
    func testParseMailboxListFlags_valid_mixedArray2() {
        TestUtilities.withBuffer("\\oflag1 \\marked \\oflag2", terminator: " \r\n") { (buffer) in
            let flags = try GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("\\oflag1"), .other("\\oflag2")])
            XCTAssertEqual(flags.sFlag, MailboxInfo.SFlag.marked)
        }
    }

    // 2*OFlag sFlag 2*OFlag
    func testParseMailboxListFlags_valid_mixedArray3() {
        TestUtilities.withBuffer("\\oflag1 \\oflag2 \\marked \\oflag3 \\oflag4", terminator: " \r\n") { (buffer) in
            let flags = try GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("\\oflag1"), .other("\\oflag2"), .other("\\oflag3"), .other("\\oflag4")])
            XCTAssertEqual(flags.sFlag, MailboxInfo.SFlag.marked)
        }
    }
}

// MARK: - parseMailboxListOflag

extension ParserUnitTests {
    func testParseMailboxListOflag_valid_inferior() {
        TestUtilities.withBuffer("\\Noinferiors") { (buffer) in
            let flag = try GrammarParser.parseMailboxListOflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .noInferiors)
        }
    }

    func testParseMailboxListOflag_valid_inferior_mixedCase() {
        TestUtilities.withBuffer("\\NOINferiors") { (buffer) in
            let flag = try GrammarParser.parseMailboxListOflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .noInferiors)
        }
    }

    func testParseMailboxListOflag_valid_other() {
        TestUtilities.withBuffer("\\SomeFlag", terminator: " ") { (buffer) in
            let flag = try GrammarParser.parseMailboxListOflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .other("\\SomeFlag"))
        }
    }
}

// MARK: - parseMediaBasic

extension ParserUnitTests {
    func testParseMediaBasic_valid_match() {
        var buffer = #""APPLICATION" "multipart/mixed""# as ByteBuffer
        do {
            let mediaBasic = try GrammarParser.parseMediaBasic(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(mediaBasic, Media.Basic(type: .application, subtype: .mixed))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseMediaBasic_valid_string() {
        var buffer = #""STRING" "multipart/related""# as ByteBuffer
        do {
            let mediaBasic = try GrammarParser.parseMediaBasic(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(mediaBasic, Media.Basic(type: .other("STRING"), subtype: .related))
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
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
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
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parseMessageAttribute

extension ParserUnitTests {
    func testParseMessageAttribute() {
        let inputs: [(String, String, MessageAttribute, UInt)] = [
            ("UID 1234", " ", .uid(1234), #line),
            ("BODY[TEXT] \"hello\"", " ", .bodySection(.text(.text), partial: nil, data: "hello"), #line),
            (#"BODY[HEADER] "string""#, " ", .bodySection(.text(.header), partial: nil, data: "string"), #line),
            (#"BODY[HEADER]<12> "string""#, " ", .bodySection(.text(.header), partial: 12, data: "string"), #line),
            ("RFC822.SIZE 1234", " ", .rfc822Size(1234), #line),
            (#"RFC822 "some string""#, " ", .rfc822("some string"), #line),
            (#"RFC822.HEADER "some string""#, " ", .rfc822Header("some string"), #line),
            (#"RFC822.TEXT "string""#, " ", .rfc822Text("string"), #line),
            (#"RFC822 NIL"#, " ", .rfc822(nil), #line),
            (#"RFC822.HEADER NIL"#, " ", .rfc822Header(nil), #line),
            (#"RFC822.TEXT NIL"#, " ", .rfc822Text(nil), #line),
            ("BINARY.SIZE[3] 4", " ", .binarySize(section: [3], size: 4), #line),
            ("BINARY[3] \"hello\"", " ", .binary(section: [3], data: "hello"), #line),
            (
                #"INTERNALDATE "25-jun-1994 01:02:03 +0000""#,
                " ",
                .internalDate(Date.DateTime(
                    date: Date(day: 25, month: .jun, year: 1994),
                    time: Date.Time(hour: 01, minute: 02, second: 03),
                    zone: Date.TimeZone(0)!
                )),
                #line
            ),
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
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseMessageAttribute)
    }
}

// MARK: - parseMessageData

extension ParserUnitTests {
    func testParseMessageData() {
        let inputs: [(String, String, MessageData, UInt)] = [
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseMessageData)
    }
}

// MARK: - mod-sequence-value parseModifierSequenceValue

extension ParserUnitTests {
    func testParseModifierSequenceValue() {
        let inputs: [(String, String, ModifierSequenceValue, UInt)] = [
            ("1", " ", 1, #line),
            ("123", " ", 123, #line),
            ("12345", " ", 12345, #line),
            ("1234567", " ", 1234567, #line),
            ("123456789", " ", 123456789, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseModifierSequenceValue)
    }
}

// MARK: - mod-sequence-valzer parseModifierSequenceValueZero

extension ParserUnitTests {
    func testParseModifierSequenceValueZero() {
        let inputs: [(String, String, ModifierSequenceValue, UInt)] = [
            ("0", " ", .zero, #line),
            ("123", " ", 123, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseModifierSequenceValue)
    }
}

// MARK: - move parseMove

extension ParserUnitTests {
    func testParseMove() {
        let inputs: [(String, String, Command, UInt)] = [
            ("MOVE * inbox", " ", .move([.wildcard], .inbox), #line),
            ("MOVE 1:2,4:5 test", " ", .move([1 ... 2, 4 ... 5], .init("test")), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseMove)
    }
}

// MARK: - parseNamespaceCommand

extension ParserUnitTests {
    func testParseNamespaceCommand() {
        let inputs: [(String, String, Command, UInt)] = [
            ("NAMESPACE", " ", .namespace, #line),
            ("nameSPACE", " ", .namespace, #line),
            ("namespace", " ", .namespace, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseNamespaceCommand)
    }
}

// MARK: - Namespace-Desc parseNamespaceResponse

extension ParserUnitTests {
    func testParseNamespaceDescription() {
        let inputs: [(String, String, NamespaceDescription, UInt)] = [
            ("(\"str1\" NIL)", " ", .init(string: "str1", char: nil, responseExtensions: []), #line),
            ("(\"str\" \"a\")", " ", .init(string: "str", char: "a", responseExtensions: []), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseNamespaceDescription)
    }
}

// MARK: - parseNamespaceResponse

extension ParserUnitTests {
    func testParseNamespaceResponse() {
        let inputs: [(String, String, NamespaceResponse, UInt)] = [
            ("NAMESPACE nil nil nil", " ", .init(userNamespace: [], otherUserNamespace: [], sharedNamespace: []), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseNamespaceResponse)
    }
}

// MARK: - parseNamespaceResponseExtension

extension ParserUnitTests {
    func testParseNamespaceResponseExtension() {
        let inputs: [(String, String, NamespaceResponseExtension, UInt)] = [
            (" \"str1\" (\"str2\")", " ", .init(string: "str1", array: ["str2"]), #line),
            (" \"str1\" (\"str2\" \"str3\" \"str4\")", " ", .init(string: "str1", array: ["str2", "str3", "str4"]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseNamespaceResponseExtension)
    }
}

// MARK: - parseNewline

extension ParserUnitTests {
    func test_parseNewlineSuccessful() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\nx")
        XCTAssertNoThrow(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker))
        XCTAssertEqual(UInt8(ascii: "x"), buffer.readInteger(as: UInt8.self))

        buffer = TestUtilities.createTestByteBuffer(for: "\n")
        XCTAssertNoThrow(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker))
        XCTAssertNil(buffer.readInteger(as: UInt8.self))

        buffer = TestUtilities.createTestByteBuffer(for: "\r\nx")
        XCTAssertNoThrow(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker))
        XCTAssertEqual(UInt8(ascii: "x"), buffer.readInteger(as: UInt8.self))

        buffer = TestUtilities.createTestByteBuffer(for: "\r\n")
        XCTAssertNoThrow(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker))
        XCTAssertNil(buffer.readInteger(as: UInt8.self))
    }

    func test_parseNewlineFailure() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\r")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
        XCTAssertEqual(UInt8(ascii: "\r"), buffer.readInteger(as: UInt8.self))

        buffer = TestUtilities.createTestByteBuffer(for: "\rx")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
        XCTAssertEqual(UInt8(ascii: "\r"), buffer.readInteger(as: UInt8.self))

        buffer = TestUtilities.createTestByteBuffer(for: "x")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
        XCTAssertEqual(UInt8(ascii: "x"), buffer.readInteger(as: UInt8.self))

        buffer = TestUtilities.createTestByteBuffer(for: "xy")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
        XCTAssertEqual(UInt8(ascii: "x"), buffer.readInteger(as: UInt8.self))
    }
}

// MARK: - parseNil

extension ParserUnitTests {
    func testNil_valid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "NIL")
        XCTAssertNoThrow(try GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker))
    }

    func testNil_valid_mixedCase() {
        var buffer = TestUtilities.createTestByteBuffer(for: "nIl")
        XCTAssertNoThrow(try GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker))
    }

    func testNil_valid_overcomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "NILL")
        XCTAssertNoThrow(try GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker))
        XCTAssertEqual(buffer.readableBytes, 1)
    }

    func testNil_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "N")
        XCTAssertThrowsError(try GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

    func testNil_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "123")
        XCTAssertThrowsError(try GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testNil_invalid_text() {
        var buffer = TestUtilities.createTestByteBuffer(for: #""NIL""#)
        XCTAssertThrowsError(try GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }
}

// MARK: - nstring parseNString

extension ParserUnitTests {
    func testNString_nil() {
        TestUtilities.withBuffer("NIL", terminator: "\n") { (buffer) in
            let val = try GrammarParser.parseNString(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(val, nil)
        }
    }

    func testNString_nil_mixedCase() {
        TestUtilities.withBuffer("Nil", terminator: "\n") { (buffer) in
            let val = try GrammarParser.parseNString(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(val, nil)
        }
    }

    func testNString_string() {
        TestUtilities.withBuffer("\"abc123\"") { (buffer) in
            let val = try GrammarParser.parseNString(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(val, "abc123")
        }
    }

    func testNString_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "hello world")
        XCTAssertThrowsError(try GrammarParser.parseNString(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - number parseNumber

extension ParserUnitTests {
    func testNumber_valid() {
        TestUtilities.withBuffer("12345", terminator: " ") { (buffer) in
            let num = try GrammarParser.parseNumber(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 12345)
        }
    }

    func testNumber_invalid_empty() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
    }

    func testNumber_invalid_alpha() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abc")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }
}

// MARK: - nz-number parseNZNumber

extension ParserUnitTests {
    func testNZNumber_valid() {
        TestUtilities.withBuffer("12345", terminator: " ") { (buffer) in
            let num = try GrammarParser.parseNumber(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 12345)
        }
    }

    func testNZNumber_valid_midZero() {
        TestUtilities.withBuffer("12045", terminator: " ") { (buffer) in
            let num = try GrammarParser.parseNumber(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 12045)
        }
    }

    func testNZNumber_allZeros() {
        var buffer = TestUtilities.createTestByteBuffer(for: "0000 ")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

    func testNZNumber_startZero() {
        var buffer = TestUtilities.createTestByteBuffer(for: "0123 ")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

    func testNZNumber_invalid_empty() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
    }

    func testNZNumber_invalid_alpha() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abc")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }
}

// MARK: - parsePartialRange

extension ParserUnitTests {
    func testParsePartialRange() {
        let inputs: [(String, String, Partial.Range, UInt)] = [
            ("1", " ", Partial.Range(from: 1, to: nil), #line),
            ("1.2", " ", Partial.Range(from: 1, to: 2), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parsePartialRange)
    }
}

// MARK: - parsePartial

extension ParserUnitTests {
    func testParsePartial() {
        let inputs: [(String, String, Partial, UInt)] = [
            ("<1.2>", " ", .init(left: 1, right: 2), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parsePartial)
    }
}

// MARK: - parseResponseData

extension ParserUnitTests {
    func testParseResponseData() {
        let inputs: [(String, String, ResponsePayload, UInt)] = [
            ("* CAPABILITY ENABLE\r\n", " ", .capabilityData([.enable]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseResponseData)
    }
}

// MARK: - parseResponsePayload

extension ParserUnitTests {
    func testParseResponsePayload() {
        let inputs: [(String, String, ResponsePayload, UInt)] = [
            ("CAPABILITY ENABLE", "\r", .capabilityData([.enable]), #line),
            ("BYE test", "\r\n", .conditionalBye(.init(code: nil, text: "test")), #line),
            ("OK test", "\r\n", .conditionalState(.ok(.init(code: nil, text: "test"))), #line),
            ("1 EXISTS", "\r", .mailboxData(.exists(1)), #line),
            ("2 EXPUNGE", "\r", .messageData(.expunge(2)), #line),
            ("ENABLED ENABLE", "\r", .enableData([.enable]), #line),
            ("ID (\"key\" NIL)", "\r", .id([.init(key: "key", value: nil)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseResponsePayload)
    }
}

// MARK: - parseResponseTextCode

extension ParserUnitTests {
    func testParseResponseTextCode() {
        let inputs: [(String, String, ResponseTextCode, UInt)] = [
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
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseResponseTextCode)
    }
}

// MARK: - parseRFC822

extension ParserUnitTests {
    func testParseRFC822_valid_header() {
        TestUtilities.withBuffer(".HEADER") { (buffer) in
            let rfc = try GrammarParser.parseRFC822(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(rfc, .header)
        }
    }

    func testParseRFC822_valid_size() {
        TestUtilities.withBuffer(".SIZE") { (buffer) in
            let rfc = try GrammarParser.parseRFC822(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(rfc, .size)
        }
    }

    func testParseRFC822_valid_text() {
        TestUtilities.withBuffer(".TEXT") { (buffer) in
            let rfc = try GrammarParser.parseRFC822(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(rfc, .text)
        }
    }
}

// MARK: - search parseSearch

extension ParserUnitTests {
    func testParseSearch() {
        let inputs: [(String, String, Command, UInt)] = [
            ("SEARCH ALL", "\r", .search(returnOptions: [], program: .init(charset: nil, keys: [.all])), #line),
            ("SEARCH ALL DELETED FLAGGED", "\r", .search(returnOptions: [], program: .init(charset: nil, keys: [.all, .deleted, .flagged])), #line),
            ("SEARCH CHARSET UTF-8 ALL", "\r", .search(returnOptions: [], program: .init(charset: "UTF-8", keys: [.all])), #line),
            ("SEARCH RETURN () ALL", "\r", .search(returnOptions: [], program: .init(charset: nil, keys: [.all])), #line),
            ("SEARCH RETURN (MIN) ALL", "\r", .search(returnOptions: [.min], program: .init(charset: nil, keys: [.all])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearch)
    }
}

// MARK: - parseSearchCorrelator

extension ParserUnitTests {
    func testParseSearchCorrelator() {
        let inputs: [(String, String, ByteBuffer, UInt)] = [
            (" (TAG \"test1\")", "\r", "test1", #line),
            (" (tag \"test2\")", "\r", "test2", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchCorrelator)
    }
}

// MARK: - `search-criteria` parseSearchCriteria

extension ParserUnitTests {
    func testParseSearchCriteria() {
        let inputs: [(String, String, [SearchKey], UInt)] = [
            ("ALL", "\r", [.all], #line),
            ("ALL ANSWERED DELETED", "\r", [.all, .answered, .deleted], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchCriteria)
    }
}

// MARK: - `search-key` parseSearchKey

extension ParserUnitTests {
    func testParseSearchKey() {
        let inputs: [(String, String, SearchKey, UInt)] = [
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
            ("ON 25-jun-1994", "\r", .on(Date(day: 25, month: .jun, year: 1994)), #line),
            ("SINCE 01-jan-2001", "\r", .since(Date(day: 1, month: .jan, year: 2001)), #line),
            ("SENTON 02-jan-2002", "\r", .sent(.on(Date(day: 2, month: .jan, year: 2002))), #line),
            ("SENTBEFORE 03-jan-2003", "\r", .sent(.before(Date(day: 3, month: .jan, year: 2003))), #line),
            ("SENTSINCE 04-jan-2004", "\r", .sent(.since(Date(day: 4, month: .jan, year: 2004))), #line),
            ("BEFORE 05-jan-2005", "\r", .before(Date(day: 5, month: .jan, year: 2005)), #line),
            ("LARGER 1234", "\r", .larger(1234), #line),
            ("SMALLER 5678", "\r", .smaller(5678), #line),
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
            ("NOT LARGER 1234", "\r", .not(.larger(1234)), #line),
            ("OR LARGER 6 SMALLER 4", "\r", .or(.larger(6), .smaller(4)), #line),
            ("UID 2:4", "\r", .uid([2 ... 4]), #line),
            ("2:4", "\r", .sequenceSet([2 ... 4]), #line),
            ("(LARGER 1)", "\r", .array([.larger(1)]), #line),
            ("(LARGER 1 SMALLER 5 KEYWORD hello)", "\r", .array([.larger(1), .smaller(5), .keyword(Flag.Keyword("hello"))]), #line),
            ("YOUNGER 34", "\r", .younger(34), #line),
            ("OLDER 45", "\r", .older(45), #line),
            ("FILTER something", "\r", .filter("something"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchKey)
    }

    func testParseSearchKey_array_none_invalid() {
        var buffer = "()" as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseSearchKey(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - `search-modifier-name` parseSearchModifierName

extension ParserUnitTests {
    func testParseSearchModifierName() {
        let inputs: [(String, String, String, UInt)] = [
            ("modifier", " ", "modifier", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchModifierName)
    }
}

// MARK: - `search-modifier-params` parseSearchModifierParams

extension ParserUnitTests {
    func testParseSearchModifierParams() {
        let inputs: [(String, String, TaggedExtensionValue, UInt)] = [
            ("()", "", .comp([]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchModifierParams)
    }
}

// MARK: - `search-program` parseSearchProgram

extension ParserUnitTests {
    func testParseSearchProgram() {
        let inputs: [(String, String, SearchProgram, UInt)] = [
            ("ALL", "\r", .init(charset: nil, keys: [.all]), #line),
            ("ALL ANSWERED DELETED", "\r", .init(charset: nil, keys: [.all, .answered, .deleted]), #line),
            ("CHARSET UTF8 ALL", "\r", .init(charset: "UTF8", keys: [.all]), #line),
            ("CHARSET UTF16 ALL ANSWERED DELETED", "\r", .init(charset: "UTF16", keys: [.all, .answered, .deleted]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchProgram)
    }
}

// MARK: - `search-ret-data-ext` parseSearchReturnDataExtension

extension ParserUnitTests {
    // the spec is ambiguous when parsing `tagged-ext-simple`, in that a "number" is also a "sequence-set"
    // our parser gives priority to "sequence-set"
    func testParseSearchReturnDataExtension() {
        let inputs: [(String, String, SearchReturnDataExtension, UInt)] = [
            ("modifier 64", "\r", .init(modifier: "modifier", returnValue: .simple(.sequence([64]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchReturnDataExtension)
    }
}

// MARK: - `search-ret-data` parseSearchReturnData

extension ParserUnitTests {
    func testParseSearchReturnData() {
        let inputs: [(String, String, SearchReturnData, UInt)] = [
            ("MIN 1", "\r", .min(1), #line),
            ("MAX 2", "\r", .max(2), #line),
            ("ALL 3", "\r", .all([3]), #line),
            ("ALL 3,4,5", "\r", .all([3, 4, 5]), #line),
            ("COUNT 4", "\r", .count(4), #line),
            ("modifier 5", "\r", .dataExtension(.init(modifier: "modifier", returnValue: .simple(.sequence([5])))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchReturnData)
    }
}

// MARK: - `search-ret-opt` parseSearchReturnOption

extension ParserUnitTests {
    func testParseSearchReturnOption() {
        let inputs: [(String, String, SearchReturnOption, UInt)] = [
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
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchReturnOption)
    }
}

// MARK: - `search-ret-opts` parseSearchReturnOptions

extension ParserUnitTests {
    func testParseSearchReturnOptions() {
        let inputs: [(String, String, [SearchReturnOption], UInt)] = [
            (" RETURN (ALL)", "\r", [.all], #line),
            (" RETURN (MIN MAX COUNT)", "\r", [.min, .max, .count], #line),
            (" RETURN (m1 m2)", "\r", [
                .optionExtension(.init(modifierName: "m1", params: nil)),
                .optionExtension(.init(modifierName: "m2", params: nil)),
            ], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchReturnOptions)
    }
}

// MARK: - `search-ret-opt-ext` parseSearchReturnOptionExtension

extension ParserUnitTests {
    func testParseSearchReturnOptionExtension() {
        let inputs: [(String, String, SearchReturnOptionExtension, UInt)] = [
            ("modifier", "\r", .init(modifierName: "modifier", params: nil), #line),
            ("modifier 4", "\r", .init(modifierName: "modifier", params: .simple(.sequence([4]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSearchReturnOptionExtension)
    }
}

// MARK: - parseSection

extension ParserUnitTests {
    func testParseSection_valid_none() {
        TestUtilities.withBuffer("[]") { (buffer) in
            let section = try GrammarParser.parseSection(buffer: &buffer, tracker: .testTracker)
            XCTAssertNil(section)
        }
    }

    func testParseSection_valid_some() {
        TestUtilities.withBuffer("[HEADER]") { (buffer) in
            let section = try GrammarParser.parseSection(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(section, SectionSpec.text(.header))
        }
    }
}

// MARK: - parseSectionBinary

extension ParserUnitTests {
    func testParseSectionBinary() {
        let inputs: [(String, String, [Int], UInt)] = [
            ("[]", "\r", [], #line),
            ("[1]", "\r", [1], #line),
            ("[1.2.3]", "\r", [1, 2, 3], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSectionBinary)
    }
}

// MARK: - parseSectionMessageText

extension ParserUnitTests {
    func testParseSectionMessageText() {
        let inputs: [(String, String, SectionMessageText, UInt)] = [
            ("HEADER", "\r", .header, #line),
            ("TEXT", "\r", .text, #line),
            ("HEADER.FIELDS (test)", "\r", .headerFields(["test"]), #line),
            ("HEADER.FIELDS.NOT (test)", "\r", .notHeaderFields(["test"]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSectionMessageText)
    }
}

// MARK: - parseSectionPart

extension ParserUnitTests {
    func testParseSection_valid_one() {
        TestUtilities.withBuffer("1", terminator: " ") { (buffer) in
            let part = try GrammarParser.parseSectionPart(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(part[0], 1)
        }
    }

    func testParseSection_valid_many() {
        TestUtilities.withBuffer("1.3.5", terminator: " ") { (buffer) in
            let part = try GrammarParser.parseSectionPart(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(part, [1, 3, 5])
        }
    }

    func testParseSection_invalid_none() {
        var buffer = "" as ByteBuffer
        XCTAssertThrowsError(try GrammarParser.parseSectionPart(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
        }
    }
}

// MARK: - parseSectionSpec

extension ParserUnitTests {
    func testParseSectionSpec() {
        let inputs: [(String, String, SectionSpec, UInt)] = [
            ("HEADER", "\r", .text(.header), #line),
            ("1.2.3", "\r", .part([1, 2, 3], text: nil), #line),
            ("1.2.3.HEADER", "\r", .part([1, 2, 3], text: .header), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSectionSpec)
    }
}

// MARK: - parseSectionText

extension ParserUnitTests {
    func testParseSectionText() {
        let inputs: [(String, String, SectionText, UInt)] = [
            ("MIME", " ", .mime, #line),
            ("HEADER", " ", .header, #line),
            ("TEXT", " ", .text, #line),
            ("HEADER.FIELDS (f1)", " ", .headerFields(["f1"]), #line),
            ("HEADER.FIELDS (f1 f2 f3)", " ", .headerFields(["f1", "f2", "f3"]), #line),
            ("HEADER.FIELDS.NOT (f1)", " ", .notHeaderFields(["f1"]), #line),
            ("HEADER.FIELDS.NOT (f1 f2 f3)", " ", .notHeaderFields(["f1", "f2", "f3"]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSectionText)
    }
}

// MARK: - select parseSelect

extension ParserUnitTests {
    func testParseSelect() {
        let inputs: [(String, String, Command, UInt)] = [
            ("SELECT inbox", "\r", .select(.inbox, []), #line),
            ("SELECT inbox (some1)", "\r", .select(.inbox, [.init(name: "some1", value: nil)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSelect)
    }

    func testSelect_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "SELECT ")
        XCTAssertThrowsError(try GrammarParser.parseSelect(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parseSelectParameter

extension ParserUnitTests {
    func testParseSelectParameter() {
        let inputs: [(String, String, SelectParameter, UInt)] = [
            ("test", "\r", .init(name: "test", value: nil), #line),
            ("some 1", "\r", .init(name: "some", value: .simple(.sequence([1]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSelectParameter)
    }
}

// MARK: - parseSelectParameters

extension ParserUnitTests {
    func testParseSelectParameters() {
        let inputs: [(String, String, [SelectParameter], UInt)] = [
            (" (test)", "\r", [.init(name: "test", value: nil)], #line),
            (" (test1 test2 test3)", "\r", [.init(name: "test1", value: nil), .init(name: "test2", value: nil), .init(name: "test3", value: nil)], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSelectParameters)
    }
}

// MARK: - parseSelectParameterName

extension ParserUnitTests {
    func testParseSelectParameterName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", "\r", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSelectParameterName)
    }
}

// MARK: - parseSelectParameterValue

extension ParserUnitTests {
    func testParseSelectParameterValue() {
        let inputs: [(String, String, TaggedExtensionValue, UInt)] = [
            ("1", "\r", .simple(.sequence([1])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSelectParameterValue)
    }
}

// MARK: - seq-number parseSequenceNumber

extension ParserUnitTests {
    func testSequenceNumber_valid_wildcard() {
        TestUtilities.withBuffer("*") { (buffer) in
            let num = try GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, .last)
        }
    }

    func testSequenceNumber_valid_number() {
        TestUtilities.withBuffer("123", terminator: " ") { (buffer) in
            let num = try GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 123)
        }
    }

    func testSequenceNumber_invalid_letters() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abc")
        XCTAssertThrowsError(try GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

    func testSequenceNumber_invalid_nznumber() {
        var buffer = TestUtilities.createTestByteBuffer(for: "0123 ")
        XCTAssertThrowsError(try GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }
}

// MARK: - sequence-set parseSequenceSet

extension ParserUnitTests {
    func testSequenceSet_valid_one() {
        TestUtilities.withBuffer("765", terminator: " ") { (buffer) in
            let set = try GrammarParser.parseSequenceSet(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(set, [765])
        }
    }

    func testSequenceSet_valid_many() {
        TestUtilities.withBuffer("1,2:5,7,9:*", terminator: " ") { (buffer) in
            let set = try GrammarParser.parseSequenceSet(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(set, [1, 2 ... 5, 7, 9...])
        }
    }

    func testSequenceSet_invalid_none() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try GrammarParser.parseSequenceSet(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? ParsingError, ParsingError.incompleteMessage)
        }
    }
}

// MARK: - s-flag parseSFlag

extension ParserUnitTests {
    func testSFlag_valid() {
        TestUtilities.withBuffer("\\unmarked", terminator: " ") { (buffer) in
            let flag = try GrammarParser.parseMailboxListSflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .unmarked)
        }
    }

    func testSFlag_valid_mixedCase() {
        TestUtilities.withBuffer("\\UNMArked", terminator: " ") { (buffer) in
            let flag = try GrammarParser.parseMailboxListSflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .unmarked)
        }
    }

    func testSFlage_invalid_noSlash() {
        var buffer = TestUtilities.createTestByteBuffer(for: "unmarked ")
        XCTAssertThrowsError(try GrammarParser.parseMailboxListSflag(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - status parseStatus

extension ParserUnitTests {
    func testParseStatus() {
        let inputs: [(String, String, Command, UInt)] = [
            ("STATUS inbox (messages unseen)", "\r\n", .status(.inbox, [.messageCount, .unseenCount]), #line),
            ("STATUS Deleted (messages unseen HIGHESTMODSEQ)", "\r\n", .status(MailboxName("Deleted"), [.messageCount, .unseenCount, .highestModificationSequence]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseStatus)
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

// MARK: - status-att-list parseStatusAttributeList

extension ParserUnitTests {
    func testStatusAttributeList_valid_single() {
        TestUtilities.withBuffer("MESSAGES 2", terminator: "\n") { (buffer) in
            let expected = [MailboxValue.messages(2)]
            let parsed = try GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(parsed, expected)
        }
    }

    func testStatusAttributeList_valid_many() {
        TestUtilities.withBuffer("MESSAGES 2 UNSEEN 3 DELETED 4", terminator: "\n") { (buffer) in
            let expected = [
                MailboxValue.messages(2),
                MailboxValue.unseen(3),
                MailboxValue.deleted(4),
            ]
            let parsed = try GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(parsed, expected)
        }
    }

    func testStatusAttributeList_invalid_none() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
        }
    }

    func testStatusAttributeList_invalid_missing_number() {
        var buffer = TestUtilities.createTestByteBuffer(for: "MESSAGES UNSEEN 3 RECENT 4\n")
        XCTAssertThrowsError(try GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testStatusAttributeList_invalid_missing_attribute() {
        var buffer = TestUtilities.createTestByteBuffer(for: "2 UNSEEN 3 RECENT 4\n")
        XCTAssertThrowsError(try GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - parseStore

extension ParserUnitTests {
    func testParseStore() {
        let inputs: [(String, String, Command, UInt)] = [
            ("STORE 1 +FLAGS \\answered", "\r", .store([1], [], .add(silent: false, list: [.answered])), #line),
            ("STORE 1 (label) -FLAGS \\seen", "\r", .store([1], [.init(name: "label", parameters: nil)], .remove(silent: false, list: [.seen])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseStore)
    }
}

// MARK: - parseStoreAttributeFlags

extension ParserUnitTests {
    func testParseStoreAttributeFlags() {
        let inputs: [(String, String, StoreFlags, UInt)] = [
            ("+FLAGS ()", "\r", .add(silent: false, list: []), #line),
            ("-FLAGS ()", "\r", .remove(silent: false, list: []), #line),
            ("FLAGS ()", "\r", .replace(silent: false, list: []), #line),
            ("+FLAGS.SILENT ()", "\r", .add(silent: true, list: []), #line),
            ("+FLAGS.SILENT (\\answered \\seen)", "\r", .add(silent: true, list: [.answered, .seen]), #line),
            ("+FLAGS.SILENT \\answered \\seen", "\r", .add(silent: true, list: [.answered, .seen]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseStoreAttributeFlags)
    }
}

// MARK: - subscribe parseSubscribe

extension ParserUnitTests {
    func testParseSubscribe() {
        let inputs: [(String, String, Command, UInt)] = [
            ("SUBSCRIBE inbox", "\r\n", .subscribe(.inbox), #line),
            ("SUBScribe INBOX", "\r\n", .subscribe(.inbox), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseSubscribe)
    }

    func testSubscribe_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "SUBSCRIBE ")
        XCTAssertThrowsError(try GrammarParser.parseSubscribe(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parseRename

extension ParserUnitTests {
    func testParseRename() {
        let inputs: [(String, String, Command, UInt)] = [
            ("RENAME box1 box2", "\r", .rename(from: .init("box1"), to: .init("box2"), params: []), #line),
            ("rename box3 box4", "\r", .rename(from: .init("box3"), to: .init("box4"), params: []), #line),
            ("RENAME box5 box6 (test)", "\r", .rename(from: .init("box5"), to: .init("box6"), params: [.init(name: "test", value: nil)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseRename)
    }
}

// MARK: - parseStoreModifier

extension ParserUnitTests {
    func testParseStoreModifier() {
        let inputs: [(String, String, StoreModifier, UInt)] = [
            ("name", "\r", .init(name: "name", parameters: nil), #line),
            ("name 1:9", "\r", .init(name: "name", parameters: .simple(.sequence([1 ... 9]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseStoreModifier)
    }
}

// MARK: - parseStoreModifiers

extension ParserUnitTests {
    func testParseStoreModifiers() {
        let inputs: [(String, String, [StoreModifier], UInt)] = [
            (" (name1)", "\r", [.init(name: "name1", parameters: nil)], #line),
            (" (name1 name2 name3)", "\r", [.init(name: "name1", parameters: nil), .init(name: "name2", parameters: nil), .init(name: "name3", parameters: nil)], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseStoreModifiers)
    }
}

// MARK: - parseStoreModifierName

extension ParserUnitTests {
    func testParseStoreModifierName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", "\r", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseStoreModifierName)
    }
}

// MARK: - parseStoreModifierParams

extension ParserUnitTests {
    func testParseStoreModifierParameters() {
        let inputs: [(String, String, TaggedExtensionValue, UInt)] = [
            ("1:9", "\r", .simple(.sequence([1 ... 9])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseStoreModifierParameters)
    }
}

// MARK: - tag parseTag

extension ParserUnitTests {
    func testTag_valid() {
        TestUtilities.withBuffer("abc123", terminator: " ") { (buffer) in
            let tag = try GrammarParser.parseTag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(tag, "abc123")
        }
    }

    func testTag_invalid_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try GrammarParser.parseTag(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
        }
    }

    func testTag_invalid_plus() {
        var buffer = TestUtilities.createTestByteBuffer(for: "+")
        XCTAssertThrowsError(try GrammarParser.parseTag(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - parseTagString

extension ParserUnitTests {
    func testParseTagString() {
        let inputs: [(String, String, ByteBuffer, UInt)] = [
            ("\"test\"", "\r", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseTagString)
    }
}

// MARK: - parseTaggedExtension

extension ParserUnitTests {
    func testParseTaggedExtension() {
        let inputs: [(String, String, TaggedExtension, UInt)] = [
            ("label 1", "\r\n", .init(label: "label", value: .simple(.sequence([1]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseTaggedExtension)
    }
}

// MARK: - tagged-extension-comp parseTaggedExtensionComplex

extension ParserUnitTests {
    func testParseTaggedExtensionComplex() {
        let inputs: [(String, String, [String], UInt)] = [
            ("test", "\r\n", ["test"], #line),
            ("(test)", "\r\n", ["test"], #line),
            ("(test1 test2)", "\r\n", ["test1", "test2"], #line),
            ("test1 test2", "\r\n", ["test1", "test2"], #line),
            ("test1 test2 (test3 test4) test5", "\r\n", ["test1", "test2", "test3", "test4", "test5"], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseTaggedExtensionComplex)
    }
}

// MARK: - parseText

extension ParserUnitTests {
    func testText_empty() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

    func testText_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "hello world!")
        XCTAssertThrowsError(try GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

    func testText_some() {
        TestUtilities.withBuffer("hello world!", terminator: "\r\n") { (buffer) in
            var parsed = try GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(parsed.readString(length: 12)!, "hello world!")
        }
    }

    func testText_CR() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\r")
        XCTAssertThrowsError(try GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testText_LF() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\n")
        XCTAssertThrowsError(try GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }
}

// MARK: - time

extension ParserUnitTests {
    func testDateTime_valid() {
        TestUtilities.withBuffer("12:34:56", terminator: "\r") { (buffer) in
            let time = try GrammarParser.parseTime(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(time, Date.Time(hour: 12, minute: 34, second: 56))
        }
    }

    func testDateTime_invalid_missingSeparator() {
        var buffer = TestUtilities.createTestByteBuffer(for: "123456\r")
        XCTAssertThrowsError(try GrammarParser.parseTime(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testDateTime_invalid_partial() {
        var buffer = TestUtilities.createTestByteBuffer(for: "12:")
        XCTAssertThrowsError(try GrammarParser.parseTime(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
        }
    }
}

// MARK: - parseUID

extension ParserUnitTests {
    func testParseUID() {
        let inputs: [(String, String, Command, UInt)] = [
            ("UID EXPUNGE 1", "\r\n", .uidExpunge([1]), #line),
            ("UID COPY 1 Inbox", "\r\n", .uidCopy([1], .inbox), #line),
            ("UID FETCH 1 FLAGS", "\r\n", .uidFetch([1], FetchType.attributes([.flags]), []), #line),
            ("UID SEARCH CHARSET UTF8 ALL", "\r\n", .uidSearch(returnOptions: [], program: .init(charset: "UTF8", keys: [.all])), #line),
            ("UID STORE 1 +FLAGS (Test)", "\r\n", .uidStore([1], [], .add(silent: false, list: [.keyword(.init("Test"))])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseUid)
    }

    func testParseUID_invalid() {
        var buffer: ByteBuffer = "UID RENAME inbox other\r"
        XCTAssertThrowsError(try GrammarParser.parseUid(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - parseUIDRange

extension ParserUnitTests {
    func testUIDRange() {
        let inputs: [(String, String, UIDRange, UInt)] = [
            ("12:34", "\r\n", .init(left: 12, right: 34), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseUidRange)
    }
}

// MARK: - parseUIDSet

extension ParserUnitTests {
    func testParseUIDSet() {
        let inputs: [(String, String, [UIDSetType], UInt)] = [
            ("1234", "\r\n", [.uniqueID(1234)], #line),
            ("12:34", "\r\n", [.range(UIDRange(left: 12, right: 34))], #line),
            ("1,2,34:56,78:910,11", "\r\n", [
                .uniqueID(1),
                .uniqueID(2),
                .range(UIDRange(left: 34, right: 56)),
                .range(UIDRange(left: 78, right: 910)),
                .uniqueID(11),
            ], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseUidSet)
    }
}

// MARK: - uniqueID parseUniqueID

extension ParserUnitTests {
    // NOTE: Maps to `nz-number`, but let's make sure we didn't break the mapping.

    func testUniqueID_valid() {
        TestUtilities.withBuffer("123", terminator: " ") { (buffer) in
            let num = try GrammarParser.parseUniqueID(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 123)
        }
    }

    func testUniqueID_invalid_zero() {
        var buffer = TestUtilities.createTestByteBuffer(for: "0123 ")
        XCTAssertThrowsError(try GrammarParser.parseUniqueID(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testUniqueID_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "123")
        XCTAssertThrowsError(try GrammarParser.parseUniqueID(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
        }
    }
}

// MARK: - unsubscribe parseUnsubscribe

extension ParserUnitTests {
    func testParseUnsubscribe() {
        let inputs: [(String, String, Command, UInt)] = [
            ("UNSUBSCRIBE inbox", "\r\n", .unsubscribe(.inbox), #line),
            ("UNSUBScribe INBOX", "\r\n", .unsubscribe(.inbox), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseUnsubscribe)
    }

    func testUnsubscribe_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "UNSUBSCRIBE ")
        XCTAssertThrowsError(try GrammarParser.parseUnsubscribe(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parseUserId

extension ParserUnitTests {
    func testParseUserId() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", "\r\n", "test", #line),
            ("{4}\r\ntest", "\r\n", "test", #line),
            ("\"test\"", "\r\n", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseUserId)
    }
}

// MARK: - vendor-token

extension ParserUnitTests {
    func testParseVendorToken() {
        let inputs: [(String, String, String, UInt)] = [
            ("token", "-atom ", "token", #line),
            ("token", " ", "token", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseVendorToken)
    }
}

// MARK: - zone (parseZone)

extension ParserUnitTests {
    func testZone() {
        let inputs: [(String, String, NIOIMAPCore.Date.TimeZone?, UInt)] = [
            ("+1234", " ", Date.TimeZone(1234), #line),
            ("-5678", " ", Date.TimeZone(-5678), #line),
            ("+0000", " ", Date.TimeZone(0), #line),
            ("-0000", " ", Date.TimeZone(0), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parseZone)
    }

    func testZone_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: "+12")
        XCTAssertThrowsError(try GrammarParser.parseZone(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

    func testZone_long() {
        var buffer = TestUtilities.createTestByteBuffer(for: "+12345678\n")
        XCTAssertThrowsError(try GrammarParser.parseZone(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testZone_nonsense() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abc")
        XCTAssertThrowsError(try GrammarParser.parseZone(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }
}

// MARK: - 2DIGIT

extension ParserUnitTests {
    func test2digit() {
        let inputs: [(String, String, Int, UInt)] = [
            ("12", " ", 12, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parse2Digit)
    }

    func test2digit_invalid_long() {
        var buffer = TestUtilities.createTestByteBuffer(for: [UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"), UInt8(ascii: "4"), CR])
        XCTAssertThrowsError(try GrammarParser.parse2Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "\(e)")
        }
    }

    func test2digit_invalid_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: [UInt8(ascii: "1")])
        XCTAssertThrowsError(try GrammarParser.parse2Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
        }
    }

    func test2digit_invalid_data() {
        var buffer = TestUtilities.createTestByteBuffer(for: "ab")
        XCTAssertThrowsError(try GrammarParser.parse2Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - 4DIGIT

extension ParserUnitTests {
    func test4digit() {
        let inputs: [(String, String, Int, UInt)] = [
            ("1234", " ", 1234, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: GrammarParser.parse4Digit)
    }

    func test4digit_invalid_long() {
        var buffer = TestUtilities.createTestByteBuffer(for: Array(UInt8(ascii: "1") ... UInt8(ascii: "7")) + [CR])
        XCTAssertThrowsError(try GrammarParser.parse4Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func test4digit_invalid_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: [UInt8(ascii: "1")])
        XCTAssertThrowsError(try GrammarParser.parse4Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? ParsingError, .incompleteMessage)
        }
    }

    func test4digit_invalid_data() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abcd")
        XCTAssertThrowsError(try GrammarParser.parse4Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}
