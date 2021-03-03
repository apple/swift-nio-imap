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

class GrammarParser_Append_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - append

extension GrammarParser_Append_Tests {}

// MARK: - parseAppendData

extension GrammarParser_Append_Tests {
    func testParseAppendData() {
        self.iterateTests(
            testFunction: GrammarParser.parseAppendData,
            validInputs: [
                ("{123}\r\n", "hello", .init(byteCount: 123), #line),
                ("~{456}\r\n", "hello", .init(byteCount: 456, withoutContentTransferEncoding: true), #line),
                ("{0}\r\n", "hello", .init(byteCount: 0), #line),
                ("~{\(Int.max)}\r\n", "hello", .init(byteCount: .max, withoutContentTransferEncoding: true), #line),
                ("{123+}\r\n", "hello", .init(byteCount: 123), #line),
                ("~{456+}\r\n", "hello", .init(byteCount: 456, withoutContentTransferEncoding: true), #line),
                ("{0+}\r\n", "hello", .init(byteCount: 0), #line),
                ("~{\(Int.max)+}\r\n", "hello", .init(byteCount: .max, withoutContentTransferEncoding: true), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testNegativeAppendDataDoesNotParse() {
        TestUtilities.withBuffer("{-1}\r\n", shouldRemainUnchanged: true) { buffer in
            XCTAssertThrowsError(try GrammarParser.parseAppendData(buffer: &buffer, tracker: .testTracker)) { error in
                XCTAssertNotNil(error as? ParserError)
            }
        }
    }

    func testHugeAppendDataDoesNotParse() {
        let oneAfterMaxInt = "\(UInt(Int.max) + 1)"
        TestUtilities.withBuffer("{\(oneAfterMaxInt)}\r\n", shouldRemainUnchanged: true) { buffer in
            XCTAssertThrowsError(try GrammarParser.parseAppendData(buffer: &buffer, tracker: .testTracker)) { error in
                XCTAssertNotNil(error as? ParserError)
            }
        }
    }
}

// MARK: - parseAppendMessage

extension GrammarParser_Append_Tests {
    // NOTE: Spec is ambiguous when parsing `append-data`, which may contain `append-data-ext`, which is the same as `append-ext`, which is inside `append-opts`
    func testParseMessage() {
        self.iterateTests(
            testFunction: GrammarParser.parseAppendMessage,
            validInputs: [
                (
                    " (\\Answered) {123}\r\n",
                    "test",
                    .init(options: .init(flagList: [.answered], internalDate: nil, extensions: [:]), data: .init(byteCount: 123)),
                    #line
                ),
                (
                    " (\\Answered) ~{456}\r\n",
                    "test",
                    .init(options: .init(flagList: [.answered], internalDate: nil, extensions: [:]), data: .init(byteCount: 456, withoutContentTransferEncoding: true)),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseAppendOptions

extension GrammarParser_Append_Tests {
    func testParseAppendOptions() throws {
        let components = InternalDate.Components(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, timeZoneMinutes: 0)
        let date = InternalDate(components!)

        self.iterateTests(
            testFunction: GrammarParser.parseAppendOptions,
            validInputs: [
                ("", "\r", .init(flagList: [], internalDate: nil, extensions: [:]), #line),
                (" (\\Answered)", "\r", .init(flagList: [.answered], internalDate: nil, extensions: [:]), #line),
                (
                    " \"25-jun-1994 01:02:03 +0000\"",
                    "\r",
                    .init(flagList: [], internalDate: date, extensions: [:]),
                    #line
                ),
                (
                    " name1 1:2",
                    "\r",
                    .init(flagList: [], internalDate: nil, extensions: ["name1": .sequence(.set(.init(1 ... 2)))]),
                    #line
                ),
                (
                    " name1 1:2 name2 2:3 name3 3:4",
                    "\r",
                    .init(flagList: [], internalDate: nil, extensions: [
                        "name1": .sequence(.set(.init(1 ... 2))),
                        "name2": .sequence(.set(.init(2 ... 3))),
                        "name3": .sequence(.set(.init(3 ... 4))),
                    ]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}
