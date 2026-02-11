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

// MARK: - copy parseCopy

extension ParserUnitTests {
    func testCopy_valid() {
        TestUtilities.withParseBuffer("COPY 1,2,3 inbox", terminator: " ") { (buffer) in
            let copy = try GrammarParser().parseCommand(buffer: &buffer, tracker: .testTracker)
            let expectedSequence: LastCommandSet<SequenceNumber> = LastCommandSet.set([1, 2, 3])
            let expectedMailbox = MailboxName.inbox
            XCTAssertEqual(copy, Command.copy(expectedSequence, expectedMailbox))
        }
    }

    func testCopy_invalid_missing_mailbox() {
        var buffer = TestUtilities.makeParseBuffer(for: "COPY 1,2,3,4 ")
        XCTAssertThrowsError(try PL.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }

    func testCopy_invalid_missing_set() {
        var buffer = TestUtilities.makeParseBuffer(for: "COPY inbox ")
        XCTAssertThrowsError(try PL.parseNewline(buffer: &buffer, tracker: .testTracker)) { error in
            XCTAssert(error is ParserError)
        }
    }
}

// MARK: - delete parseDelete

extension ParserUnitTests {
    func testDelete_valid() {
        TestUtilities.withParseBuffer("DELETE inbox", terminator: "\n") { (buffer) in
            let commandType = try GrammarParser().parseCommand(buffer: &buffer, tracker: .testTracker)
            guard case Command.delete(let mailbox) = commandType else {
                XCTFail("Didn't parse delete")
                return
            }
            XCTAssertEqual(mailbox, MailboxName("inbox"))
        }
    }

    func testDelete_valid_mixedCase() {
        TestUtilities.withParseBuffer("DELete inbox", terminator: "\n") { (buffer) in
            let commandType = try GrammarParser().parseCommand(buffer: &buffer, tracker: .testTracker)
            guard case Command.delete(let mailbox) = commandType else {
                XCTFail("Didn't parse delete")
                return
            }
            XCTAssertEqual(mailbox, MailboxName("inbox"))
        }
    }

    func testDelete_invalid_incomplete() {
        var buffer = TestUtilities.makeParseBuffer(for: "DELETE ")
        XCTAssertThrowsError(try GrammarParser().parseCommand(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is IncompleteMessage, "e has type \(e)")
        }
    }
}

// MARK: - subscribe parseSubscribe

extension ParserUnitTests {
    func testParseSubscribe() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommand,
            validInputs: [
                ("SUBSCRIBE inbox", "\r\n", .subscribe(.inbox), #line),
                ("SUBScribe INBOX", "\r\n", .subscribe(.inbox), #line),
            ],
            parserErrorInputs: [
                ("SUBSCRIBE ", "\r", #line)
            ],
            incompleteMessageInputs: [
                ("SUBSCRIBE ", "", #line)
            ]
        )
    }
}

// MARK: - unsubscribe parseUnsubscribe

extension ParserUnitTests {
    func testParseUnsubscribe() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommand,
            validInputs: [
                ("UNSUBSCRIBE inbox", "\r\n", .unsubscribe(.inbox), #line),
                ("UNSUBScribe INBOX", "\r\n", .unsubscribe(.inbox), #line),
            ],
            parserErrorInputs: [
                ("UNSUBSCRIBE \r", " ", #line)
            ],
            incompleteMessageInputs: [
                ("UNSUBSCRIBE", " ", #line)
            ]
        )
    }
}

// MARK: - parseRename

extension ParserUnitTests {
    func testParseRename() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommand,
            validInputs: [
                ("RENAME box1 box2", "\r", .rename(from: .init("box1"), to: .init("box2"), parameters: [:]), #line),
                ("rename box3 box4", "\r", .rename(from: .init("box3"), to: .init("box4"), parameters: [:]), #line),
                (
                    "RENAME box5 box6 (test)", "\r",
                    .rename(from: .init("box5"), to: .init("box6"), parameters: ["test": nil]), #line
                ),
            ],
            parserErrorInputs: [
                ("RENAME box1 ", "\r", #line)
            ],
            incompleteMessageInputs: [
                ("RENAME box1 ", "", #line)
            ]
        )
    }
}

// MARK: - parseNamespaceCommand

extension ParserUnitTests {
    func testParseNamespaceCommand() {
        self.iterateTests(
            testFunction: GrammarParser().parseCommand,
            validInputs: [
                ("NAMESPACE", " ", .namespace, #line),
                ("nameSPACE", " ", .namespace, #line),
                ("namespace", " ", .namespace, #line),
            ],
            parserErrorInputs: [
                ("something", " ", #line)
            ],
            incompleteMessageInputs: [
                ("", "", #line),
                ("name", "", #line),
            ]
        )
    }
}

// MARK: - parseSelectParameter

extension ParserUnitTests {
    func testParseSelectParameter() {
        self.iterateTests(
            testFunction: GrammarParser().parseSelectParameter,
            validInputs: [
                ("test 1", "\r", .basic(.init(key: "test", value: .sequence(.set([1])))), #line),
                (
                    "QRESYNC (1 1)", "\r",
                    .qresync(
                        .init(uidValidity: 1, modificationSequenceValue: 1, knownUIDs: nil, sequenceMatchData: nil)
                    ), #line
                ),
                (
                    "QRESYNC (1 1 1:2)", "\r",
                    .qresync(
                        .init(uidValidity: 1, modificationSequenceValue: 1, knownUIDs: [1...2], sequenceMatchData: nil)
                    ), #line
                ),
                (
                    "QRESYNC (1 1 1:2 (1:* 1:*))", "\r",
                    .qresync(
                        .init(
                            uidValidity: 1,
                            modificationSequenceValue: 1,
                            knownUIDs: [1...2],
                            sequenceMatchData: .init(knownSequenceSet: .set(.all), knownUidSet: .set(.all))
                        )
                    ), #line
                ),
            ],
            parserErrorInputs: [
                ("1", "\r", #line)
            ],
            incompleteMessageInputs: [
                ("test ", "", #line),
                ("QRESYNC (", "", #line),
                ("QRESYNC (1 1", "", #line),
            ]
        )
    }
}

// MARK: - parseInitialResponse

extension ParserUnitTests {
    func testParseInitialResponse() {
        self.iterateTests(
            testFunction: GrammarParser().parseInitialResponse,
            validInputs: [
                ("=", " ", .empty, #line),
                ("YQ==", " ", .init("a"), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}
