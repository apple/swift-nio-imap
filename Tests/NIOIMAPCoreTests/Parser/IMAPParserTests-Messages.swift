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

// MARK: - atom parseAttributeFlag

extension ParserUnitTests {
    func testParseAttributeFlag() {
        self.iterateTests(
            testFunction: GrammarParser().parseAttributeFlag,
            validInputs: [
                ("\\\\Answered", " ", .answered, #line),
                ("some", " ", .init("some"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFlagExtension

extension ParserUnitTests {
    func testParseFlagExtension_valid() {
        TestUtilities.withParseBuffer("\\Something", terminator: " ") { (buffer) in
            let flagExtension = try GrammarParser().parseFlagExtension(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flagExtension, "\\Something")
        }
    }

    func testParseFlagExtension_invalid_noSlash() {
        var buffer = TestUtilities.makeParseBuffer(for: "Something ")
        XCTAssertThrowsError(try GrammarParser().parseFlagExtension(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - parseFlagKeyword

extension ParserUnitTests {
    func testParseFlagKeyword_valid() {
        TestUtilities.withParseBuffer("keyword", terminator: " ") { (buffer) in
            let flagExtension = try GrammarParser().parseFlagKeyword(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(flagExtension, Flag.Keyword("keyword"))
        }
    }
}

// MARK: - parseFlagList

extension ParserUnitTests {
    func testParseFlagList() {
        self.iterateTests(
            testFunction: GrammarParser().parseFlagList,
            validInputs: [
                ("()", " ", [], #line),
                ("(\\seen)", " ", [.seen], #line),
                ("(\\seen \\answered \\draft)", " ", [.seen, .answered, .draft], #line),
                // iCloud sends a superfluous terminating space
                ("(\\seen \\answered \\draft )", " ", [.seen, .answered, .draft], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseHeaderList

extension ParserUnitTests {
    func testHeaderList_valid_one() {
        TestUtilities.withParseBuffer(#"("field")"#) { (buffer) in
            let array = try GrammarParser().parseHeaderList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(array[0], "field")
        }
    }

    func testHeaderList_valid_many() {
        TestUtilities.withParseBuffer(#"("first" "second" "third")"#) { (buffer) in
            let array = try GrammarParser().parseHeaderList(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(array[0], "first")
            XCTAssertEqual(array[1], "second")
            XCTAssertEqual(array[2], "third")
        }
    }

    func testHeaderList_invalid_none() {
        var buffer = TestUtilities.makeParseBuffer(for: #"()"#)
        XCTAssertThrowsError(try GrammarParser().parseHeaderList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - testParseMediaType

extension ParserUnitTests {
    func testParseMediaType_valid_match() {
        var buffer = TestUtilities.makeParseBuffer(for: #""APPLICATION" "mixed""#)
        do {
            let mediaBasic = try GrammarParser().parseMediaType(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(mediaBasic, Media.MediaType(topLevel: .application, sub: .mixed))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseMediaType_valid_string() {
        var buffer = TestUtilities.makeParseBuffer(for: #""STRING" "related""#)
        do {
            let mediaBasic = try GrammarParser().parseMediaType(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(mediaBasic, Media.MediaType(topLevel: .init("STRING"), sub: .related))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testParseMediaType_valid_invalidString() {
        var buffer = TestUtilities.makeParseBuffer(for: #"hey "something""#)
        XCTAssertThrowsError(try GrammarParser().parseMediaType(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - media-message parseMediaMessage

extension ParserUnitTests {
    func testMediaMessage_valid_rfc() {
        var buffer = TestUtilities.makeParseBuffer(for: "\"MESSAGE\" \"RFC822\"")
        XCTAssertNoThrow(try GrammarParser().parseMediaMessage(buffer: &buffer, tracker: .testTracker))
    }

    func testMediaMessage_valid_mixedCase() {
        var buffer = TestUtilities.makeParseBuffer(for: "\"messAGE\" \"RfC822\"")
        XCTAssertNoThrow(try GrammarParser().parseMediaMessage(buffer: &buffer, tracker: .testTracker))
    }

    func testMediaMessage_invalid() {
        var buffer = TestUtilities.makeParseBuffer(for: "abcdefghijklmnopqrstuvwxyz\n")
        XCTAssertThrowsError(try GrammarParser().parseMediaMessage(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testMediaMessage_invalid_partial() {
        var buffer = TestUtilities.makeParseBuffer(for: "\"messAGE\"")
        XCTAssertThrowsError(try GrammarParser().parseMediaMessage(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is IncompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - media-text parseMediaText

extension ParserUnitTests {
    func testMediaText_valid() {
        TestUtilities.withParseBuffer(#""TEXT" "something""#, terminator: "\n") { (buffer) in
            let media = try GrammarParser().parseMediaText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(media, "something")
        }
    }

    func testMediaText_valid_mixedCase() {
        TestUtilities.withParseBuffer(#""TExt" "something""#, terminator: "\n") { (buffer) in
            let media = try GrammarParser().parseMediaText(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(media, "something")
        }
    }

    func testMediaText_invalid_missingQuotes() {
        var buffer = TestUtilities.makeParseBuffer(for: #"TEXT "something"\n"#)
        XCTAssertThrowsError(try GrammarParser().parseMediaText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError, "e has type \(e)")
        }
    }

    func testMediaText_invalid_missingSubtype() {
        var buffer = TestUtilities.makeParseBuffer(for: #""TEXT""#)
        XCTAssertThrowsError(try GrammarParser().parseMediaText(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is IncompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - parsePartial

extension ParserUnitTests {
    func testParsePartial() {
        self.iterateTests(
            testFunction: GrammarParser().parsePartial,
            validInputs: [
                ("<0.1000000000>", " ", ClosedRange(uncheckedBounds: (0, 999_999_999)), #line),
                ("<0.4294967290>", " ", ClosedRange(uncheckedBounds: (0, 4_294_967_289)), #line),
                ("<1.2>", " ", ClosedRange(uncheckedBounds: (1, 2)), #line),
                ("<4294967290.2>", " ", ClosedRange(uncheckedBounds: (4_294_967_290, 4_294_967_291)), #line),
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
            testFunction: GrammarParser().parseByteRange,
            validInputs: [
                ("1", " ", .init(offset: 1, length: nil), #line),
                ("1.2", " ", .init(offset: 1, length: 2), #line),
            ],
            parserErrorInputs: [
                ("a.1", " ", #line)
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
            testFunction: GrammarParser().parseScopeOption,
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
            testFunction: GrammarParser().parseSection,
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
            testFunction: GrammarParser().parseSectionBinary,
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
            testFunction: GrammarParser().parseSectionPart,
            validInputs: [
                ("1", "\r", [1], #line),
                ("1.2", "\r", [1, 2], #line),
                ("1.2.3.4.5", "\r", [1, 2, 3, 4, 5], #line),
            ],
            parserErrorInputs: [
                ("", "\r", #line)
            ],
            incompleteMessageInputs: [
                ("1.", "", #line)
            ]
        )
    }
}

// MARK: - parseSectionSpecifier

extension ParserUnitTests {
    func testParseSectionSpecifier() {
        self.iterateTests(
            testFunction: GrammarParser().parseSectionSpecifier,
            validInputs: [
                ("HEADER", "\r", .init(kind: .header), #line),
                ("1.2.3", "\r", .init(part: [1, 2, 3], kind: .complete), #line),
                ("1.2.3.HEADER", "\r", .init(part: [1, 2, 3], kind: .header), #line),
            ],
            parserErrorInputs: [
                ("MIME", "\r", #line)
            ],
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
            testFunction: GrammarParser().parseSectionSpecifierKind,
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

// MARK: - parseStoreModifier

extension ParserUnitTests {
    func testParseStoreModifier() {
        self.iterateTests(
            testFunction: GrammarParser().parseStoreModifier,
            validInputs: [
                ("UNCHANGEDSINCE 2", " ", .unchangedSince(.init(modificationSequence: 2)), #line),
                ("test", "\r", .other(.init(key: "test", value: nil)), #line),
                ("test 1", " ", .other(.init(key: "test", value: .sequence(.set([1])))), #line),
            ],
            parserErrorInputs: [
                ("1", " ", #line)
            ],
            incompleteMessageInputs: [
                ("UNCHANGEDSINCE 1", "", #line),
                ("test 1", "", #line),
            ]
        )
    }
}

// MARK: - parseStoreData

extension ParserUnitTests {
    func testParseStoreData() {
        self.iterateTests(
            testFunction: GrammarParser().parseStoreData,
            validInputs: [
                ("+FLAGS (foo)", "\r", .flags(.add(silent: false, list: [.init("foo")])), #line),
                ("-X-GM-LABELS (bar)", "\r", .gmailLabels(.remove(silent: false, gmailLabels: [.init("bar")])), #line),
            ],
            parserErrorInputs: [
                ("+SOMETHING \\answered", "\r", #line)
            ],
            incompleteMessageInputs: [
                ("+", "", #line),
                ("-", "", #line),
                ("", "", #line),
            ]
        )
    }
}

// MARK: - parseStoreFlags

extension ParserUnitTests {
    func testParseStoreFlags() {
        self.iterateTests(
            testFunction: GrammarParser().parseStoreFlags,
            validInputs: [
                ("+FLAGS ()", "\r", .add(silent: false, list: []), #line),
                ("-FLAGS ()", "\r", .remove(silent: false, list: []), #line),
                ("FLAGS ()", "\r", .replace(silent: false, list: []), #line),
                ("+FLAGS.SILENT ()", "\r", .add(silent: true, list: []), #line),
                ("+FLAGS.SILENT (\\answered \\seen)", "\r", .add(silent: true, list: [.answered, .seen]), #line),
                ("+FLAGS.SILENT \\answered \\seen", "\r", .add(silent: true, list: [.answered, .seen]), #line),
            ],
            parserErrorInputs: [
                ("FLAGS.SILEN \\answered", "\r", #line)
            ],
            incompleteMessageInputs: [
                ("+FLAGS ", "", #line),
                ("-FLAGS ", "", #line),
                ("FLAGS ", "", #line),
            ]
        )
    }
}

// MARK: - parseStoreGmailLabels

extension ParserUnitTests {
    func testParseStoreGmailLabels() {
        self.iterateTests(
            testFunction: GrammarParser().parseStoreGmailLabels,
            validInputs: [
                ("+X-GM-LABELS (foo)", "\r", .add(silent: false, gmailLabels: [.init("foo")]), #line),
                (
                    "-X-GM-LABELS (foo bar)", "\r", .remove(silent: false, gmailLabels: [.init("foo"), .init("bar")]),
                    #line
                ),
                (
                    "X-GM-LABELS (foo bar boo far)", "\r",
                    .replace(silent: false, gmailLabels: [.init("foo"), .init("bar"), .init("boo"), .init("far")]),
                    #line
                ),
                ("X-GM-LABELS.SILENT (foo)", "\r", .replace(silent: true, gmailLabels: [.init("foo")]), #line),
            ],
            parserErrorInputs: [
                ("+X-GM-LABEL.SILEN (foo)", "\r", #line)
            ],
            incompleteMessageInputs: [
                ("+X-GM-LABELS ", "", #line),
                ("-X-GM-LABELS ", "", #line),
                ("X-GM-LABELS ", "", #line),
            ]
        )
    }
}
