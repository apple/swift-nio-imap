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
        EncodeFixture.mailboxData(
            .list(MailboxInfo(attributes: [], path: try! .init(name: .inbox), extensions: [:])),
            "LIST () NIL \"INBOX\""
        ),
        EncodeFixture.mailboxData(
            .lsub(
                .init(
                    attributes: [.init("\\draft")],
                    path: try! .init(name: .init("Drafts"), pathSeparator: "."),
                    extensions: [:]
                )
            ),
            "LSUB (\\draft) \".\" \"Drafts\""
        ),
        EncodeFixture.mailboxData(
            .extendedSearch(ExtendedSearchResponse(correlator: nil, kind: .sequenceNumber, returnData: [.count(1)])),
            "ESEARCH COUNT 1"
        ),
        EncodeFixture.mailboxData(
            .extendedSearch(
                ExtendedSearchResponse(correlator: nil, kind: .sequenceNumber, returnData: [.count(1), .count(2)])
            ),
            "ESEARCH COUNT 1 COUNT 2"
        ),
        EncodeFixture.mailboxData(.status(.inbox, .init(messageCount: 1)), "STATUS \"INBOX\" (MESSAGES 1)"),
        EncodeFixture.mailboxData(
            .status(.inbox, .init(messageCount: 1, unseenCount: 2)),
            "STATUS \"INBOX\" (MESSAGES 1 UNSEEN 2)"
        ),
        EncodeFixture.mailboxData(
            .namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])),
            "NAMESPACE NIL NIL NIL"
        ),
        EncodeFixture.mailboxData(.search([]), "SEARCH"),
        EncodeFixture.mailboxData(.search([1]), "SEARCH 1"),
        EncodeFixture.mailboxData(.search([1, 2, 3, 4, 5]), "SEARCH 1 2 3 4 5"),
        EncodeFixture.mailboxData(
            .search([20, 23], ModificationSequenceValue(917_162_500)),
            "SEARCH 20 23 (MODSEQ 917162500)"
        ),
        EncodeFixture.mailboxData(
            .uidBatches(
                UIDBatchesResponse(
                    correlator: .init(tag: "A143"),
                    batches: [99_695...215_295, 20_350...99_696, 7_829...20_351, 1...7830]
                )
            ),
            #"UIDBATCHES (TAG "A143") 215295:99695,99696:20350,20351:7829,7830:1"#
        ),
        EncodeFixture.mailboxData(
            .uidBatches(UIDBatchesResponse(correlator: .init(tag: "A143"), batches: [])),
            #"UIDBATCHES (TAG "A143")"#
        ),
        EncodeFixture.mailboxData(
            .uidBatches(UIDBatchesResponse(correlator: .init(tag: "A143"), batches: [99_695])),
            #"UIDBATCHES (TAG "A143") 99695"#
        ),
        EncodeFixture.mailboxData(
            .uidBatches(
                UIDBatchesResponse(
                    correlator: .init(tag: "A143", mailbox: MailboxName("Drafts"), uidValidity: 4_889_695),
                    batches: [99_695]
                )
            ),
            #"UIDBATCHES (TAG "A143" MAILBOX "Drafts" UIDVALIDITY 4889695) 99695"#
        )
    ])
    func encode(_ fixture: EncodeFixture<MailboxData>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode search/sort",
        arguments: [
            EncodeFixture.mailboxDataSearchSort(nil, "SEARCH"),
            EncodeFixture.mailboxDataSearchSort(
                .init(identifiers: [1], modificationSequence: 2),
                "SEARCH 1 (MODSEQ 2)"
            ),
            EncodeFixture.mailboxDataSearchSort(
                .init(identifiers: [1, 2, 3], modificationSequence: 2),
                "SEARCH 1 2 3 (MODSEQ 2)"
            )
        ]
    )
    func encodeSearchSort(_ fixture: EncodeFixture<MailboxData.SearchSort?>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse search/sort modification sequence",
        arguments: [
            ParseFixture.searchSortModificationSequence("(MODSEQ 123)", "\r", expected: .success(123)),
            ParseFixture.searchSortModificationSequence("(MODSEQ a)", "", expected: .failure),
            ParseFixture.searchSortModificationSequence("(MODSEQ ", "", expected: .incompleteMessage),
            ParseFixture.searchSortModificationSequence("(MODSEQ 111", "", expected: .incompleteMessage)
        ]
    )
    func parseSearchSortModificationSequence(_ fixture: ParseFixture<ModificationSequenceValue>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.mailboxData("FLAGS (\\seen \\draft)", " ", expected: .success(.flags([.seen, .draft]))),
        ParseFixture.mailboxData(
            "LIST (\\oflag1 \\oflag2) NIL inbox",
            "\r\n",
            expected: .success(
                .list(
                    .init(
                        attributes: [.init("\\oflag1"), .init("\\oflag2")],
                        path: try! .init(name: .inbox),
                        extensions: [:]
                    )
                )
            )
        ),
        ParseFixture.mailboxData(
            #"LSUB () "." #news.comp.mail.misc"#,
            "\r\n",
            expected: .success(
                .lsub(
                    MailboxInfo(
                        attributes: [],
                        path: try! .init(name: MailboxName("#news.comp.mail.misc"), pathSeparator: "."),
                        extensions: [:]
                    )
                )
            )
        ),
        ParseFixture.mailboxData(
            "ESEARCH MIN 1 MAX 2",
            "\r\n",
            expected: .success(
                .extendedSearch(.init(correlator: nil, kind: .sequenceNumber, returnData: [.min(1), .max(2)]))
            )
        ),
        ParseFixture.mailboxData(
            "ESEARCH",
            "\r",
            expected: .success(.extendedSearch(.init(correlator: nil, kind: .sequenceNumber, returnData: [])))
        ),
        ParseFixture.mailboxData("1234 EXISTS", "\r\n", expected: .success(.exists(1234))),
        ParseFixture.mailboxData("5678 RECENT", "\r\n", expected: .success(.recent(5678))),
        ParseFixture.mailboxData("STATUS INBOX ()", "\r\n", expected: .success(.status(.inbox, .init()))),
        ParseFixture.mailboxData(
            "STATUS INBOX (MESSAGES 2)",
            "\r\n",
            expected: .success(.status(.inbox, .init(messageCount: 2)))
        ),
        ParseFixture.mailboxData(
            "LSUB (\\seen \\draft) NIL inbox",
            "\r\n",
            expected: .success(
                .lsub(
                    .init(
                        attributes: [.init("\\seen"), .init("\\draft")],
                        path: try! .init(name: .inbox),
                        extensions: [:]
                    )
                )
            )
        ),
        ParseFixture.mailboxData("SEARCH", "\r\n", expected: .success(.search([]))),
        ParseFixture.mailboxData("SEARCH 1", "\r\n", expected: .success(.search([1]))),
        ParseFixture.mailboxData("SEARCH 1 2 3 4 5", "\r\n", expected: .success(.search([1, 2, 3, 4, 5]))),
        ParseFixture.mailboxData(
            "NAMESPACE NIL NIL NIL",
            "\r\n",
            expected: .success(.namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])))
        ),
        ParseFixture.mailboxData(
            "SEARCH 1 2 3 (MODSEQ 4)",
            "\r\n",
            expected: .success(.searchSort(.init(identifiers: [1, 2, 3], modificationSequence: 4)))
        ),
        ParseFixture.mailboxData(
            "SEARCH 1 (MODSEQ 2)",
            "\r\n",
            expected: .success(.searchSort(.init(identifiers: [1], modificationSequence: 2)))
        ),
        ParseFixture.mailboxData(
            "NAMESPACE NIL NIL NIL",
            "\r\n",
            expected: .success(.namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])))
        ),
        ParseFixture.mailboxData(
            #"UIDBATCHES (TAG "A143") 20351:7829,7830:1"#,
            "\r\n",
            expected: .success(
                .uidBatches(.init(correlator: .init(tag: "A143"), batches: [7_829...20_351, 1...7_830]))
            )
        )
    ])
    func parse(_ fixture: ParseFixture<MailboxData>) {
        fixture.checkParsing()
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

extension ParseFixture<ModificationSequenceValue> {
    fileprivate static func searchSortModificationSequence(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSearchSortModificationSequence
        )
    }
}

extension ParseFixture<MailboxData> {
    fileprivate static func mailboxData(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMailboxData
        )
    }
}
