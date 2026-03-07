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
            .internalDate(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 1994,
                        month: 6,
                        day: 25,
                        hour: 1,
                        minute: 2,
                        second: 3,
                        timeZoneMinutes: 0
                    )!
                )
            ),
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
        EncodeFixture.messageAttribute(
            .preview(.init("Lorem ipsum dolor sit amet")),
            "PREVIEW \"Lorem ipsum dolor sit amet\""
        ),
        EncodeFixture.messageAttribute(.preview(.init(#"A\B"#)), #"PREVIEW "A\\B""#),
        EncodeFixture.messageAttribute(.emailID(.init("123-456-789")!), "EMAILID (123-456-789)"),
        EncodeFixture.messageAttribute(.threadID(.init("123-456-789")!), "THREADID (123-456-789)"),
        EncodeFixture.messageAttribute(.threadID(nil), "THREADID NIL"),
        EncodeFixture.messageAttribute(.body(.invalid, hasExtensionData: false), "BODY ()"),
        EncodeFixture.messageAttribute(.body(.invalid, hasExtensionData: true), "BODYSTRUCTURE ()"),
        EncodeFixture.messageAttribute(.nilBody(.rfc822Text), "RFC822.TEXT NIL"),
        EncodeFixture.messageAttribute(.nilBody(.rfc822Header), "RFC822.HEADER NIL"),
        EncodeFixture.messageAttribute(
            .nilBody(.body(section: .init(part: [4], kind: .text), offset: 5)),
            "BODY[4.TEXT]<5> NIL"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MessageAttribute>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode multiple",
        arguments: [
            EncodeFixture.messageAttributes([.flags([.draft])], "(FLAGS (\\Draft))"),
            EncodeFixture.messageAttributes(
                [.flags([.flagged]), .rfc822Size(123)],
                "(FLAGS (\\Flagged) RFC822.SIZE 123)"
            ),
            EncodeFixture.messageAttributes(
                [.flags([.flagged]), .rfc822Size(123), .uid(456)],
                "(FLAGS (\\Flagged) RFC822.SIZE 123 UID 456)"
            ),
        ]
    )
    func encodeMultiple(_ fixture: EncodeFixture<[MessageAttribute]>) {
        fixture.checkEncoding()
    }

    @Test(
        "custom debug string convertible",
        arguments: [
            DebugStringFixture(sut: MessageAttribute.rfc822Size(123), expected: "RFC822.SIZE 123"),
            DebugStringFixture(sut: MessageAttribute.flags([.draft]), expected: "FLAGS (\\Draft)"),
            DebugStringFixture(
                sut: MessageAttribute.gmailLabels([
                    GmailLabel("\\Inbox"), GmailLabel("\\Sent"), GmailLabel("Important"), GmailLabel("Muy Importante"),
                ]),
                expected: "X-GM-LABELS (\\Inbox \\Sent \"Important\" \"Muy Importante\")"
            ),
        ]
    )
    func customDebugStringConvertible(_ fixture: DebugStringFixture<MessageAttribute>) {
        fixture.check()
    }

    @Test(arguments: Self.parseMessageAttributeFixtures())
    func parse(_ fixture: ParseFixture<MessageAttribute>) {
        fixture.checkParsing()
    }

    private static func parseMessageAttributeFixtures() -> [ParseFixture<MessageAttribute>] {
        let components1 = ServerMessageDate.Components(
            year: 1994,
            month: 6,
            day: 25,
            hour: 1,
            minute: 2,
            second: 3,
            timeZoneMinutes: 0
        )
        let date1 = ServerMessageDate(components1!)
        let components2 = ServerMessageDate.Components(
            year: 2023,
            month: 3,
            day: 8,
            hour: 12,
            minute: 16,
            second: 47,
            timeZoneMinutes: 8 * 60
        )
        let date2 = ServerMessageDate(components2!)

        return [
            ParseFixture.messageAttribute(#"FLAGS (\seen)"#, " ", expected: .success(.flags([.seen]))),
            ParseFixture.messageAttribute(
                #"FLAGS (\Answered \Flagged \Draft)"#,
                " ",
                expected: .success(.flags([.answered, .flagged, .draft]))
            ),
            ParseFixture.messageAttribute("UID 1234", " ", expected: .success(.uid(1234))),
            ParseFixture.messageAttribute("RFC822.SIZE 1234", " ", expected: .success(.rfc822Size(1234))),
            ParseFixture.messageAttribute(
                "BINARY.SIZE[3] 4",
                " ",
                expected: .success(.binarySize(section: [3], size: 4))
            ),
            ParseFixture.messageAttribute(
                #"INTERNALDATE "25-jun-1994 01:02:03 +0000""#,
                " ",
                expected: .success(.internalDate(date1))
            ),
            ParseFixture.messageAttribute(
                #"INTERNALDATE "8-Mar-2023 12:16:47 +0800""#,
                " ",
                expected: .success(.internalDate(date2))
            ),
            ParseFixture.messageAttribute(
                #"INTERNALDATE "08-Mar-2023 12:16:47 +0800""#,
                " ",
                expected: .success(.internalDate(date2))
            ),
            ParseFixture.messageAttribute(
                #"ENVELOPE ("date" "subject" (("from1" "from2" "from3" "from4")) (("sender1" "sender2" "sender3" "sender4")) (("reply1" "reply2" "reply3" "reply4")) (("to1" "to2" "to3" "to4")) (("cc1" "cc2" "cc3" "cc4")) (("bcc1" "bcc2" "bcc3" "bcc4")) "inreplyto" "messageid")"#,
                " ",
                expected: .success(
                    .envelope(
                        Envelope(
                            date: "date",
                            subject: "subject",
                            from: [
                                .singleAddress(
                                    .init(personName: "from1", sourceRoot: "from2", mailbox: "from3", host: "from4")
                                )
                            ],
                            sender: [
                                .singleAddress(
                                    .init(
                                        personName: "sender1",
                                        sourceRoot: "sender2",
                                        mailbox: "sender3",
                                        host: "sender4"
                                    )
                                )
                            ],
                            reply: [
                                .singleAddress(
                                    .init(personName: "reply1", sourceRoot: "reply2", mailbox: "reply3", host: "reply4")
                                )
                            ],
                            to: [
                                .singleAddress(.init(personName: "to1", sourceRoot: "to2", mailbox: "to3", host: "to4"))
                            ],
                            cc: [
                                .singleAddress(.init(personName: "cc1", sourceRoot: "cc2", mailbox: "cc3", host: "cc4"))
                            ],
                            bcc: [
                                .singleAddress(
                                    .init(personName: "bcc1", sourceRoot: "bcc2", mailbox: "bcc3", host: "bcc4")
                                )
                            ],
                            inReplyTo: "inreplyto",
                            messageID: "messageid"
                        )
                    )
                )
            ),
            ParseFixture.messageAttribute(
                #"BODY (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 1772 47 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 2778 40 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015") NIL NIL NIL)"#,
                " ",
                expected: .success(
                    .body(
                        .valid(
                            .multipart(
                                .init(
                                    parts: [
                                        .singlepart(
                                            .init(
                                                kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 47)),
                                                fields: .init(
                                                    parameters: ["CHARSET": "utf-8"],
                                                    id: nil,
                                                    contentDescription: nil,
                                                    encoding: .quotedPrintable,
                                                    octetCount: 1772
                                                ),
                                                extension: .init(
                                                    digest: nil,
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        ),
                                        .singlepart(
                                            .init(
                                                kind: .text(.init(mediaSubtype: "HTML", lineCount: 40)),
                                                fields: .init(
                                                    parameters: ["CHARSET": "utf-8"],
                                                    id: nil,
                                                    contentDescription: nil,
                                                    encoding: .quotedPrintable,
                                                    octetCount: 2778
                                                ),
                                                extension: .init(
                                                    digest: nil,
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        ),
                                    ],
                                    mediaSubtype: .alternative,
                                    extension: .init(
                                        parameters: ["BOUNDARY": "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015"],
                                        dispositionAndLanguage: .init(
                                            disposition: nil,
                                            language: .init(
                                                languages: [],
                                                location: .init(location: nil, extensions: [])
                                            )
                                        )
                                    )
                                )
                            )
                        ),
                        hasExtensionData: false
                    )
                )
            ),
            ParseFixture.messageAttribute(
                #"BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 1772 47 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 2778 40 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015") NIL NIL NIL)"#,
                " ",
                expected: .success(
                    .body(
                        .valid(
                            .multipart(
                                .init(
                                    parts: [
                                        .singlepart(
                                            .init(
                                                kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 47)),
                                                fields: .init(
                                                    parameters: ["CHARSET": "utf-8"],
                                                    id: nil,
                                                    contentDescription: nil,
                                                    encoding: .quotedPrintable,
                                                    octetCount: 1772
                                                ),
                                                extension: .init(
                                                    digest: nil,
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        ),
                                        .singlepart(
                                            .init(
                                                kind: .text(.init(mediaSubtype: "HTML", lineCount: 40)),
                                                fields: .init(
                                                    parameters: ["CHARSET": "utf-8"],
                                                    id: nil,
                                                    contentDescription: nil,
                                                    encoding: .quotedPrintable,
                                                    octetCount: 2778
                                                ),
                                                extension: .init(
                                                    digest: nil,
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        ),
                                    ],
                                    mediaSubtype: .alternative,
                                    extension: .init(
                                        parameters: ["BOUNDARY": "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015"],
                                        dispositionAndLanguage: .init(
                                            disposition: nil,
                                            language: .init(
                                                languages: [],
                                                location: .init(location: nil, extensions: [])
                                            )
                                        )
                                    )
                                )
                            )
                        ),
                        hasExtensionData: true
                    )
                )
            ),
            ParseFixture.messageAttribute(
                #"BODYSTRUCTURE ("text")"#,
                " ",
                expected: .success(.body(.invalid, hasExtensionData: true))
            ),
            ParseFixture.messageAttribute("RFC822.TEXT NIL", " ", expected: .success(.nilBody(.rfc822Text))),
            ParseFixture.messageAttribute("RFC822.HEADER NIL", " ", expected: .success(.nilBody(.rfc822Header))),
            ParseFixture.messageAttribute(
                "BINARY[4]<5> NIL",
                " ",
                expected: .success(.nilBody(.binary(section: [4], offset: 5)))
            ),
            ParseFixture.messageAttribute(
                "BODY[4.TEXT]<5> NIL",
                " ",
                expected: .success(.nilBody(.body(section: .init(part: [4], kind: .text), offset: 5)))
            ),
            ParseFixture.messageAttribute(
                "MODSEQ (3)",
                " ",
                expected: .success(.fetchModificationResponse(.init(modifierSequenceValue: 3)))
            ),
            ParseFixture.messageAttribute(
                "X-GM-MSGID 1278455344230334865",
                " ",
                expected: .success(.gmailMessageID(1_278_455_344_230_334_865))
            ),
            ParseFixture.messageAttribute(
                "X-GM-THRID 1278455344230334865",
                " ",
                expected: .success(.gmailThreadID(1_278_455_344_230_334_865))
            ),
            ParseFixture.messageAttribute(
                "X-GM-LABELS (\\Inbox \\Sent Important \"Muy Importante\")",
                " ",
                expected: .success(
                    .gmailLabels([
                        GmailLabel("\\Inbox"), GmailLabel("\\Sent"), GmailLabel("Important"),
                        GmailLabel("Muy Importante"),
                    ])
                )
            ),
            ParseFixture.messageAttribute(
                "X-GM-LABELS (foo)",
                " ",
                expected: .success(.gmailLabels([GmailLabel("foo")]))
            ),
            ParseFixture.messageAttribute("X-GM-LABELS ()", " ", expected: .success(.gmailLabels([]))),
            ParseFixture.messageAttribute(
                #"X-GM-LABELS (\Drafts)"#,
                " ",
                expected: .success(.gmailLabels([GmailLabel(#"\Drafts"#)]))
            ),
            ParseFixture.messageAttribute(
                #"X-GM-LABELS ("\\Important")"#,
                " ",
                expected: .success(.gmailLabels([GmailLabel(#"\Important"#)]))
            ),
            ParseFixture.messageAttribute(
                "PREVIEW \"Lorem ipsum dolor sit amet\"",
                "",
                expected: .success(.preview(.init("Lorem ipsum dolor sit amet")))
            ),
            ParseFixture.messageAttribute(
                "EMAILID (123-456-789)",
                " ",
                expected: .success(.emailID(.init("123-456-789")!))
            ),
            ParseFixture.messageAttribute(
                "THREADID (123-456-789)",
                " ",
                expected: .success(.threadID(.init("123-456-789")!))
            ),
            ParseFixture.messageAttribute("THREADID NIL", " ", expected: .success(.threadID(nil))),
        ]
    }
}

// MARK: -

extension EncodeFixture<MessageAttribute> {
    fileprivate static func messageAttribute(_ input: MessageAttribute, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMessageAttribute($1) }
        )
    }
}

extension EncodeFixture<[MessageAttribute]> {
    fileprivate static func messageAttributes(_ input: [MessageAttribute], _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMessageAttributes($1) }
        )
    }
}

extension ParseFixture<MessageAttribute> {
    fileprivate static func messageAttribute(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMessageAttribute
        )
    }
}

// MARK: - writeMessageAttribute_rfc822 helpers

extension MessageAttributeTests {
    @Test(
        "encode rfc822 helpers",
        arguments: [
            Rfc822Fixture(method: .rfc822, string: nil, expected: "RFC822 NIL"),
            Rfc822Fixture(method: .rfc822, string: ByteBuffer(string: "hi"), expected: "RFC822 \"hi\""),
            Rfc822Fixture(method: .rfc822Text, string: nil, expected: "RFC822.TEXT NIL"),
            Rfc822Fixture(method: .rfc822Text, string: ByteBuffer(string: "body"), expected: "RFC822.TEXT \"body\""),
            Rfc822Fixture(method: .rfc822Header, string: nil, expected: "RFC822.HEADER NIL"),
            Rfc822Fixture(method: .rfc822Header, string: ByteBuffer(string: "hdr"), expected: "RFC822.HEADER \"hdr\""),
        ]
    )
    func encodeRfc822Helpers(_ fixture: Rfc822Fixture) {
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        switch fixture.method {
        case .rfc822: _ = buffer.writeMessageAttribute_rfc822(fixture.string)
        case .rfc822Text: _ = buffer.writeMessageAttribute_rfc822Text(fixture.string)
        case .rfc822Header: _ = buffer.writeMessageAttribute_rfc822Header(fixture.string)
        }
        var remaining = buffer
        let chunk = remaining.nextChunk()
        let actualString = String(buffer: chunk.bytes)
        #expect(actualString.mappingControlPictures() == fixture.expected.mappingControlPictures())
    }

    @Test(
        "encode body section text",
        arguments: [
            BodySectionTextFixture(number: nil, size: 5, expected: "BODY[TEXT] {5}\r\n"),
            BodySectionTextFixture(number: 3, size: 8, expected: "BODY[TEXT]<3> {8}\r\n"),
        ]
    )
    func encodeBodySectionText(_ fixture: BodySectionTextFixture) {
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        _ = buffer.writeMessageAttribute_bodySectionText(number: fixture.number, size: fixture.size)
        var remaining = buffer
        let chunk = remaining.nextChunk()
        let actualString = String(buffer: chunk.bytes)
        #expect(actualString.mappingControlPictures() == fixture.expected.mappingControlPictures())
    }
}

enum Rfc822Method: Sendable { case rfc822, rfc822Text, rfc822Header }

struct Rfc822Fixture: Sendable, CustomTestStringConvertible {
    var method: Rfc822Method
    var string: ByteBuffer?
    var expected: String

    var testDescription: String { expected }
}

struct BodySectionTextFixture: Sendable, CustomTestStringConvertible {
    var number: Int?
    var size: Int
    var expected: String

    var testDescription: String { expected }
}

extension MessageAttributeTests {
    @Test(
        "encode body section attribute",
        arguments: [
            BodySectionFixture(section: nil, number: nil, string: nil, expected: "BODY[] NIL"),
            BodySectionFixture(
                section: .init(kind: .header),
                number: nil,
                string: "header data",
                expected: #"BODY[HEADER] "header data""#
            ),
            BodySectionFixture(
                section: .init(part: [1, 2], kind: .text),
                number: 0,
                string: "body text",
                expected: #"BODY[1.2.TEXT]<0> "body text""#
            ),
            BodySectionFixture(
                section: .init(kind: .complete),
                number: 512,
                string: nil,
                expected: "BODY[]<512> NIL"
            ),
        ]
    )
    func encodeBodySection(_ fixture: BodySectionFixture) {
        fixture.checkEncoding()
    }
}

struct BodySectionFixture: Sendable, CustomTestStringConvertible {
    var section: SectionSpecifier?
    var number: Int?
    var string: ByteBuffer?
    var expected: String

    init(section: SectionSpecifier?, number: Int?, string: ByteBuffer?, expected: String) {
        self.section = section
        self.number = number
        self.string = string
        self.expected = expected
    }

    var testDescription: String { expected }

    func checkEncoding() {
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        let size = buffer.writeMessageAttribute_bodySection(section, number: number, string: string)
        var remaining = buffer
        let chunk = remaining.nextChunk()
        let actualString = String(buffer: chunk.bytes)
        #expect(size == expected.utf8.count)
        #expect(actualString.mappingControlPictures() == expected.mappingControlPictures())
    }
}
