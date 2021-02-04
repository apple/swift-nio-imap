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

class GrammarParser_Commands_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseCommand

extension GrammarParser_Commands_Tests {
    func testParseCommand_valid_any() {
        TestUtilities.withBuffer("a1 NOOP", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.command, .noop)
        }
    }

    func testParseCommand_valid_auth() {
        TestUtilities.withBuffer("a1 CREATE \"mailbox\"", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.command, .create(MailboxName("mailbox"), []))
        }
    }

    func testParseCommand_valid_nonauth() {
        TestUtilities.withBuffer("a1 STARTTLS", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.command, .starttls)
        }
    }

    func testParseCommand_valid_select() {
        TestUtilities.withBuffer("a1 CHECK", terminator: "\r\n") { (buffer) in
            let result = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(result.tag, "a1")
            XCTAssertEqual(result.command, .check)
        }
    }
}

// MARK: - CommandType parseCommandAny

extension GrammarParser_Commands_Tests {
    func testParseCommandAny() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandAny,
            validInputs: [
                ("CAPABILITY", " ", .capability, #line),
                ("LOGOUT", " ", .logout, #line),
                ("NOOP", " ", .noop, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - CommandType parseCommandNonAuth

extension GrammarParser_Commands_Tests {
    func testParseCommandNonAuth() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandNonauth,
            validInputs: [
                ("LOGIN david evans", "\r\n", .login(username: "david", password: "evans"), #line),
                ("AUTHENTICATE some", "\r\n", .authenticate(method: "some", initialClientResponse: nil), #line),
                ("AUTHENTICATE some =", "\r\n", .authenticate(method: "some", initialClientResponse: .empty), #line),
                ("STARTTLS", "\r\n", .starttls, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - CommandType parseCommandAuth

extension GrammarParser_Commands_Tests {
    func testParseCommandAuth() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandAuth,
            validInputs: [
                ("LSUB inbox someList", " ", .lsub(reference: .inbox, pattern: "someList"), #line),
                ("CREATE inbox (something)", " ", .create(.inbox, [.labelled(.init(key: "something", value: nil))]), #line),
                ("NAMESPACE", " ", .namespace, #line),
                ("GETMETADATA INBOX a", " ", .getMetadata(options: [], mailbox: .inbox, entries: ["a"]), #line),
                ("GETMETADATA (MAXSIZE 123) INBOX (a b)", " ", .getMetadata(options: [.maxSize(123)], mailbox: .inbox, entries: ["a", "b"]), #line),
                ("SETMETADATA INBOX (a NIL)", " ", .setMetadata(mailbox: .inbox, entries: [.init(key: "a", value: .init(nil))]), #line),
                ("RESETKEY", "\r", .resetKey(mailbox: nil, mechanisms: []), #line),
                ("RESETKEY INBOX", "\r", .resetKey(mailbox: .inbox, mechanisms: []), #line),
                ("RESETKEY INBOX INTERNAL", "\r", .resetKey(mailbox: .inbox, mechanisms: [.internal]), #line),
                ("RESETKEY INBOX INTERNAL test", "\r", .resetKey(mailbox: .inbox, mechanisms: [.internal, .init("test")]), #line),
                ("GENURLAUTH test INTERNAL", "\r", .genURLAuth([.init(urlRump: "test", mechanism: .internal)]), #line),
                ("GENURLAUTH test INTERNAL test2 INTERNAL", "\r", .genURLAuth([.init(urlRump: "test", mechanism: .internal), .init(urlRump: "test2", mechanism: .internal)]), #line),
                ("URLFETCH test", "\r", .urlFetch(["test"]), #line),
                ("URLFETCH test1 test2", "\r", .urlFetch(["test1", "test2"]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - CommandType parseCommandSelect

extension GrammarParser_Commands_Tests {
    func testParseCommandSelect() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSelect,
            validInputs: [
                ("UNSELECT", " ", .unselect, #line),
                ("unselect", " ", .unselect, #line),
                ("UNSelect", " ", .unselect, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}
