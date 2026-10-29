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

@Suite("MailboxAttribute")
struct MailboxAttributeTests {
    @Test(
        "encode attributes",
        arguments: [
            EncodeFixture.mailboxAttributes([], ""),
            EncodeFixture.mailboxAttributes(
                [MailboxAttribute.messageCount, .recentCount, .unseenCount],
                "MESSAGES RECENT UNSEEN"
            ),
            EncodeFixture.mailboxAttributes(
                [MailboxAttribute.appendLimit, .uidNext, .uidValidity],
                "APPENDLIMIT UIDNEXT UIDVALIDITY"
            ),
            EncodeFixture.mailboxAttributes([MailboxAttribute.size], "SIZE"),
            EncodeFixture.mailboxAttributes(
                [MailboxAttribute.highestModificationSequence, .messageCount],
                "HIGHESTMODSEQ MESSAGES"
            ),
            EncodeFixture.mailboxAttributes([MailboxAttribute.mailboxID], "MAILBOXID"),
        ]
    )
    func encodeAttributes(_ fixture: EncodeFixture<[MailboxAttribute]>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode status",
        arguments: [
            EncodeFixture.mailboxStatus(.init(), ""),
            EncodeFixture.mailboxStatus(
                .init(
                    messageCount: 133_701,
                    recentCount: 255_813,
                    nextUID: 377_003,
                    uidValidity: 427_421,
                    unseenCount: 528_028,
                    size: 680_543,
                    highestModificationSequence: 797_237,
                    appendLimit: 86_254_193,
                    mailboxID: .valid("F2212ea87-6097-4256-9d51-71338625")
                ),
                "MESSAGES 133701 RECENT 255813 UIDNEXT 377003 UIDVALIDITY 427421 UNSEEN 528028 SIZE 680543 HIGHESTMODSEQ 797237 APPENDLIMIT 86254193 MAILBOXID (F2212ea87-6097-4256-9d51-71338625)"
            ),
            EncodeFixture.mailboxStatus(.init(mailboxID: .invalid), "MAILBOXID ()"),
            EncodeFixture.mailboxStatus(.init(messageCount: 3, mailboxID: .invalid), "MESSAGES 3 MAILBOXID ()"),
            EncodeFixture.mailboxStatus(.init(messageCount: 3, mailboxID: nil), "MESSAGES 3"),
            EncodeFixture.mailboxStatus(
                .init(messageCount: 133_701, nextUID: 377_003, uidValidity: 427_421, appendLimit: 86_254_193),
                "MESSAGES 133701 UIDNEXT 377003 UIDVALIDITY 427421 APPENDLIMIT 86254193"
            ),
            EncodeFixture.mailboxStatus(
                .init(nextUID: 377_003),
                "UIDNEXT 377003"
            ),
        ]
    )
    func encodeStatus(_ fixture: EncodeFixture<MailboxStatus>) {
        fixture.checkEncoding()
    }

    @Test("parse all mailbox attributes")
    func parseAllMailboxAttributes() {
        for att in MailboxAttribute.allCases {
            let fixture = ParseFixture.mailboxAttribute(
                att.rawValue,
                " ",
                expected: .success(att)
            )
            fixture.checkParsing()
        }
    }

    @Test(
        "parse mailbox attribute errors",
        arguments: [
            ParseFixture.mailboxAttribute("a", "", expected: .incompleteMessageIgnoringBufferModifications),
            ParseFixture.mailboxAttribute("a ", " ", expected: .failureIgnoringBufferModifications),
        ]
    )
    func parseMailboxAttributeErrors(_ fixture: ParseFixture<MailboxAttribute>) {
        fixture.checkParsing()
    }

