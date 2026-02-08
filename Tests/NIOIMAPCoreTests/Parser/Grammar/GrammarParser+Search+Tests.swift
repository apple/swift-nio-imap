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

class GrammarParser_Search_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseSearchModifierSequenceExtension

extension GrammarParser_Search_Tests {
    func testParseSearchModifierSequenceExtension() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchModificationSequenceExtension,
            validInputs: [
                (" \"/flags/\\\\Seen\" all", "", .init(key: .init(flag: .seen), value: .all), #line)
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-data` parseSearchReturnData

extension GrammarParser_Search_Tests {
    func testParseSearchReturnData() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnData,
            validInputs: [
                ("MIN 1", "\r", .min(1), #line),
                ("MAX 2", "\r", .max(2), #line),
                ("ALL 3", "\r", .all(.set([3])), #line),
                ("ALL 3,4,5", "\r", .all(.set([3, 4, 5])), #line),
                ("COUNT 4", "\r", .count(4), #line),
                ("MODSEQ 4", "\r", .modificationSequence(4), #line),
                ("PARTIAL (1:10 108595)", "\r", .partial(.first(1...10), [108595]), #line),
                ("PARTIAL (-2:-20 20:24,108595)", "\r", .partial(.last(2...20), [20...24, 108595]), #line),
                ("PARTIAL (1:10 NIL)", "\r", .partial(.first(1...10), []), #line),
                ("modifier 5", "\r", .dataExtension(.init(key: "modifier", value: .sequence(.set([5])))), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `ret-data-partial` parseSearchReturnData_partial

extension GrammarParser_Search_Tests {
    func testParseSearchReturnDataPartial() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnData_partial,
            validInputs: [
                ("PARTIAL (23500:24000 67,100:102)", "\r", .partial(.first(23_500...24_000), [67, 100...102]), #line),
                ("PARTIAL (-55:-700 NIL)", "\r", .partial(.last(55...700), []), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-opts` parseSearchReturnOptions

extension GrammarParser_Search_Tests {
    func testParseSearchReturnOptions() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnOptions,
            validInputs: [
                (" RETURN (ALL)", "\r", [.all], #line),
                (" RETURN (MIN MAX COUNT)", "\r", [.min, .max, .count], #line),
                (
                    " RETURN (m1 m2)", "\r",
                    [
                        .optionExtension(.init(key: "m1", value: nil)),
                        .optionExtension(.init(key: "m2", value: nil)),
                    ], #line
                ),
                (" RETURN (PARTIAL 23500:24000)", "\r", [.partial(.first(23_500...24_000))], #line),
                (" RETURN (MIN PARTIAL -1:-100 MAX)", "\r", [.min, .partial(.last(1...100)), .max], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-opt-ext` parseSearchReturnOptionExtension

extension GrammarParser_Search_Tests {
    func testParseSearchReturnOptionExtension() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnOptionExtension,
            validInputs: [
                ("modifier", "\r", .init(key: "modifier", value: nil), #line),
                ("modifier 4", "\r", .init(key: "modifier", value: .sequence(.set([4]))), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: [
                ("modifier ", "", #line)
            ]
        )
    }
}

// MARK: - parseSearchSortModifierSequence

extension GrammarParser_Search_Tests {
    func testParseSearchSortModifierSequence() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchSortModificationSequence,
            validInputs: [
                ("(MODSEQ 123)", "\r", 123, #line)
            ],
            parserErrorInputs: [
                ("(MODSEQ a)", "", #line)
            ],
            incompleteMessageInputs: [
                ("(MODSEQ ", "", #line),
                ("(MODSEQ 111", "", #line),
            ]
        )
    }
}
