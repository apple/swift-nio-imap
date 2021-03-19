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
                ("GENURLAUTH rump INTERNAL", "\r", .generateAuthorizedURL([.init(urlRump: "rump", mechanism: .internal)]), #line),
                ("URLFETCH test", "\r", .urlFetch(["test"]), #line),
                ("COPY 1 INBOX", "\r", .copy(.set([1]), .inbox), #line),
                ("DELETE INBOX", "\r", .delete(.inbox), #line),
                ("MOVE $ INBOX", "\r", .move(.lastCommand, .inbox), #line),
                ("SEARCH ALL", "\r", .search(key: .all, charset: nil, returnOptions: []), #line),
                ("ESEARCH ALL", "\r", .extendedsearch(.init(key: .all)), #line),
                ("STORE $ +FLAGS \\Answered", "\r", .store(.lastCommand, [], .add(silent: false, list: [.answered])), #line),
                ("EXAMINE INBOX", "\r", .examine(.inbox, .init()), #line),
                ("LIST INBOX test", "\r", .list(nil, reference: .inbox, .mailbox("test"), []), #line),
                ("LSUB INBOX test", "\r", .lsub(reference: .inbox, pattern: "test"), #line),
                ("RENAME INBOX inbox2", "\r", .rename(from: .inbox, to: .init("inbox2"), params: .init()), #line),
                ("SELECT INBOX", "\r", .select(.inbox, []), #line),
                ("STATUS INBOX (SIZE)", "\r", .status(.inbox, [.size]), #line),
                ("SUBSCRIBE INBOX", "\r", .subscribe(.inbox), #line),
                ("UNSUBSCRIBE INBOX", "\r", .unsubscribe(.inbox), #line),
                ("UID EXPUNGE 1:2", "\r", .uidExpunge(.set([1 ... 2])), #line),
                ("FETCH $ (FLAGS)", "\r", .fetch(.lastCommand, [.flags], .init()), #line),
                ("LOGIN \"user\" \"password\"", "\r", .login(username: "user", password: "password"), #line),
                ("AUTHENTICATE GSSAPI", "\r", .authenticate(method: AuthenticationKind("GSSAPI"), initialClientResponse: nil), #line),
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
                (" ()", "\r", .id([:]), #line),
                (" nil", "\r", .id([:]), #line),
                (#" ("name" "some")"#, "\r", .id(["name":"some"]), #line),
                (#" ("k1" "v1" "k2" "v2")"#, "\r", .id(["k1":"v1", "k2":"v2"]), #line),
                ],
            parserErrorInputs: [
                (" ~", "", #line),
                (" []", "", #line),
                ],
            incompleteMessageInputs: [
                (" (\"name\"", "", #line),
                (" (\"name\" \"some\"", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_enable() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_enable,
            validInputs: [
                (" ACL", "\r", .enable([.acl]), #line),
                (" ACL BINARY CHILDREN", "\r", .enable([.acl, .binary, .children]), #line),
                ],
            parserErrorInputs: [
                (" (ACL)", "\r", #line),
                ],
            incompleteMessageInputs: [
                (" ACL", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_getMetadata() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_getMetadata,
            validInputs: [
                (" INBOX a", " ", .getMetadata(options: [], mailbox: .inbox, entries: ["a"]), #line),
                (" (MAXSIZE 123) INBOX (a b)", " ", .getMetadata(options: [.maxSize(123)], mailbox: .inbox, entries: ["a", "b"]), #line),
            ],
            parserErrorInputs: [
                (" (MAXSIZE 123 rogue) INBOX", "\r", #line),
                ],
            incompleteMessageInputs: [
                (" (key", "", #line),
                (" (key value", "", #line),
                (" (MAXSIZE 123) INBOX", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_setMetadata() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_setMetadata,
            validInputs: [
                (" INBOX (a NIL)", " ", .setMetadata(mailbox: .inbox, entries: ["a": .init(nil)]), #line),
            ],
            parserErrorInputs: [
                (" (a NIL)", "", #line),
                ],
            incompleteMessageInputs: [
                (" INBOX", "", #line),
                (" INBOX (", "", #line),
                (" INBOX (a", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_resetKey() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_resetKey,
            validInputs: [
                ("", "\r", .resetKey(mailbox: nil, mechanisms: []), #line),
                (" INBOX", "\r", .resetKey(mailbox: .inbox, mechanisms: []), #line),
                (" INBOX INTERNAL", "\r", .resetKey(mailbox: .inbox, mechanisms: [.internal]), #line),
                (" INBOX INTERNAL test", "\r", .resetKey(mailbox: .inbox, mechanisms: [.internal, .init("test")]), #line),
            ],
            parserErrorInputs: [
                ],
            incompleteMessageInputs: [
                (" INBOX", "", #line),
                (" INBOX INTERNAL", "", #line),
                (" INBOX INTERNAL test", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_genURLAuth() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_genURLAuth,
            validInputs: [
                (" test INTERNAL", "\r", .generateAuthorizedURL([.init(urlRump: "test", mechanism: .internal)]), #line),
                (" test INTERNAL test2 INTERNAL", "\r", .generateAuthorizedURL([.init(urlRump: "test", mechanism: .internal), .init(urlRump: "test2", mechanism: .internal)]), #line),
            ],
            parserErrorInputs: [
                (" \\", "", #line),
                ],
            incompleteMessageInputs: [
                (" ", "", #line),
                (" test", "", #line),
                (" test internal", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_urlFetch() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_urlFetch,
            validInputs: [
                (" test", "\r", .urlFetch(["test"]), #line),
                (" test1 test2", "\r", .urlFetch(["test1", "test2"]), #line),
            ],
            parserErrorInputs: [
                (" \\ ", "", #line),
                ],
            incompleteMessageInputs: [
                (" test", "", #line),
                (" test1 test2 test3", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_copy() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_copy,
            validInputs: [
                (" $ inbox", "\r", .copy(.lastCommand, .inbox), #line),
                (" 1 inbox", "\r", .copy(.set([1]), .inbox), #line),
                (" 1,5,7 inbox", "\r", .copy(.set([1, 5, 7]), .inbox), #line),
                (" 1:100 inbox", "\r", .copy(.set([1...100]), .inbox), #line),
                ],
            parserErrorInputs: [
                (" a inbox", "\r", #line),
                (" 1: inbox", "\r", #line),
                ],
            incompleteMessageInputs: [
                (" 1", "", #line),
                (" 1 inbox", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_delete() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_delete,
            validInputs: [
                (" INBOX", "\r\n", .delete(.inbox), #line),
                ],
            parserErrorInputs: [
                (" {5}12345", " ", #line),
                ],
            incompleteMessageInputs: [
                (" INBOX", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_move() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_move,
            validInputs: [
                (" $ inbox", "\r", .move(.lastCommand, .inbox), #line),
                (" 1 inbox", "\r", .move(.set([1]), .inbox), #line),
                (" 1,5,7 inbox", "\r", .move(.set([1, 5, 7]), .inbox), #line),
                (" 1:100 inbox", "\r", .move(.set([1...100]), .inbox), #line),
                ],
            parserErrorInputs: [
                (" a inbox", "\r", #line),
                (" 1: inbox", "\r", #line),
                ],
            incompleteMessageInputs: [
                (" 1", "", #line),
                (" 1 inbox", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_search() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_search,
            validInputs: [
                (
                    "", "",
                    .search(key: <#T##SearchKey#>, charset: <#T##String?#>, returnOptions: <#T##[SearchReturnOption]#>),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("", "", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
            ]
        )
    }

    func testParseCommandSuffix_esearch() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_esearch,
            validInputs: [
                ("", "", .id([:]), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_store() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_store,
            validInputs: [
                ("", "", .id([:]), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_examine() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_examine,
            validInputs: [
                (" INBOX", "\r", .examine(.inbox, [:]), #line),
                ],
            parserErrorInputs: [
                (" INBOX ", "", #line),
                ],
            incompleteMessageInputs: [
                (" INBOX", "", #line),
                (" INBOX ()", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_list() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_list,
            validInputs: [
                ("", "", .id([:]), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_LSUB() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_LSUB,
            validInputs: [
                (" inbox someList", " ", .lsub(reference: .inbox, pattern: "someList"), #line),
            ],
            parserErrorInputs: [
                ("", "", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_rename() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_rename,
            validInputs: [
                (" box1 box2", "\r", .rename(from: .init(.init(string: "box1")), to: .init(.init(string: "box2")), params: [:]), #line),
                ],
            parserErrorInputs: [
                (" {2}b1 {2}b2", "", #line),
                (" {2}\r\nb1 {2}b2", "", #line),
                ],
            incompleteMessageInputs: [
                (" box1", "", #line),
                (" box1 box2", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_select() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_select,
            validInputs: [
                (" INBOX", "\r", .select(.inbox, []), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                (" INBOX", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_status() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_status,
            validInputs: [
                ("", "", .id([:]), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_subscribe() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_subscribe,
            validInputs: [
                (" INBOX", "\r", .subscribe(.inbox), #line),
                ],
            parserErrorInputs: [
                ("inbox", "", #line),
                ],
            incompleteMessageInputs: [
                (" inbox", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_unsubscribe() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_unsubscribe,
            validInputs: [
                (" inbox", "\r", .unsubscribe(.inbox), #line),
                ],
            parserErrorInputs: [
                ("inbox", "", #line),
                ],
            incompleteMessageInputs: [
                (" inbox", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_uid() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_uid,
            validInputs: [
                ("", "", .id([:]), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_fetch() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_fetch,
            validInputs: [
                ("", "", .id([:]), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_login() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_login,
            validInputs: [
                (" email password", "\r", .login(username: "email", password: "password"), #line),
                (" \"email\" \"password\"", "\r", .login(username: "email", password: "password"), #line),
                (" {5}\r\nemail {8}\r\npassword", "\r", .login(username: "email", password: "password"), #line),
                ],
            parserErrorInputs: [
                ("email password", "", #line),
                ],
            incompleteMessageInputs: [
                (" email", "", #line),
                (" email password", "", #line),
                (" {5}\r\nemail {8}", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_authenticate() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_authenticate,
            validInputs: [
                (" GSSAPI", "\r", .authenticate(method: .gssAPI, initialClientResponse: nil), #line),
                ],
            parserErrorInputs: [
                (" ", "", #line),
                ],
            incompleteMessageInputs: [
                ("gssapi", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_create() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_create,
            validInputs: [
                (" inbox (something)", " ", .create(.inbox, [.labelled(.init(key: "something", value: nil))]), #line),
                (" inbox (k1 v1 $junk)", " ", .create(.inbox, [.labelled(.init(key: "k1", value: .comp(["v1"]))), .attributes([.junk])]), #line),
            ],
            parserErrorInputs: [
                (" inbox ()", "", #line),
                ],
            incompleteMessageInputs: [
                (" inbox", "", #line),
                (" inbox (k1", "", #line),
                (" inbox (k1 v1", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_getQuota() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [
                ("", "", .id([:]), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_setQuota() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [
                ("", "", .id([:]), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }

    func testParseCommandSuffix_getQuotaRoot() {
        self.iterateTests(
            testFunction: GrammarParser.parseCommandSuffix_id,
            validInputs: [
                ("", "", .id([:]), #line),
                ],
            parserErrorInputs: [
                ("", "", #line),
                ],
            incompleteMessageInputs: [
                ("", "", #line),
                ]
        )
    }
}
