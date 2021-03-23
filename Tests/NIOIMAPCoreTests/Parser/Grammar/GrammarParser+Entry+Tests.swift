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

class GrammarParser_Entry_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseEntryValue

extension GrammarParser_Entry_Tests {
    func testParseEntryValue() {
        self.iterateTests(
            testFunction: GrammarParser.parseEntryValue,
            validInputs: [
                ("\"name\" \"value\"", "", .init(key: "name", value: .init("value")), #line),
                ("\"name\" NIL", "", .init(key: "name", value: .init(nil)), #line),
            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }
}

// MARK: - parseEntryValues

extension GrammarParser_Entry_Tests {
    func testParseEntryValues() {
        self.iterateTests(
            testFunction: GrammarParser.parseEntryValues,
            validInputs: [
                (
                    "(\"name\" \"value\")",
                    "",
                    ["name": .init("value")],
                    #line
                ),
                (
                    "(\"name1\" \"value1\" \"name2\" \"value2\")",
                    "",
                    ["name1": .init("value1"), "name2": .init("value2")],
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

// MARK: - parseEntries

extension GrammarParser_Entry_Tests {
    func testParseEntries() {
        self.iterateTests(
            testFunction: GrammarParser.parseEntries,
            validInputs: [
                ("\"name\"", "", ["name"], #line),
                ("(\"name\")", "", ["name"], #line),
                ("(\"name1\" \"name2\")", "", ["name1", "name2"], #line),
            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }
}

// MARK: - parseEntryList

extension GrammarParser_Entry_Tests {
    func testParseEntryList() {
        self.iterateTests(
            testFunction: GrammarParser.parseEntryList,
            validInputs: [
                ("\"name\"", "\r", ["name"], #line),
                ("\"name1\" \"name2\"", "\r", ["name1", "name2"], #line),
            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }
}

// MARK: - parseEntryFlagName

extension GrammarParser_Entry_Tests {
    func testParseEntryFlagName() {
        self.iterateTests(
            testFunction: GrammarParser.parseEntryFlagName,
            validInputs: [
                ("\"/flags/\\\\Answered\"", "", .init(flag: .answered), #line),
            ],
            parserErrorInputs: [
                ("/flags/\\Answered", "", #line),
            ],
            incompleteMessageInputs: [
                ("\"/flags", "", #line),
            ]
        )
    }
}

// MARK: - entry-type-resp parseEntryTypeResponse

extension GrammarParser_Entry_Tests {
    func testParseEntryTypeRequest() {
        self.iterateTests(
            testFunction: GrammarParser.parseEntryKindRequest,
            validInputs: [
                ("all", " ", .all, #line),
                ("ALL", " ", .all, #line),
                ("aLL", " ", .all, #line),
                ("priv", " ", .private, #line),
                ("PRIV", " ", .private, #line),
                ("shared", " ", .shared, #line),
                ("SHARED", " ", .shared, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - entry-type-resp parseEntryTypeResponse

extension GrammarParser_Entry_Tests {
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
