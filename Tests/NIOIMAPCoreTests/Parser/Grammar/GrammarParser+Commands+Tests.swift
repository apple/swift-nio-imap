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
    func testParserLiteralLengthLimit() {
        let parser = GrammarParser(literalSizeLimit: 5)
        var b1 = ParseBuffer("{5}\r\nabcde")
        XCTAssertEqual(try parser.parseLiteral(buffer: &b1, tracker: .makeNewDefaultLimitStackTracker), "abcde")

        var b2 = ParseBuffer("{6}\r\nabcdef")
        XCTAssertThrowsError(try parser.parseLiteral(buffer: &b2, tracker: .makeNewDefaultLimitStackTracker)) { e in
            XCTAssertTrue(e is ExceededLiteralSizeLimitError)
        }
    }

    func testParseTaggedCommand() {
        // the failures here don't have a parseable tag
        self.iterateTests(
            testFunction: GrammarParser().parseTaggedCommand,
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

    // here the command tag should be parseable, so we want to
    // include it in a thrown error
    func testParseTaggedCommandThrowsBadCommand() {
        // test that the parser error occurs when parsing the command name
        var buffer1 = TestUtilities.makeParseBuffer(for: "A1 ()\r\n")
        XCTAssertThrowsError(try GrammarParser().parseTaggedCommand(buffer: &buffer1, tracker: .testTracker)) { e in
            guard let error = e as? BadCommand else {
                XCTFail("Expected BadCommand, got \(e)")
                return
            }
            XCTAssertEqual(error.commandTag, "A1")
        }

        // test that the parser error occurs when parsing a command component
        var buffer2 = TestUtilities.makeParseBuffer(for: "A2 ID aaaa\r\n")
        XCTAssertThrowsError(try GrammarParser().parseTaggedCommand(buffer: &buffer2, tracker: .testTracker)) { e in
            guard let error = e as? BadCommand else {
                XCTFail("Expected BadCommand, got \(e)")
                return
            }
            XCTAssertEqual(error.commandTag, "A2")
        }

        // make sure we still throw incomplete messages
        var buffer3 = TestUtilities.makeParseBuffer(for: "A2 LOGIN")
        XCTAssertThrowsError(try GrammarParser().parseTaggedCommand(buffer: &buffer3, tracker: .testTracker)) { e in
            XCTAssertTrue(e is IncompleteMessage)
        }
    }

    // Minimum 1 valid test for each command to ensure all commands are supported
    // dedicated unit tests are provided for each sub-parser
    func testParseCommand() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommand,
            validInputs: [
                ("CAPABILITY", "\r", .capability, #line),
                ("LOGOUT", "\r", .logout, #line),
                ("NOOP", "\r", .noop, #line),
                ("STARTTLS", "\r", .startTLS, #line),
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
                ("ESEARCH ALL", "\r", .extendedSearch(.init(key: .all)), #line),
                ("STORE $ +FLAGS \\Answered", "\r", .store(.lastCommand, [], .flags(.add(silent: false, list: [.answered]))), #line),
                ("EXAMINE INBOX", "\r", .examine(.inbox, .init()), #line),
                ("LIST INBOX test", "\r", .list(nil, reference: .inbox, .mailbox("test"), []), #line),
                ("LSUB INBOX test", "\r", .lsub(reference: .inbox, pattern: "test"), #line),
                ("RENAME INBOX inbox2", "\r", .rename(from: .inbox, to: .init("inbox2"), parameters: .init()), #line),
                ("SELECT INBOX", "\r", .select(.inbox, []), #line),
                ("STATUS INBOX (SIZE)", "\r", .status(.inbox, [.size]), #line),
                ("SUBSCRIBE INBOX", "\r", .subscribe(.inbox), #line),
                ("UNSUBSCRIBE INBOX", "\r", .unsubscribe(.inbox), #line),
                ("UID EXPUNGE 1:2", "\r", .uidExpunge(.set([1 ... 2])), #line),
                ("FETCH $ (FLAGS)", "\r", .fetch(.lastCommand, [.flags], .init()), #line),
                ("LOGIN \"user\" \"password\"", "\r", .login(username: "user", password: "password"), #line),
                ("AUTHENTICATE GSSAPI", "\r", .authenticate(mechanism: AuthenticationMechanism("GSSAPI"), initialResponse: nil), #line),
                ("CREATE test", "\r", .create(.init("test"), []), #line),
                ("GETQUOTA root", "\r", .getQuota(.init("root")), #line),
                ("GETQUOTAROOT INBOX", "\r", .getQuotaRoot(.inbox), #line),
                ("SETQUOTA ROOT (resource 123)", "\r", .setQuota(.init("ROOT"), [.init(resourceName: "resource", limit: 123)]), #line),
                ("COMPRESS DEFLATE", "\r", .compress(.deflate), #line),
            ],
            parserErrorInputs: [
                ("123", "\r", #line),
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
            testFunction: GrammarParser().parseCommandSuffix_id,
            validInputs: [
                (" ()", "\r", .id([:]), #line),
                (" nil", "\r", .id([:]), #line),
                (#" ("name" "some")"#, "\r", .id(["name": "some"]), #line),
                (#" ("k1" "v1" "k2" "v2")"#, "\r", .id(["k1": "v1", "k2": "v2"]), #line),
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
            testFunction: GrammarParser().parseCommandSuffix_enable,
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
            testFunction: GrammarParser().parseCommandSuffix_getMetadata,
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
            testFunction: GrammarParser().parseCommandSuffix_setMetadata,
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
            testFunction: GrammarParser().parseCommandSuffix_resetKey,
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
            testFunction: GrammarParser().parseCommandSuffix_genURLAuth,
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
            testFunction: GrammarParser().parseCommandSuffix_urlFetch,
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
            testFunction: GrammarParser().parseCommandSuffix_copy,
            validInputs: [
                (" $ inbox", "\r", .copy(.lastCommand, .inbox), #line),
                (" 1 inbox", "\r", .copy(.set([1]), .inbox), #line),
                (" 1,5,7 inbox", "\r", .copy(.set([1, 5, 7]), .inbox), #line),
                (" 1:100 inbox", "\r", .copy(.set([1 ... 100]), .inbox), #line),
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
            testFunction: GrammarParser().parseCommandSuffix_delete,
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
            testFunction: GrammarParser().parseCommandSuffix_move,
            validInputs: [
                (" $ inbox", "\r", .move(.lastCommand, .inbox), #line),
                (" 1 inbox", "\r", .move(.set([1]), .inbox), #line),
                (" 1,5,7 inbox", "\r", .move(.set([1, 5, 7]), .inbox), #line),
                (" 1:100 inbox", "\r", .move(.set([1 ... 100]), .inbox), #line),
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
            testFunction: GrammarParser().parseCommandSuffix_search,
            validInputs: [
                (" ALL", "\r", .search(key: .all), #line),
                (" ALL DELETED FLAGGED", "\r", .search(key: .and([.all, .deleted, .flagged])), #line),
                (" CHARSET UTF-8 ALL", "\r", .search(key: .all, charset: "UTF-8"), #line),
                (" DELETED", "\r", .search(key: .deleted, returnOptions: []), #line),
                (" RETURN () DELETED", "\r", .search(key: .deleted, returnOptions: [.all]), #line),
                (" RETURN (ALL) DELETED", "\r", .search(key: .deleted, returnOptions: [.all]), #line),
                (" RETURN (ALL COUNT) ANSWERED", "\r", .search(key: .answered, returnOptions: [.all, .count]), #line),
                (" RETURN (MIN) ALL", "\r", .search(key: .all, returnOptions: [.min]), #line),
                (
                    #" CHARSET UTF-8 (OR FROM "me" FROM "you") (OR NEW UNSEEN)"#,
                    "\r",
                    .search(key: .and([.or(.from("me"), .from("you")), .or(.new, .unseen)]), charset: "UTF-8"),
                    #line
                ),
                (
                    #" RETURN (MIN MAX) CHARSET UTF-8 OR (FROM "me" FROM "you") (NEW UNSEEN)"#,
                    "\r",
                    .search(key: .or(.and([.from("me"), .from("you")]), .and([.new, .unseen])), charset: "UTF-8", returnOptions: [.min, .max]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseCommandSuffix_esearch() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_esearch,
            validInputs: [
                (" ALL", "\r", .extendedSearch(.init(key: .all)), #line),
                (
                    " IN (mailboxes \"folder1\" subtree \"folder2\") unseen", "\r",
                    .extendedSearch(ExtendedSearchOptions(key: .unseen, charset: nil, returnOptions: [], sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.mailboxes(Mailboxes([MailboxName("folder1")])!), .subtree(Mailboxes([MailboxName("folder2")])!)]))),
                    #line
                ),
            ],
            parserErrorInputs: [
            ],
            incompleteMessageInputs: [
                (" IN (mailboxes ", "", #line),
            ]
        )
    }

    func testParseCommandSuffix_store() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_store,
            validInputs: [
                (" 1 +FLAGS \\answered", "\r", .store(.set([1]), [], .flags(.add(silent: false, list: [.answered]))), #line),
                (" 1 (label) -FLAGS \\seen", "\r", .store(.set([1]), [.other(.init(key: "label", value: nil))], .flags(.remove(silent: false, list: [.seen]))), #line),
                (" 1 (label UNCHANGEDSINCE 5) -FLAGS \\seen", "\r", .store(.set([1]), [.other(.init(key: "label", value: nil)), .unchangedSince(.init(modificationSequence: 5))], .flags(.remove(silent: false, list: [.seen]))), #line),
            ],
            parserErrorInputs: [
                (" +FLAGS \\answered", "\r", #line),
            ],
            incompleteMessageInputs: [
                (" ", "", #line),
                (" 1 ", "", #line),
            ]
        )
    }

    func testParseCommandSuffix_examine() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommand,
            validInputs: [
                ("EXAMINE inbox", "\r", .examine(.inbox, []), #line),
                ("examine inbox", "\r", .examine(.inbox, []), #line),
                ("EXAMINE inbox (number)", "\r", .examine(.inbox, [.basic(.init(key: "number", value: nil))]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseCommandSuffix_list() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_list,
            validInputs: [
                (#" "" """#, "\r", .list(nil, reference: MailboxName(""), .mailbox(""), []), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseCommandSuffix_LSUB() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_LSUB,
            validInputs: [
                (" inbox someList", " ", .lsub(reference: .inbox, pattern: "someList"), #line),
                (" \"inbox\" \"someList\"", " ", .lsub(reference: .inbox, pattern: "someList"), #line),
            ],
            parserErrorInputs: [
                (" {5}inbox", "", #line),
            ],
            incompleteMessageInputs: [
                (" inbox", "", #line),
                (" inbox list", "", #line),
            ]
        )
    }

    func testParseCommandSuffix_rename() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_rename,
            validInputs: [
                (" box1 box2", "\r", .rename(from: .init(.init(string: "box1")), to: .init(.init(string: "box2")), parameters: [:]), #line),
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
            testFunction: GrammarParser().parseCommandSuffix_select,
            validInputs: [
                (" inbox", "\r", .select(.inbox, []), #line),
                (" inbox (some1)", "\r", .select(.inbox, [.basic(.init(key: "some1", value: nil))]), #line),
            ],
            parserErrorInputs: [
                (" ", "\r", #line),
            ],
            incompleteMessageInputs: [
                (" ", "", #line),
            ]
        )
    }

    func testParseCommandSuffix_status() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_status,
            validInputs: [
                (" inbox (messages unseen)", "\r\n", .status(.inbox, [.messageCount, .unseenCount]), #line),
                (" Deleted (messages unseen HIGHESTMODSEQ)", "\r\n", .status(MailboxName("Deleted"), [.messageCount, .unseenCount, .highestModificationSequence]), #line),
            ],
            parserErrorInputs: [
                (" inbox (messages unseen", "\r\n", #line),
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                (" Deleted (messages ", "", #line),
            ]
        )
    }

    func testParseCommandSuffix_subscribe() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_subscribe,
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
            testFunction: GrammarParser().parseCommandSuffix_unsubscribe,
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
            testFunction: GrammarParser().parseCommandSuffix_uid,
            validInputs: [
                (" EXPUNGE 1", "\r\n", .uidExpunge(.set([1])), #line),
                (" COPY 1 Inbox", "\r\n", .uidCopy(.set([1]), .inbox), #line),
                (" FETCH 1 FLAGS", "\r\n", .uidFetch(.set([1]), [.flags], []), #line),
                (" SEARCH CHARSET UTF8 ALL", "\r\n", .uidSearch(key: .all, charset: "UTF8"), #line),
                (" STORE 1 +FLAGS (Test)", "\r\n", .uidStore(.set([1]), [], .flags(.add(silent: false, list: [.keyword(.init("Test"))]))), #line),
                (" STORE 1 (UNCHANGEDSINCE 5 test) +FLAGS (Test)", "\r\n", .uidStore(.set([1]), [.unchangedSince(.init(modificationSequence: 5)), .other(.init(key: "test", value: nil))], .flags(.add(silent: false, list: [.keyword(.init("Test"))]))), #line),
                (" COPY * Inbox", "\r\n", .uidCopy(.set([MessageIdentifierRange<UID>(.max)]), .inbox), #line),
            ],
            parserErrorInputs: [
                ("UID RENAME inbox other", " ", #line),
            ],
            incompleteMessageInputs: [
                //                ("UID COPY 1", " ", #line),
            ]
        )
    }

    func testParseCommandSuffix_fetch() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_fetch,
            validInputs: [
                (" 1:3 ALL", "\r", .fetch(.set([1 ... 3]), .all, []), #line),
                (" 2:4 FULL", "\r", .fetch(.set([2 ... 4]), .full, []), #line),
                (" 3:5 FAST", "\r", .fetch(.set([3 ... 5]), .fast, []), #line),
                (" 4:6 ENVELOPE", "\r", .fetch(.set([4 ... 6]), [.envelope], []), #line),
                (" 5:7 (ENVELOPE FLAGS)", "\r", .fetch(.set([5 ... 7]), [.envelope, .flags], []), #line),
                (" 3:5 FAST (name)", "\r", .fetch(.set([3 ... 5]), .fast, [.other(.init(key: "name", value: nil))]), #line),
                (" 1 BODY[TEXT]", "\r", .fetch(.set([1]), [.bodySection(peek: false, .init(kind: .text), nil)], []), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseCommandSuffix_login() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_login,
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
            testFunction: GrammarParser().parseCommandSuffix_authenticate,
            validInputs: [
                (" GSSAPI", "\r", .authenticate(mechanism: .gssAPI, initialResponse: nil), #line),
                (" GSSAPI aGV5", "\r", .authenticate(mechanism: .gssAPI, initialResponse: .init(.init(.init(string: "hey")))), #line),
            ],
            parserErrorInputs: [
                (" \"GSSAPI\"", "", #line),
            ],
            incompleteMessageInputs: [
                (" gssapi", "", #line),
            ]
        )
    }

    func testParseCommandSuffix_create() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_create,
            validInputs: [
                (" inbox", "\r", .create(.inbox, []), #line),
                (" inbox (some)", "\r", .create(.inbox, [.labelled(.init(key: "some", value: nil))]), #line),
                (" inbox (USE (\\All))", "\r", .create(.inbox, [.attributes([.all])]), #line),
                (" inbox (USE (\\All \\Flagged))", "\r", .create(.inbox, [.attributes([.all, .flagged])]), #line),
                (
                    " inbox (USE (\\All \\Flagged) some1 2 USE (\\Sent))",
                    "\r",
                    .create(.inbox, [.attributes([.all, .flagged]), .labelled(.init(key: "some1", value: .sequence(.set([2])))), .attributes([.sent])]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: [
                (" inbox", "", #line),
                (" inbox (USE", "", #line),
            ]
        )
    }

    func testParseCommandSuffix_getQuota() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_getQuota,
            validInputs: [
                (" \"\"", "\r", .getQuota(.init("")), #line),
                (" \"quota\"", "\r", .getQuota(.init("quota")), #line),
            ],
            parserErrorInputs: [
                (" {5}quota", "\r", #line),
            ],
            incompleteMessageInputs: [
                (" \"root", "", #line),
            ]
        )
    }

    func testParseCommandSuffix_setQuota() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_setQuota,
            validInputs: [
                (#" "" (STORAGE 512)"#, "\r", .setQuota(.init(""), [.init(resourceName: "STORAGE", limit: 512)]), #line),
                (
                    #" "" (STORAGE 512 BANDWIDTH 123)"#, "\r",
                    .setQuota(.init(""), [.init(resourceName: "STORAGE", limit: 512), .init(resourceName: "BANDWIDTH", limit: 123)]),
                    #line
                ),
            ],
            parserErrorInputs: [
                (#" "" STORAGE 512"#, "", #line),
            ],
            incompleteMessageInputs: [
                (#" ""#, "", #line),
                (#" "root"#, "", #line),
                (#" "root" ("#, "", #line),
                (#" "root" (STORAGE"#, "", #line),
                (#" "root" (STORAGE 123"#, "", #line),
            ]
        )
    }

    func testParseCommandSuffix_getQuotaRoot() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommandSuffix_getQuotaRoot,
            validInputs: [
                (" INBOX", "\r", .getQuotaRoot(.inbox), #line),
                (" \"INBOX\"", "\r", .getQuotaRoot(.inbox), #line),
                (" {5}\r\nINBOX", "\r", .getQuotaRoot(.inbox), #line),
            ],
            parserErrorInputs: [
                (" {5}INBOX", "", #line),
            ],
            incompleteMessageInputs: [
                (" INBOX", "", #line),
            ]
        )
    }
}
