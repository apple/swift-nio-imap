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

class GrammarParser_Mailbox_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseMailboxData

extension GrammarParser_Mailbox_Tests {
    func testParseMailboxData() {
        self.iterateTests(
            testFunction: GrammarParser().parseMailboxData,
            validInputs: [
                ("FLAGS (\\seen \\draft)", " ", .flags([.seen, .draft]), #line),
                (
                    "LIST (\\oflag1 \\oflag2) NIL inbox",
                    "\r\n",
                    .list(.init(attributes: [.init("\\oflag1"), .init("\\oflag2")], path: try! .init(name: .inbox), extensions: [:])),
                    #line
                ),
                ("ESEARCH MIN 1 MAX 2", "\r\n", .extendedSearch(.init(correlator: nil, kind: .sequenceNumber, returnData: [.min(1), .max(2)])), #line),
                ("1234 EXISTS", "\r\n", .exists(1234), #line),
                ("5678 RECENT", "\r\n", .recent(5678), #line),
                ("STATUS INBOX ()", "\r\n", .status(.inbox, .init()), #line),
                ("STATUS INBOX (MESSAGES 2)", "\r\n", .status(.inbox, .init(messageCount: 2)), #line),
                (
                    "LSUB (\\seen \\draft) NIL inbox",
                    "\r\n",
                    .lsub(.init(attributes: [.init("\\seen"), .init("\\draft")], path: try! .init(name: .inbox), extensions: [:])),
                    #line
                ),
                ("SEARCH", "\r\n", .search([]), #line),
                ("SEARCH 1", "\r\n", .search([1]), #line),
                ("SEARCH 1 2 3 4 5", "\r\n", .search([1, 2, 3, 4, 5]), #line),
                ("NAMESPACE NIL NIL NIL", "\r\n", .namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), #line),
                ("SEARCH 1 2 3 (MODSEQ 4)", "\r\n", .searchSort(.init(identifiers: [1, 2, 3], modificationSequence: 4)), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMailboxList

extension GrammarParser_Mailbox_Tests {
    func testParseMailboxList() {
        self.iterateTests(
            testFunction: GrammarParser().parseMailboxList,
            validInputs: [
                (
                    "() NIL inbox",
                    "\r",
                    .init(attributes: [], path: try! .init(name: .inbox), extensions: [:]),
                    #line
                ),
                (
                    "() \"d\" inbox",
                    "\r",
                    .init(attributes: [], path: try! .init(name: .inbox, pathSeparator: "d"), extensions: [:]),
                    #line
                ),
                (
                    "(\\oflag1 \\oflag2) NIL inbox",
                    "\r",
                    .init(attributes: [.init("\\oflag1"), .init("\\oflag2")], path: try! .init(name: .inbox), extensions: [:]),
                    #line
                ),
                (
                    "(\\oflag1 \\oflag2) \"d\" inbox",
                    "\r",
                    .init(attributes: [.init("\\oflag1"), .init("\\oflag2")], path: try! .init(name: .inbox, pathSeparator: "d"), extensions: [:]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseMailboxList_invalid_character_incomplete() {
        var buffer = TestUtilities.makeParseBuffer(for: "() \"")
        XCTAssertThrowsError(try GrammarParser().parseMailboxList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is IncompleteMessage)
        }
    }

    func testParseMailboxList_invalid_character() {
        var buffer = TestUtilities.makeParseBuffer(for: "() \"\\\" inbox")
        XCTAssertThrowsError(try GrammarParser().parseMailboxList(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - parseMailboxListFlags

extension GrammarParser_Mailbox_Tests {
    func testParseMailboxListFlags() {
        self.iterateTests(
            testFunction: GrammarParser().parseMailboxListFlags,
            validInputs: [
                ("\\marked", "\r", [.marked], #line),
                ("\\marked \\remote", "\r", [.marked, .remote], #line),
                ("\\marked \\o1 \\o2", "\r", [.marked, .init("\\o1"), .init("\\o2")], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}
