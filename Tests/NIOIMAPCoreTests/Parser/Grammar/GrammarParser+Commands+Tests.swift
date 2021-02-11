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

// MARK: - Top level

extension GrammarParser_Commands_Tests {

    // Make sure we isolate the tag from the command
    func testParseTaggedCommand() {
        self.iterateTests(
            testFunction: GrammarParser.parseTaggedCommand,
            validInputs: [
                ("a CAPABILITY", "\r", .init(tag: "a", command: .capability), #line),
                ("1 CAPABILITY", "\r", .init(tag: "1", command: .capability), #line),
                ("a1 CAPABILITY", "\r", .init(tag: "a1", command: .capability), #line),
            ],
            parserErrorInputs: [
                ("(", "CAPABILITY", #line),
            ],
            incompleteMessageInputs: [
                ("a CAPABILITY", "", #line),
            ]
        )
    }

    // Minimum 1 valid test for each command to ensure all commands are supported
    // dedicated unit tests areprovided for each sub-parser
    func testParseCommand() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommand,
            validInputs: [
                ("CAPABILITY", "\r", .capability, #line),
                ("LOGOUT", "\r", .logout, #line),
                ("NOOP", "\r", .noop, #line),
                ("STARTTLS", "\r", .starttls, #line),
                ("CHECK", "\r", .check, #line),
                ("CLOSE", "\r", .close, #line),
                ("EXPUNGE", "\r", .expunge, #line),
                ("UNSELECT", "\r", .unselect, #line),
                ("IDLE", "\r", .idleStart, #line),
                ("NAMESPACE", "\r", .namespace, #line),
                ("ID NIL", "\r", .id(.init()), #line),
                ("ENABLE BINARY", "\r", .enable([.binary]), #line),
                ("GETMETADATA INBOX (test)", "\r", .getMetadata(options: [], mailbox: .inbox, entries: ["test"]), #line),
                ("SETMETADATA INBOX (test NIL)", "\r", .setMetadata(mailbox: .inbox, entries: ["test": nil]), #line),
                ("RESETKEY INBOX INTERNAL", "\r", .resetKey(mailbox: .inbox, mechanisms: [.internal]), #line),
                ("GENURLAUTH rump INTERNAL", "\r", .genURLAuth([.init(urlRump: "rump", mechanism: .internal)]), #line),
                ("URLFETCH test", "\r", .urlFetch(["test"]), #line),
                ("COPY 1 INBOX", "\r", .copy([1], .inbox), #line),
                ("DELETE INBOX", "\r", .delete(.inbox), #line),
                ("MOVE $ INBOX", "\r", .move(.lastCommand, .inbox), #line),
                ("SEARCH ALL", "\r", .search(key: .all, charset: nil, returnOptions: []), #line),
                ("ESEARCH ALL", "\r", .esearch(.init(key: .all)), #line),
                ("STORE $ +FLAGS \\Answered", "\r", .store(.lastCommand, [], .add(silent: false, list: [.answered])), #line),
                ("EXAMINE INBOX", "\r", .examine(.inbox, .init()), #line),
                ("LIST INBOX test", "\r", .list(nil, reference: .inbox, .mailbox("test"), []), #line),
                ("LSUB INBOX test", "\r", .lsub(reference: .inbox, pattern: "test"), #line),
                ("RENAME INBOX inbox2", "\r", .rename(from: .inbox, to: .init("inbox2"), params: .init()), #line),
                ("SELECT INBOX", "\r", .select(.inbox, []), #line),
                ("STATUS INBOX (SIZE)", "\r", .status(.inbox, [.size]), #line),
                ("SUBSCRIBE INBOX", "\r", .subscribe(.inbox), #line),
                ("UNSUBSCRIBE INBOX", "\r", .unsubscribe(.inbox), #line),
                ("UID EXPUNGE 1:2", "\r", .uidExpunge([1...2]), #line),
                ("FETCH $ (FLAGS)", "\r", .fetch(.lastCommand, [.flags], .init()), #line),
                ("LOGIN \"user\" \"password\"", "\r", .login(username: "user", password: "password"), #line),
                ("AUTHENTICATE GSSAPI", "\r", .authenticate(method: "GSSAPI", initialClientResponse: nil), #line),
                ("CREATE test", "\r", .create(.init("test"), []), #line),
                ("GETQUOTA root", "\r", .getQuota(.init("root")), #line),
                ("GETQUOTAROOT INBOX", "\r", .getQuotaRoot(.inbox), #line),
                ("SETQUOTA ROOT (resource 123)", "\r", .setQuota(.init("ROOT"), [.init(resourceName: "resource", limit: 123)]), #line),
            ],
            parserErrorInputs: [
                ("123", "", #line),
                ("NOTHING", "\r", #line),
                ("...", "\r", #line),
            ],
            incompleteMessageInputs: [
                ("CAPABILITY", "", #line),
                ("CHECK", "", #line),
            ]
        )
    }

}

// MARK: - Command suffixes
extension GrammarParser_Commands_Tests {

    func testParseCommandSuffix_id() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_enable() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [
                ("LSUB inbox someList", " ", .lsub(reference: .inbox, pattern: "someList"), #line),
                ("CREATE inbox (something)", " ", .create(.inbox, [.labelled(.init(key: "something", value: nil))]), #line),
                ("NAMESPACE", " ", .namespace, #line),
                ("GETMETADATA INBOX a", " ", .getMetadata(options: [], mailbox: .inbox, entries: ["a"]), #line),
                ("GETMETADATA (MAXSIZE 123) INBOX (a b)", " ", .getMetadata(options: [.maxSize(123)], mailbox: .inbox, entries: ["a", "b"]), #line),
                ("SETMETADATA INBOX (a NIL)", " ", .setMetadata(mailbox: .inbox, entries: ["a": .init(nil)]), #line),
                ("RESETKEY", "\r", .resetKey(mailbox: nil, mechanisms: []), #line),
                ("RESETKEY INBOX", "\r", .resetKey(mailbox: .inbox, mechanisms: []), #line),
                ("RESETKEY INBOX INTERNAL", "\r", .resetKey(mailbox: .inbox, mechanisms: [.internal]), #line),
                ("RESETKEY INBOX INTERNAL test", "\r", .resetKey(mailbox: .inbox, mechanisms: [.internal, .init("test")]), #line),
                ("GENURLAUTH test INTERNAL", "\r", .generateAuthorizedURL([.init(urlRump: "test", mechanism: .internal)]), #line),
                ("GENURLAUTH test INTERNAL test2 INTERNAL", "\r", .generateAuthorizedURL([.init(urlRump: "test", mechanism: .internal), .init(urlRump: "test2", mechanism: .internal)]), #line),
                ("URLFETCH test", "\r", .urlFetch(["test"]), #line),
                ("URLFETCH test1 test2", "\r", .urlFetch(["test1", "test2"]), #line),
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_getMetadata() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_setMetadata() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_resetKey() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_genURLAuth() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_urlFetch() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_copy() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_delete() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_move() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_search() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_esearch() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_store() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_examine() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_list() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_LSUB() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_rename() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_select() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_status() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_subscribe() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_unsubscribe() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_uid() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_fetch() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_login() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_authenticate() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_create() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_getQuota() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_setQuota() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

    func testParseCommandSuffix_getQuotaRoot() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [

            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
            ]
        )
    }

}
