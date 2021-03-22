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

class GrammarParser_UID_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseUIDValidity

extension GrammarParser_UID_Tests {
    func testParseUIDValidity() {
        self.iterateTests(
            testFunction: GrammarParser.parseUIDValidity,
            validInputs: [
                ("1", " ", 1, #line),
                ("12", " ", 12, #line),
                ("123", " ", 123, #line),
            ],
            parserErrorInputs: [
                ("0", " ", #line),
            ],
            incompleteMessageInputs: [
                ("1", "", #line),
            ]
        )
    }
}

// MARK: - parseUIDRange

extension GrammarParser_UID_Tests {
    func testUIDRange() {
        self.iterateTests(
            testFunction: GrammarParser.parseUIDRange,
            validInputs: [
                ("*", "\r\n", UIDRange(.max), #line),
                ("1:*", "\r\n", UIDRange.all, #line),
                ("12:34", "\r\n", UIDRange(12 ... 34), #line),
                ("12:*", "\r\n", UIDRange(12 ... .max), #line),
                ("1:34", "\r\n", UIDRange((.min) ... 34), #line),
            ],
            parserErrorInputs: [
                ("!", " ", #line),
                ("a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("1", "", #line),
            ]
        )
    }
}

// MARK: - parseUIDSet

extension GrammarParser_UID_Tests {
    func testParseUIDSet() {
        self.iterateTests(
            testFunction: GrammarParser.parseUIDSet,
            validInputs: [
                ("1234", "\r\n", UIDSet(1234 as UID), #line),
                ("12:34", "\r\n", UIDSet(UIDRange(12 ... 34)), #line),
                ("1,2,34:56,78:910,11", "\r\n", UIDSet([
                    UIDRange(1),
                    UIDRange(2),
                    UIDRange(34 ... 56),
                    UIDRange(78 ... 910),
                    UIDRange(11),
                ]), #line),
                ("*", "\r\n", UIDSet(UIDRange(.max)), #line),
                ("1:*", "\r\n", .all, #line),
            ],
            parserErrorInputs: [
                ("a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("1234", "", #line),
                ("", "", #line),
            ]
        )
    }
}
