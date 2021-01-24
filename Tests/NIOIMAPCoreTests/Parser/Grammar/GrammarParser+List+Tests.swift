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

class GrammarParser_List_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseList

extension GrammarParser_List_Tests {
    func testParseList() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommand,
            validInputs: [
                (#"LIST "" """#, "\r", .list(nil, reference: MailboxName(""), .mailbox(""), []), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - list-wildcard parseListWildcard

extension GrammarParser_List_Tests {
    func testWildcard() {
        let valid: Set<UInt8> = [UInt8(ascii: "%"), UInt8(ascii: "*")]
        let invalid: Set<UInt8> = Set(UInt8.min ... UInt8.max).subtracting(valid)

        for v in valid {
            var buffer = TestUtilities.makeParseBuffer(for: String(decoding: [v], as: UTF8.self))
            do {
                let str = try GrammarParser.parseListWildcards(buffer: &buffer, tracker: .testTracker)
                XCTAssertEqual(str[str.startIndex], Character(Unicode.Scalar(v)))
            } catch {
                XCTFail("\(v) doesn't satisfy \(error)")
                return
            }
        }
        for v in invalid {
            var buffer = TestUtilities.makeParseBuffer(for: String(decoding: [v], as: UTF8.self))
            XCTAssertThrowsError(try GrammarParser.parseListWildcards(buffer: &buffer, tracker: .testTracker)) { e in
                XCTAssertTrue(e is ParserError)
            }
        }
    }
}
