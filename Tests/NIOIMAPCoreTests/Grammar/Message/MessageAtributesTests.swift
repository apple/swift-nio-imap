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
import Testing

@Suite("MessageAttribute")
struct MessageAttributeTests {
    @Test(arguments: [
        EncodeFixture.messageAttribute(.rfc822Size(123), "RFC822.SIZE 123"),
        EncodeFixture.messageAttribute(.uid(123), "UID 123"),
        EncodeFixture.messageAttribute(
            .envelope(
                Envelope(
                    date: "date",
                    subject: "subject",
                    from: [
                        .singleAddress(
                            .init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host")
                        )
                    ],
                    sender: [
                        .singleAddress(
                            .init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host")
                        )
                    ],
                    reply: [
                        .singleAddress(
                            .init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host")
                        )
                    ],
                    to: [
                        .singleAddress(
                            .init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host")
                        )
                    ],
                    cc: [
                        .singleAddress(
                            .init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host")
                        )
                    ],
                    bcc: [
                        .singleAddress(
                            .init(personName: "name", sourceRoot: "adl", mailbox: "mailbox", host: "host")
                        )
                    ],
                    inReplyTo: "replyto",
                    messageID: "abc123"
                )
            ),
            "ENVELOPE (\"date\" \"subject\" ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) \"replyto\" \"abc123\")"
        ),
        EncodeFixture.messageAttribute(
            .internalDate(ServerMessageDate(ServerMessageDate.Components(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, timeZoneMinutes: 0)!)),
            #"INTERNALDATE "25-Jun-1994 01:02:03 +0000""#
        ),
        EncodeFixture.messageAttribute(.binarySize(section: [2], size: 3), "BINARY.SIZE[2] 3"),
        EncodeFixture.messageAttribute(.flags([.draft]), "FLAGS (\\Draft)"),
        EncodeFixture.messageAttribute(.flags([.flagged, .draft]), "FLAGS (\\Flagged \\Draft)"),
        EncodeFixture.messageAttribute(.fetchModificationResponse(.init(modifierSequenceValue: 3)), "MODSEQ (3)"),
        EncodeFixture.messageAttribute(.gmailMessageID(1_278_455_344_230_334_865), "X-GM-MSGID 1278455344230334865"),
        EncodeFixture.messageAttribute(.gmailThreadID(1_266_894_439_832_287_888), "X-GM-THRID 1266894439832287888"),
        EncodeFixture.messageAttribute(
            .gmailLabels([
                GmailLabel("\\Inbox"), GmailLabel("\\Sent"), GmailLabel("Important"), GmailLabel("Muy Importante"),
            ]),
            "X-GM-LABELS (\\Inbox \\Sent \"Important\" \"Muy Importante\")"
        ),
        EncodeFixture.messageAttribute(.preview(.init("Lorem ipsum dolor sit amet")), "PREVIEW \"Lorem ipsum dolor sit amet\""),
        EncodeFixture.messageAttribute(.preview(.init(#"A\B"#)), #"PREVIEW "A\\B""#),
        EncodeFixture.messageAttribute(.emailID(.init("123-456-789")!), "EMAILID (123-456-789)"),
        EncodeFixture.messageAttribute(.threadID(.init("123-456-789")!), "THREADID (123-456-789)"),
        EncodeFixture.messageAttribute(.threadID(nil), "THREADID NIL"),
    ])
    func encode(_ fixture: EncodeFixture<MessageAttribute>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.messageAttributes([.flags([.draft])], "(FLAGS (\\Draft))"),
        EncodeFixture.messageAttributes([.flags([.flagged]), .rfc822Size(123)], "(FLAGS (\\Flagged) RFC822.SIZE 123)"),
        EncodeFixture.messageAttributes([.flags([.flagged]), .rfc822Size(123), .uid(456)], "(FLAGS (\\Flagged) RFC822.SIZE 123 UID 456)"),
    ])
    func `encode multiple`(_ fixture: EncodeFixture<[MessageAttribute]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        DebugStringFixture(sut: MessageAttribute.rfc822Size(123), expected: "RFC822.SIZE 123"),
        DebugStringFixture(sut: MessageAttribute.flags([.draft]), expected: "FLAGS (\\Draft)"),
        DebugStringFixture(
            sut: MessageAttribute.gmailLabels([
                GmailLabel("\\Inbox"), GmailLabel("\\Sent"), GmailLabel("Important"), GmailLabel("Muy Importante"),
            ]),
            expected: "X-GM-LABELS (\\Inbox \\Sent \"Important\" \"Muy Importante\")"
        ),
    ])
    func `custom debug string convertible`(_ fixture: DebugStringFixture<MessageAttribute>) {
        fixture.check()
    }
}

// MARK: -

extension EncodeFixture<MessageAttribute> {
    fileprivate static func messageAttribute(_ input: MessageAttribute, _ expectedString: String) -> Self {
        EncodeFixture(input: input, bufferKind: .defaultServer, expectedString: expectedString, encoder: { $0.writeMessageAttribute($1) })
    }
}

extension EncodeFixture<[MessageAttribute]> {
    fileprivate static func messageAttributes(_ input: [MessageAttribute], _ expectedString: String) -> Self {
        EncodeFixture(input: input, bufferKind: .defaultServer, expectedString: expectedString, encoder: { $0.writeMessageAttributes($1) })
    }
}
