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

class GrammarParser_Envelope_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseEnvelopeEmailAddressGroups

extension GrammarParser_Envelope_Tests {
    func testParseEnvelopeEmailAddressGroups() {
        let inputs: [([EmailAddress], [EmailAddressListElement], UInt)] = [
            ([], [], #line), // extreme case, this should never happen, but we don't want to crash
            ( // single address
                [.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")],
                [.singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"))],
                #line
            ),
            ( // multiple addresses
                [.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"), .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b")],
                [.singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")), .singleAddress(.init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"))],
                #line
            ),
            ( // single group: 1 address
                [
                    .init(personName: nil, sourceRoot: nil, mailbox: "group", host: nil),
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                ],
                [
                    .group(.init(groupName: "group", sourceRoot: nil, children: [.singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"))])),
                ],
                #line
            ),
            ( // 1 address with no information
                [
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                ],
                [
                    .singleAddress(.init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil))
                ],
                #line
            ),
            ( // single group: 1 address
                [
                    .init(personName: nil, sourceRoot: nil, mailbox: "group", host: nil),
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"),
                    .init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c"),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                ],
                [
                    .group(.init(groupName: "group", sourceRoot: nil, children: [
                        .singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")),
                        .singleAddress(.init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b")),
                        .singleAddress(.init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c")),
                    ])),
                ],
                #line
            ),
            ( // nested groups
                [
                    .init(personName: nil, sourceRoot: nil, mailbox: "group1", host: nil),
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: nil, sourceRoot: nil, mailbox: "group2", host: nil),
                    .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"),
                    .init(personName: nil, sourceRoot: nil, mailbox: "group3", host: nil),
                    .init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c"),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                ],
                [
                    .group(.init(groupName: "group1", sourceRoot: nil, children: [
                        .singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")),
                        .group(.init(groupName: "group2", sourceRoot: nil, children: [
                            .singleAddress(.init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b")),
                            .group(.init(groupName: "group3", sourceRoot: nil, children: [
                                .singleAddress(.init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c")),
                            ])),
                        ])),
                    ])),
                ],
                #line
            ),
        ]
        for (original, expected, line) in inputs {
            let actual = GrammarParser().parseEnvelopeEmailAddressGroups(original)
            XCTAssertEqual(actual, expected, line: line)
        }
    }
}

// MARK: - parseEnvelopeEmailAddresses

extension GrammarParser_Envelope_Tests {
    func testParseEnvelopeEmailAddresses() {
        self.iterateTests(
            testFunction: GrammarParser().parseEnvelopeEmailAddresses,
            validInputs: [
                (
                    "((NIL NIL NIL NIL))",
                    " ",
                    [.init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil)],
                    #line
                ),
                (
                    "((\"a\" \"b\" \"c\" \"d\"))",
                    " ",
                    [.init(personName: "a", sourceRoot: "b", mailbox: "c", host: "d")],
                    #line
                ),
                (
                    "((\"a\" \"b\" \"c\" \"d\"))",
                    " ",
                    [.init(personName: "a", sourceRoot: "b", mailbox: "c", host: "d")],
                    #line
                ),
            ],
            parserErrorInputs: [], incompleteMessageInputs: []
        )
    }
}

// MARK: - parseOptionalEnvelopeEmailAddresses

extension GrammarParser_Envelope_Tests {
    func testParseOptionalEnvelopeEmailAddresses() {
        self.iterateTests(
            testFunction: GrammarParser().parseOptionalEnvelopeEmailAddresses,
            validInputs: [
                ("NIL", " ", [], #line),
            ],
            parserErrorInputs: [], incompleteMessageInputs: []
        )
    }
}

// MARK: - parseEnvelope

extension GrammarParser_Envelope_Tests {
    func testParseEnvelopeTo_valid() {
        TestUtilities.withParseBuffer(#"("date" "subject" (("name1" "adl1" "mailbox1" "host1")) (("name2" "adl2" "mailbox2" "host2")) (("name3" "adl3" "mailbox3" "host3")) (("name4" "adl4" "mailbox4" "host4")) (("name5" "adl5" "mailbox5" "host5")) (("name6" "adl6" "mailbox6" "host6")) "someone" "messageid")"#) { (buffer) in
            let envelope = try GrammarParser().parseEnvelope(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(envelope.date, "date")
            XCTAssertEqual(envelope.subject, "subject")
            XCTAssertEqual(envelope.from, [.singleAddress(.init(personName: "name1", sourceRoot: "adl1", mailbox: "mailbox1", host: "host1"))])
            XCTAssertEqual(envelope.sender, [.singleAddress(.init(personName: "name2", sourceRoot: "adl2", mailbox: "mailbox2", host: "host2"))])
            XCTAssertEqual(envelope.reply, [.singleAddress(.init(personName: "name3", sourceRoot: "adl3", mailbox: "mailbox3", host: "host3"))])
            XCTAssertEqual(envelope.to, [.singleAddress(.init(personName: "name4", sourceRoot: "adl4", mailbox: "mailbox4", host: "host4"))])
            XCTAssertEqual(envelope.cc, [.singleAddress(.init(personName: "name5", sourceRoot: "adl5", mailbox: "mailbox5", host: "host5"))])
            XCTAssertEqual(envelope.bcc, [.singleAddress(.init(personName: "name6", sourceRoot: "adl6", mailbox: "mailbox6", host: "host6"))])
            XCTAssertEqual(envelope.inReplyTo, "someone")
            XCTAssertEqual(envelope.messageID, "messageid")
        }
    }
}
