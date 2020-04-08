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

import XCTest
import NIO
import NIOTestUtils
@testable import NIOIMAP

extension StackTracker {

    static var testTracker: StackTracker {
        return StackTracker(maximumParserStackDepth: 30)
    }

}

let CR = UInt8(ascii: "\r")
let LF = UInt8(ascii: "\n")
let CRLF = String(decoding: [CR, LF], as: Unicode.UTF8.self)

final class ParserUnitTests: XCTestCase {
    private var channel: EmbeddedChannel!

    override func setUp() {
        XCTAssertNil(self.channel)
        self.channel = EmbeddedChannel(handler: ByteToMessageHandler(NIOIMAP.CommandDecoder(bufferLimit: 80_000)))
    }

    override func tearDown() {
        XCTAssertNotNil(self.channel)
        XCTAssertNoThrow(XCTAssertTrue(try channel.finish().isClean))
        self.channel = nil
    }
    
    func iterateTestInputs<T: Equatable>(_ inputs: [(String, String, T, UInt)], testFunction: (inout ByteBuffer, StackTracker) throws -> T) {
        for (input, terminator, expected, line) in inputs {
            TestUtilities.withBuffer(input, terminator: terminator, line: line) { (buffer) in
                let testValue = try testFunction(&buffer, .testTracker)
                XCTAssertEqual(testValue, expected, line: line)
            }
        }
    }

    // - MARK: ByteToMessageDecoderVerifier tests
    func testBasicDecodes() {
        let inoutPairs: [(String, [NIOIMAP.CommandStream])] = [
            // LOGIN
            (#"tag LOGIN "foo" "bar""#      + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            ("tag LOGIN \"\" {0}\r\n"       + CRLF, [.command(.init("tag", .login("", "")))]),
            (#"tag LOGIN "foo" "bar""#      + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            (#"tag LOGIN foo bar"#          + CRLF, [.command(.init("tag", .login("foo", "bar")))]),
            // RENAME
            (#"tag RENAME "foo" "bar""#         + CRLF, [.command(NIOIMAP.Command("tag", .rename(from: NIOIMAP.Mailbox("foo"), to: NIOIMAP.Mailbox("bar"), params: nil)))]),
            (#"tag RENAME InBoX "inBOX""#       + CRLF, [.command(NIOIMAP.Command("tag", .rename(from: .inbox, to: .inbox, params: nil)))]),
            ("tag RENAME {1}\r\n1 {1}\r\n2"     + CRLF, [.command(NIOIMAP.Command("tag", .rename(from: NIOIMAP.Mailbox("1"), to: NIOIMAP.Mailbox("2"), params: nil)))]),
        ]
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
                decoderFactory: { () -> NIOIMAP.CommandDecoder in
                    return NIOIMAP.CommandDecoder()
            })
        } catch {
            switch error as? ByteToMessageDecoderVerifier.VerificationError<NIOIMAP.CommandStream> {
            case .some(let error):
                for input in error.inputs {
                    print(" input: \(String(decoding: input.readableBytesView, as: Unicode.UTF8.self))")
                }
                switch error.errorCode {
                case .underProduction(let command):
                    print("UNDER PRODUCTION")
                    print(command)
                case .wrongProduction(actual: let actualCommand, expected: let expectedCommand):
                    print("WRONG PRODUCTION")
                    print(actualCommand)
                    print(expectedCommand)
                default:
                    print(error)
                }
            case .none:
                ()
            }
            XCTFail("unhandled error: \(error)")
        }
    }

    // - MARK: Parser unit tests
    func testPreventInfiniteRecursion() {
        var longBuffer = self.channel.allocator.buffer(capacity: 80_000)
        longBuffer.writeString("tag SEARCH (")
        for _ in 0 ..< 3_000 {
            longBuffer.writeString(#"ALL ANSWERED BCC CC ("#)
        }
        for _ in 0 ..< 3_000 {
            longBuffer.writeString(")") // close the recursive brackets 
        }
        longBuffer.writeString(")\r\n")

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { _error in
            guard let error = _error as? NIOIMAP.IMAPDecoderError else {
                XCTFail("\(_error)")
                return
            }
            XCTAssertTrue(error.parserError is TooDeep, "\(error)")
        }
    }

    func testWeNeverAttemptToParseSomethingThatIs80kWithoutANewline() {
        var longBuffer = self.channel.allocator.buffer(capacity: 90_000)
        longBuffer.writeString(String(repeating: "X", count: 80_001))

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { _error in
            guard let error = _error as? NIOIMAP.IMAPDecoderError else {
                XCTFail("\(_error)")
                return
            }
            XCTAssertEqual(error.parserError as? NIOIMAP.ParsingError, .lineTooLong, "\(error)")
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
        
        var parser = NIOIMAP.CommandParser()
        do {
            let c1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c3 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c1, .command(NIOIMAP.Command("1", .noop)))
            XCTAssertEqual(
                c2_1,
                .command(NIOIMAP.Command("2", .append(
                    to: .inbox,
                    firstMessageMetadata: .options(.flagList(nil, dateTime: nil, extensions: []), data: .init(byteCount: 10))
                )))
            )
            XCTAssertEqual(c2_2, .bytes("0123456789"))
            XCTAssertEqual(c3, .command(NIOIMAP.Command("3", .noop)))
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testResponseMessageDataStreaming() {
        
        // command tag FETCH 1:3 (BODY[TEXT] FLAGS)
        let lines = [
            "* OK [CAPABILITY IMAP4rev1] Ready.\r\n",
            "* 1 FETCH (BODY[TEXT] {3}\r\nabc FLAGS (\\seen \\answered))\r\n",
            "* 2 FETCH (FLAGS (\\deleted) BODY[TEXT] {3}\r\ndef)\r\n",
            "* 3 FETCH (BODY[TEXT] {3}\r\nghi)\r\n",
        ]
        var buffer = ByteBuffer(stringLiteral: "")
        buffer.writeString(lines.joined())
        
        var parser = NIOIMAP.ResponseParser()
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .greeting(.auth(.ok(.code(.capability([]), text: "Ready."))))
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .responseBegin(.messageData(.fetch(1)))
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .attributeBegin(.bodySectionText(nil, 3))
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .attributeBytes("abc")
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .simpleAttribute(.dynamic([.seen, .answered]))
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .responseBegin(.messageData(.fetch(2)))
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .simpleAttribute(.dynamic([.deleted]))
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .attributeBegin(.bodySectionText(nil, 3))
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .attributeBytes("def")
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .responseBegin(.messageData(.fetch(3)))
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .attributeBegin(.bodySectionText(nil, 3))
        )
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .attributeBytes("ghi")
        )
//        XCTAssertEqual(buffer.readableBytes, 0)
        // TODO: enable this final check for readable bytes when the framing parser is ready
        
        // this currently fails as there's data left over, the last ")\r\n"
        // this should be fixed with the framing parser
    }
    
    func testIdle() {
        // 1 NOOP
        // 2 IDLE\r\nDONE\r\n
        // 3 NOOP
        var buffer: ByteBuffer = "1 NOOP\r\n2 IDLE\r\nDONE\r\n3 NOOP\r\n"
        
        var parser = NIOIMAP.CommandParser()
        do {
            let c1 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c1, .command(NIOIMAP.Command("1", .noop)))
            XCTAssertEqual(parser.mode, .lines)
            
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c2_1, .command(NIOIMAP.Command("2", .idleStart)))
            XCTAssertEqual(parser.mode, .idle)
            
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c2_2, NIOIMAP.CommandStream.idleDone)
            XCTAssertEqual(parser.mode, .lines)
            
            let c3 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c3, .command(NIOIMAP.Command("3", .noop)))
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
            let address = try NIOIMAP.GrammarParser.parseAddress(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(address.name, "a")
            XCTAssertEqual(address.adl, "b")
            XCTAssertEqual(address.mailbox, "c")
            XCTAssertEqual(address.host, "d")
        }
    }

