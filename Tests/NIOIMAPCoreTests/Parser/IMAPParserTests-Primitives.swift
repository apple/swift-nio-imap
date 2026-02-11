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

// MARK: - parseAtom

extension ParserUnitTests {
    func testParseAtom() {
        let b1 = ByteBuffer(string: "test\r")
        var pb1 = ParseBuffer(b1)
        XCTAssertEqual(try GrammarParser().parseAtom(buffer: &pb1, tracker: .testTracker), "test")
    }
}

// MARK: - atom parseAtom

extension ParserUnitTests {
    func testAtom_valid() {
        TestUtilities.withParseBuffer("hello", terminator: " ") { (buffer) in
            let atom = try GrammarParser().parseAtom(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(atom, "hello")
        }
    }

    func testAtom_invalid_incomplete() {
        var buffer = TestUtilities.makeParseBuffer(for: "hello")
        XCTAssertThrowsError(try GrammarParser().parseAtom(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is IncompleteMessage)
        }
    }

    func testAtom_invalid_short() {
        var buffer = TestUtilities.makeParseBuffer(for: " ")
        XCTAssertThrowsError(try GrammarParser().parseAtom(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - parseBase64

extension ParserUnitTests {
    func testParseBase64Terminal_valid_short() {
        TestUtilities.withParseBuffer("YWFh", terminator: " ") { (buffer) in
            let result = try GrammarParser().parseBase64(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, "aaa")
        }
    }

    func testParseBase64Terminal_valid_short_terminal() {
        TestUtilities.withParseBuffer("YQ==", terminator: " ") { (buffer) in
            let result = try GrammarParser().parseBase64(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result, "a")
        }
    }
}

// MARK: - parseCharset

extension ParserUnitTests {
    func testParseCharset() {
        self.iterateTests(
            testFunction: GrammarParser().parseCharset,
            validInputs: [
                ("UTF8", " ", "UTF8", #line),
                ("\"UTF8\"", " ", "UTF8", #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseNil

extension ParserUnitTests {
    func testParseNil() {
        self.iterateTests(
            testFunction: GrammarParser().parseNil,
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

// MARK: - parseNewline

extension ParserUnitTests {
    func testParseNewline() {
        self.iterateTests(
            testFunction: PL.parseNewline,
            validInputs: [
                ("\n", "", #line),
                ("\r", "", #line),
                ("\r\n", "", #line),
            ],
            parserErrorInputs: [
                ("\\", " ", #line)
            ],
            incompleteMessageInputs: [
                ("", "", #line)
            ]
        )
    }
}

// MARK: - astring parseNString

extension ParserUnitTests {
    func testParseAString() {
        // 1*ASTRING-CHAR / quoted / literal
        self.iterateTests(
            testFunction: GrammarParser().parseAString,
            validInputs: [
                ("NIL", " ", "NIL", #line),
                ("A", " ", "A", #line),
                ("Foo", " ", "Foo", #line),
                ("a]b", " ", "a]b", #line),
                ("{3}\r\nabc", "", "abc", #line),
                ("{3+}\r\nabc", "", "abc", #line),
                (#""abc""#, "", "abc", #line),
                (#""a\\bc""#, "", #"a\bc"#, #line),
                (#""a\"bc""#, "", #"a"bc"#, #line),
                (#""København""#, " ", "København", #line),
            ],
            parserErrorInputs: [
                (#""a\bc""#, "", #line)
            ],
            incompleteMessageInputs: [
                ("\"", "", #line),
                (#""a\""#, "", #line),
                ("{1}\r\n", "", #line),
            ]
        )
    }
}

// MARK: - nstring parseNString

extension ParserUnitTests {
    func testParseNString() {
        self.iterateTests(
            testFunction: GrammarParser().parseNString,
            validInputs: [
                ("NIL", "", nil, #line),
                ("{3}\r\nabc", "", "abc", #line),
                ("{3+}\r\nabc", "", "abc", #line),
                (#""abc""#, "", "abc", #line),
                (#""a\\bc""#, "", #"a\bc"#, #line),
                (#""a\"bc""#, "", #"a"bc"#, #line),
                (#""København""#, "", "København", #line),
            ],
            parserErrorInputs: [
                ("abc", " ", #line),
                (#""a\bc""#, "", #line),
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
            testFunction: GrammarParser().parseNumber,
            validInputs: [
                ("1234", " ", 1234, #line),
                ("10", " ", 10, #line),
                ("0", " ", 0, #line),
            ],
            parserErrorInputs: [
                ("abcd", " ", #line)
            ],
            incompleteMessageInputs: [
                ("1234", "", #line)
            ]
        )
    }
}

// MARK: - nz-number parseNZNumber

extension ParserUnitTests {
    func testNZNumber() {
        self.iterateTests(
            testFunction: GrammarParser().parseNZNumber,
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
                ("1234", "", #line)
            ]
        )
    }
}

// MARK: - parseText

extension ParserUnitTests {
    func testParseText() {
        let invalid: Set<UInt8> = [UInt8(ascii: "\r"), .init(ascii: "\n"), 0]
        let valid = Array(Set((UInt8.min...UInt8.max)).subtracting(invalid).subtracting(128...UInt8.max))
        let validString = String(decoding: valid, as: UTF8.self)
        self.iterateTests(
            testFunction: GrammarParser().parseText,
            validInputs: [
                (validString, "\r", ByteBuffer(string: validString), #line)
            ],
            parserErrorInputs: [
                ("\r", "", #line),
                ("\n", "", #line),
                (String(decoding: (UInt8(128)...UInt8.max), as: UTF8.self), " ", #line),
            ],
            incompleteMessageInputs: [
                ("a", "", #line)
            ]
        )
    }
}

// MARK: - parseUchar

extension ParserUnitTests {
    func testParseUchar() {
        self.iterateTests(
            testFunction: GrammarParser().parseUChar,
            validInputs: [
                ("%00", "", [UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "0")], #line),
                ("%0A", "", [UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "A")], #line),
                ("%1F", "", [UInt8(ascii: "%"), UInt8(ascii: "1"), UInt8(ascii: "F")], #line),
                ("%FF", "", [UInt8(ascii: "%"), UInt8(ascii: "F"), UInt8(ascii: "F")], #line),
            ],
            parserErrorInputs: [
                ("%GG", " ", #line)
            ],
            incompleteMessageInputs: [
                ("%", "", #line)
            ]
        )
    }
}

// MARK: - parseAchar

extension ParserUnitTests {
    func testParseAchar() {
        self.iterateTests(
            testFunction: GrammarParser().parseAChar,
            validInputs: [
                ("%00", "", [UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "0")], #line),
                ("&", "", [UInt8(ascii: "&")], #line),
                ("=", "", [UInt8(ascii: "=")], #line),
            ],
            parserErrorInputs: [
                ("£", " ", #line)
            ],
            incompleteMessageInputs: [
                ("", "", #line)
            ]
        )
    }
}

// MARK: - parseBchar

extension ParserUnitTests {
    func testParseBchar() {
        self.iterateTests(
            testFunction: GrammarParser().parseBChar,
            validInputs: [
                ("%00", "", [UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "0")], #line),
                ("@", "", [UInt8(ascii: "@")], #line),
                (":", "", [UInt8(ascii: ":")], #line),
                ("/", "", [UInt8(ascii: "/")], #line),
            ],
            parserErrorInputs: [
                ("£", " ", #line)
            ],
            incompleteMessageInputs: [
                ("", "", #line)
            ]
        )
    }
}

// MARK: - 2DIGIT

extension ParserUnitTests {
    func test2digit() {
        self.iterateTests(
            testFunction: GrammarParser().parse2Digit,
            validInputs: [
                ("12", " ", 12, #line)
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
            testFunction: GrammarParser().parse4Digit,
            validInputs: [
                ("1234", " ", 1234, #line)
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

// MARK: - tag parseTag

extension ParserUnitTests {
    func testTag() {
        self.iterateTests(
            testFunction: GrammarParser().parseTag,
            validInputs: [
                ("abc", "\r", "abc", #line),
                ("abc", "+", "abc", #line),
            ],
            parserErrorInputs: [
                ("+", "", #line)
            ],
            incompleteMessageInputs: [
                ("", "", #line)
            ]
        )
    }
}

// MARK: - vendor-token

extension ParserUnitTests {
    func testParseVendorToken() {
        self.iterateTests(
            testFunction: GrammarParser().parseVendorToken,
            validInputs: [
                ("token", "-atom ", "token", #line),
                ("token", " ", "token", #line),
            ],
            parserErrorInputs: [
                ("1a", " ", #line)
            ],
            incompleteMessageInputs: [
                ("token", "", #line)
            ]
        )
    }
}
