//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import IMAPCommands
import Foundation
@testable import IMAPToolLib
import NIO
import NIOIMAP
import Testing

@Suite
enum FetchTests {
    struct MessageInfoFixture: Sendable, CustomTestStringConvertible {
        var name: String
        var mailboxMessageCount: Int
        var capabilities: [Capability]
        var query: FetchQuery
        var expectedCommands: [TestConnection.CommandAndResponses]
        var expectedResults: [ExpectedMessageInfo]

        var testDescription: String { name }

        struct ExpectedMessageInfo: Sendable {
            var uid: UID
            var date: String?
            var subject: String?
            var from: String?
            var to: String?
            var cc: String?
            var messageID: String?
            var inReplyTo: String?
            var flags: [String]
        }
    }

    @Test(arguments: [
        MessageInfoFixture(
            name: "last 2 messages",
            mailboxMessageCount: 10_000,
            capabilities: [],
            query: .last(count: 2),
            expectedCommands: [
                .init(
                    command: .uidSearch(
                        key: .sequenceNumbers(.set(.init(set: [9_999...])!)),
                        charset: nil,
                        returnOptions: []
                    ),
                    responses: [
                        .untagged(
                            .mailboxData(
                                .search(
                                    [
                                        309_727,
                                        967_986,
                                    ],
                                    nil
                                )
                            )
                        )
                    ],
                    completion: .ok(.init(text: "Done searching"))
                ),
                .init(
                    command: .uidFetch(
                        .set([309_727...967_986]),
                        [.uid, .flags, .envelope],
                        []
                    ),
                    responses: [
                        .fetch(.start(5)),
                        .fetch(.simpleAttribute(.uid(309_727))),
                        .fetch(.simpleAttribute(.flags([.seen]))),
                        .fetch(
                            .simpleAttribute(
                                .envelope(
                                    Envelope(
                                        date: InternetMessageDate("Mon, 10 Feb 2025 12:14:53 -0700 (MST)"),
                                        subject: ByteBuffer(string: "Fwd: iOS email"),
                                        from: [.a],
                                        sender: [.b],
                                        reply: [.c],
                                        to: [.d],
                                        cc: [.e],
                                        bcc: [.f],
                                        inReplyTo: "<13D87EC32432@example.apple.com>",
                                        messageID: "<2F89B1064815@example.apple.com>"
                                    )
                                )
                            )
                        ),
                        .fetch(.finish),
                        .fetch(.start(55)),
                        .fetch(.simpleAttribute(.uid(967_986))),
                        .fetch(.simpleAttribute(.flags([.answered]))),
                        .fetch(
                            .simpleAttribute(
                                .envelope(
                                    Envelope(
                                        date: InternetMessageDate("Sat, 29 Jun 2024 22:25:38 +0900"),
                                        subject: ByteBuffer(string: "Fotowelt"),
                                        from: [.f],
                                        sender: [.e],
                                        reply: [],
                                        to: [.a],
                                        cc: [],
                                        bcc: [],
                                        inReplyTo: nil,
                                        messageID: "<7A9EEFC3D051@example.apple.com>"
                                    )
                                )
                            )
                        ),
                        .fetch(.finish),
                    ],
                    completion: .ok(.init(text: "Fetch done"))
                ),
            ],
            expectedResults: [
                .init(
                    uid: 309_727,
                    date: "Mon, 10 Feb 2025 12:14:53 -0700 (MST)",
                    subject: "Fwd: iOS email",
                    from: "a@example.apple.com",
                    to: "d@example.apple.com",
                    cc: "e@example.apple.com",
                    messageID: "<2F89B1064815@example.apple.com>",
                    inReplyTo: "<13D87EC32432@example.apple.com>",
                    flags: ["\\Seen"]
                ),
                .init(
                    uid: 967_986,
                    date: "Sat, 29 Jun 2024 22:25:38 +0900",
                    subject: "Fotowelt",
                    from: "f@example.apple.com",
                    to: "a@example.apple.com",
                    cc: nil,
                    messageID: "<7A9EEFC3D051@example.apple.com>",
                    inReplyTo: nil,
                    flags: ["\\Answered"]
                ),
            ]
        ),
        MessageInfoFixture(
            name: "specific UIDs",
            mailboxMessageCount: 1_000,
            capabilities: [],
            query: .uids([10, 20]),
            expectedCommands: [
                .init(
                    command: .uidFetch(
                        .set([10, 20]),
                        [.uid, .flags, .envelope],
                        []
                    ),
                    responses: [
                        .fetch(.start(1)),
                        .fetch(.simpleAttribute(.uid(10))),
                        .fetch(.simpleAttribute(.flags([.draft]))),
                        .fetch(
                            .simpleAttribute(
                                .envelope(
                                    Envelope(
                                        date: InternetMessageDate("Wed, 15 Jan 2025 08:00:00 +0000"),
                                        subject: ByteBuffer(string: "Test Subject"),
                                        from: [.a],
                                        sender: [.a],
                                        reply: [.a],
                                        to: [.b],
                                        cc: [],
                                        bcc: [],
                                        inReplyTo: nil,
                                        messageID: "<TEST001@example.apple.com>"
                                    )
                                )
                            )
                        ),
                        .fetch(.finish),
                        .fetch(.start(2)),
                        .fetch(.simpleAttribute(.uid(20))),
                        .fetch(.simpleAttribute(.flags([]))),
                        .fetch(
                            .simpleAttribute(
                                .envelope(
                                    Envelope(
                                        date: InternetMessageDate("Thu, 16 Jan 2025 09:30:00 +0000"),
                                        subject: ByteBuffer(string: "Another Test"),
                                        from: [.b],
                                        sender: [.b],
                                        reply: [.b],
                                        to: [.a],
                                        cc: [],
                                        bcc: [],
                                        inReplyTo: nil,
                                        messageID: "<TEST002@example.apple.com>"
                                    )
                                )
                            )
                        ),
                        .fetch(.finish),
                    ],
                    completion: .ok(.init(text: "Fetch done"))
                )
            ],
            expectedResults: [
                .init(
                    uid: 10,
                    date: "Wed, 15 Jan 2025 08:00:00 +0000",
                    subject: "Test Subject",
                    from: "a@example.apple.com",
                    to: "b@example.apple.com",
                    cc: nil,
                    messageID: "<TEST001@example.apple.com>",
                    inReplyTo: nil,
                    flags: ["\\Draft"]
                ),
                .init(
                    uid: 20,
                    date: "Thu, 16 Jan 2025 09:30:00 +0000",
                    subject: "Another Test",
                    from: "b@example.apple.com",
                    to: "a@example.apple.com",
                    cc: nil,
                    messageID: "<TEST002@example.apple.com>",
                    inReplyTo: nil,
                    flags: []
                ),
            ]
        ),
    ])
    static func messageInfo(_ fixture: MessageInfoFixture) async throws {
        let connection = TestConnection(expectedCommands: fixture.expectedCommands)
        let result = try await fetchMessageInfo(
            connection: connection,
            mailboxMessageCount: fixture.mailboxMessageCount,
            capabilities: fixture.capabilities,
            query: fixture.query
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(result.count == fixture.expectedResults.count)

        for (actual, expected) in zip(result, fixture.expectedResults) {
            #expect(actual.uid == expected.uid)
            #expect(actual.date == expected.date)
            #expect(actual.subject == expected.subject)
            #expect(actual.from == expected.from)
            #expect(actual.to == expected.to)
            #expect(actual.cc == expected.cc)
            #expect(actual.messageID == expected.messageID)
            #expect(actual.inReplyTo == expected.inReplyTo)
            #expect(actual.flags == expected.flags)
        }
    }

    @Test
    static func simpleAttributes() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidFetch(
                    .set([309_727, 967_986]),
                    [.uid, .flags, .internalDate],
                    []
                ),
                responses: [
                    .fetch(.start(5)),
                    .fetch(.simpleAttribute(.uid(309_727))),
                    .fetch(.simpleAttribute(.flags([.seen]))),
                    .fetch(
                        .simpleAttribute(
                            .internalDate(
                                ServerMessageDate(
                                    .init(
                                        year: 2025,
                                        month: 4,
                                        day: 7,
                                        hour: 17,
                                        minute: 46,
                                        second: 22,
                                        timeZoneMinutes: 600
                                    )!
                                )
                            )
                        )
                    ),
                    .fetch(.finish),

                    .fetch(.start(55)),
                    .fetch(.simpleAttribute(.uid(967_986))),
                    .fetch(.simpleAttribute(.flags([.answered]))),
                    .fetch(
                        .simpleAttribute(
                            .internalDate(
                                ServerMessageDate(
                                    .init(
                                        year: 2025,
                                        month: 4,
                                        day: 7,
                                        hour: 17,
                                        minute: 47,
                                        second: 55,
                                        timeZoneMinutes: 600
                                    )!
                                )
                            )
                        )
                    ),
                    .fetch(.finish),
                ],
                completion: .ok(.init(text: "Fetch done"))
            )
        ])
        let result: [(UID, SequenceNumber?, [MessageAttribute])]
        result = try await fetchSimpleAttributes(
            connection: connection,
            capabilities: [],
            uids: [309_727, 967_986],
            attributes: [.flags, .internalDate],
            modifiers: [],
            into: []
        ) { all, uid, seq, attr in
            all.append((uid, seq, attr))
        }
        #expect(await connection.expectedCommands.isEmpty)
        #expect(result.count == 2)

        #expect(result.first?.0 == 309_727)
        #expect(result.first?.1 == 5)
        #expect(
            result.first?.2 == [
                .uid(309_727),
                .flags([.seen]),
                .internalDate(
                    ServerMessageDate(
                        .init(year: 2025, month: 4, day: 7, hour: 17, minute: 46, second: 22, timeZoneMinutes: 600)!
                    )
                ),
            ]
        )

        #expect(result.last?.0 == 967_986)
        #expect(result.last?.1 == 55)
        #expect(
            result.last?.2 == [
                .uid(967_986),
                .flags([.answered]),
                .internalDate(
                    ServerMessageDate(
                        .init(year: 2025, month: 4, day: 7, hour: 17, minute: 47, second: 55, timeZoneMinutes: 600)!
                    )
                ),
            ]
        )
    }
}

extension EmailAddressListElement {
    static var a: EmailAddressListElement { .example("a") }
    static var b: EmailAddressListElement { .example("b") }
    static var c: EmailAddressListElement { .example("c") }
    static var d: EmailAddressListElement { .example("d") }
    static var e: EmailAddressListElement { .example("e") }
    static var f: EmailAddressListElement { .example("f") }

    static func example(_ name: String) -> EmailAddressListElement {
        .singleAddress(
            EmailAddress(
                personName: nil,
                sourceRoot: nil,
                mailbox: ByteBuffer(string: name),
                host: ByteBuffer(string: "example.apple.com")
            )
        )
    }
}