    func testAddress_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"("a" "b" "c""#)
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseAddress(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

    func testAddress_invalid_missing_brackets() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"("a" "b" "c" "d""# + "\n")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseAddress(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testAddress_invalid_too_few() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"("a" "b" "c")"# + "\n")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseAddress(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - append
extension ParserUnitTests {

    

}

// MARK: - parseAppendUID
extension ParserUnitTests {

    func testParseAppendUID() {
        TestUtilities.withBuffer("12", terminator: " ") { (buffer) in
             let num = try NIOIMAP.GrammarParser.parseAppendUid(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 12)
        }
    }

}

// MARK: - parseAppendData
extension ParserUnitTests {

    func testParseAppendData() {
        let inputs: [(String, String, NIOIMAP.AppendData, UInt)] = [
            ("{123}\r\n", "hello", .init(byteCount: 123), #line),
            ("~{456}\r\n", "hello", .init(byteCount: 456, needs8BitCleanTransport: true), #line),
            ("{0}\r\n", "hello", .init(byteCount: 0), #line),
            ("~{\(Int.max)}\r\n", "hello", .init(byteCount: .max, needs8BitCleanTransport: true), #line),
            ("{123+}\r\n", "hello", .init(byteCount: 123, synchronizing: false), #line),
            ("~{456+}\r\n", "hello", .init(byteCount: 456, needs8BitCleanTransport: true, synchronizing: false), #line),
            ("{0+}\r\n", "hello", .init(byteCount: 0, synchronizing: false), #line),
            ("~{\(Int.max)+}\r\n", "hello", .init(byteCount: .max, needs8BitCleanTransport: true, synchronizing: false), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseAppendData)
    }

    func testNegativeAppendDataDoesNotParse() {
        TestUtilities.withBuffer("{-1}\r\n", shouldRemainUnchanged: true) { buffer in
            XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseAppendData(buffer: &buffer, tracker: .testTracker)) { error in
                XCTAssertNotNil(error as? ParserError)
            }
        }
    }

    func testHugeAppendDataDoesNotParse() {
        let oneAfterMaxInt = "\(UInt(Int.max)+1)"
        TestUtilities.withBuffer("{\(oneAfterMaxInt)}\r\n", shouldRemainUnchanged: true) { buffer in
            XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseAppendData(buffer: &buffer, tracker: .testTracker)) { error in
                XCTAssertNotNil(error as? ParserError)
            }
        }
    }

}

// MARK: - parseAppendDataExtension
extension ParserUnitTests {

    func testParseAppendDataExtension() {
        let inputs: [(String, String, NIOIMAP.TaggedExtension, UInt)] = [
            ("label 1:9", " ", .label("label", value: .simple(.sequence([1...9]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseAppendDataExtension)
    }

}

// MARK: - parseAppendExtension
extension ParserUnitTests {

    func testParseAppendExtension() {
        let inputs: [(String, String, NIOIMAP.AppendExtension, UInt)] = [
            ("name 1:9", " ", .name("name", value: .simple(.sequence([1...9]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseAppendExtension)
    }

}

// MARK: - parseAppendExtensionName
extension ParserUnitTests {

    func testParseAppendExtensionName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", " ", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseAppendExtensionName)
    }

}

// MARK: - parseAppendExtensionValue
extension ParserUnitTests {

    func testParseAppendExtensionValue() {
        let inputs: [(String, String, NIOIMAP.TaggedExtensionValue, UInt)] = [
            ("1:9", " ", .simple(.sequence([1...9])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseAppendExtensionValue)
    }

}


// MARK: - parseAppendMessage
extension ParserUnitTests {

    // NOTE: Spec is ambiguous when parsing `append-data`, which may contain `append-data-ext`, which is the same as `append-ext`, which is inside `append-opts`
    func testParseMessage() {
        let inputs: [(String, String, NIOIMAP.AppendMessage, UInt)] = [
            (
                " (\\Answered) {123}\r\n",
                "test",
                .options(.flagList([.answered], dateTime: nil, extensions: []), data: .init(byteCount: 123)),
                #line
            ),
            (
                " (\\Answered) ~{456}\r\n",
                "test",
                .options(.flagList([.answered], dateTime: nil, extensions: []), data: .init(byteCount: 456, needs8BitCleanTransport: true)),
                #line
            ),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseAppendMessage)
    }

}

// MARK: - parseAppendOptions
extension ParserUnitTests {

    func testParseAppendOptions() {
        let inputs: [(String, String, NIOIMAP.AppendOptions, UInt)] = [
            ("", "\r", .flagList(nil, dateTime: nil, extensions: []), #line),
            (" (\\Answered)", "\r", .flagList([.answered], dateTime: nil, extensions: []), #line),
            (
                " \"25-jun-1994 01:02:03 +0000\"",
                "\r",
                .flagList(nil, dateTime: .date(.day(25, month: .jun, year: 1994), time: .hour(01, minute: 02, second: 03), zone: NIOIMAP.Date.TimeZone(0)!), extensions: []),
                #line
            ),
            (
                " name1 1:2",
                "\r",
                .flagList(nil, dateTime: nil, extensions: [.name("name1", value: .simple(.sequence([1...2])))]),
                #line
            ),
            (
                " name1 1:2 name2 2:3 name3 3:4",
                "\r",
                .flagList(nil, dateTime: nil, extensions: [
                    .name("name1", value: .simple(.sequence([1...2]))),
                    .name("name2", value: .simple(.sequence([2...3]))),
                    .name("name3", value: .simple(.sequence([3...4]))),
                ]),
                #line
            ),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseAppendOptions)
    }

}

// MARK: - atom parseAtom
extension ParserUnitTests {

    func testAtom_valid() {
        TestUtilities.withBuffer("hello", terminator: " ") { (buffer) in
            let atom = try NIOIMAP.GrammarParser.parseAtom(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(atom, "hello")
        }
    }

    func testAtom_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "hello")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseAtom(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

    func testAtom_invalid_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: " ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseAtom(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - parseBase64
extension ParserUnitTests {

    func testParseBase64Terminal_valid_short() {
        TestUtilities.withBuffer("abcd1234", terminator: " ") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseBase64(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, "abcd1234" )
        }
    }

    func testParseBase64Terminal_valid_short_terminal() {
        TestUtilities.withBuffer("abcd1234++==", terminator: " ") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseBase64(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, "abcd1234++==" )
        }
    }
}


// MARK: - parseBodyExtension
extension ParserUnitTests {
 
    func testParseBodyExtension() {
        let inputs: [(String, String, [NIOIMAP.BodyExtensionType], UInt)] = [
            ("1", "\r", [.number(1)], #line),
            ("\"s\"", "\r", [.string("s")], #line),
            ("(1)", "\r", [.number(1)], #line),
            ("(1 \"2\" 3)", "\r", [.number(1), .string("2"), .number(3)], #line),
            ("(1 2 3 (4 (5 (6))))", "\r", [.number(1), .number(2), .number(3), .number(4), .number(5), .number(6)], #line),
            ("(((((1)))))", "\r", [.number(1)], #line), // yeh, this is valid, don't ask
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseBodyExtension)
    }
    
}

// MARK: - parseBodyFieldDsp
extension ParserUnitTests {

    func testParseBodyFieldDsp_some() {
        TestUtilities.withBuffer(#"("astring" ("f1" "v1"))"#) { (buffer) in
            let dsp = try NIOIMAP.GrammarParser.parseBodyFieldDsp(buffer: &buffer, tracker: .testTracker)
            XCTAssertNotNil(dsp)
            XCTAssertEqual(dsp, NIOIMAP.Body.FieldDSPData(string: "astring", parameter: [.field("f1", value: "v1")]))
        }
    }

    func testParseBodyFieldDsp_none() {
        TestUtilities.withBuffer(#"NIL"#, terminator: "") { (buffer) in
            let string = try NIOIMAP.GrammarParser.parseBodyFieldDsp(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(string, .none)
        }
    }

}

// MARK: - parseBodyFieldEncoding
extension ParserUnitTests {
    
    func testParseBodyFieldEncoding() {
        let inputs: [(String, String, NIOIMAP.Body.FieldEncoding, UInt)] = [
            (#""BASE64""#, " ", .base64, #line),
            (#""BINARY""#, " ", .binary, #line),
            (#""7BIT""#, " ", .bit7, #line),
            (#""8BIT""#, " ", .bit8, #line),
            (#""QUOTED-PRINTABLE""#, " ", .quotedPrintable, #line),
            (#""other""#, " ", .string("other"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseBodyFieldEncoding)
    }

    func testParseBodyFieldEncoding_invalid_missingQuotes() {
        var buffer = TestUtilities.createTestByteBuffer(for: "other")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseBodyFieldEncoding(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - parseBodyFieldLanguage
extension ParserUnitTests {

    func testParseBodyFieldLanguage() {
        let inputs: [(String, String, NIOIMAP.Body.FieldLanguage, UInt)] = [
            (#""english""#, " ", .single("english"), #line),
            (#"("english")"#, " ", .multiple(["english"]), #line),
            (#"("english" "french")"#, " ", .multiple(["english", "french"]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseBodyFieldLanguage)
    }

}

// MARK: - parseBodyFieldLines
extension ParserUnitTests {

    func testBodyFieldLines() {
        TestUtilities.withBuffer("12", terminator: " ") { (buffer) in
             let num = try NIOIMAP.GrammarParser.parseBodyFieldLines(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 12)
        }
    }

}

// MARK: - parseBodyFieldParam
extension ParserUnitTests {
    
    func testParseBodyFieldParam() {
        let inputs: [(String, String, [NIOIMAP.FieldParameterPair], UInt)] = [
            (#"NIL"#, " ", [], #line),
            (#"("f1" "v1")"#, " ", [.field("f1", value: "v1")], #line),
            (#"("f1" "v1" "f2" "v2")"#, " ", [.field("f1", value: "v1"), .field("f2", value: "v2")], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseBodyFieldParam)
    }

    func testParseBodyFieldParam_invalid_oneObject() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"("p1" "#)
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseBodyFieldParam(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

}

// MARK: - parseBodyFields
extension ParserUnitTests {

    func testParseBodyFields_valid() {
        TestUtilities.withBuffer(#"("f1" "v1") "id" "desc" "8BIT" 1234"#, terminator: " ") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseBodyFields(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.parameter, [.field("f1", value: "v1")])
            XCTAssertEqual(result.id, "id")
            XCTAssertEqual(result.description, "desc")
            XCTAssertEqual(result.encoding, .bit8)
            XCTAssertEqual(result.octets, 1234)
        }
    }

}

// MARK: - parseBodyTypeBasic
extension ParserUnitTests {

    func testParseBodyBasic_valid() {
        TestUtilities.withBuffer(#""APPLICATION" "something" ("f1" "v1") "id" "desc" "8BIT" 1234"#, terminator: " ") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseBodyTypeBasic(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.media.type, .application)
            XCTAssertEqual(result.media.subtype, "something")
            XCTAssertEqual(result.fields.parameter, [.field("f1", value: "v1")])
            XCTAssertEqual(result.fields.id, "id")
            XCTAssertEqual(result.fields.description, "desc")
            XCTAssertEqual(result.fields.encoding, .bit8)
            XCTAssertEqual(result.fields.octets, 1234)
        }
    }
}

// MARK: - capability parseCapability
extension ParserUnitTests {
    
    func testParseCapability() {
        let inputs: [(String, String, NIOIMAP.Capability, UInt)] = [
            ("CONDSTORE", " ", .condStore, #line),
            ("ENABLE", " ", .enable, #line),
            ("AUTH=some", " ", .auth("some"), #line),
            ("other", " ", .other("other"), #line),
            ("MOVE", " ", .move, #line),
            ("FILTERS", " ", .filters, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCapability)
    }

    func testCapability_invalid_empty() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? NIOIMAP.ParsingError, NIOIMAP.ParsingError.incompleteMessage)
        }
    }

}

// MARK: - capability parseCapabilityData
extension ParserUnitTests {
    
    func testParseCapabilityData() {
        let inputs: [(String, String, [NIOIMAP.Capability], UInt)] = [
            ("CAPABILITY", "\r", [], #line),
            ("CAPABILITY IMAP4 IMAP4rev1", "\r", [], #line),
            ("CAPABILITY IMAP4 IMAP4rev1 IMAP4 IMAP4rev1", "\r", [], #line),
            ("CAPABILITY FILTERS IMAP4", "\r", [.filters], #line),
            ("CAPABILITY FILTERS IMAP4rev1 ENABLE IMAP4", "\r", [.filters, .enable], #line),
            ("CAPABILITY FILTERS IMAP4rev1 ENABLE IMAP4 IMAP4 IMAP4 IMAP4 IMAP4", "\r", [.filters, .enable], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCapabilityData)
    }

}

// MARK: - parseCharset
extension ParserUnitTests {

    func testParseCharset() {
        let inputs: [(String, String, String, UInt)] = [
            ("UTF8", " ", "UTF8", #line),
            ("\"UTF8\"", " ", "UTF8", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCharset)
    }

}

// MARK: - parseChildMailboxFlag
extension ParserUnitTests {

    func testParseChildMailboxFlag() {
        let inputs: [(String, String, NIOIMAP.ChildMailboxFlag, UInt)] = [
            ("\\HasChildren", " ", .HasChildren, #line),
            ("\\haschildren", " ", .HasChildren, #line),
            ("\\HASCHILDREN", " ", .HasChildren, #line),
            ("\\HasNoChildren", " ", .HasNoChildren, #line),
            ("\\hasnochildren", " ", .HasNoChildren, #line),
            ("\\HASNOCHILDREN", " ", .HasNoChildren, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseChildMailboxFlag)
    }

}

// MARK: - parseContinueRequest
extension ParserUnitTests {

    func testParseContinueRequest() {
        let inputs: [(String, String, NIOIMAP.ContinueRequest, UInt)] = [
            ("+ OK\r\n", " ", .responseText(.code(nil, text: "OK")), #line),
            ("+ abc=\r\n", " ", .base64("abc="), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseContinueRequest)
    }

}

// MARK: - create parseCreate
extension ParserUnitTests {
    
    func testParseCreate() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("CREATE inbox", "\r", .create(.inbox, nil), #line),
            ("CREATE inbox (some)", "\r", .create(.inbox, [.name("some", value: nil)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCreate)
    }


    func testCreate_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "CREATE ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseCreate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

}

// MARK: - parseCommand
extension ParserUnitTests {

    func testParseCommand_valid_any() {
        TestUtilities.withBuffer("a1 NOOP", terminator: "\r\n") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.type, .noop)
        }
    }

    func testParseCommand_valid_auth() {
        TestUtilities.withBuffer("a1 CREATE \"mailbox\"", terminator: "\r\n") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.type, .create(NIOIMAP.Mailbox("mailbox"), nil))
        }
    }

    func testParseCommand_valid_nonauth() {
        TestUtilities.withBuffer("a1 STARTTLS", terminator: "\r\n") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.type, .starttls)
        }
    }

    func testParseCommand_valid_select() {
        TestUtilities.withBuffer("a1 CHECK", terminator: "\r\n") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.type, .check)
        }
    }

}

// MARK: - CommandType parseCommandAny
extension ParserUnitTests {
    
    func testParseCommandAny() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("CAPABILITY", " ", .capability, #line),
            ("LOGOUT", " ", .logout, #line),
            ("NOOP", " ", .noop, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCommandAny)
    }

    func testParseCommandAny_valid_xcommand() {
        TestUtilities.withBuffer("XHELLO", terminator: " ") { (buffer) in
            let commandType = try NIOIMAP.GrammarParser.parseCommandAny(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(commandType, .xcommand("HELLO"))
        }
    }

}

// MARK: - CommandType parseCommandNonAuth
extension ParserUnitTests {

    func testParseCommandNonAuth_valid_login() {
        TestUtilities.withBuffer("LOGIN david evans", terminator: " \r\n") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseCommandNonauth(buffer: &buffer, tracker: .testTracker)
            guard case .login(let username, let password) = result else {
                XCTFail("Case mixup \(result)")
                return
            }
            XCTAssertEqual(username, "david")
            XCTAssertEqual(password, "evans")
        }
    }

    func testParseCommandNonAuth_valid_authenticate() {
        TestUtilities.withBuffer("AUTHENTICATE some", terminator: "\r\n111=") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseCommandNonauth(buffer: &buffer, tracker: .testTracker)
            guard case .authenticate(let type, let initial, _) = result else {
                XCTFail("Case mixup \(result)")
                return
            }
            XCTAssertNil(initial)
            XCTAssertEqual(type, "some")
            
            // temporarily disable this check as the spec is unclear
//            XCTAssertEqual(dataArray, ["111=" ])
        }
    }

    func testParseCommandNonAuth_valid_starttls() {
        TestUtilities.withBuffer("STARTTLS", terminator: "\r\n") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseCommandNonauth(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, .starttls)
        }
    }
}

// MARK: - CommandType parseCommandAuth
extension ParserUnitTests {

    func testParseCommandAuth() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("LSUB inbox someList", " ", .lsub(.inbox, "someList"), #line),
            ("CREATE inbox (something)", " ", .create(.inbox, [.name("something", value: nil)]), #line),
            ("NAMESPACE", " ", .namespace, #line)
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCommandAuth)
    }
    
}

// MARK: - CommandType parseCommandSelect
extension ParserUnitTests {
    
    func testParseCommandSelect() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("UNSELECT", " ", .unselect, #line),
            ("unselect", " ", .unselect, #line),
            ("UNSelect", " ", .unselect, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCommandSelect)
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
                XCTAssertNoThrow(try NIOIMAP.GrammarParser.parseConditionalStoreParameter(buffer: &buffer, tracker: .testTracker), line: line)
            }
        }
    }
    
}

// MARK: - copy parseCopy
extension ParserUnitTests {

    func testCopy_valid() {
        TestUtilities.withBuffer("COPY 1,2,3 inbox", terminator: " ") { (buffer) in
            let copy = try NIOIMAP.GrammarParser.parseCopy(buffer: &buffer, tracker: .testTracker)
            let expectedSequence: [NIOIMAP.SequenceRange] = [1, 2, 3]
            let expectedMailbox = NIOIMAP.Mailbox.inbox
            XCTAssertEqual(copy, NIOIMAP.CommandType.copy(expectedSequence, expectedMailbox))
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
        let inputs: [(String, String, NIOIMAP.CreateParameter, UInt)] = [
            ("test", "\r", .name("test", value: nil), #line),
            ("some 1", "\r", .name("some", value: .simple(.sequence([1]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCreateParameter)
    }
    
}

// MARK: - parseCreateParameter
extension ParserUnitTests {
    
    func testParseCreateParameters() {
        let inputs: [(String, String, [NIOIMAP.CreateParameter], UInt)] = [
            (" (test)", "\r", [.name("test", value: nil)], #line),
            (" (test1 test2 test3)", "\r", [.name("test1", value: nil), .name("test2", value: nil), .name("test3", value: nil)], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCreateParameters)
    }
    
}

// MARK: - parseCreateParameterName
extension ParserUnitTests {
    
    func testParseCreateParameterName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", "\r", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCreateParameterName)
    }
    
}

// MARK: - parseCreateParameterValue
extension ParserUnitTests {
    
    func testParseCreateParameterValue() {
        let inputs: [(String, String, NIOIMAP.TaggedExtensionValue, UInt)] = [
            ("1", "\r", .simple(.sequence([1])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseCreateParameterValue)
    }
    
}

// MARK: - date
extension ParserUnitTests {

    func testDate_valid_plain() {
        TestUtilities.withBuffer("25-Jun-1994", terminator: " ") { (buffer) in
            let day = try NIOIMAP.GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, NIOIMAP.Date(day: 25, month: .jun, year: 1994))
        }
    }

    func testDate_valid_quoted() {
        TestUtilities.withBuffer("\"25-Jun-1994\"") { (buffer) in
            let day = try NIOIMAP.GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, NIOIMAP.Date(day: 25, month: .jun, year: 1994))
        }
    }

    func testDate_invalid_quoted_missing_end_quote() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"25-Jun-1994 ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testDate_invalid_quoted_missing_date() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"\"")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDate(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - date-day
extension ParserUnitTests {

    func testDateDay_valid_single() {
        TestUtilities.withBuffer("1", terminator: "\r") { (buffer) in
            let day = try NIOIMAP.GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, 1)
        }
    }

    func testDateDay_valid_double() {
        TestUtilities.withBuffer("12", terminator: "\r") { (buffer) in
            let day = try NIOIMAP.GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, 12)
        }
    }

    func testDateDay_valid_single_followon() {
        TestUtilities.withBuffer("1", terminator: "a") { (buffer) in
            let day = try NIOIMAP.GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, 1)
        }
    }

    func testDateDay_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "a")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testDateDay_invalid_long() {
        var buffer = TestUtilities.createTestByteBuffer(for: "1234 ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDateDay(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - date-month
extension ParserUnitTests {

    func testDateMonth_valid() {
        TestUtilities.withBuffer("jun", terminator: " ") { (buffer) in
            let day = try NIOIMAP.GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, .jun)
        }
    }

    func testDateMonth_valid_mixedCase() {
        TestUtilities.withBuffer("JUn", terminator: " ") { (buffer) in
            let day = try NIOIMAP.GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, .jun)
        }
    }

    func testDateMonth_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "ju")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

    func testDateMonth_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "aaa ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDateMonth(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - date-text
extension ParserUnitTests {

    func testDateText_valid() {
        TestUtilities.withBuffer("25-Jun-1994", terminator: " ") { (buffer) in
            let day = try NIOIMAP.GrammarParser.parseDateText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(day, NIOIMAP.Date(day: 25, month: .jun, year: 1994))
        }
    }

    func testDateText_invalid_missing_year() {
        var buffer = TestUtilities.createTestByteBuffer(for: "25-Jun-")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDateText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

}

// MARK: - date-time parseDateTime
extension ParserUnitTests {

    // NOTE: Only a few sample failure cases tested, more will be handled by the `ByteToMessageDecoder`

    func testParseDateTime_valid() {
        TestUtilities.withBuffer(#""25-Jun-1994 01:02:03 +1020""#) { (buffer) in
            let dateTime = try NIOIMAP.GrammarParser.parseDateTime(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(dateTime.date, NIOIMAP.Date(day: 25, month: .jun, year: 1994))
            XCTAssertEqual(dateTime.time, NIOIMAP.Date.Time(hour: 01, minute: 02, second: 03))
            XCTAssertEqual(dateTime.zone, NIOIMAP.Date.TimeZone(1020)!)
        }
    }

    func testParseDateTime__invalid_incomplete() {
        var buffer = #""25-Jun-1994 01"# as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDateTime(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? NIOIMAP.ParsingError, NIOIMAP.ParsingError.incompleteMessage)
        }
    }

    func testParseDateTime__invalid_missing_space() {
        var buffer = #""25-Jun-199401:02:03+1020""# as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDateTime(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

}

// MARK: - delete parseDelete
extension ParserUnitTests {

    func testDelete_valid() {
        TestUtilities.withBuffer("DELETE inbox", terminator: "\n") { (buffer) in
            let commandType = try NIOIMAP.GrammarParser.parseDelete(buffer: &buffer, tracker: .testTracker)
            guard case NIOIMAP.CommandType.delete(let mailbox) = commandType else {
                XCTFail("Didn't parse delete")
                return
            }
            XCTAssertEqual(mailbox, NIOIMAP.Mailbox("inbox"))
        }
    }

    func testDelete_valid_mixedCase() {
        TestUtilities.withBuffer("DELete inbox", terminator: "\n") { (buffer) in
            let commandType = try NIOIMAP.GrammarParser.parseDelete(buffer: &buffer, tracker: .testTracker)
            guard case NIOIMAP.CommandType.delete(let mailbox) = commandType else {
                XCTFail("Didn't parse delete")
                return
            }
            XCTAssertEqual(mailbox, NIOIMAP.Mailbox("inbox"))
        }
    }

    func testDelete_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "DELETE ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseDelete(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

}

// MARK: - enable-data parseEnableData
extension ParserUnitTests {
 
    func testParseEnableData() {
        let inputs: [(String, String, [NIOIMAP.Capability], UInt)] = [
            ("ENABLED", "\r", [], #line),
            ("ENABLED ENABLE", "\r", [.enable], #line),
            ("ENABLED ENABLE CONDSTORE", "\r", [.enable, .condStore], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseEnableData)
    }
    
}

// MARK: - parseEItemStandardTag
extension ParserUnitTests {

    func testParseEItemStandardTag() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", " ", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseEitemStandardTag)
    }

}

// MARK: - parseEItemVendorTag
extension ParserUnitTests {

    func testParseEItemVendorTag() {
        let inputs: [(String, String, NIOIMAP.EItemVendorTag, UInt)] = [
            ("token-atom", " ", NIOIMAP.EItemVendorTag(token: "token", atom: "atom"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseEitemVendorTag)
    }

}

// MARK: - entry-type-resp parseEntryTypeResponse
extension ParserUnitTests {
    
    func testParseEntryTypeRequest() {
        let inputs: [(String, String, NIOIMAP.EntryTypeRequest, UInt)] = [
            ("all", " ", .all, #line),
            ("ALL", " ", .all, #line),
            ("aLL", " ", .all, #line),
            ("shared", " ", .response(.shared), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseEntryTypeRequest)
    }
    
}

// MARK: - entry-type-resp parseEntryTypeResponse
extension ParserUnitTests {
    
    func testParseEntryTypeResponse() {
        let inputs: [(String, String, NIOIMAP.EntryTypeResponse, UInt)] = [
            ("priv", " ", .private, #line),
            ("PRIV", " ", .private, #line),
            ("prIV", " ", .private, #line),
            ("shared", " ", .shared, #line),
            ("SHARED", " ", .shared, #line),
            ("shaRED", " ", .shared, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseEntryTypeResponse)
    }
    
}

// MARK: - parseEnvelope
extension ParserUnitTests {

    func testParseEnvelopeTo_valid() {
        TestUtilities.withBuffer(#"("date" "subject" (("name1" "adl1" "mailbox1" "host1")) (("name2" "adl2" "mailbox2" "host2")) (("name3" "adl3" "mailbox3" "host3")) (("name4" "adl4" "mailbox4" "host4")) (("name5" "adl5" "mailbox5" "host5")) (("name6" "adl6" "mailbox6" "host6")) "someone" "messageid")"#) { (buffer) in
            let envelope = try NIOIMAP.GrammarParser.parseEnvelope(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(envelope.date, "date")
            XCTAssertEqual(envelope.subject, "subject")
            XCTAssertEqual(envelope.from, [.name("name1", adl: "adl1", mailbox: "mailbox1", host: "host1")])
            XCTAssertEqual(envelope.sender, [.name("name2", adl: "adl2", mailbox: "mailbox2", host: "host2")])
            XCTAssertEqual(envelope.reply, [.name("name3", adl: "adl3", mailbox: "mailbox3", host: "host3")])
            XCTAssertEqual(envelope.to, [.name("name4", adl: "adl4", mailbox: "mailbox4", host: "host4")])
            XCTAssertEqual(envelope.cc, [.name("name5", adl: "adl5", mailbox: "mailbox5", host: "host5")])
            XCTAssertEqual(envelope.bcc, [.name("name6", adl: "adl6", mailbox: "mailbox6", host: "host6")])
            XCTAssertEqual(envelope.inReplyTo, "someone")
            XCTAssertEqual(envelope.messageID, "messageid")
        }
    }

}

// MARK: - parseEsearchResponse
extension ParserUnitTests {

    func testParseEsearchResponse() {
        let inputs: [(String, String, NIOIMAP.ESearchResponse, UInt)] = [
            ("ESEARCH", "\r", .correlator(nil, uid: false, returnData: []), #line),
            ("ESEARCH UID", "\r", .correlator(nil, uid: true, returnData: []), #line),
            ("ESEARCH (TAG \"col\") UID", "\r", .correlator("col", uid: true, returnData: []), #line),
            ("ESEARCH (TAG \"col\") UID COUNT 2", "\r", .correlator("col", uid: true, returnData: [.count(2)]), #line),
            ("ESEARCH (TAG \"col\") UID MIN 1 MAX 2", "\r", .correlator("col", uid: true, returnData: [.min(1), .max(2)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseEsearchResponse)
    }

}

// MARK: - examine parseExamine
extension ParserUnitTests {

    func testParseExamine() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("EXAMINE inbox", "\r", .examine(.inbox, nil), #line),
            ("examine inbox", "\r", .examine(.inbox, nil), #line),
            ("EXAMINE inbox (number)", "\r", .examine(.inbox, [.name("number", value: nil)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseExamine)
    }

    func testExamine_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "EXAMINE ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseExamine(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

}

// MARK: - parseFetch
extension ParserUnitTests {
    
    func testParseFetch() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("FETCH 1:3 ALL", "\r", .fetch([1...3], .all, nil), #line),
            ("FETCH 2:4 FULL", "\r", .fetch([2...4], .full, nil), #line),
            ("FETCH 3:5 FAST", "\r", .fetch([3...5], .fast, nil), #line),
            ("FETCH 4:6 ENVELOPE", "\r", .fetch([4...6], .attributes([.envelope]), nil), #line),
            ("FETCH 5:7 (ENVELOPE FLAGS)", "\r", .fetch([5...7], .attributes([.envelope, .flags]), nil), #line),
            ("FETCH 3:5 FAST (name)", "\r", .fetch([3...5], .fast, [.name("name", value: nil)]), #line),
            ("FETCH 1 BODY[TEXT]", "\r", .fetch([1], .attributes([.bodySection(.text(.text), nil)]), nil), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseFetch)
    }

}

// MARK: - parseFetchAttribute
extension ParserUnitTests {
    
    func testParseFetchAttribute() {
        let inputs: [(String, String, NIOIMAP.FetchAttribute, UInt)] = [
            ("ENVELOPE", " ", .envelope, #line),
            ("FLAGS", " ", .flags, #line),
            ("INTERNALDATE", " ", .internaldate, #line),
            ("RFC822.HEADER", " ", .rfc822(.header), #line),
            ("RFC822", " ", .rfc822(nil), #line),
            ("BODY", " ", .body(structure: false), #line),
            ("BODYSTRUCTURE", " ", .body(structure: true), #line),
            ("UID", " ", .uid, #line),
            ("BODY[1]<1.2>", " ", .bodySection(.part([1], text: nil), NIOIMAP.Partial(left: 1, right: 2)), #line),
            ("BODY[1.TEXT]", " ", .bodySection(.part([1], text: .message(.text)), nil), #line),
            ("BODY[4.2.TEXT]", " ", .bodySection(.part([4, 2], text: .message(.text)), nil), #line),
            ("BODY[HEADER]", " ", .bodySection(.text(.header), nil), #line),
            ("BODY.PEEK[HEADER]<3.4>", " ", .bodyPeekSection(.text(.header), NIOIMAP.Partial(left: 3, right: 4)), #line),
            ("BODY.PEEK[HEADER]", " ", .bodyPeekSection(.text(.header), nil), #line),
            ("BINARY.PEEK[1]", " ", .binary(peek: true, section: [1], partial: nil), #line),
            ("BINARY.PEEK[1]<3.4>", " ", .binary(peek: true, section: [1], partial: .init(left: 3, right: 4)), #line),
            ("BINARY[2]<4.5>", " ", .binary(peek: false, section: [2], partial: .init(left: 4, right: 5)), #line),
            ("BINARY.SIZE[5]", " ", .binarySize(section: [5]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseFetchAttribute)
    }

}

// MARK: - parseFetchModifier
extension ParserUnitTests {
    
    func testParseFetchModifier() {
        let inputs: [(String, String, NIOIMAP.FetchModifier, UInt)] = [
            ("test", "\r", .name("test", value: nil), #line),
            ("some 1", "\r", .name("some", value: .simple(.sequence([1]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseFetchModifier)
    }
    
}

// MARK: - parseFetchModifiers
extension ParserUnitTests {
    
    func testParseFetchModifiers() {
        let inputs: [(String, String, [NIOIMAP.FetchModifier], UInt)] = [
            (" (test)", "\r", [.name("test", value: nil)], #line),
            (" (test1 test2 test3)", "\r", [.name("test1", value: nil), .name("test2", value: nil), .name("test3", value: nil)], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseFetchModifiers)
    }
    
}

// MARK: - parseFetchModifierName
extension ParserUnitTests {
    
    func testParseFetchModifierName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", "\r", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseFetchModifierName)
    }
    
}

// MARK: - parseFetchModifierParameter
extension ParserUnitTests {
    
    func testParseFetchModifierParameter() {
        let inputs: [(String, String, NIOIMAP.TaggedExtensionValue, UInt)] = [
            ("1", "\r", .simple(.sequence([1])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseFetchModifierParameter)
    }
    
}

// MARK: - filter-name parseFilterName
extension ParserUnitTests {

    func testParseFilterName() {

        let inputs: [(String, String, String, UInt)] = [
            ("a", " ", "a", #line),
            ("abcdefg", " ", "abcdefg", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseFilterName)
    }

}

// MARK: - parseFlag
extension ParserUnitTests {
    
    func testParseFlag() {
        let inputs: [(String, String, NIOIMAP.Flag, UInt)] = [
            ("\\answered", " ", .answered, #line),
            ("\\flagged", " ", .flagged, #line),
            ("\\deleted", " ", .deleted, #line),
            ("\\seen", " ", .seen, #line),
            ("\\draft", " ", .draft, #line),
            ("keyword", " ", .keyword("keyword"), #line),
            ("\\extension", " ", .extension("extension"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseFlag)
    }

}

// MARK: - parseFlagExtension
extension ParserUnitTests {

    func testParseFlagExtension_valid() {
        TestUtilities.withBuffer("\\Something", terminator: " ") { (buffer) in
            let flagExtension = try NIOIMAP.GrammarParser.parseFlagExtension(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flagExtension, "Something")
        }
    }

    func testParseFlagExtension_invalid_noSlash() {
        var buffer = "Something " as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseFlagExtension(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - parseFlagKeyword
extension ParserUnitTests {

    func testParseFlagKeyword_valid() {
        TestUtilities.withBuffer("keyword", terminator: " ") { (buffer) in
            let flagExtension = try NIOIMAP.GrammarParser.parseFlagKeyword(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flagExtension, "keyword")
        }
    }

}

// MARK: - parseHeaderList
extension ParserUnitTests {

    func testHeaderList_valid_one() {
        TestUtilities.withBuffer(#"("field")"#) { (buffer) in
            let array = try NIOIMAP.GrammarParser.parseHeaderList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(array[0], "field")
        }
    }

    func testHeaderList_valid_many() {
        TestUtilities.withBuffer(#"("first" "second" "third")"#) { (buffer) in
            let array = try NIOIMAP.GrammarParser.parseHeaderList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(array[0], "first")
            XCTAssertEqual(array[1], "second")
            XCTAssertEqual(array[2], "third")
        }
    }

    func testHeaderList_invalid_none() {
        var buffer = #"()"# as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseHeaderList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - id (parseID, parseIDResponse, parseIDParamsList)
extension ParserUnitTests {
    
    func testParseIDParamsList() {
        let inputs: [(String, String, [NIOIMAP.IDParamsListElement]?, UInt)] = [
            ("NIL", " ", nil, #line),
            (#"("key1" "value1")"#, "" , [.key("key1", value: "value1")], #line),
            (
                #"("key1" "value1" "key2" "value2" "key3" "value3")"#,
                "",
                [
                    .key("key1", value: "value1"),
                    .key("key2", value: "value2"),
                    .key("key3", value: "value3")
                ],
                #line
            )
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseIDParamsList)
    }
    
}

// MARK: - parseList
extension ParserUnitTests {
    
    func testParseList() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            (#"LIST "" """#, "\r", .list(nil, NIOIMAP.Mailbox(""), .mailbox(""), []), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseList)
    }

}

// MARK: - list-wildcard parseListWildcard
extension ParserUnitTests {

    func testWildcard() {
        let valid: Set<UInt8> = [UInt8(ascii: "%"), UInt8(ascii: "*")]
        let invalid: Set<UInt8> = Set(UInt8.min...UInt8.max).subtracting(valid)

        for v in valid {
            var buffer = TestUtilities.createTestByteBuffer(for: [v])
            do {
                let str = try NIOIMAP.GrammarParser.parseListWildcards(buffer: &buffer, tracker: .testTracker)
                XCTAssertEqual(str[str.startIndex], Character(Unicode.Scalar(v)))
            } catch {
                XCTFail("\(v) doesn't satisfy \(error)")
                return
            }
        }
        for v in invalid {
            var buffer = TestUtilities.createTestByteBuffer(for: [v])
            XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseListWildcards(buffer: &buffer, tracker: .testTracker)) { e in
                XCTAssertTrue(e is ParserError)
            }
        }
    }

}

// MARK: - parseMailboxData
extension ParserUnitTests {
    
    func testParseMailboxData() {
        let inputs: [(String, String, NIOIMAP.Mailbox.Data, UInt)] = [
            ("FLAGS (\\seen \\draft)", " ", .flags([.seen, .draft]), #line),
            (
                "LIST (\\oflag1 \\oflag2) NIL inbox",
                "\r\n",
                .list(.flags(.oFlags([.other("oflag1"), .other("oflag2")], sFlag: nil), char: nil, mailbox: .inbox, listExtended: nil)),
                #line
            ),
            ("ESEARCH MIN 1 MAX 2", "\r\n", .search(.correlator(nil, uid: false, returnData: [.min(1), .max(2)])), #line),
            ("1234 EXISTS", "\r\n", .exists(1234), #line),
            ("5678 RECENT", "\r\n", .exists(5678), #line),
            ("STATUS INBOX ()", "\r\n", .status(.inbox, nil), #line),
            ("STATUS INBOX (MESSAGES 2)", "\r\n", .status(.inbox, [.messages(2)]), #line),
            (
                "LSUB (\\seen \\draft) NIL inbox",
                "\r\n",
                .lsub(.flags(.oFlags([.other("seen"), .other("draft")], sFlag: nil), char: nil, mailbox: .inbox, listExtended: nil)),
                #line
            ),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseMailboxData)
    }

}

// MARK: - parseMailboxList
extension ParserUnitTests {

    func testParseMailboxList_valid_noFlags_noCharacter() {
        TestUtilities.withBuffer("() NIL inbox") { (buffer) in
            let list = try NIOIMAP.GrammarParser.parseMailboxList(buffer: &buffer, tracker: .testTracker)
            XCTAssertNil(list.flags)
            XCTAssertNil(list.char)
            XCTAssertEqual(list.mailbox, .inbox)
        }
    }

    func testParseMailboxList_valid_noFlags_character() {
        TestUtilities.withBuffer("() \"d\" inbox") { (buffer) in
            let list = try NIOIMAP.GrammarParser.parseMailboxList(buffer: &buffer, tracker: .testTracker)
            XCTAssertNil(list.flags)
            XCTAssertEqual(list.char, "d")
            XCTAssertEqual(list.mailbox, .inbox)
        }
    }

    func testParseMailboxList_valid_flags_noCharacter() {
        TestUtilities.withBuffer("(\\oflag1 \\oflag2) NIL inbox") { (buffer) in
            let list = try NIOIMAP.GrammarParser.parseMailboxList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(list.flags, NIOIMAP.Mailbox.List.Flags(oFlags: [.other("oflag1"), .other("oflag2")], sFlag: nil))
            XCTAssertNil(list.char)
            XCTAssertEqual(list.mailbox, .inbox)
        }
    }

    func testParseMailboxList_valid_flags_character() {
        TestUtilities.withBuffer("(\\oflag1 \\oflag2) \"d\" inbox") { (buffer) in
            let list = try NIOIMAP.GrammarParser.parseMailboxList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(list.flags, NIOIMAP.Mailbox.List.Flags(oFlags: [.other("oflag1"), .other("oflag2")], sFlag: nil))
            XCTAssertEqual(list.char, "d")
            XCTAssertEqual(list.mailbox, .inbox)
        }
    }

    func testParseMailboxList_invalid_character_incomplete() {
        var buffer = "() \"" as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseMailboxList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

    func testParseMailboxList_invalid_character() {
        var buffer = "() \"\\\" inbox" as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseMailboxList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - parseMailboxListFlags
extension ParserUnitTests {

    func testParseMailboxListFlags_valid_oFlags_one() {
        TestUtilities.withBuffer("\\flag1", terminator: " \r\n") { (buffer) in
            let flags = try NIOIMAP.GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("flag1")])
            XCTAssertNil(flags.sFlag)
        }

    }

    func testParseMailboxListFlags_valid_oFlags_multiple() {
        TestUtilities.withBuffer("\\flag1 \\flag2", terminator: " \r\n") { (buffer) in
            let flags = try NIOIMAP.GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("flag1"), .other("flag2")])
            XCTAssertNil(flags.sFlag)
        }

    }

    // 1*OFlag sFlag 0*OFlag
    func testParseMailboxListFlags_valid_mixedArray1() {
        TestUtilities.withBuffer("\\oflag1 \\marked", terminator: "\r\n") { (buffer) in
            let flags = try NIOIMAP.GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("oflag1")])
            XCTAssertEqual(flags.sFlag, NIOIMAP.Mailbox.List.SFlag.marked)
        }

    }

    // 1*OFlag sFlag 1*OFlag
    func testParseMailboxListFlags_valid_mixedArray2() {
        TestUtilities.withBuffer("\\oflag1 \\marked \\oflag2", terminator: " \r\n") { (buffer) in
            let flags = try NIOIMAP.GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("oflag1"), .other("oflag2")])
            XCTAssertEqual(flags.sFlag, NIOIMAP.Mailbox.List.SFlag.marked)
        }

    }

    // 2*OFlag sFlag 2*OFlag
    func testParseMailboxListFlags_valid_mixedArray3() {
        TestUtilities.withBuffer("\\oflag1 \\oflag2 \\marked \\oflag3 \\oflag4", terminator: " \r\n") { (buffer) in
            let flags = try NIOIMAP.GrammarParser.parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flags.oFlags, [.other("oflag1"), .other("oflag2"), .other("oflag3"), .other("oflag4")])
            XCTAssertEqual(flags.sFlag, NIOIMAP.Mailbox.List.SFlag.marked)
        }

    }

}

// MARK: - parseMailboxListOflag
extension ParserUnitTests {

    func testParseMailboxListOflag_valid_inferior() {
        TestUtilities.withBuffer("\\Noinferiors") { (buffer) in
            let flag = try NIOIMAP.GrammarParser.parseMailboxListOflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .noInferiors)
        }
    }

    func testParseMailboxListOflag_valid_inferior_mixedCase() {
        TestUtilities.withBuffer("\\NOINferiors") { (buffer) in
            let flag = try NIOIMAP.GrammarParser.parseMailboxListOflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .noInferiors)
        }
    }
    func testParseMailboxListOflag_valid_other() {
        TestUtilities.withBuffer("\\SomeFlag", terminator: " ") { (buffer) in
            let flag = try NIOIMAP.GrammarParser.parseMailboxListOflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .other("SomeFlag"))
        }
    }

}

// MARK: - parseMediaBasic
extension ParserUnitTests {

    func testParseMediaBasic_valid_match() {
        var buffer = #""APPLICATION" "something""# as ByteBuffer
        do {
            let mediaBasic = try NIOIMAP.GrammarParser.parseMediaBasic(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(mediaBasic, NIOIMAP.Media.Basic(type: .application, subtype: "something"))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseMediaBasic_valid_string() {
        var buffer = #""STRING" "something""# as ByteBuffer
        do {
            let mediaBasic = try NIOIMAP.GrammarParser.parseMediaBasic(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(mediaBasic, NIOIMAP.Media.Basic(type: .other("STRING"), subtype: "something"))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseMediaBasic_valid_invalidString() {
        var buffer = #"hey "something""# as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseMediaBasic(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - media-message parseMediaMessage
extension ParserUnitTests {

    func testMediaMessage_valid_rfc() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"MESSAGE\" \"RFC822\"")
        XCTAssertNoThrow(try NIOIMAP.GrammarParser.parseMediaMessage(buffer: &buffer, tracker: .testTracker))
    }

    func testMediaMessage_valid_mixedCase() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"messAGE\" \"RfC822\"")
        XCTAssertNoThrow(try NIOIMAP.GrammarParser.parseMediaMessage(buffer: &buffer, tracker: .testTracker))
    }

    func testMediaMessage_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abcdefghijklmnopqrstuvwxyz\n")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseMediaMessage(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testMediaMessage_invalid_partial() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\"messAGE\"")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseMediaMessage(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

}

// MARK: - media-text parseMediaText
extension ParserUnitTests {

    func testMediaText_valid() {
        TestUtilities.withBuffer(#""TEXT" "something""#, terminator: "\n") { (buffer) in
            let media = try NIOIMAP.GrammarParser.parseMediaText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(media, "something")
        }
    }

    func testMediaText_valid_mixedCase() {
        TestUtilities.withBuffer(#""TExt" "something""#, terminator: "\n") { (buffer) in
            let media = try NIOIMAP.GrammarParser.parseMediaText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(media, "something")
        }
    }

    func testMediaText_invalid_missingQuotes() {
        var buffer = TestUtilities.createTestByteBuffer(for: #"TEXT "something"\n"#)
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseMediaText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testMediaText_invalid_missingSubtype() {
        var buffer = TestUtilities.createTestByteBuffer(for: #""TEXT""#)
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseMediaText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

}

// MARK: - parseMessageAttribute
extension ParserUnitTests {
    
    // TODO: Write tests

}

// MARK: - parseMessageAttributeDynamic
extension ParserUnitTests {

    func testParseMessageAttributeDynamic_valid_single() {
        TestUtilities.withBuffer("FLAGS (\\Draft)", terminator: "") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseMessageAttributeDynamic(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, [.draft])
        }
    }

    func testParseMessageAttributeDynamic_valid_multiple() {
        TestUtilities.withBuffer("FLAGS (flag1 flag2 flag3)", terminator: "") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseMessageAttributeDynamic(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, [.keyword("flag1"), .keyword("flag2"), .keyword("flag3")])
        }
    }

    func testParseMessageAttributeDynamic_invalid_empty() {
        var buffer = "FLAGS ()" as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseMessageAttributeDynamic(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - parseMessageAttributeStatic
extension ParserUnitTests {

    func testParseMessageAttributeStatic_envelope() {
        TestUtilities.withBuffer(#"ENVELOPE ("date" "subject" (("from1" "from2" "from3" "from4")) (("sender1" "sender2" "sender3" "sender4")) (("reply1" "reply2" "reply3" "reply4")) (("to1" "to2" "to3" "to4")) (("cc1" "cc2" "cc3" "cc4")) (("bcc1" "bcc2" "bcc3" "bcc4")) "inreplyto" "messageid")"#) { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseMessageAttributeStatic(buffer: &buffer, tracker: .testTracker)
            let expectedEnvelope = NIOIMAP.Envelope(
                date: "date",
                subject: "subject",
                from: [.name("from1", adl: "from2", mailbox: "from3", host: "from4")],
                sender: [.name("sender1", adl: "sender2", mailbox: "sender3", host: "sender4")],
                reply: [.name("reply1", adl: "reply2", mailbox: "reply3", host: "reply4")],
                to: [.name("to1", adl: "to2", mailbox: "to3", host: "to4")],
                cc: [.name("cc1", adl: "cc2", mailbox: "cc3", host: "cc4")],
                bcc: [.name("bcc1", adl: "bcc2", mailbox: "bcc3", host: "bcc4")],
                inReplyTo: "inreplyto",
                messageID: "messageid"
            )
            XCTAssertEqual(result, .envelope(expectedEnvelope))
        }
    }

    func testParseMessageAttributeStatic_dateTime() {
        TestUtilities.withBuffer(#"INTERNALDATE "25-jun-1994 01:02:03 +0000""#) { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseMessageAttributeStatic(buffer: &buffer, tracker: .testTracker)
            let expectedDateTime = NIOIMAP.Date.DateTime(
                date: NIOIMAP.Date(day: 25, month: .jun, year: 1994),
                time: NIOIMAP.Date.Time(hour: 01, minute: 02, second: 03),
                zone: NIOIMAP.Date.TimeZone(0)!
            )
            XCTAssertEqual(result, .internalDate(expectedDateTime))
        }
    }
    
    func testParseMessageAttributeStatic() {
        let inputs: [(String, String, NIOIMAP.MessageAttributesStatic, UInt)] = [
            ("UID 1234", " ", .uid(1234), #line),
            ("BODY[TEXT]<1> {999}\r\n", " ", .bodySectionText(1, 999), #line),
            (#"BODY[HEADER] "string""#, " ", .bodySection(.text(.header), nil, "string"), #line),
            (#"BODY[HEADER]<12> "string""#, " ", .bodySection(.text(.header), 12, "string"), #line),
            ("RFC822.SIZE 1234", " ", .rfc822Size(1234), #line),
            (#"RFC822 "some string""#, " ", .rfc822(nil, "some string"), #line),
            (#"RFC822.HEADER "some string""#, " ", .rfc822(.header, "some string"), #line),
            ("BINARY.SIZE[3] 4", " ", .binarySize(section: [3], number: 4), #line),
            ("BINARY[3] ~{4}\r\n", " ", .binaryLiteral(section: [3], size: 4), #line),
            ("BINARY[3] {4}\r\n", " ", .binaryLiteral(section: [3], size: 4), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseMessageAttributeStatic)
    }
}

// MARK: - parseMessageData
extension ParserUnitTests {
    
    func testParseMessageData() {
        let inputs: [(String, String, NIOIMAP.MessageData, UInt)] = [
            ("1 FETCH ", "", .fetch(1), #line)
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseMessageData)
    }

}

// MARK: - mod-sequence-value parseModifierSequenceValue
extension ParserUnitTests {
 
    func testParseModifierSequenceValue() {
        let inputs: [(String, String, NIOIMAP.ModifierSequenceValue, UInt)] = [
            ("1", " ", .value(1)!, #line),
            ("123", " ", .value(123)!, #line),
            ("12345", " ", .value(12345)!, #line),
            ("1234567", " ", .value(1234567)!, #line),
            ("123456789", " ", .value(123456789)!, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseModifierSequenceValue)
    }
    
}

// MARK: - mod-sequence-valzer parseModifierSequenceValueZero
extension ParserUnitTests {
 
    func testParseModifierSequenceValueZero() {
        let inputs: [(String, String, NIOIMAP.ModifierSequenceValue, UInt)] = [
            ("0", " ", .zero, #line),
            ("123", " ", .value(123), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseModifierSequenceValue)
    }
    
}

// MARK: - move parseMove
extension ParserUnitTests {
 
    func testParseMove() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("MOVE * inbox", " ", .move([.wildcard], .inbox), #line),
            ("MOVE 1:2,4:5 test", " ", .move([1...2, 4...5], "test"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseMove)
    }
    
}

// MARK: - parseNamespaceCommand
extension ParserUnitTests {
    
    func testParseNamespaceCommand() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("NAMESPACE", " ", .namespace, #line),
            ("nameSPACE", " ", .namespace, #line),
            ("namespace", " ", .namespace, #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseNamespaceCommand)
    }
    
}

// MARK: - Namespace-Desc parseNamespaceResponse
extension ParserUnitTests {
    
    func testParseNamespaceDescription() {
        let inputs: [(String, String, NIOIMAP.NamespaceDescription, UInt)] = [
            ("(\"str1\" NIL)", " ", .string("str1", char: nil, responseExtensions: []), #line),
            ("(\"str\" \"a\")", " ", .string("str", char: "a", responseExtensions: []), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseNamespaceDescription)
    }
    
}

// MARK: - parseNamespaceResponse
extension ParserUnitTests {
    
    func testParseNamespaceResponse() {
        let inputs: [(String, String, NIOIMAP.NamespaceResponse, UInt)] = [
            ("NAMESPACE nil nil nil", " ", .userNamespace(nil, otherUserNamespace: nil, sharedNamespace: nil), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseNamespaceResponse)
    }
    
}

// MARK: - parseNamespaceResponseExtension
extension ParserUnitTests {
    
    func testParseNamespaceResponseExtension() {
        let inputs: [(String, String, NIOIMAP.NamespaceResponseExtension, UInt)] = [
            (" \"str1\" (\"str2\")", " ", .string("str1", array: ["str2"]), #line),
            (" \"str1\" (\"str2\" \"str3\" \"str4\")", " ", .string("str1", array: ["str2", "str3", "str4"]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseNamespaceResponseExtension)
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
            XCTAssertEqual(error as? NIOIMAP.ParsingError, NIOIMAP.ParsingError.incompleteMessage)
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
        XCTAssertNoThrow(try NIOIMAP.GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker))
    }

    func testNil_valid_mixedCase() {
        var buffer = TestUtilities.createTestByteBuffer(for: "nIl")
        XCTAssertNoThrow(try NIOIMAP.GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker))
    }

    func testNil_valid_overcomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "NILL")
        XCTAssertNoThrow(try NIOIMAP.GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker))
        XCTAssertEqual(buffer.readableBytes, 1)
    }

    func testNil_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "N")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

    func testNil_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "123")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testNil_invalid_text() {
        var buffer = TestUtilities.createTestByteBuffer(for: #""NIL""#)
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseNil(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

}

// MARK: - nstring parseNString
extension ParserUnitTests {

    func testNString_nil() {
        TestUtilities.withBuffer("NIL", terminator: "\n") { (buffer) in
            let val = try NIOIMAP.GrammarParser.parseNString(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(val, nil)
        }
    }

    func testNString_nil_mixedCase() {
        TestUtilities.withBuffer("Nil", terminator: "\n") { (buffer) in
            let val = try NIOIMAP.GrammarParser.parseNString(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(val, nil)
        }

    }

    func testNString_string() {
        TestUtilities.withBuffer("\"abc123\"") { (buffer) in
            let val = try NIOIMAP.GrammarParser.parseNString(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(val, "abc123")
        }
    }

    func testNString_invalid() {
        var buffer = TestUtilities.createTestByteBuffer(for: "hello world")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseNString(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - number parseNumber
extension ParserUnitTests {

    func testNumber_valid() {
        TestUtilities.withBuffer("12345", terminator: " ") { (buffer) in
            let num = try NIOIMAP.GrammarParser.parseNumber(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 12345)
        }
    }

    func testNumber_invalid_empty() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try ParserLibrary.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? NIOIMAP.ParsingError, NIOIMAP.ParsingError.incompleteMessage)
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
            let num = try NIOIMAP.GrammarParser.parseNumber(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 12345)
        }
    }

    func testNZNumber_valid_midZero() {
        TestUtilities.withBuffer("12045", terminator: " ") { (buffer) in
            let num = try NIOIMAP.GrammarParser.parseNumber(buffer: &buffer, tracker: .testTracker)
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
            XCTAssertEqual(error as? NIOIMAP.ParsingError, NIOIMAP.ParsingError.incompleteMessage)
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
        let inputs: [(String, String, NIOIMAP.Partial.Range, UInt)] = [
            ("1", " ", NIOIMAP.Partial.Range(num1: 1, num2: nil), #line),
            ("1.2", " ", NIOIMAP.Partial.Range(num1: 1, num2: 2), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parsePartialRange)
    }

}

// MARK: - parsePartial
extension ParserUnitTests {

    func testParsePartial() {
        let inputs: [(String, String, NIOIMAP.Partial, UInt)] = [
            ("<1.2>", " ", .init(left: 1, right: 2), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parsePartial)
    }

}

// MARK: - parseResponseData
extension ParserUnitTests {

    func testParseResponseData() {
        let inputs: [(String, String, NIOIMAP.ResponsePayload, UInt)] = [
            ("* CAPABILITY ENABLE\r\n", " ", .capabilityData([.enable]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseResponseData)
    }

}

// MARK: - parseResponseDone
extension ParserUnitTests {

    func testParseResponseDone() {
        let inputs: [(String, String, NIOIMAP.ResponseDone, UInt)] = [
            ("1.250 OK ID completed.\r\n", "", .tagged(.tag("1.250", state: .ok(.code(nil, text: "ID completed.")))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseResponseDone)
    }

}

// MARK: - parseResponsePayload
extension ParserUnitTests {

    func testParseResponsePayload() {
        let inputs: [(String, String, NIOIMAP.ResponsePayload, UInt)] = [
            ("CAPABILITY ENABLE", "\r", .capabilityData([.enable]), #line),
            ("BYE test", "\r\n", .conditionalBye(.code(nil, text: "test")), #line),
            ("OK test", "\r\n", .conditionalState(.ok(.code(nil, text: "test"))), #line),
            ("1 EXISTS", "\r", .mailboxData(.exists(1)), #line),
            ("2 EXPUNGE", "\r", .messageData(.expunge(2)), #line),
            ("ENABLED ENABLE", "\r", .enableData([.enable]), #line),
            ("ID (\"key\" NIL)", "\r", .id([.key("key", value: nil)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseResponsePayload)
    }

}

// MARK: - parseResponseTextCode
extension ParserUnitTests {

    func testParseResponseTextCode() {
        let inputs: [(String, String, NIOIMAP.ResponseTextCode, UInt)] = [
            ("ALERT", "\r", .alert, #line),
            ("BADCHARSET", "\r", .badCharset(nil), #line),
            ("BADCHARSET (UTF8)", "\r", .badCharset(["UTF8"]), #line),
            ("BADCHARSET (UTF8 UTF9 UTF10)", "\r", .badCharset(["UTF8", "UTF9", "UTF10"]), #line),
            ("CAPABILITY IMAP4 IMAP4rev1", "\r", .capability([]), #line),
            ("PARSE", "\r", .parse, #line),
            ("PERMANENTFLAGS ()", "\r", .permanentFlags([]), #line),
            ("PERMANENTFLAGS (\\Answered)", "\r", .permanentFlags([.flag(.answered)]), #line),
            ("PERMANENTFLAGS (\\Answered \\Seen \\*)", "\r", .permanentFlags([.flag(.answered), .flag(.seen), .wildcard]), #line),
            ("READ-ONLY", "\r", .readOnly, #line),
            ("READ-WRITE", "\r", .readWrite, #line),
            ("UIDNEXT 12", "\r", .uidNext(12), #line),
            ("UIDVALIDITY 34", "\r", .uidValidity(34), #line),
            ("UNSEEN 56", "\r", .unseen(56), #line),
            ("NAMESPACE NIL NIL NIL", "\r", .namespace(.userNamespace(nil, otherUserNamespace: nil, sharedNamespace: nil)), #line),
            ("some", "\r", .other("some", nil), #line),
            ("some thing", "\r", .other("some", "thing"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseResponseTextCode)
    }

}

// MARK: - parseRFC822
extension ParserUnitTests {

    func testParseRFC822_valid_header() {
        TestUtilities.withBuffer(".HEADER") { (buffer) in
            let rfc = try NIOIMAP.GrammarParser.parseRFC822(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(rfc, .header)
        }
    }

    func testParseRFC822_valid_size() {
        TestUtilities.withBuffer(".SIZE") { (buffer) in
            let rfc = try NIOIMAP.GrammarParser.parseRFC822(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(rfc, .size)
        }
    }

    func testParseRFC822_valid_text() {
        TestUtilities.withBuffer(".TEXT") { (buffer) in
            let rfc = try NIOIMAP.GrammarParser.parseRFC822(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(rfc, .text)
        }
    }

}

// MARK: - parseRFC822Reduced
extension ParserUnitTests {

    func testParseRFC822Reduced_header() {
        TestUtilities.withBuffer(".HEADER") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseRFC822Reduced(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, .header)
        }
    }

    func testParseRFC822Reduced_text() {
        TestUtilities.withBuffer(".TEXT") { (buffer) in
            let result = try NIOIMAP.GrammarParser.parseRFC822Reduced(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, .text)
        }
    }

}

// MARK: - search parseSearch
extension ParserUnitTests {



}

// MARK: - parseSearchCorrelator
extension ParserUnitTests {

    func testParseSearchCorrelator() {
        let inputs: [(String, String, ByteBuffer, UInt)] = [
            (" (TAG \"test1\")", "\r", "test1", #line),
            (" (tag \"test2\")", "\r", "test2", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchCorrelator)
    }

}

// MARK: - `search-criteria` parseSearchCriteria
extension ParserUnitTests {
    
    func testParseSearchCriteria() {
        let inputs: [(String, String, [NIOIMAP.SearchKey], UInt)] = [
            ("ALL", "\r", [.all], #line),
            ("ALL ANSWERED DELETED", "\r", [.all, .answered, .deleted], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchCriteria)
    }
    
}

// MARK: - `search-key` parseSearchKey
extension ParserUnitTests {

    func testParseSearchKey() {
        let inputs: [(String, String, NIOIMAP.SearchKey, UInt)] = [
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
            ("ON 25-jun-1994", "\r", .on(NIOIMAP.Date(day: 25, month: .jun, year: 1994)), #line),
            ("SINCE 01-jan-2001", "\r", .since(NIOIMAP.Date(day: 1, month: .jan, year: 2001)), #line),
            ("SENTON 02-jan-2002", "\r", .sent(.on(NIOIMAP.Date(day: 2, month: .jan, year: 2002))), #line),
            ("SENTBEFORE 03-jan-2003", "\r", .sent(.before(NIOIMAP.Date(day: 3, month: .jan, year: 2003))), #line),
            ("SENTSINCE 04-jan-2004", "\r", .sent(.since(NIOIMAP.Date(day: 4, month: .jan, year: 2004))), #line),
            ("BEFORE 05-jan-2005", "\r", .before(NIOIMAP.Date(day: 5, month: .jan, year: 2005)), #line),
            ("LARGER 1234", "\r", .larger(1234), #line),
            ("SMALLER 5678", "\r", .smaller(5678), #line),
            ("BCC data1", "\r", .bcc("data1"), #line),
            ("BODY data2", "\r", .body("data2"), #line),
            ("CC data3", "\r", .cc("data3"), #line),
            ("FROM data4", "\r", .from("data4"), #line),
            ("SUBJECT data5", "\r", .subject("data5"), #line),
            ("TEXT data6", "\r", .text("data6"), #line),
            ("TO data7", "\r", .to("data7"), #line),
            ("KEYWORD key1", "\r", .keyword("key1"), #line),
            ("HEADER some value", "\r", .header("some", "value"), #line),
            ("UNKEYWORD key2", "\r", .unkeyword("key2"), #line),
            ("NOT LARGER 1234", "\r", .not(.larger(1234)), #line),
            ("OR LARGER 6 SMALLER 4", "\r", .or(.larger(6), .smaller(4)), #line),
            ("UID 2:4", "\r", .uid([2...4]), #line),
            ("2:4", "\r", .sequenceSet([2...4]), #line),
            ("(LARGER 1)", "\r", .array([.larger(1)]), #line),
            ("(LARGER 1 SMALLER 5 KEYWORD hello)", "\r", .array([.larger(1), .smaller(5), .keyword("hello")]), #line),
            ("YOUNGER 34", "\r", .younger(34), #line),
            ("OLDER 45", "\r", .older(45), #line),
            ("FILTER something", "\r", .filter("something"), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchKey)
    }

    func testParseSearchKey_array_none_invalid() {
        var buffer = "()" as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseSearchKey(buffer: &buffer, tracker: .testTracker)) { e in
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
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchModifierName)
    }

}

// MARK: - `search-modifier-params` parseSearchModifierParams
extension ParserUnitTests {

    func testParseSearchModifierParams() {
        let inputs: [(String, String, NIOIMAP.TaggedExtensionValue, UInt)] = [
            ("()", "", .comp(nil), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchModifierParams)
    }

}

// MARK: - `search-program` parseSearchProgram
extension ParserUnitTests {

    func testParseSearchProgram() {
        let inputs: [(String, String, NIOIMAP.SearchProgram, UInt)] = [
            ("ALL", "\r", .charset(nil, keys: [.all]), #line),
            ("ALL ANSWERED DELETED", "\r", .charset(nil, keys: [.all, .answered, .deleted]), #line),
            ("CHARSET UTF8 ALL", "\r", .charset("UTF8", keys: [.all]), #line),
            ("CHARSET UTF16 ALL ANSWERED DELETED", "\r", .charset("UTF16", keys: [.all, .answered, .deleted]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchProgram)
    }

}

// MARK: - `search-ret-data-ext` parseSearchReturnDataExtension
extension ParserUnitTests {

    // the spec is ambiguous when parsing `tagged-ext-simple`, in that a "number" is also a "sequence-set"
    // our parser gives priority to "sequence-set"
    func testParseSearchReturnDataExtension() {
        let inputs: [(String, String, NIOIMAP.SearchReturnDataExtension, UInt)] = [
            ("modifier 64", "\r", .modifier("modifier", returnValue: .simple(.sequence([64]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchReturnDataExtension)
    }

}

// MARK: - `search-ret-data` parseSearchReturnData
extension ParserUnitTests {

    func testParseSearchReturnData() {
        let inputs: [(String, String, NIOIMAP.SearchReturnData, UInt)] = [
            ("MIN 1", "\r", .min(1), #line),
            ("MAX 2", "\r", .max(2), #line),
            ("ALL 3", "\r", .all([3]), #line),
            ("ALL 3,4,5", "\r", .all([3, 4, 5]), #line),
            ("COUNT 4", "\r", .count(4), #line),
            ("modifier 5", "\r", .dataExtension(.modifier("modifier", returnValue: .simple(.sequence([5])))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchReturnData)
    }

}

// MARK: - `search-ret-opt` parseSearchReturnOption
extension ParserUnitTests {

    func testParseSearchReturnOption() {
        let inputs: [(String, String, NIOIMAP.SearchReturnOption, UInt)] = [
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
            ("modifier", "\r", .optionExtension(.modifier("modifier", params: nil)), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchReturnOption)
    }

}

// MARK: - `search-ret-opts` parseSearchReturnOptions
extension ParserUnitTests {

    func testParseSearchReturnOptions() {
        let inputs: [(String, String, [NIOIMAP.SearchReturnOption], UInt)] = [
            (" RETURN (ALL)", "\r", [.all], #line),
            (" RETURN (MIN MAX COUNT)", "\r", [.min, .max, .count], #line),
            (" RETURN (m1 m2)","\r",[
                .optionExtension(.modifier("m1", params: nil)),
                .optionExtension(.modifier("m2", params: nil))
            ], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchReturnOptions)
    }

}

// MARK: - `search-ret-opt-ext` parseSearchReturnOptionExtension
extension ParserUnitTests {

    func testParseSearchReturnOptionExtension() {
        let inputs: [(String, String, NIOIMAP.SearchReturnOptionExtension, UInt)] = [
            ("modifier", "\r", .modifier("modifier", params: nil), #line),
            ("modifier 4", "\r", .modifier("modifier", params: .simple(.sequence([4]))), #line)
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSearchReturnOptionExtension)
    }

}

// MARK: - parseSection
extension ParserUnitTests {

    func testParseSection_valid_none() {
        TestUtilities.withBuffer("[]") { (buffer) in
            let section = try NIOIMAP.GrammarParser.parseSection(buffer: &buffer, tracker: .testTracker)
            XCTAssertNil(section)
        }
    }

    func testParseSection_valid_some() {
        TestUtilities.withBuffer("[HEADER]") { (buffer) in
            let section = try NIOIMAP.GrammarParser.parseSection(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(section, NIOIMAP.SectionSpec.text(.header))
        }
    }

}

// MARK: - parseSectionBinary
extension ParserUnitTests {
    
    func testParseSectionBinary() {
        let inputs: [(String, String, [Int]?, UInt)] = [
            ("[]", "\r", nil, #line),
            ("[1]", "\r", [1], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSectionBinary)
    }

}

// MARK: - parseSectionMessageText
extension ParserUnitTests {
    
    func testParseSectionMessageText() {
        let inputs: [(String, String, NIOIMAP.SectionMessageText, UInt)] = [
            ("HEADER", "\r", .header, #line),
            ("TEXT", "\r", .text, #line),
            ("HEADER.FIELDS (test)", "\r", .headerFields(["test"]), #line),
            ("HEADER.FIELDS.NOT (test)", "\r", .notHeaderFields(["test"]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSectionMessageText)
    }

}

// MARK: - parseSectionPart
extension ParserUnitTests {

    func testParseSection_valid_one() {
        TestUtilities.withBuffer("1", terminator: " ") { (buffer) in
            let part = try NIOIMAP.GrammarParser.parseSectionPart(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(part[0], 1)
        }
    }

    func testParseSection_valid_many() {
        TestUtilities.withBuffer("1.3.5", terminator: " ") { (buffer) in
            let part = try NIOIMAP.GrammarParser.parseSectionPart(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(part, [1, 3, 5])
        }
    }

    func testParseSection_invalid_none() {
        var buffer = "" as ByteBuffer
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseSectionPart(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

}

// MARK: - parseSectionSpec
extension ParserUnitTests {
    
    func testParseSectionSpec() {
        let inputs: [(String, String, NIOIMAP.SectionSpec, UInt)] = [
            ("HEADER", "\r", .text(.header), #line),
            ("1.2.3", "\r", .part([1, 2, 3], text: nil), #line),
            ("1.2.3.HEADER", "\r", .part([1, 2, 3], text: .message(.header)), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSectionSpec)
    }

}

// MARK: - select parseSelect
extension ParserUnitTests {

    func testParseSelect() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("SELECT inbox", "\r", .select(.inbox, nil), #line),
            ("SELECT inbox (some1)", "\r", .select(.inbox, [.name("some1", value: nil)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSelect)
    }

    func testSelect_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "SELECT ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseSelect(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

}

// MARK: - parseSelectParameter
extension ParserUnitTests {
    
    func testParseSelectParameter() {
        let inputs: [(String, String, NIOIMAP.SelectParameter, UInt)] = [
            ("test", "\r", .name("test", value: nil), #line),
            ("some 1", "\r", .name("some", value: .simple(.sequence([1]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSelectParameter)
    }
    
}

// MARK: - parseSelectParameters
extension ParserUnitTests {
    
    func testParseSelectParameters() {
        let inputs: [(String, String, [NIOIMAP.SelectParameter], UInt)] = [
            (" (test)", "\r", [.name("test", value: nil)], #line),
            (" (test1 test2 test3)", "\r", [.name("test1", value: nil), .name("test2", value: nil), .name("test3", value: nil)], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSelectParameters)
    }
    
}

// MARK: - parseSelectParameterName
extension ParserUnitTests {
    
    func testParseSelectParameterName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", "\r", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSelectParameterName)
    }
    
}

// MARK: - parseSelectParameterValue
extension ParserUnitTests {
    
    func testParseSelectParameterValue() {
        let inputs: [(String, String, NIOIMAP.TaggedExtensionValue, UInt)] = [
            ("1", "\r", .simple(.sequence([1])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSelectParameterValue)
    }
    
}

// MARK: - seq-number parseSequenceNumber
extension ParserUnitTests {

    func testSequenceNumber_valid_wildcard() {
        TestUtilities.withBuffer("*") { (buffer) in
            let num = try NIOIMAP.GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, .last)
        }
    }

    func testSequenceNumber_valid_number() {
        TestUtilities.withBuffer("123", terminator: " ") { (buffer) in
            let num = try NIOIMAP.GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 123)
        }
    }

    func testSequenceNumber_invalid_letters() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abc")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

    func testSequenceNumber_invalid_nznumber() {
        var buffer = TestUtilities.createTestByteBuffer(for: "0123 ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseSequenceNumber(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

}

// MARK: - sequence-set parseSequenceSet
extension ParserUnitTests {

    func testSequenceSet_valid_one() {
        TestUtilities.withBuffer("765", terminator: " ") { (buffer) in
            let set = try NIOIMAP.GrammarParser.parseSequenceSet(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(set, [765])
        }
    }

    func testSequenceSet_valid_many() {
        TestUtilities.withBuffer("1,2:5,7,9:*", terminator: " ") { (buffer) in
            let set = try NIOIMAP.GrammarParser.parseSequenceSet(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(set, [1, 2...5, 7, 9...])
        }
    }

    func testSequenceSet_invalid_none() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseSequenceSet(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssertEqual(error as? NIOIMAP.ParsingError, NIOIMAP.ParsingError.incompleteMessage)
        }
    }

}

// MARK: - s-flag parseSFlag
extension ParserUnitTests {

    func testSFlag_valid() {
        TestUtilities.withBuffer("\\unmarked", terminator: " ") { (buffer) in
            let flag = try NIOIMAP.GrammarParser.parseMailboxListSflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .unmarked)
        }
    }

    func testSFlag_valid_mixedCase() {
        TestUtilities.withBuffer("\\UNMArked", terminator: " ") { (buffer) in
            let flag = try NIOIMAP.GrammarParser.parseMailboxListSflag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flag, .unmarked)
        }
    }

    func testSFlage_invalid_noSlash() {
        var buffer = TestUtilities.createTestByteBuffer(for: "unmarked ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseMailboxListSflag(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - status parseStatus
extension ParserUnitTests {

    func testParseStatus() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("STATUS inbox (messages unseen)", "\r\n", .status(.inbox, [.messages, .unseen]), #line),
            ("STATUS Deleted (messages unseen HIGHESTMODSEQ)", "\r\n", .status(NIOIMAP.Mailbox("Deleted"), [.messages, .unseen, .highestModSeq]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseStatus)
    }
    
}

// MARK: - status-att parseStatusAttribute
extension ParserUnitTests {

    func testStatusAttribute_valid_all() {
        for att in NIOIMAP.StatusAttribute.AllCases() {
            do {
                var buffer = TestUtilities.createTestByteBuffer(for: att.rawValue)
                let parsedAtt = try NIOIMAP.GrammarParser.parseStatusAttribute(buffer: &buffer, tracker: .testTracker)
                XCTAssertEqual(att, parsedAtt)
            } catch {
                XCTFail()
                return
            }
        }
    }

    func testStatusAttribute_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "a")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseStatusAttribute(buffer: &buffer, tracker: .testTracker)) { e in

        }
    }


    func testStatusAttribute_invalid_noMatch() {
        var buffer = TestUtilities.createTestByteBuffer(for: "a ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseStatusAttribute(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }
}

// MARK: - status-att-list parseStatusAttributeList
extension ParserUnitTests {

    func testStatusAttributeList_valid_single() {
        TestUtilities.withBuffer("MESSAGES 2", terminator: "\n") { (buffer) in
            let expected = [NIOIMAP.StatusAttributeValue.messages(2)]
            let parsed = try NIOIMAP.GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(parsed, expected)
        }
    }

    func testStatusAttributeList_valid_many() {
        TestUtilities.withBuffer("MESSAGES 2 UNSEEN 3 DELETED 4", terminator: "\n") { (buffer) in
            let expected = [
                NIOIMAP.StatusAttributeValue.messages(2),
                NIOIMAP.StatusAttributeValue.unseen(3),
                NIOIMAP.StatusAttributeValue.deleted(4)
            ]
            let parsed = try NIOIMAP.GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(parsed, expected)
        }
    }

    func testStatusAttributeList_invalid_none() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

    func testStatusAttributeList_invalid_missing_number() {
        var buffer = TestUtilities.createTestByteBuffer(for: "MESSAGES UNSEEN 3 RECENT 4\n")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testStatusAttributeList_invalid_missing_attribute() {
        var buffer = TestUtilities.createTestByteBuffer(for: "2 UNSEEN 3 RECENT 4\n")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseStatusAttributeList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - parseStore
extension ParserUnitTests {

    func testParseStore() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("STORE 1 +FLAGS \\answered", "\r", .store([1], nil, .add(silent: false, list: [.answered])), #line),
            ("STORE 1 (label) -FLAGS \\seen", "\r", .store([1], [.name("label", parameters: nil)], .remove(silent: false, list: [.seen])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseStore)
    }

}

// MARK: - parseStoreAttributeFlags
extension ParserUnitTests {
    
    func testParseStoreAttributeFlags() {
        let inputs: [(String, String, NIOIMAP.StoreAttributeFlags, UInt)] = [
            ("+FLAGS ()", "\r", .add(silent: false, list: []), #line),
            ("-FLAGS ()", "\r", .remove(silent: false, list: []), #line),
            ("FLAGS ()", "\r", .other(silent: false, list: []), #line),
            ("+FLAGS.SILENT ()", "\r", .add(silent: true, list: []), #line),
            ("+FLAGS.SILENT (\\answered \\seen)", "\r", .add(silent: true, list: [.answered, .seen]), #line),
            ("+FLAGS.SILENT \\answered \\seen", "\r", .add(silent: true, list: [.answered, .seen]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseStoreAttributeFlags)
    }

}

// MARK: - subscribe parseSubscribe
extension ParserUnitTests {
    
    func testParseSubscribe() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("SUBSCRIBE inbox", "\r\n", .subscribe(.inbox), #line),
            ("SUBScribe INBOX", "\r\n", .subscribe(.inbox), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseSubscribe)
    }

    func testSubscribe_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "SUBSCRIBE ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseSubscribe(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

}

// MARK: - parseRename
extension ParserUnitTests {
    
    func testParseRename() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("RENAME box1 box2", "\r", .rename(from: "box1", to: "box2", params: nil), #line),
            ("rename box3 box4", "\r", .rename(from: "box3", to: "box4", params: nil), #line),
            ("RENAME box5 box6 (test)", "\r", .rename(from: "box5", to: "box6", params: [.name("test", value: nil)]), #line)
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseRename)
    }
    
}

// MARK: - parseStoreModifier
extension ParserUnitTests {
    
    func testParseStoreModifier() {
        let inputs: [(String, String, NIOIMAP.StoreModifier, UInt)] = [
            ("name", "\r", .name("name", parameters: nil), #line),
            ("name 1:9", "\r", .name("name", parameters: .simple(.sequence([1...9]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseStoreModifier)
    }
    
}

// MARK: - parseStoreModifiers
extension ParserUnitTests {
    
    func testParseStoreModifiers() {
        let inputs: [(String, String, [NIOIMAP.StoreModifier], UInt)] = [
            (" (name1)", "\r", [.name("name1", parameters: nil)], #line),
            (" (name1 name2 name3)", "\r", [.name("name1", parameters: nil), .name("name2", parameters: nil), .name("name3", parameters: nil)], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseStoreModifiers)
    }
    
}

// MARK: - parseStoreModifierName
extension ParserUnitTests {
    
    func testParseStoreModifierName() {
        let inputs: [(String, String, String, UInt)] = [
            ("test", "\r", "test", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseStoreModifierName)
    }
    
}

// MARK: - parseStoreModifierParams
extension ParserUnitTests {
    
    func testParseStoreModifierParameters() {
        let inputs: [(String, String, NIOIMAP.TaggedExtensionValue, UInt)] = [
            ("1:9", "\r", .simple(.sequence([1...9])), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseStoreModifierParameters)
    }
    
}

// MARK: - tag parseTag
extension ParserUnitTests {

    func testTag_valid() {
        TestUtilities.withBuffer("abc123", terminator: " ") { (buffer) in
            let tag = try NIOIMAP.GrammarParser.parseTag(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(tag, "abc123")
        }
    }

    func testTag_invalid_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseTag(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

    func testTag_invalid_plus() {
        var buffer = TestUtilities.createTestByteBuffer(for: "+")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseTag(buffer: &buffer, tracker: .testTracker)) { e in
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
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseTagString)
    }

}

// MARK: - parseTaggedExtension
extension ParserUnitTests {

    func testParseTaggedExtension() {
        let inputs: [(String, String, NIOIMAP.TaggedExtension, UInt)] = [
            ("label 1", "\r\n", .label("label", value: .simple(.sequence([1]))), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseTaggedExtension)
    }

}

// MARK: - tagged-extension-comp parseTaggedExtensionComplex
extension ParserUnitTests {

    func testParseTaggedExtensionComplex() {

        let inputs: [(String, String, [ByteBuffer], UInt)] = [
            ("test", "\r\n", ["test"], #line),
            ("(test)", "\r\n", ["test"], #line),
            ("(test1 test2)", "\r\n", ["test1", "test2"], #line),
            ("test1 test2", "\r\n", ["test1", "test2"], #line),
            ("test1 test2 (test3 test4) test5", "\r\n", ["test1", "test2", "test3", "test4", "test5"], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseTaggedExtensionComplex)
    }

}

// MARK: - parseText
extension ParserUnitTests {

    func testText_empty() {
        var buffer = TestUtilities.createTestByteBuffer(for: "")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

    func testText_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "hello world!")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

    func testText_some() {
        TestUtilities.withBuffer("hello world!", terminator: "\r\n") { (buffer) in
            var parsed = try NIOIMAP.GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(parsed.readString(length: 12)!, "hello world!")
        }
    }

    func testText_CR() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\r")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testText_LF() {
        var buffer = TestUtilities.createTestByteBuffer(for: "\n")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

}

// MARK: - time
extension ParserUnitTests {

    func testDateTime_valid() {
        TestUtilities.withBuffer("12:34:56", terminator: "\r") { (buffer) in
            let time = try NIOIMAP.GrammarParser.parseTime(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(time, NIOIMAP.Date.Time(hour: 12, minute: 34, second: 56))
        }
    }

    func testDateTime_invalid_missingSeparator() {
        var buffer = TestUtilities.createTestByteBuffer(for: "123456\r")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseTime(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testDateTime_invalid_partial() {
        var buffer = TestUtilities.createTestByteBuffer(for: "12:")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseTime(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

}

// MARK: - parseUID
extension ParserUnitTests {
    
    func testParseUID() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("UID EXPUNGE 1", "\r\n", .uid(.uidExpunge([.single(1)])), #line),
            ("UID COPY 1 inbox", "\r\n", .uid(.copy([.single(1)], .inbox)), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseUid)
    }

    func testParseUID_invalid() {
        var buffer: ByteBuffer = "UID RENAME inbox other\r"
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseUid(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}

// MARK: - parseUIDExpunge
extension ParserUnitTests {
    
    func testParseUIDExpunge() {
        let inputs: [(String, String, NIOIMAP.UIDCommandType, UInt)] = [
            ("EXPUNGE 1", "\r\n", .uidExpunge([.single(1)]), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseUidExpunge)
    }

}

// MARK: - parseUIDRange
extension ParserUnitTests {
    
    func testUIDRange() {
        let inputs: [(String, String, NIOIMAP.UIDRange, UInt)] = [
            ("12:34", "\r\n", .from(12, to: 34), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseUidRange)
    }

}

// MARK: - parseUIDSet
extension ParserUnitTests {
    
    func testParseUIDSet() {
        let inputs: [(String, String, [NIOIMAP.UIDSetType], UInt)] = [
            ("1234", "\r\n", [.uniqueID(1234)], #line),
            ("12:34", "\r\n", [.range(NIOIMAP.UIDRange(left: 12, right: 34))], #line),
            ("1,2,34:56,78:910,11", "\r\n", [
                .uniqueID(1),
                .uniqueID(2),
                .range(NIOIMAP.UIDRange(left: 34, right: 56)),
                .range(NIOIMAP.UIDRange(left: 78, right: 910)),
                .uniqueID(11)
            ], #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseUidSet)
    }

}

// MARK: - uniqueID parseUniqueID
extension ParserUnitTests {

    // NOTE: Maps to `nz-number`, but let's make sure we didn't break the mapping.

    func testUniqueID_valid() {
        TestUtilities.withBuffer("123", terminator: " ") { (buffer) in
            let num = try NIOIMAP.GrammarParser.parseUniqueID(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(num, 123)
        }
    }

    func testUniqueID_invalid_zero() {
        var buffer = TestUtilities.createTestByteBuffer(for: "0123 ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseUniqueID(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func testUniqueID_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "123")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseUniqueID(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

}

// MARK: - unsubscribe parseUnsubscribe
extension ParserUnitTests {
    
    func testParseUnsubscribe() {
        let inputs: [(String, String, NIOIMAP.CommandType, UInt)] = [
            ("UNSUBSCRIBE inbox", "\r\n", .unsubscribe(.inbox), #line),
            ("UNSUBScribe INBOX", "\r\n", .unsubscribe(.inbox), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseUnsubscribe)
    }

    func testUnsubscribe_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "UNSUBSCRIBE ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseUnsubscribe(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
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
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseUserId)
    }
    
}

// MARK: - vendor-token
extension ParserUnitTests {

    func testParseVendorToken() {
        let inputs: [(String, String, String, UInt)] = [
            ("token", "-atom ", "token", #line),
            ("token", " ", "token", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseVendorToken)
    }

}

// MARK: - atom parseXCommand {
extension ParserUnitTests {

    func testXCommand() {
        let inputs: [(String, String, String, UInt)] = [
            ("xhello", " ", "hello", #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseXCommand)
    }

    func testXCommand_invalid_incomplete() {
        var buffer = TestUtilities.createTestByteBuffer(for: "xhello")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseXCommand(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

    func testXCommand_invalid_noX() {
        var buffer = TestUtilities.createTestByteBuffer(for: "hello ")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseXCommand(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - zone (parseZone)
extension ParserUnitTests {

    func testZone() {
        let inputs: [(String, String, NIOIMAP.Date.TimeZone?, UInt)] = [
            ("+1234", " ", NIOIMAP.Date.TimeZone(1234), #line),
            ("-5678", " ", NIOIMAP.Date.TimeZone(-5678), #line),
            ("+0000", " ", NIOIMAP.Date.TimeZone(0), #line),
            ("-0000", " ", NIOIMAP.Date.TimeZone(0), #line),
        ]
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parseZone)
    }

    func testZone_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: "+12")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseZone(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage, "e has type \(e)")
        }
    }

    func testZone_long() {
        var buffer = TestUtilities.createTestByteBuffer(for: "+12345678\n")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseZone(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testZone_nonsense() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abc")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parseZone(buffer: &buffer, tracker: .testTracker)) { e in
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
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parse2Digit)
    }

    func test2digit_invalid_long() {
        var buffer = TestUtilities.createTestByteBuffer(for: [UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"), UInt8(ascii: "4"), CR])
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parse2Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "\(e)")
        }
    }

    func test2digit_invalid_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: [UInt8(ascii: "1")  ])
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parse2Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

    func test2digit_invalid_data() {
        var buffer = TestUtilities.createTestByteBuffer(for: "ab")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parse2Digit(buffer: &buffer, tracker: .testTracker)) { e in
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
        self.iterateTestInputs(inputs, testFunction: NIOIMAP.GrammarParser.parse4Digit)
    }

    func test4digit_invalid_long() {
        var buffer = TestUtilities.createTestByteBuffer(for: Array(UInt8(ascii: "1")...UInt8(ascii: "7")) + [CR])
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parse4Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

    func test4digit_invalid_short() {
        var buffer = TestUtilities.createTestByteBuffer(for: [UInt8(ascii: "1")])
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parse4Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertEqual(e as? NIOIMAP.ParsingError, .incompleteMessage)
        }
    }

    func test4digit_invalid_data() {
        var buffer = TestUtilities.createTestByteBuffer(for: "abcd")
        XCTAssertThrowsError(try NIOIMAP.GrammarParser.parse4Digit(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }

}
