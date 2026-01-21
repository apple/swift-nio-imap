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

@Suite("MailboxData")
struct MailboxDataTests {
    @Test(arguments: [
        EncodeFixture.mailboxData(.exists(1), "1 EXISTS"),
        EncodeFixture.mailboxData(.flags([.answered, .deleted]), "FLAGS (\\Answered \\Deleted)"),
        EncodeFixture.mailboxData(.list(MailboxInfo(attributes: [], path: try! .init(name: .inbox), extensions: [:])), "LIST () NIL \"INBOX\""),
        EncodeFixture.mailboxData(.lsub(.init(attributes: [.init("\\draft")], path: try! .init(name: .init("Drafts"), pathSeparator: "."), extensions: [:])), "LSUB (\\draft) \".\" \"Drafts\""),
        EncodeFixture.mailboxData(.extendedSearch(ExtendedSearchResponse(correlator: nil, kind: .sequenceNumber, returnData: [.count(1)])), "ESEARCH COUNT 1"),
        EncodeFixture.mailboxData(.extendedSearch(ExtendedSearchResponse(correlator: nil, kind: .sequenceNumber, returnData: [.count(1), .count(2)])), "ESEARCH COUNT 1 COUNT 2"),
        EncodeFixture.mailboxData(.status(.inbox, .init(messageCount: 1)), "STATUS \"INBOX\" (MESSAGES 1)"),
        EncodeFixture.mailboxData(.status(.inbox, .init(messageCount: 1, unseenCount: 2)), "STATUS \"INBOX\" (MESSAGES 1 UNSEEN 2)"),
        EncodeFixture.mailboxData(.namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), "NAMESPACE NIL NIL NIL"),
        EncodeFixture.mailboxData(.search([]), "SEARCH"),
        EncodeFixture.mailboxData(.search([1]), "SEARCH 1"),
        EncodeFixture.mailboxData(.search([1, 2, 3, 4, 5]), "SEARCH 1 2 3 4 5"),
        EncodeFixture.mailboxData(.search([20, 23], ModificationSequenceValue(917_162_500)), "SEARCH 20 23 (MODSEQ 917162500)"),
        EncodeFixture.mailboxData(.uidBatches(UIDBatchesResponse(correlator: .init(tag: "A143"), batches: [99_695...215_295, 20_350...99_696, 7_829...20_351, 1...7830])), #"UIDBATCHES (TAG "A143") 215295:99695,99696:20350,20351:7829,7830:1"#),
        EncodeFixture.mailboxData(.uidBatches(UIDBatchesResponse(correlator: .init(tag: "A143"), batches: [])), #"UIDBATCHES (TAG "A143")"#),
        EncodeFixture.mailboxData(.uidBatches(UIDBatchesResponse(correlator: .init(tag: "A143"), batches: [99_695])), #"UIDBATCHES (TAG "A143") 99695"#),
        EncodeFixture.mailboxData(.uidBatches(UIDBatchesResponse(correlator: .init(tag: "A143", mailbox: MailboxName("Drafts"), uidValidity: 4_889_695), batches: [99_695])), #"UIDBATCHES (TAG "A143" MAILBOX "Drafts" UIDVALIDITY 4889695) 99695"#),
    ])
    func `encode`(_ fixture: EncodeFixture<MailboxData>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.mailboxDataSearchSort(nil, "SEARCH"),
        EncodeFixture.mailboxDataSearchSort(.init(identifiers: [1], modificationSequence: 2), "SEARCH 1 (MODSEQ 2)"),
        EncodeFixture.mailboxDataSearchSort(.init(identifiers: [1, 2, 3], modificationSequence: 2), "SEARCH 1 2 3 (MODSEQ 2)"),
    ])
    func `encode search/sort`(_ fixture: EncodeFixture<MailboxData.SearchSort?>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<MailboxData> {
    fileprivate static func mailboxData(_ input: MailboxData, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxData($1) }
        )
    }
}

extension EncodeFixture<MailboxData.SearchSort?> {
    fileprivate static func mailboxDataSearchSort(_ input: MailboxData.SearchSort?, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxDataSearchSort($1) }
        )
    }
}
