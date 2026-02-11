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
import NIOTestUtils
import XCTest

// MARK: - parseEmailAddress

extension ParserUnitTests {
    func testparseEmailAddress_valid() {
        self.iterateTests(
            testFunction: GrammarParser().parseEmailAddress,
            validInputs: [
                ("(NIL NIL NIL NIL)", "", .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil), #line),
                (#"("a" "b" "c" "d")"#, "", .init(personName: "a", sourceRoot: "b", mailbox: "c", host: "d"), #line),
                (#"("å" "é" "ı" "ø")"#, "", .init(personName: "å", sourceRoot: "é", mailbox: "ı", host: "ø"), #line),
            ],
            parserErrorInputs: [
                ("(NIL NIL NIL NIL ", "\r", #line)
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("(NIL ", "", #line),
            ]
        )
    }
}

// MARK: - parseMetadataOption

extension ParserUnitTests {
    func testParseMetadataOption() {
        self.iterateTests(
            testFunction: GrammarParser().parseMetadataOption,
            validInputs: [
                ("MAXSIZE 123", "\r", .maxSize(123), #line),
                ("DEPTH 1", "\r", .scope(.one), #line),
                ("param", "\r", .other(.init(key: "param", value: nil)), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMetadataOptions

extension ParserUnitTests {
    func testParseMetadataOptions() {
        self.iterateTests(
            testFunction: GrammarParser().parseMetadataOptions,
            validInputs: [
                ("(MAXSIZE 123)", "\r", [.maxSize(123)], #line),
                ("(DEPTH 1 MAXSIZE 123)", "\r", [.scope(.one), .maxSize(123)], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMetadatResponse

extension ParserUnitTests {
    func testParseMetadataResponse() {
        self.iterateTests(
            testFunction: GrammarParser().parseMetadataResponse,
            validInputs: [
                ("METADATA INBOX \"a\"", "\r", .list(list: ["a"], mailbox: .inbox), #line),
                ("METADATA INBOX \"a\" \"b\" \"c\"", "\r", .list(list: ["a", "b", "c"], mailbox: .inbox), #line),
                ("METADATA INBOX (\"a\" NIL)", "\r", .values(values: ["a": .init(nil)], mailbox: .inbox), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMetadataValue

extension ParserUnitTests {
    func testParseMetadataValue() {
        self.iterateTests(
            testFunction: GrammarParser().parseMetadataValue,
            validInputs: [
                ("NIL", "\r", .init(nil), #line),
                ("\"a\"", "\r", .init("a"), #line),
                ("{1}\r\na", "\r", .init("a"), #line),
                ("~{1}\r\na", "\r", .init("a"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseCreateParameter

extension ParserUnitTests {
    func testParseCreateParameter() {
        self.iterateTests(
            testFunction: GrammarParser().parseCreateParameter,
            validInputs: [
                ("param", "\r", .labelled(.init(key: "param", value: nil)), #line),
                ("param 1", "\r", .labelled(.init(key: "param", value: .sequence(.set([1])))), #line),
                ("USE (\\All)", "\r", .attributes([.all]), #line),
                ("USE (\\All \\Sent \\Drafts)", "\r", .attributes([.all, .sent, .drafts]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: [
                ("param", "", #line),
                ("param 1", "", #line),
                ("USE (\\Test", "", #line),
                ("USE (\\All ", "", #line),
            ]
        )
    }
}

// MARK: - parseCreateParameters

extension ParserUnitTests {
    func testParseCreateParameters() {
        self.iterateTests(
            testFunction: GrammarParser().parseCreateParameters,
            validInputs: [
                (
                    " (param1 param2)", "\r",
                    [.labelled(.init(key: "param1", value: nil)), .labelled(.init(key: "param2", value: nil))], #line
                )
            ],
            parserErrorInputs: [
                (" (param1", "\r", #line)
            ],
            incompleteMessageInputs: [
                (" (param1", "", #line)
            ]
        )
    }
}

// MARK: - useAttribute parseUseAttribute

extension ParserUnitTests {
    func testParseUseAttribute() {
        self.iterateTests(
            testFunction: GrammarParser().parseUseAttribute,
            validInputs: [
                ("\\All", "", .all, #line),
                ("\\Archive", "", .archive, #line),
                ("\\Flagged", "", .flagged, #line),
                ("\\Trash", "", .trash, #line),
                ("\\Sent", "", .sent, #line),
                ("\\Drafts", "", .drafts, #line),
                ("\\Other", " ", .init("\\Other"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - condstore-param parseConditionalStoreParameter

extension ParserUnitTests {
    func testParseConditionalStoreParameter() {
        let inputs: [(String, UInt)] = [
            ("condstore", #line),
            ("CONDSTORE", #line),
            ("condSTORE", #line),
        ]

        for (input, line) in inputs {
            TestUtilities.withParseBuffer(input, terminator: " ") { (buffer) in
                XCTAssertNoThrow(
                    try GrammarParser().parseConditionalStoreParameter(buffer: &buffer, tracker: .testTracker),
                    line: line
                )
            }
        }
    }
}

// MARK: - parseChangedSinceModifier

extension ParserUnitTests {
    func testParseChangedSinceModifier() {
        self.iterateTests(
            testFunction: GrammarParser().parseChangedSinceModifier,
            validInputs: [
                ("CHANGEDSINCE 1", " ", .init(modificationSequence: 1), #line),
                ("changedsince 1", " ", .init(modificationSequence: 1), #line),
            ],
            parserErrorInputs: [
                ("TEST", "", #line),
                ("CHANGEDSINCE a", "", #line),
            ],
            incompleteMessageInputs: [
                ("CHANGEDSINCE 1", "", #line)
            ]
        )
    }
}

// MARK: - parseUnchangedSinceModifier

extension ParserUnitTests {
    func testParseUnchangedSinceModifier() {
        self.iterateTests(
            testFunction: GrammarParser().parseUnchangedSinceModifier,
            validInputs: [
                ("UNCHANGEDSINCE 1", " ", .init(modificationSequence: 1), #line),
                ("unchangedsince 1", " ", .init(modificationSequence: 1), #line),
            ],
            parserErrorInputs: [
                ("TEST", "", #line),
                ("UNCHANGEDSINCE a", "", #line),
            ],
            incompleteMessageInputs: [
                ("UNCHANGEDSINCE 1", "", #line)
            ]
        )
    }
}

// MARK: - parseEItemVendorTag

extension ParserUnitTests {
    func testParseEItemVendorTag() {
        self.iterateTests(
            testFunction: GrammarParser().parseEitemVendorTag,
            validInputs: [
                ("token-atom", " ", EItemVendorTag(token: "token", atom: "atom"), #line)
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFullDateTime

extension ParserUnitTests {
    func testParseFullDateTime() {
        self.iterateTests(
            testFunction: GrammarParser().parseFullDateTime,
            validInputs: [
                (
                    "1234-12-20T11:22:33",
                    " ",
                    .init(date: .init(year: 1234, month: 12, day: 20), time: .init(hour: 11, minute: 22, second: 33)),
                    #line
                )
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseFullDate

extension ParserUnitTests {
    func testParseFullDate() {
        self.iterateTests(
            testFunction: GrammarParser().parseFullDate,
            validInputs: [
                ("1234-12-23", " ", .init(year: 1234, month: 12, day: 23), #line)
            ],
            parserErrorInputs: [
                ("a", "", #line)
            ],
            incompleteMessageInputs: [
                ("1234", "", #line)
            ]
        )
    }
}

// MARK: - parseFullTime

extension ParserUnitTests {
    func testParseFullTime() {
        self.iterateTests(
            testFunction: GrammarParser().parseFullTime,
            validInputs: [
                ("12:34:56", " ", .init(hour: 12, minute: 34, second: 56), #line),
                ("12:34:56.123456", " ", .init(hour: 12, minute: 34, second: 56, fraction: 123456), #line),
            ],
            parserErrorInputs: [
                ("a", "", #line),
                ("1234:56:12", "", #line),
            ],
            incompleteMessageInputs: [
                ("1234", "", #line)
            ]
        )
    }
}

// MARK: - filter-name parseFilterName

extension ParserUnitTests {
    func testParseFilterName() {
        self.iterateTests(
            testFunction: GrammarParser().parseFilterName,
            validInputs: [
                ("a", " ", "a", #line),
                ("abcdefg", " ", "abcdefg", #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseJMAPAccess

extension ParserUnitTests {
    func testJMAPAccess_valid() {
        TestUtilities.withParseBuffer(#"JMAPACCESS "https://example.com/.well-known/jmap""#) { (buffer) in
            let url = try GrammarParser().parseJMAPAccess(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(url, URL(string: "https://example.com/.well-known/jmap")!)
        }
    }

    func testJMAPAccess_nonHTTPS() {
        var buffer = TestUtilities.makeParseBuffer(for: #"JMAPACCESS "http://example.com/.well-known/jmap""#)
        XCTAssertThrowsError(try GrammarParser().parseJMAPAccess(buffer: &buffer, tracker: .testTracker))
    }

    func testJMAPAccess_notAURL() {
        var buffer = TestUtilities.makeParseBuffer(for: #"JMAPACCESS "example.com""#)
        XCTAssertThrowsError(try GrammarParser().parseJMAPAccess(buffer: &buffer, tracker: .testTracker))
    }
}

// MARK: - id (parseID, parseIDResponse, parseIDParamsList)

extension ParserUnitTests {
    func testParseIDParamsList() {
        self.iterateTests(
            testFunction: GrammarParser().parseIDParamsList,
            validInputs: [
                ("NIL", " ", [:], #line),
                ("()", " ", [:], #line),
                ("( )", " ", [:], #line),
                (#"("key1" "value1")"#, "", ["key1": "value1"], #line),
                (
                    #"("key1" "value1" "key2" "value2" "key3" "value3")"#,
                    "",
                    ["key1": "value1", "key2": "value2", "key3": "value3"],
                    #line
                ),
                (
                    #"("key1" "&AKM-" "flag" "&2Dzf9NtA3GfbQNxi20DcZdtA3G7bQNxn20Dcfw-")"#,
                    #""#,
                    ["key1": "£", "flag": "🏴󠁧󠁢󠁥󠁮󠁧󠁿"],
                    #line
                ),
                (
                    #"("a" "1" "b" "2")"#,
                    "",
                    ["a": "1", "b": "2"],
                    #line
                ),
                // Extra spaces
                (
                    #"( "a" "1" "b" "2" )"#,
                    "",
                    ["a": "1", "b": "2"],
                    #line
                ),
                (
                    #"("a"  "1"  "b"   "2")"#,
                    "",
                    ["a": "1", "b": "2"],
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMechanismBase64

extension ParserUnitTests {
    func testParseMechanismBase64() {
        self.iterateTests(
            testFunction: GrammarParser().parseMechanismBase64,
            validInputs: [
                ("INTERNAL", " ", .init(mechanism: .internal, base64: nil), #line),
                ("INTERNAL=YQ==", " ", .init(mechanism: .internal, base64: "a"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - Namespace-Desc parseNamespaceResponse

extension ParserUnitTests {
    func testParseNamespaceDescription() {
        self.iterateTests(
            testFunction: GrammarParser().parseNamespaceDescription,
            validInputs: [
                ("(\"str1\" NIL)", " ", .init(string: "str1", char: nil, responseExtensions: [:]), #line),
                ("(\"str\" \"a\")", " ", .init(string: "str", char: "a", responseExtensions: [:]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseNamespaceResponse

extension ParserUnitTests {
    func testParseNamespaceResponse() {
        self.iterateTests(
            testFunction: GrammarParser().parseNamespaceResponse,
            validInputs: [
                (
                    " nil nil nil", " ", .init(userNamespace: [], otherUserNamespace: [], sharedNamespace: []),
                    #line
                )
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseNamespaceResponseExtension

extension ParserUnitTests {
    func testParseNamespaceResponseExtension() {
        self.iterateTests(
            testFunction: GrammarParser().parseNamespaceResponseExtension,
            validInputs: [
                (" \"str1\" (\"str2\")", " ", .init(key: "str1", value: ["str2"]), #line),
                (
                    " \"str1\" (\"str2\" \"str3\" \"str4\")", " ", .init(key: "str1", value: ["str2", "str3", "str4"]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseSequenceMatchData

extension ParserUnitTests {
    func testParseSequenceMatchData() {
        self.iterateTests(
            testFunction: GrammarParser().parseSequenceMatchData,
            validInputs: [
                ("(1:* 1:*)", "\r", .init(knownSequenceSet: .set(.all), knownUidSet: .set(.all)), #line),
                ("(1,2 3,4)", "\r", .init(knownSequenceSet: .set([1, 2]), knownUidSet: .set([3, 4])), #line),
            ],
            parserErrorInputs: [
                ("()", "", #line),
                ("(* )", "", #line),
            ],
            incompleteMessageInputs: [
                ("(1", "", #line),
                ("(1111:2222", "", #line),
            ]
        )
    }
}

// MARK: - parseUserId

extension ParserUnitTests {
    func testParseUserId() {
        self.iterateTests(
            testFunction: GrammarParser().parseUserId,
            validInputs: [
                ("test", " ", "test", #line),
                ("{4}\r\ntest", " ", "test", #line),
                ("{4+}\r\ntest", " ", "test", #line),
                ("\"test\"", " ", "test", #line),
            ],
            parserErrorInputs: [
                ("\\\\", "", #line)
            ],
            incompleteMessageInputs: [
                ("aaa", "", #line),
                ("{1}\r\n", "", #line),
            ]
        )
    }
}

// MARK: RFC 2087 - Quota

extension ParserUnitTests {
    func testSetQuota() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommand,
            validInputs: [
                (
                    "SETQUOTA \"\" (STORAGE 512)",
                    "\r",
                    Command.setQuota(QuotaRoot(""), [QuotaLimit(resourceName: "STORAGE", limit: 512)]),
                    #line
                ),
                (
                    "SETQUOTA \"MASSIVE_POOL\" (STORAGE 512)",
                    "\r",
                    Command.setQuota(QuotaRoot("MASSIVE_POOL"), [QuotaLimit(resourceName: "STORAGE", limit: 512)]),
                    #line
                ),
                (
                    "SETQUOTA \"MASSIVE_POOL\" (STORAGE 512 BEANS 50000)",
                    "\r",
                    Command.setQuota(
                        QuotaRoot("MASSIVE_POOL"),
                        [
                            QuotaLimit(resourceName: "STORAGE", limit: 512),
                            QuotaLimit(resourceName: "BEANS", limit: 50000),
                        ]
                    ),
                    #line
                ),
                (
                    "SETQUOTA \"MASSIVE_POOL\" ()",
                    "\r",
                    Command.setQuota(QuotaRoot("MASSIVE_POOL"), []),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("SETQUOTA \"MASSIVE_POOL\" (STORAGE BEANS)", "\r", #line),
                ("SETQUOTA \"MASSIVE_POOL\" (STORAGE 40M)", "\r", #line),
                ("SETQUOTA \"MASSIVE_POOL\" (STORAGE)", "\r", #line),
                ("SETQUOTA \"MASSIVE_POOL\" (", "\r", #line),
                ("SETQUOTA \"MASSIVE_POOL\"", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testGetQuota() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommand,
            validInputs: [
                ("GETQUOTA \"\"", "\r", Command.getQuota(QuotaRoot("")), #line),
                ("GETQUOTA \"MASSIVE_POOL\"", "\r", Command.getQuota(QuotaRoot("MASSIVE_POOL")), #line),
            ],
            parserErrorInputs: [
                ("GETQUOTA", "\r", #line)
            ],
            incompleteMessageInputs: []
        )
    }

    func testGetQuotaRoot() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommand,
            validInputs: [
                ("GETQUOTAROOT INBOX", "\r", Command.getQuotaRoot(MailboxName("INBOX")), #line),
                ("GETQUOTAROOT Other", "\r", Command.getQuotaRoot(MailboxName("Other")), #line),
            ],
            parserErrorInputs: [
                ("GETQUOTAROOT", "\r", #line)
            ],
            incompleteMessageInputs: []
        )
    }

    func testResponsePayload_quotaRoot() {
        self.iterateTests(
            testFunction: GrammarParser().parseResponsePayload_quotaRoot,
            validInputs: [
                ("QUOTAROOT INBOX \"Root\"", "\r", .quotaRoot(.init("INBOX"), .init("Root")), #line)
            ],
            parserErrorInputs: [
                ("QUOTAROOT", "\r", #line),
                ("QUOTAROOT INBOX", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testResponsePayload_quota() {
        self.iterateTests(
            testFunction: GrammarParser().parseResponsePayload_quota,
            validInputs: [
                (
                    "QUOTA \"Root\" (STORAGE 10 512)", "\r",
                    .quota(.init("Root"), [QuotaResource(resourceName: "STORAGE", usage: 10, limit: 512)]),
                    #line
                ),
                (
                    "QUOTA \"Root\" (STORAGE 10 512 BEANS 50 100)", "\r",
                    .quota(
                        .init("Root"),
                        [
                            QuotaResource(resourceName: "STORAGE", usage: 10, limit: 512),
                            QuotaResource(resourceName: "BEANS", usage: 50, limit: 100),
                        ]
                    ),
                    #line
                ),
                (
                    "QUOTA \"Root\" ()", "\r",
                    .quota(.init("Root"), []),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("QUOTA", "\r", #line),
                ("QUOTA \"Root\"", "\r", #line),
                ("QUOTA \"Root\" (", "\r", #line),
                ("QUOTA \"Root\" (STORAGE", "\r", #line),
                ("QUOTA \"Root\" (STORAGE)", "\r", #line),
                ("QUOTA \"Root\" (STORAGE 10", "\r", #line),
                ("QUOTA \"Root\" (STORAGE 10)", "\r", #line),
                ("QUOTA \"Root\" (STORAGE 10 512 BEANS)", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }
}

// MARK: RFC 7377 & 5465 - Extended Search/Filters tests

extension ParserUnitTests {
    func testParseOneOrMoreMailbox() {
        self.iterateTests(
            testFunction: GrammarParser().parseOneOrMoreMailbox,
            validInputs: [
                (
                    "\"box1\"", "\r",
                    Mailboxes([.init("box1")])!,
                    #line
                ),
                (
                    "(\"box1\")", "\r",
                    Mailboxes([.init("box1")])!,
                    #line
                ),
                (
                    "(\"box1\" \"box2\")", "\r",
                    Mailboxes([.init("box1"), .init("box2")]),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("()", "\r", #line)
            ],
            incompleteMessageInputs: []
        )
    }

    func testParseFilterMailboxes() {
        self.iterateTests(
            testFunction: GrammarParser().parseFilterMailboxes,
            validInputs: [
                (
                    "inboxes", " ",
                    .inboxes,
                    #line
                ),
                (
                    "personal", " ",
                    .personal,
                    #line
                ),
                (
                    "subscribed", " ",
                    .subscribed,
                    #line
                ),
                (
                    "selected", " ",
                    .selected,
                    #line
                ),
                (
                    "selected-delayed", " ",
                    .selectedDelayed,
                    #line
                ),
                (
                    "subtree \"box1\"", " ",
                    .subtree(Mailboxes([.init("box1")])!),
                    #line
                ),
                (
                    "subtree-one \"box1\"", " ",
                    .subtreeOne(Mailboxes([.init("box1")])!),
                    #line
                ),
                (
                    "mailboxes \"box1\"", " ",
                    .mailboxes(Mailboxes([.init("box1")])!),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("subtree ", "\r", #line),
                ("subtree-one", "\r", #line),
                ("mailboxes", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testParseExtendedSearchScopeOptions() {
        self.iterateTests(
            testFunction: GrammarParser().parseExtendedSearchScopeOptions,
            validInputs: [
                (
                    "name", "\r",
                    ExtendedSearchScopeOptions(["name": nil])!,
                    #line
                ),
                (
                    "name $", "\r",
                    ExtendedSearchScopeOptions(["name": .sequence(.lastCommand)]),
                    #line
                ),
                (
                    "name name2", "\r",
                    ExtendedSearchScopeOptions(["name": nil, "name2": nil])!,
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseExtendedSearchSourceOptions() {
        self.iterateTests(
            testFunction: GrammarParser().parseExtendedSearchSourceOptions,
            validInputs: [
                (
                    "IN (inboxes)", "\r",
                    ExtendedSearchSourceOptions(sourceMailbox: [.inboxes]),
                    #line
                ),
                (
                    "IN (inboxes personal)", "\r",
                    ExtendedSearchSourceOptions(sourceMailbox: [.inboxes, .personal]),
                    #line
                ),
                (
                    "IN (inboxes (name))", "\r",
                    ExtendedSearchSourceOptions(
                        sourceMailbox: [.inboxes],
                        scopeOptions: ExtendedSearchScopeOptions(["name": nil])!
                    ),
                    #line
                ),
            ],
            parserErrorInputs: [
                ("IN (inboxes ())", "\r", #line),
                ("IN ((name))", "\r", #line),
                ("IN (inboxes (name)", "\r", #line),
                ("IN (inboxes (name", "\r", #line),
                ("IN (inboxes (", "\r", #line),
                ("IN (inboxes )", "\r", #line),
                ("IN (", "\r", #line),
                ("IN", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }

    func testParseExtendedSearchOptions() {
        self.iterateTests(
            testFunction: GrammarParser().parseExtendedSearchOptions,
            validInputs: [
                (
                    " ALL", "\r",
                    ExtendedSearchOptions(key: .all),
                    #line
                ),
                (
                    " RETURN (MIN) ALL", "\r",
                    ExtendedSearchOptions(key: .all, returnOptions: [.min]),
                    #line
                ),
                (
                    " CHARSET Alien ALL", "\r",
                    ExtendedSearchOptions(key: .all, charset: "Alien"),
                    #line
                ),
                (
                    " IN (inboxes) ALL", "\r",
                    ExtendedSearchOptions(
                        key: .all,
                        sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                    ),
                    #line
                ),
                (
                    " IN (inboxes) CHARSET Alien ALL", "\r",
                    ExtendedSearchOptions(
                        key: .all,
                        charset: "Alien",
                        sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                    ),
                    #line
                ),
                (
                    " IN (inboxes) RETURN (MIN) ALL", "\r",
                    ExtendedSearchOptions(
                        key: .all,
                        returnOptions: [.min],
                        sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                    ),
                    #line
                ),
                (
                    " RETURN (MIN) CHARSET Alien ALL", "\r",
                    ExtendedSearchOptions(
                        key: .all,
                        charset: "Alien",
                        returnOptions: [.min]
                    ),
                    #line
                ),
                (
                    " IN (inboxes) RETURN (MIN) CHARSET Alien ALL", "\r",
                    ExtendedSearchOptions(
                        key: .all,
                        charset: "Alien",
                        returnOptions: [.min],
                        sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                    ),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}
