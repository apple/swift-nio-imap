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
    @Test(arguments: [
        EncodeFixture.mailboxAttributes([], ""),
        EncodeFixture.mailboxAttributes([MailboxAttribute.messageCount, .recentCount, .unseenCount], "MESSAGES RECENT UNSEEN"),
        EncodeFixture.mailboxAttributes([MailboxAttribute.appendLimit, .uidNext, .uidValidity], "APPENDLIMIT UIDNEXT UIDVALIDITY"),
        EncodeFixture.mailboxAttributes([MailboxAttribute.size], "SIZE"),
        EncodeFixture.mailboxAttributes([MailboxAttribute.highestModificationSequence, .messageCount], "HIGHESTMODSEQ MESSAGES"),
        EncodeFixture.mailboxAttributes([MailboxAttribute.mailboxID], "MAILBOXID"),
    ])
    func `encode attributes`(_ fixture: EncodeFixture<[MailboxAttribute]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
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
                mailboxID: "F2212ea87-6097-4256-9d51-71338625"
            ),
            "MESSAGES 133701 RECENT 255813 UIDNEXT 377003 UIDVALIDITY 427421 UNSEEN 528028 SIZE 680543 HIGHESTMODSEQ 797237 APPENDLIMIT 86254193 MAILBOXID (F2212ea87-6097-4256-9d51-71338625)"
        ),
        EncodeFixture.mailboxStatus(
            .init(messageCount: 133_701, nextUID: 377_003, uidValidity: 427_421, appendLimit: 86_254_193),
            "MESSAGES 133701 UIDNEXT 377003 UIDVALIDITY 427421 APPENDLIMIT 86254193"
        ),
        EncodeFixture.mailboxStatus(
            .init(nextUID: 377_003),
            "UIDNEXT 377003"
        ),
    ])
    func `encode status`(_ fixture: EncodeFixture<MailboxStatus>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<[MailboxAttribute]> {
    fileprivate static func mailboxAttributes(_ input: [MailboxAttribute], _ expectedString: String) -> Self {
        EncodeFixture(input: input, bufferKind: .defaultServer, expectedString: expectedString, encoder: { $0.writeMailboxAttributes($1) })
    }
}

extension EncodeFixture<MailboxStatus> {
    fileprivate static func mailboxStatus(_ input: MailboxStatus, _ expectedString: String) -> Self {
        EncodeFixture(input: input, bufferKind: .defaultServer, expectedString: expectedString, encoder: { $0.writeMailboxStatus($1) })
    }
}
