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

class GrammarParser_Fetch_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseFetch

extension GrammarParser_Fetch_Tests {
    func testParseFetch() {
        self.iterateTests(
            testFunction: GrammarParser.parseFetch,
            validInputs: [
                ("FETCH 1:3 ALL", "\r", .fetch([1 ... 3], .all, [:]), #line),
                ("FETCH 2:4 FULL", "\r", .fetch([2 ... 4], .full, [:]), #line),
                ("FETCH 3:5 FAST", "\r", .fetch([3 ... 5], .fast, [:]), #line),
                ("FETCH 4:6 ENVELOPE", "\r", .fetch([4 ... 6], [.envelope], [:]), #line),
                ("FETCH 5:7 (ENVELOPE FLAGS)", "\r", .fetch([5 ... 7], [.envelope, .flags], [:]), #line),
                ("FETCH 3:5 FAST (name)", "\r", .fetch([3 ... 5], .fast, ["name": nil]), #line),
                ("FETCH 1 BODY[TEXT]", "\r", .fetch([1], [.bodySection(peek: false, .init(kind: .text), nil)], [:]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFetchAttribute

extension GrammarParser_Fetch_Tests {
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
                ("X-GM-MSGID", " ", .gmailMessageID, #line),
                ("X-GM-THRID", " ", .gmailThreadID, #line),
                ("X-GM-LABELS", " ", .gmailLabels, #line),
                ("MODSEQ", " ", .modificationSequence, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFetchResponse

extension GrammarParser_Fetch_Tests {
    func testParseFetchResponse() {
        self.iterateTests(
            testFunction: GrammarParser.parseFetchResponse,
            validInputs: [
                ("UID 54", " ", .simpleAttribute(.uid(54)), #line),
                ("RFC822.SIZE 40639", " ", .simpleAttribute(.rfc822Size(40639)), #line),
                ("FLAGS ()", " ", .simpleAttribute(.flags([])), #line),
                ("FLAGS (\\seen)", " ", .simpleAttribute(.flags([.seen])), #line),
                ("FLAGS (\\seen \\answered \\draft)", " ", .simpleAttribute(.flags([.seen, .answered, .draft])), #line),
                (")\r\n", " ", .finish, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFetchResponseStart

extension GrammarParser_Fetch_Tests {
    func testParseFetchResponseStart() {
        self.iterateTests(
            testFunction: GrammarParser.parseFetchResponseStart,
            validInputs: [
                ("* 1 FETCH (", " ", .start(1), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFetchModifier

extension GrammarParser_Fetch_Tests {
    func testParseFetchModifier() {
        self.iterateTests(
            testFunction: GrammarParser.parseFetchModifier,
            validInputs: [
                ("CHANGEDSINCE 2", " ", .changedSince(.init(modificationSequence: 2)), #line),
                ("test", "\r", .other(.init(key: "test", value: nil)), #line),
                ("test 1", " ", .other(.init(key: "test", value: .sequence([1]))), #line),
            ],
            parserErrorInputs: [
                ("1", " ", #line),
            ],
            incompleteMessageInputs: [
                ("CHANGEDSINCE 1", "", #line),
                ("test 1", "", #line),
            ]
        )
    }
}

// MARK: - parseFetchModifierResponse

extension GrammarParser_Fetch_Tests {
    func testParseFetchModifierResponse() {
        self.iterateTests(
            testFunction: GrammarParser.parseFetchModificationResponse,
            validInputs: [
                ("MODSEQ (2)", "", .init(modifierSequenceValue: 2), #line),
            ],
            parserErrorInputs: [
                ("MODSEQ (a)", "", #line),
            ],
            incompleteMessageInputs: [
                ("MODSEQ (1", "", #line),
            ]
        )
    }
}
