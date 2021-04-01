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

class GrammarParser_Message_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseMessageAttribute

extension GrammarParser_Message_Tests {
    func testParseMessageAttribute() throws {
        let components = ServerMessageDate.Components(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, timeZoneMinutes: 0)
        let date = ServerMessageDate(components!)

        self.iterateTests(
            testFunction: GrammarParser.parseMessageAttribute,
            validInputs: [
                ("UID 1234", " ", .uid(1234), #line),
                ("RFC822.SIZE 1234", " ", .rfc822Size(1234), #line),
                ("BINARY.SIZE[3] 4", " ", .binarySize(section: [3], size: 4), #line),
                ("BINARY[3] \"hello\"", " ", .binary(section: [3], data: "hello"), #line),
                (#"INTERNALDATE "25-jun-1994 01:02:03 +0000""#, " ", .internalDate(date), #line),
                (
                    #"ENVELOPE ("date" "subject" (("from1" "from2" "from3" "from4")) (("sender1" "sender2" "sender3" "sender4")) (("reply1" "reply2" "reply3" "reply4")) (("to1" "to2" "to3" "to4")) (("cc1" "cc2" "cc3" "cc4")) (("bcc1" "bcc2" "bcc3" "bcc4")) "inreplyto" "messageid")"#,
                    " ",
                    .envelope(Envelope(
                        date: "date",
                        subject: "subject",
                        from: [.singleAddress(.init(personName: "from1", sourceRoot: "from2", mailbox: "from3", host: "from4"))],
                        sender: [.singleAddress(.init(personName: "sender1", sourceRoot: "sender2", mailbox: "sender3", host: "sender4"))],
                        reply: [.singleAddress(.init(personName: "reply1", sourceRoot: "reply2", mailbox: "reply3", host: "reply4"))],
                        to: [.singleAddress(.init(personName: "to1", sourceRoot: "to2", mailbox: "to3", host: "to4"))],
                        cc: [.singleAddress(.init(personName: "cc1", sourceRoot: "cc2", mailbox: "cc3", host: "cc4"))],
                        bcc: [.singleAddress(.init(personName: "bcc1", sourceRoot: "bcc2", mailbox: "bcc3", host: "bcc4"))],
                        inReplyTo: "inreplyto",
                        messageID: "messageid"
                    )),
                    #line
                ),
                ("MODSEQ (3)", " ", .fetchModificationResponse(.init(modifierSequenceValue: 3)), #line),
                ("X-GM-MSGID 1278455344230334865", " ", .gmailMessageID(1278455344230334865), #line),
                ("X-GM-THRID 1278455344230334865", " ", .gmailThreadID(1278455344230334865), #line),
                ("X-GM-LABELS (\\Inbox \\Sent Important \"Muy Importante\")", " ", .gmailLabels([GmailLabel("\\Inbox"), GmailLabel("\\Sent"), GmailLabel("Important"), GmailLabel("Muy Importante")]), #line),
                ("X-GM-LABELS (foo)", " ", .gmailLabels([GmailLabel("foo")]), #line),
                ("X-GM-LABELS ()", " ", .gmailLabels([]), #line),
                ("X-GM-LABELS (\\Drafts)", " ", .gmailLabels([GmailLabel("\\Drafts")]), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseMessageData

extension GrammarParser_Message_Tests {
    func testParseMessageData() {
        self.iterateTests(
            testFunction: GrammarParser.parseMessageData,
            validInputs: [
                ("3 EXPUNGE", "\r", .expunge(3), #line),
                ("VANISHED *", "\r", .vanished(.all), #line),
                ("VANISHED (EARLIER) *", "\r", .vanishedEarlier(.all), #line),
                ("GENURLAUTH test", "\r", .generateAuthorizedURL(["test"]), #line),
                ("GENURLAUTH test1 test2", "\r", .generateAuthorizedURL(["test1", "test2"]), #line),
                ("URLFETCH url NIL", "\r", .urlFetch([.init(url: "url", data: nil)]), #line),
                (
                    "URLFETCH url1 NIL url2 NIL url3 \"data\"",
                    "\r",
                    .urlFetch([.init(url: "url1", data: nil), .init(url: "url2", data: nil), .init(url: "url3", data: "data")]),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}
