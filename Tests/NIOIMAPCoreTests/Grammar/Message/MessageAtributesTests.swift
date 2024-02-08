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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class MessageAttributesTests: EncodeTestClass {}

// MARK: - Encoding

extension MessageAttributesTests {
    func testEncode() throws {
        let components = ServerMessageDate.Components(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, timeZoneMinutes: 0)!
        let date = ServerMessageDate(components)

        let inputs: [(MessageAttribute, String, UInt)] = [
            (.rfc822Size(123), "RFC822.SIZE 123", #line),
            (.uid(123), "UID 123", #line),
            (.envelope(Envelope(date: "date", subject: "subject", from: [.singleAddress(.init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host"))], sender: [.singleAddress(.init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host"))], reply: [.singleAddress(.init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host"))], to: [.singleAddress(.init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host"))], cc: [.singleAddress(.init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host"))], bcc: [.singleAddress(.init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host"))], inReplyTo: "replyto", messageID: "abc123")), "ENVELOPE (\"date\" \"subject\" ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) \"replyto\" \"abc123\")", #line),
            (.internalDate(date), #"INTERNALDATE "25-Jun-1994 01:02:03 +0000""#, #line),
            (.binarySize(section: [2], size: 3), "BINARY.SIZE[2] 3", #line),
            (.flags([.draft]), "FLAGS (\\Draft)", #line),
            (.flags([.flagged, .draft]), "FLAGS (\\Flagged \\Draft)", #line),
            (.fetchModificationResponse(.init(modifierSequenceValue: 3)), "MODSEQ (3)", #line),
            (.gmailMessageID(1278455344230334865), "X-GM-MSGID 1278455344230334865", #line),
            (.gmailThreadID(1266894439832287888), "X-GM-THRID 1266894439832287888", #line),
            (.gmailLabels([GmailLabel("\\Inbox"), GmailLabel("\\Sent"), GmailLabel("Important"), GmailLabel("Muy Importante")]), "X-GM-LABELS (\\Inbox \\Sent \"Important\" \"Muy Importante\")", #line),
            (.preview("Lorem ipsum dolor sit amet"), "PREVIEW \"Lorem ipsum dolor sit amet\"", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMessageAttribute(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_multiple() {
        let inputs: [([MessageAttribute], String, UInt)] = [
            ([.flags([.draft])], "(FLAGS (\\Draft))", #line),
            ([.flags([.flagged]), .rfc822Size(123)], "(FLAGS (\\Flagged) RFC822.SIZE 123)", #line),
            ([.flags([.flagged]), .rfc822Size(123), .uid(456)], "(FLAGS (\\Flagged) RFC822.SIZE 123 UID 456)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMessageAttributes(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension MessageAttributesTests {
    func testCustomDebugStringConvertible() {
        let inputs: [(MessageAttribute, String, UInt)] = [
            (.rfc822Size(123), "RFC822.SIZE 123", #line),
            (.flags([.draft]), "FLAGS (\\Draft)", #line),
            (.gmailLabels([GmailLabel("\\Inbox"), GmailLabel("\\Sent"), GmailLabel("Important"), GmailLabel("Muy Importante")]), "X-GM-LABELS (\\Inbox \\Sent \"Important\" \"Muy Importante\")", #line),
        ]
        inputs.forEach { (part, expected, line) in
            XCTAssertEqual("\(part)", expected, line: line)
        }
    }
}
