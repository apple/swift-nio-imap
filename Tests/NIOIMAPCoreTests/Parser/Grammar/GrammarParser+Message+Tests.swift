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
    func testParseMessageFlags() throws {
        self.iterateTests(
            testFunction: GrammarParser().parseFlag,
            validInputs: [
                (#"\Answered"#, " ", .answered, #line),
                (#"\flagged"#, " ", .flagged, #line),
                (#"\deleted"#, " ", .deleted, #line),
                (#"\seen"#, " ", .seen, #line),
                (#"\Draft"#, " ", .draft, #line),
                (#"\extension"#, " ", .extension(#"\extension"#), #line),
                (#"$Forwarded"#, " ", "$Forwarded", #line),
                (#"Forwarded"#, " ", "Forwarded", #line),
                // Apple / NeXT flag colors:
                (#"$MailFlagBit0"#, " ", "$MailFlagBit0", #line),
                (#"$MailFlagBit2"#, " ", "$MailFlagBit2", #line),
                // Gmail exposes its labels as keyword flags:
                (#"OIB-Seen-INBOX"#, " ", "OIB-Seen-INBOX", #line),
                (#"OIB-Seen-Unsubscribe"#, " ", "OIB-Seen-Unsubscribe", #line),
                (#"OIB-Seen-[Gmail]/Trash"#, " ", "OIB-Seen-[Gmail]/Trash", #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseMessageAttribute() throws {
        let components1 = ServerMessageDate.Components(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, timeZoneMinutes: 0)
        let date1 = ServerMessageDate(components1!)
        let components2 = ServerMessageDate.Components(year: 2023, month: 3, day: 8, hour: 12, minute: 16, second: 47, timeZoneMinutes: 8 * 60)
        let date2 = ServerMessageDate(components2!)

        self.iterateTests(
            testFunction: GrammarParser().parseMessageAttribute,
            validInputs: [
                (#"FLAGS (\seen)"#, " ", .flags([.seen]), #line),
                (#"FLAGS (\Answered \Flagged \Draft)"#, " ", .flags([.answered, .flagged, .draft]), #line),
                ("UID 1234", " ", .uid(1234), #line),
                ("RFC822.SIZE 1234", " ", .rfc822Size(1234), #line),
                ("BINARY.SIZE[3] 4", " ", .binarySize(section: [3], size: 4), #line),
                (#"INTERNALDATE "25-jun-1994 01:02:03 +0000""#, " ", .internalDate(date1), #line),
                (#"INTERNALDATE "8-Mar-2023 12:16:47 +0800""#, " ", .internalDate(date2), #line), // qq.com can return a day without a leading zero
                (#"INTERNALDATE "08-Mar-2023 12:16:47 +0800""#, " ", .internalDate(date2), #line),
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
                (#"BODY (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 1772 47 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 2778 40 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015") NIL NIL NIL)"#, " ", .body(.valid(.multipart(.init(parts: [
                    .singlepart(.init(kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 47)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 1772), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                    .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 40)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 2778), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                ], mediaSubtype: .alternative, extension: .init(parameters: ["BOUNDARY": "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: []))))))), hasExtensionData: false), #line),
                (#"BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 1772 47 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 2778 40 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015") NIL NIL NIL)"#, " ", .body(.valid(.multipart(.init(parts: [
                    .singlepart(.init(kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 47)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 1772), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                    .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 40)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 2778), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                ], mediaSubtype: .alternative, extension: .init(parameters: ["BOUNDARY": "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: []))))))), hasExtensionData: true), #line),
                ("RFC822.TEXT NIL", " ", .nilBody(.rfc822Text), #line),
                ("RFC822.HEADER NIL", " ", .nilBody(.rfc822Header), #line),
                ("BINARY[4]<5> NIL", " ", .nilBody(.binary(section: [4], offset: 5)), #line),
                ("BODY[4.TEXT]<5> NIL", " ", .nilBody(.body(section: .init(part: [4], kind: .text), offset: 5)), #line),
                ("MODSEQ (3)", " ", .fetchModificationResponse(.init(modifierSequenceValue: 3)), #line),
                ("X-GM-MSGID 1278455344230334865", " ", .gmailMessageID(1278455344230334865), #line),
                ("X-GM-THRID 1278455344230334865", " ", .gmailThreadID(1278455344230334865), #line),
                ("X-GM-LABELS (\\Inbox \\Sent Important \"Muy Importante\")", " ", .gmailLabels([GmailLabel("\\Inbox"), GmailLabel("\\Sent"), GmailLabel("Important"), GmailLabel("Muy Importante")]), #line),
                ("X-GM-LABELS (foo)", " ", .gmailLabels([GmailLabel("foo")]), #line),
                ("X-GM-LABELS ()", " ", .gmailLabels([]), #line),
                (#"X-GM-LABELS (\Drafts)"#, " ", .gmailLabels([GmailLabel(#"\Drafts"#)]), #line),
                (#"X-GM-LABELS ("\\Important")"#, " ", .gmailLabels([GmailLabel(#"\Important"#)]), #line),
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
            testFunction: GrammarParser().parseMessageData,
            validInputs: [
                ("3 EXPUNGE", "\r", .expunge(3), #line),
                ("VANISHED 1:3", "\r", .vanished([1 ... 3]), #line),
                ("VANISHED (EARLIER) 1:3", "\r", .vanishedEarlier([1 ... 3]), #line),
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
