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

// MARK: - seq-number parseSequenceNumber

extension GrammarParser_Sequence_Tests {
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

extension GrammarParser_Sequence_Tests {
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

extension GrammarParser_Sequence_Tests {
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
