//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class PartialRange_Tests: EncodeTestClass, _ParserTestHelpers {}

// MARK: - Encoding

extension PartialRange_Tests {
    func testEncode() {
        let inputs: [(PartialRange, String, UInt)] = [
            (.first(1 ... 1), "1:1", #line),
            (.first(100 ... 200), "100:200", #line),
            (.last(1 ... 1), "-1:-1", #line),
            (.last(100 ... 200), "-100:-200", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writePartialRange($0) })
    }

    func testParse() {
        self.iterateTests(
            testFunction: GrammarParser().parsePartialRange,
            validInputs: [
                ("1:2", " ", .first(1 ... 2), #line),
                ("1:1", " ", .first(1 ... 1), #line),
                ("100:200", " ", .first(100 ... 200), #line),
                ("200:100", " ", .first(100 ... 200), #line),
                ("333:333", " ", .first(333 ... 333), #line),
                ("1234567:2345678", " ", .first(1234567 ... 2345678), #line),
                ("-1:-2", " ", .last(1 ... 2), #line),
                ("-1:-1", " ", .last(1 ... 1), #line),
                ("-100:-200", " ", .last(100 ... 200), #line),
                ("-200:-100", " ", .last(100 ... 200), #line),
                ("-333:-333", " ", .last(333 ... 333), #line),
                ("-1234567:-2345678", " ", .last(1234567 ... 2345678), #line),
            ],
            parserErrorInputs: [
                ("1", " ", #line),
                ("1:", " ", #line),
                ("10:-20", " ", #line),
                ("-10:20", " ", #line),
                ("1:*", " ", #line),
                ("*", " ", #line),
                ("a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("1", "", #line),
                ("1:", "", #line),
                ("1:2", "", #line),
            ]
        )
    }
}
