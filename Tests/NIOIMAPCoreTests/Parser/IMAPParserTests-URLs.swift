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

// MARK: - parseAuthIMAPURL

extension ParserUnitTests {
    func testParseAuthIMAPURL() {
        self.iterateTests(
            testFunction: GrammarParser().parseAuthenticatedURL,
            validInputs: [
                (
                    "imap://localhost/test/;UID=123", " ",
                    .init(
                        server: .init(host: "localhost"),
                        messagePath: .init(
                            mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                            iUID: .init(uid: 123)
                        )
                    ), #line
                )
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseAuthIMAPURLFull

extension ParserUnitTests {
    func testParseAuthIMAPURLFull() {
        self.iterateTests(
            testFunction: GrammarParser().parseAuthIMAPURLFull,
            validInputs: [
                (
                    "imap://localhost/test/;UID=123;URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901",
                    " ",
                    .init(
                        networkMessagePath: .init(
                            server: .init(host: "localhost"),
                            messagePath: .init(
                                mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                                iUID: .init(uid: 123)
                            )
                        ),
                        authenticatedURL: .init(
                            authenticatedURL: .init(access: .anonymous),
                            verifier: .init(
                                urlAuthMechanism: .internal,
                                encodedAuthenticationURL: .init(data: "01234567890123456789012345678901")
                            )
                        )
                    ),
                    #line
                )
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseAuthIMAPURLRump

extension ParserUnitTests {
    func testParseAuthIMAPURLRump() {
        self.iterateTests(
            testFunction: GrammarParser().parseAuthIMAPURLRump,
            validInputs: [
                (
                    "imap://localhost/test/;UID=123;URLAUTH=anonymous",
                    " ",
                    .init(
                        authenticatedURL: .init(
                            server: .init(host: "localhost"),
                            messagePath: .init(
                                mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                                iUID: .init(uid: 123)
                            )
                        ),
                        authenticatedURLRump: .init(access: .anonymous)
                    ),
                    #line
                )
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - IMAPURLAuthenticationMechanism

extension ParserUnitTests {
    func testParseIMAPURLAuthenticationMechanism() {
        self.iterateTests(
            testFunction: GrammarParser().parseIMAPURLAuthenticationMechanism,
            validInputs: [
                (";AUTH=*", " ", .any, #line),
                (";AUTH=test", " ", .type(.init(authenticationType: "test")), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - AbsoluteMessagePath

extension ParserUnitTests {
    func testParseAbsoluteMessagePath() {
        self.iterateTests(
            testFunction: GrammarParser().parseAbsoluteMessagePath,
            validInputs: [
                ("/", " ", .init(command: nil), #line),
                (
                    "/test", " ",
                    .init(
                        command: .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"))))
                    ), #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - URLCommand

extension ParserUnitTests {
    func testParseURLCommand() {
        self.iterateTests(
            testFunction: GrammarParser().parseURLCommand,
            validInputs: [
                (
                    "test", " ", .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test")))),
                    #line
                ),
                (
                    "test/;UID=123", " ",
                    .fetch(
                        path: .init(
                            mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                            iUID: .init(uid: 123)
                        ),
                        authenticatedURL: nil
                    ), #line
                ),
                (
                    "test/;UID=123;URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901", " ",
                    .fetch(
                        path: .init(
                            mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                            iUID: .init(uid: 123)
                        ),
                        authenticatedURL: .init(
                            authenticatedURL: .init(access: .anonymous),
                            verifier: .init(
                                urlAuthMechanism: .internal,
                                encodedAuthenticationURL: .init(data: "01234567890123456789012345678901")
                            )
                        )
                    ), #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - IUID

extension ParserUnitTests {
    func testParseIUID() {
        self.iterateTests(
            testFunction: GrammarParser().parseIUID,
            validInputs: [
                ("/;UID=1", " ", .init(uid: 1), #line),
                ("/;UID=12", " ", .init(uid: 12), #line),
                ("/;UID=123", " ", .init(uid: 123), #line),
            ],
            parserErrorInputs: [
                ("a", " ", #line)
            ],
            incompleteMessageInputs: [
                ("/;UID=1", "", #line)
            ]
        )
    }
}

// MARK: - IUIDOnly

extension ParserUnitTests {
    func testParseIUIDOnly() {
        self.iterateTests(
            testFunction: GrammarParser().parseIUIDOnly,
            validInputs: [
                (";UID=1", " ", .init(uid: 1), #line),
                (";UID=12", " ", .init(uid: 12), #line),
                (";UID=123", " ", .init(uid: 123), #line),
            ],
            parserErrorInputs: [
                ("a", " ", #line)
            ],
            incompleteMessageInputs: [
                (";UID=1", "", #line)
            ]
        )
    }
}

// MARK: - IURLAuth

extension ParserUnitTests {
    func testParseIURLAuth() {
        self.iterateTests(
            testFunction: GrammarParser().parseIURLAuth,
            validInputs: [
                (
                    ";URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901", " ",
                    .init(
                        authenticatedURL: .init(access: .anonymous),
                        verifier: .init(
                            urlAuthMechanism: .internal,
                            encodedAuthenticationURL: .init(data: "01234567890123456789012345678901")
                        )
                    ), #line
                )
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - AuthenticatedURLRump

extension ParserUnitTests {
    func testParseAuthenticatedURLRump() {
        self.iterateTests(
            testFunction: GrammarParser().parseAuthenticatedURLRump,
            validInputs: [
                (";URLAUTH=anonymous", " ", .init(access: .anonymous), #line),
                (
                    ";EXPIRE=1234-12-23T12:34:56;URLAUTH=anonymous",
                    " ",
                    .init(
                        expire: .init(
                            dateTime: .init(
                                date: .init(year: 1234, month: 12, day: 23),
                                time: .init(hour: 12, minute: 34, second: 56)
                            )
                        ),
                        access: .anonymous
                    ),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - AuthenticatedURLVerifier

extension ParserUnitTests {
    func testParseAuthenticatedURLVerifier() {
        self.iterateTests(
            testFunction: GrammarParser().parseAuthenticatedURLVerifier,
            validInputs: [
                (
                    ":INTERNAL:01234567890123456789012345678901", " ",
                    .init(
                        urlAuthMechanism: .internal,
                        encodedAuthenticationURL: .init(data: "01234567890123456789012345678901")
                    ), #line
                )
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - UserAuthenticationMechanism

extension ParserUnitTests {
    func testParseUserAuthenticationMechanism() {
        self.iterateTests(
            testFunction: GrammarParser().parseUserAuthenticationMechanism,
            validInputs: [
                (";AUTH=*", " ", .init(encodedUser: nil, authenticationMechanism: .any), #line),
                ("test", " ", .init(encodedUser: .init(data: "test"), authenticationMechanism: nil), #line),
                ("test;AUTH=*", " ", .init(encodedUser: .init(data: "test"), authenticationMechanism: .any), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEncodedAuthenticationType

extension ParserUnitTests {
    func testParseEncodedAuthenticationType() {
        self.iterateTests(
            testFunction: GrammarParser().parseEncodedAuthenticationType,
            validInputs: [
                ("hello%FF", " ", .init(authenticationType: "hello%FF"), #line)
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEncodedMailbox

extension ParserUnitTests {
    func testParseEncodedMailbox() {
        self.iterateTests(
            testFunction: GrammarParser().parseEncodedMailbox,
            validInputs: [
                ("hello%FF", " ", .init(mailbox: "hello%FF"), #line)
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseNetworkPath

extension ParserUnitTests {
    func testParseNetworkPath() {
        self.iterateTests(
            testFunction: GrammarParser().parseNetworkPath,
            validInputs: [
                ("//localhost/", " ", .init(server: .init(host: "localhost"), query: nil), #line),
                (
                    "//localhost/test/;UID=123",
                    " ",
                    .init(
                        server: .init(host: "localhost"),
                        query: .fetch(
                            path: .init(
                                mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                                iUID: .init(uid: 123)
                            ),
                            authenticatedURL: nil
                        )
                    ),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEncodedSearch

extension ParserUnitTests {
    func testParseEncodedSearch() {
        self.iterateTests(
            testFunction: GrammarParser().parseEncodedSearch,
            validInputs: [
                ("query%FF", " ", .init(query: "query%FF"), #line)
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEncodedSection

extension ParserUnitTests {
    func testParseEncodedSection() {
        self.iterateTests(
            testFunction: GrammarParser().parseEncodedSection,
            validInputs: [
                ("query%FF", " ", .init(section: "query%FF"), #line)
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEncodedUser

extension ParserUnitTests {
    func testParseEncodedUser() {
        self.iterateTests(
            testFunction: GrammarParser().parseEncodedUser,
            validInputs: [
                ("query%FF", " ", .init(data: "query%FF"), #line)
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEncodedURLAuth

extension ParserUnitTests {
    func testParseEncodedURLAuth() {
        self.iterateTests(
            testFunction: GrammarParser().parseEncodedURLAuth,
            validInputs: [
                ("0123456789abcdef01234567890abcde", "", .init(data: "0123456789abcdef01234567890abcde"), #line)
            ],
            parserErrorInputs: [
                ("0123456789zbcdef01234567890abcde", "", #line)
            ],
            incompleteMessageInputs: [
                ("0123456789", "", #line)
            ]
        )
    }
}

// MARK: - parseExpire

extension ParserUnitTests {
    func testParseExpire() {
        self.iterateTests(
            testFunction: GrammarParser().parseExpire,
            validInputs: [
                (
                    ";EXPIRE=1234-12-20T12:34:56",
                    "\r",
                    Expire(
                        dateTime: FullDateTime(
                            date: FullDate(year: 1234, month: 12, day: 20),
                            time: FullTime(hour: 12, minute: 34, second: 56)
                        )
                    ),
                    #line
                ),
                (
                    ";EXPIRE=1234-12-20t12:34:56",
                    "\r",
                    Expire(
                        dateTime: FullDateTime(
                            date: FullDate(year: 1234, month: 12, day: 20),
                            time: FullTime(hour: 12, minute: 34, second: 56)
                        )
                    ),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMessagePathByteRange

extension ParserUnitTests {
    func testParseMessagePathByteRange() {
        self.iterateTests(
            testFunction: GrammarParser().parseMessagePathByteRange,
            validInputs: [
                ("/;PARTIAL=1", " ", .init(range: .init(offset: 1, length: nil)), #line),
                ("/;PARTIAL=1.2", " ", .init(range: .init(offset: 1, length: 2)), #line),
            ],
            parserErrorInputs: [
                ("/;PARTIAL=a", " ", #line),
                ("PARTIAL=a", " ", #line),
            ],
            incompleteMessageInputs: [
                ("/;PARTIAL=1", "", #line)
            ]
        )
    }
}

// MARK: - parseMessagePathByteRangeOnly

extension ParserUnitTests {
    func testParseMessagePathByteRangeOnly() {
        self.iterateTests(
            testFunction: GrammarParser().parseMessagePathByteRangeOnly,
            validInputs: [
                (";PARTIAL=1", " ", .init(range: .init(offset: 1, length: nil)), #line),
                (";PARTIAL=1.2", " ", .init(range: .init(offset: 1, length: 2)), #line),
            ],
            parserErrorInputs: [
                (";PARTIAL=a", " ", #line),
                ("PARTIAL=a", " ", #line),
            ],
            incompleteMessageInputs: [
                (";PARTIAL=1", "", #line)
            ]
        )
    }
}

// MARK: - parseIMAPURLSection

extension ParserUnitTests {
    func testParseIMAPURLSection() {
        self.iterateTests(
            testFunction: GrammarParser().parseIMAPURLSection,
            validInputs: [
                ("/;SECTION=a", " ", URLMessageSection(encodedSection: .init(section: "a")), #line),
                ("/;SECTION=abc", " ", URLMessageSection(encodedSection: .init(section: "abc")), #line),
            ],
            parserErrorInputs: [
                ("SECTION=a", " ", #line)
            ],
            incompleteMessageInputs: [
                ("/;SECTION=1", "", #line)
            ]
        )
    }
}

// MARK: - parseIMAPURLSectionOnly

extension ParserUnitTests {
    func testParseIMAPURLSectionOnly() {
        self.iterateTests(
            testFunction: GrammarParser().parseIMAPURLSectionOnly,
            validInputs: [
                (";SECTION=a", " ", URLMessageSection(encodedSection: .init(section: "a")), #line),
                (";SECTION=abc", " ", URLMessageSection(encodedSection: .init(section: "abc")), #line),
            ],
            parserErrorInputs: [
                ("SECTION=a", " ", #line)
            ],
            incompleteMessageInputs: [
                (";SECTION=1", "", #line)
            ]
        )
    }
}

// MARK: - parseIMAPServer

extension ParserUnitTests {
    func testParseIMAPServer() {
        self.iterateTests(
            testFunction: GrammarParser().parseIMAPServer,
            validInputs: [
                ("localhost", " ", .init(userAuthenticationMechanism: nil, host: "localhost", port: nil), #line),
                (
                    ";AUTH=*@localhost", " ",
                    .init(
                        userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any),
                        host: "localhost",
                        port: nil
                    ), #line
                ),
                ("localhost:1234", " ", .init(userAuthenticationMechanism: nil, host: "localhost", port: 1234), #line),
                (
                    ";AUTH=*@localhost:1234", " ",
                    .init(
                        userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any),
                        host: "localhost",
                        port: 1234
                    ), #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEncodedMailboxUIDValidity

extension ParserUnitTests {
    func testParseEncodedMailboxUIDValidity() {
        self.iterateTests(
            testFunction: GrammarParser().parseEncodedMailboxUIDValidity,
            validInputs: [
                ("abc", " ", .init(encodeMailbox: .init(mailbox: "abc"), uidValidity: nil), #line),
                ("abc;UIDVALIDITY=123", " ", .init(encodeMailbox: .init(mailbox: "abc"), uidValidity: 123), #line),
            ],
            parserErrorInputs: [
                ("¢", " ", #line)
            ],
            incompleteMessageInputs: [
                ("abc", "", #line),
                ("abc123", "", #line),
            ]
        )
    }
}

// MARK: - parseIMapURL

extension ParserUnitTests {
    func testParseIMAPURL() {
        self.iterateTests(
            testFunction: GrammarParser().parseIMAPURL,
            validInputs: [
                ("imap://localhost/", " ", .init(server: .init(host: "localhost"), query: nil), #line),
                (
                    "imap://localhost/test/;UID=123",
                    " ",
                    .init(
                        server: .init(host: "localhost"),
                        query: .fetch(
                            path: .init(
                                mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                                iUID: .init(uid: 123)
                            ),
                            authenticatedURL: nil
                        )
                    ),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseURLRumpMechanism

extension ParserUnitTests {
    func testParseURLRumpMechanism() {
        self.iterateTests(
            testFunction: GrammarParser().parseURLRumpMechanism,
            validInputs: [
                ("test INTERNAL", " ", .init(urlRump: "test", mechanism: .internal), #line),
                ("\"test\" INTERNAL", " ", .init(urlRump: "test", mechanism: .internal), #line),
                ("{4}\r\ntest INTERNAL", " ", .init(urlRump: "test", mechanism: .internal), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseURLFetchData

extension ParserUnitTests {
    func testParseURLFetchData() {
        self.iterateTests(
            testFunction: GrammarParser().parseURLFetchData,
            validInputs: [
                ("url NIL", " ", .init(url: "url", data: nil), #line),
                ("url \"data\"", " ", .init(url: "url", data: "data"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseIMapURLRel

extension ParserUnitTests {
    func testParseIMAPURLRel() {
        self.iterateTests(
            testFunction: GrammarParser().parseRelativeIMAPURL,
            validInputs: [
                (
                    "/test", " ",
                    .absolutePath(
                        .init(
                            command: .messageList(
                                .init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test")))
                            )
                        )
                    ), #line
                ),
                ("//localhost/", " ", .networkPath(.init(server: .init(host: "localhost"), query: nil)), #line),
                ("", " ", .empty, #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEncodedSearchQuery

extension ParserUnitTests {
    func testParseEncodedSearchQuery() {
        self.iterateTests(
            testFunction: GrammarParser().parseEncodedSearchQuery,
            validInputs: [
                (
                    "test", " ",
                    .init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"), uidValidity: nil)), #line
                ),
                (
                    "test?query", " ",
                    .init(
                        mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"), uidValidity: nil),
                        encodedSearch: .init(query: "query")
                    ), #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseIMessageOrPart

extension ParserUnitTests {
    func testParseURLFetchType() {
        self.iterateTests(
            testFunction: GrammarParser().parseURLFetchType,
            validInputs: [
                (
                    ";PARTIAL=1.2",
                    " ",
                    .partialOnly(.init(range: .init(offset: 1, length: 2))),
                    #line
                ),
                (
                    ";SECTION=test",
                    " ",
                    .sectionPartial(section: .init(encodedSection: .init(section: "test")), partial: nil),
                    #line
                ),
                (
                    ";SECTION=test/;PARTIAL=1.2",
                    " ",
                    .sectionPartial(
                        section: .init(encodedSection: .init(section: "test")),
                        partial: .init(range: .init(offset: 1, length: 2))
                    ),
                    #line
                ),
                (
                    ";UID=123",
                    " ",
                    .uidSectionPartial(uid: .init(uid: 123), section: nil, partial: nil),
                    #line
                ),
                (
                    ";UID=123/;SECTION=test",
                    " ",
                    .uidSectionPartial(
                        uid: .init(uid: 123),
                        section: .init(encodedSection: .init(section: "test")),
                        partial: nil
                    ),
                    #line
                ),
                (
                    ";UID=123/;PARTIAL=1.2",
                    " ",
                    .uidSectionPartial(
                        uid: .init(uid: 123),
                        section: nil,
                        partial: .init(range: .init(offset: 1, length: 2))
                    ),
                    #line
                ),
                (
                    ";UID=123/;SECTION=test/;PARTIAL=1.2",
                    " ",
                    .uidSectionPartial(
                        uid: .init(uid: 123),
                        section: .init(encodedSection: .init(section: "test")),
                        partial: .init(range: .init(offset: 1, length: 2))
                    ),
                    #line
                ),
                (
                    "test;UID=123",
                    " ",
                    .refUidSectionPartial(
                        ref: .init(encodeMailbox: .init(mailbox: "test")),
                        uid: .init(uid: 123),
                        section: nil,
                        partial: nil
                    ),
                    #line
                ),
                (
                    "test;UID=123/;SECTION=section",
                    " ",
                    .refUidSectionPartial(
                        ref: .init(encodeMailbox: .init(mailbox: "test")),
                        uid: .init(uid: 123),
                        section: .init(encodedSection: .init(section: "section")),
                        partial: nil
                    ),
                    #line
                ),
                (
                    "test;UID=123/;PARTIAL=1.2",
                    " ",
                    .refUidSectionPartial(
                        ref: .init(encodeMailbox: .init(mailbox: "test")),
                        uid: .init(uid: 123),
                        section: nil,
                        partial: .init(range: .init(offset: 1, length: 2))
                    ),
                    #line
                ),
                (
                    "test;UID=123/;SECTION=section/;PARTIAL=1.2",
                    " ",
                    .refUidSectionPartial(
                        ref: .init(encodeMailbox: .init(mailbox: "test")),
                        uid: .init(uid: 123),
                        section: .init(encodedSection: .init(section: "section")),
                        partial: .init(range: .init(offset: 1, length: 2))
                    ),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMessagePart

extension ParserUnitTests {
    func testParseMessagePart() {
        self.iterateTests(
            testFunction: GrammarParser().parseMessagePath,
            validInputs: [
                (
                    "test/;UID=123",
                    " ",
                    .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123),
                        section: nil,
                        range: nil
                    ),
                    #line
                ),
                (
                    "test/;UID=123/;SECTION=section",
                    " ",
                    .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123),
                        section: .init(encodedSection: .init(section: "section")),
                        range: nil
                    ),
                    #line
                ),
                (
                    "test/;UID=123/;PARTIAL=1.2",
                    " ",
                    .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123),
                        section: nil,
                        range: .init(range: .init(offset: 1, length: 2))
                    ),
                    #line
                ),
                (
                    "test/;UID=123/;SECTION=section/;PARTIAL=1.2",
                    " ",
                    .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123),
                        section: .init(encodedSection: .init(section: "section")),
                        range: .init(range: .init(offset: 1, length: 2))
                    ),
                    #line
                ),
                (
                    "test/;UIDVALIDITY=123/;UID=123/;SECTION=section/;PARTIAL=1.2",
                    " ",
                    .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test/"), uidValidity: 123),
                        iUID: .init(uid: 123),
                        section: .init(encodedSection: .init(section: "section")),
                        range: .init(range: .init(offset: 1, length: 2))
                    ),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseUAuthMechanism

extension ParserUnitTests {
    func testParseUAuthMechanism() {
        self.iterateTests(
            testFunction: GrammarParser().parseUAuthMechanism,
            validInputs: [
                ("INTERNAL", " ", .internal, #line),
                ("abcdEFG0123456789", " ", .init("abcdEFG0123456789"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseAccess

extension ParserUnitTests {
    func testParseAccess() {
        self.iterateTests(
            testFunction: GrammarParser().parseAccess,
            validInputs: [
                ("authuser", "", .authenticateUser, #line),
                ("anonymous", "", .anonymous, #line),
                ("submit+abc", " ", .submit(.init(data: "abc")), #line),
                ("user+abc", " ", .user(.init(data: "abc")), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}