    @Test(
        "parse mailbox status",
        arguments: [
            ParseFixture.mailboxStatus("MESSAGES 1", expected: .success(.init(messageCount: 1))),
            ParseFixture.mailboxStatus(
                "MESSAGES 1 RECENT 2 UIDNEXT 3 UIDVALIDITY 4 UNSEEN 5 SIZE 6 HIGHESTMODSEQ 7",
                expected: .success(
                    .init(
                        messageCount: 1,
                        recentCount: 2,
                        nextUID: 3,
                        uidValidity: 4,
                        unseenCount: 5,
                        size: 6,
                        highestModificationSequence: 7
                    )
                )
            ),
            ParseFixture.mailboxStatus("APPENDLIMIT 257890", expected: .success(.init(appendLimit: 257_890))),
            ParseFixture.mailboxStatus("APPENDLIMIT NIL", expected: .success(.init(appendLimit: nil))),
            ParseFixture.mailboxStatus("MESSAGES 3", expected: .success(.init(messageCount: 3, mailboxID: nil))),
            ParseFixture.mailboxStatus("SIZE 81630", expected: .success(.init(size: 81_630))),
            ParseFixture.mailboxStatus(
                "UIDNEXT 95604  HIGHESTMODSEQ 35227 APPENDLIMIT 81818  UIDVALIDITY 33682",
                expected: .success(
                    .init(nextUID: 95604, uidValidity: 33682, highestModificationSequence: 35227, appendLimit: 81818)
                )
            ),
            ParseFixture.mailboxStatus(
                "MAILBOXID (F2212ea87-6097-4256-9d51-71338625)",
                expected: .success(.init(mailboxID: .valid("F2212ea87-6097-4256-9d51-71338625")))
            ),
            ParseFixture.mailboxStatus(
                "MESSAGES 3 MAILBOXID (bad!id) UNSEEN 1",
                expected: .success(.init(messageCount: 3, unseenCount: 1, mailboxID: .invalid))
            ),
            ParseFixture.mailboxStatus("MAILBOXID ()", expected: .success(.init(mailboxID: .invalid))),
            ParseFixture.mailboxStatus(
                "UNSEEN 1 MAILBOXID (bad!id)",
                expected: .success(.init(unseenCount: 1, mailboxID: .invalid))
            ),
            ParseFixture.mailboxStatus("MESSAGES UNSEEN 3 RECENT 4", "\r", expected: .failure),
            ParseFixture.mailboxStatus("2 UNSEEN 3 RECENT 4", "\r", expected: .failure),
            ParseFixture.mailboxStatus("", "", expected: .incompleteMessage),
            ParseFixture.mailboxStatus("MESSAGES 2 UNSEEN ", "", expected: .incompleteMessage),
        ]
    )
    func parseMailboxStatus(_ fixture: ParseFixture<MailboxStatus>) {
        fixture.checkParsing()
    }

    @Test("invalid non-UTF-8 MAILBOXID in STATUS is parsed as invalid")
    func parseStatusMailboxIDWithNonUTF8Bytes() throws {
        var buffer = ByteBuffer(string: "MAILBOXID (")
        buffer.writeBytes([0x30, 0x10, 0x50, 0x87, 0x6d, 0x55])
        buffer.writeString(")\r")
        var parseBuffer = ParseBuffer(buffer)
        let status = try GrammarParser().parseMailboxStatus(buffer: &parseBuffer, tracker: .testTracker)
        #expect(status.mailboxID == .invalid)
    }

    @Test("nil, invalid, and valid mailbox IDs are distinct")
    func mailboxIDStatesAreDistinct() {
        let states: [MailboxStatus] = [
            .init(mailboxID: nil),
            .init(mailboxID: .invalid),
            .init(mailboxID: .valid("a")),
            .init(mailboxID: .valid("b")),
        ]
        #expect(Set(states).count == states.count)
        #expect(MailboxStatus.MailboxID.valid("a") == .valid("a"))
    }

    @Test(
        "parse status option",
        arguments: [
            ParseFixture.statusOption("STATUS (MESSAGES)", expected: .success([.messageCount])),
            ParseFixture.statusOption(
                "STATUS (MESSAGES RECENT UNSEEN)",
                expected: .success([.messageCount, .recentCount, .unseenCount])
            ),
            ParseFixture.statusOption("STATUS (UIDNEXT)", expected: .success([.uidNext])),
            ParseFixture.statusOption("", "", expected: .incompleteMessage),
        ]
    )
    func parseStatusOption(_ fixture: ParseFixture<[MailboxAttribute]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<[MailboxAttribute]> {
    fileprivate static func mailboxAttributes(_ input: [MailboxAttribute], _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxAttributes($1) }
        )
    }
}

extension EncodeFixture<MailboxStatus> {
    fileprivate static func mailboxStatus(_ input: MailboxStatus, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxStatus($1) }
        )
    }
}

extension ParseFixture<MailboxAttribute> {
    fileprivate static func mailboxAttribute(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStatusAttribute
        )
    }
}

extension ParseFixture<MailboxStatus> {
    fileprivate static func mailboxStatus(
        _ input: String,
        _ terminator: String = ")",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMailboxStatus
        )
    }
}

extension ParseFixture<[MailboxAttribute]> {
    fileprivate static func statusOption(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseStatusOption
        )
    }
}
