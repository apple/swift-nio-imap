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

class GrammarParser_Body_Tests: XCTestCase, _ParserTestHelpers {}

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
            XCTAssertEqual(dsp, BodyStructure.Disposition(kind: "astring", parameters: [.init(field: "f1", value: "v1")]))
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
            XCTAssertEqual(result.parameters, [.init(field: "f1", value: "v1")])
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
                    fields: .init(parameters: [], id: nil, description: nil, encoding: .base64, octetCount: 1),
                    extension: nil
                ),
                #line
            ),
            (
                "\"APPLICATION\" \"multipart/mixed\" NIL \"id\" \"description\" \"7BIT\" 2",
                "\r\n",
                .init(
                    type: .basic(.init(kind: .application, subtype: .mixed)),
                    fields: .init(parameters: [], id: "id", description: "description", encoding: .sevenBit, octetCount: 2),
                    extension: nil
                ),
                #line
            ),
            (
                "\"VIDEO\" \"multipart/related\" (\"f1\" \"v1\") NIL NIL \"8BIT\" 3",
                "\r\n",
                .init(
                    type: .basic(.init(kind: .video, subtype: .related)),
                    fields: .init(parameters: [.init(field: "f1", value: "v1")], id: nil, description: nil, encoding: .eightBit, octetCount: 3),
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
                            body: .singlepart(.init(type: .basic(.init(kind: .image, subtype: .related)), fields: .init(parameters: [], id: nil, description: nil, encoding: .binary, octetCount: 5))),
                            fieldLines: 8
                        )
                    ),
                    fields: .init(parameters: [], id: nil, description: nil, encoding: .base64, octetCount: 4),
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
                    fields: .init(parameters: [], id: nil, description: nil, encoding: .quotedPrintable, octetCount: 1),
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
