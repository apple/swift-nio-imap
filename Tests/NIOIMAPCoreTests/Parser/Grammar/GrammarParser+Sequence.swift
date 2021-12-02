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

class GrammarParser_Sequence_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - sequence-set parseSequenceSet

extension GrammarParser_Sequence_Tests {
    func testSequenceSet() {
        self.iterateTests(
            testFunction: GrammarParser.parseSequenceSet,
            validInputs: [
                ("765", " ", .set([765]), #line),
                ("1,2:5,7,9:*", " ", .set([MessageIdentifierRange<SequenceNumber>(1), MessageIdentifierRange<SequenceNumber>(2 ... 5), MessageIdentifierRange<SequenceNumber>(7), MessageIdentifierRange<SequenceNumber>(9...)]), #line),
                ("*", "\r", .set([.all]), #line),
                ("1:2", "\r", .set([1 ... 2]), #line),
                ("1:2,2:3,3:4", "\r", .set([1 ... 2, 2 ... 3, 3 ... 4]), #line),
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

// MARK: - mod-sequence-value parseModifierSequenceValue

extension GrammarParser_Sequence_Tests {
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

extension GrammarParser_Sequence_Tests {
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
