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
private enum SearchTests {
    struct CombineKeyAndBatchFixture: Sendable, CustomTestStringConvertible {
        var key: SearchKey
        var query: FetchQuery
        var batch: FetchBatch
        var expected: SearchKey

        var testDescription: String { "\(key) \(query) \(batch)" }
    }

    @Test(arguments: [
        CombineKeyAndBatchFixture(
            key: .flagged,
            query: .all,
            batch: FetchBatch.partialLast(.last(1...40)),
            expected: .flagged
        ),
        CombineKeyAndBatchFixture(
            key: .seen,
            query: .last(count: 100),
            batch: FetchBatch.partialLast(.last(1...50)),
            expected: .seen
        ),
        CombineKeyAndBatchFixture(
            key: .all,
            query: .all,
            batch: FetchBatch.uidRange(100...200),
            expected: .uid(.set(UIDSetNonEmpty(range: 100...200)))
        ),
        CombineKeyAndBatchFixture(
            key: .flagged,
            query: .all,
            batch: FetchBatch.uidRange(100...200),
            expected: .and([.uid(.set(UIDSetNonEmpty(range: 100...200))), .flagged])
        ),
        CombineKeyAndBatchFixture(
            key: .flagged,
            query: .uids([]),
            batch: FetchBatch.uidRange(100...200),
            expected: .not(.all)
        ),
        CombineKeyAndBatchFixture(
            key: .seen,
            query: .uids([]),
            batch: FetchBatch.partialLast(.last(1...50)),
            expected: .not(.all)
        ),
        CombineKeyAndBatchFixture(
            key: .answered,
            query: .uids([50, 150, 250]),
            batch: FetchBatch.uidRange(100...200),
            expected: .and([.uid(.set(UIDSetNonEmpty(range: 150...150))), .answered])
        ),
        CombineKeyAndBatchFixture(
            key: .draft,
            query: .uids([10, 20, 30]),
            batch: FetchBatch.partialLast(.last(1...100)),
            expected: .and([.uid(.set(UIDSetNonEmpty(set: [10, 20, 30])!)), .draft])
        ),
    ])
    static func testCombineKeyAndBatch(
        _ fixture: CombineKeyAndBatchFixture
    ) {
        #expect(
            SearchKey.combine(
                key: fixture.key,
                query: fixture.query,
                batch: fixture.batch
            ) == fixture.expected
        )
    }

    struct MessageIDKeyFixture: Sendable, CustomTestStringConvertible {
        var input: [MessageID]
        var expected: SearchKey?

        var testDescription: String {
            input.map { "\($0)" }.joined(separator: ", ")
        }
    }

    @Test(arguments: [
        MessageIDKeyFixture(
            input: ["<a@foo.example.com>"],
            expected: SearchKey.header("message-id", ByteBuffer(string: "<a@foo.example.com>"))
        ),
        MessageIDKeyFixture(
            input: [],
            expected: nil
        ),
        MessageIDKeyFixture(
            input: ["<a@foo.example.com>"],
            expected: SearchKey.header("message-id", ByteBuffer(string: "<a@foo.example.com>"))
        ),
        MessageIDKeyFixture(
            input: ["<a@foo.example.com>", "<b@foo.example.com>"],
            expected: SearchKey.or(
                SearchKey.header("message-id", ByteBuffer(string: "<a@foo.example.com>")),
                SearchKey.header("message-id", ByteBuffer(string: "<b@foo.example.com>"))
            )
        ),
        MessageIDKeyFixture(
            input: ["<a@foo.example.com>", "<b@foo.example.com>", "<c@foo.example.com>"],
            expected: SearchKey.or(
                SearchKey.or(
                    SearchKey.header("message-id", ByteBuffer(string: "<a@foo.example.com>")),
                    SearchKey.header("message-id", ByteBuffer(string: "<b@foo.example.com>"))
                ),
                SearchKey.header("message-id", ByteBuffer(string: "<c@foo.example.com>"))
            )
        ),
    ])
    static func messageIDKey(_ fixture: MessageIDKeyFixture) {
        #expect(SearchKey.messageID(fixture.input) == fixture.expected)
    }

    struct LastMessagesKeyFixture: Sendable, CustomTestStringConvertible {
        var count: Int
        var mailboxMessageCount: Int
        var expected: SearchKey

        var testDescription: String { "count: \(count), mailboxMessageCount: \(mailboxMessageCount)" }
    }

    @Test(arguments: [
        LastMessagesKeyFixture(
            count: 10,
            mailboxMessageCount: 200,
            expected: SearchKey.sequenceNumbers(.set(MessageIdentifierSetNonEmpty(range: 191...SequenceNumber.max)))
        ),
        LastMessagesKeyFixture(
            count: 10,
            mailboxMessageCount: 12,
            expected: SearchKey.sequenceNumbers(.set(MessageIdentifierSetNonEmpty(range: 3...SequenceNumber.max)))
        ),
        LastMessagesKeyFixture(
            count: 10,
            mailboxMessageCount: 11,
            expected: SearchKey.sequenceNumbers(.set(MessageIdentifierSetNonEmpty(range: 2...SequenceNumber.max)))
        ),
        LastMessagesKeyFixture(
            count: 10,
            mailboxMessageCount: 10,
            expected: SearchKey.all
        ),
        LastMessagesKeyFixture(
            count: 10,
            mailboxMessageCount: 8,
            expected: SearchKey.all
        ),
        LastMessagesKeyFixture(
            count: 10,
            mailboxMessageCount: 0,
            expected: SearchKey.all
        ),
    ])
    static func lastMessagesKey(_ fixture: LastMessagesKeyFixture) {
        #expect(
            SearchKey.lastMessages(count: fixture.count, mailboxMessageCount: fixture.mailboxMessageCount)
                == fixture.expected
        )
    }

    @Test
    static func plain_RFC_3501() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidSearch(
                    key: .not(.deleted),
                    charset: nil,
                    returnOptions: []
                ),
                responses: [
                    .untagged(.mailboxData(.search([309_727, 967_986], nil)))
                ],
                completion: .ok(.init(text: "Done searching"))
            )
        ])
        let uids = try await search(
            connection: connection,
            capabilities: [],
            key: .not(.deleted)
        )
        #expect(await connection.expectedCommands.isEmpty)
        #expect(uids == [309_727, 967_986])
    }

    struct ParseMessageLimitFixture: Sendable, CustomTestStringConvertible {
        var capabilities: [Capability]
        var expected: UInt32

        var testDescription: String { "\(capabilities)" }
    }

    @Test(arguments: [
        ParseMessageLimitFixture(
            capabilities: [],
            expected: 1_000
        ),
        ParseMessageLimitFixture(
            capabilities: [.messageLimit(999)],
            expected: 1_000
        ),
        ParseMessageLimitFixture(
            capabilities: [.messageLimit(1_000)],
            expected: 1_000
        ),
        ParseMessageLimitFixture(
            capabilities: [.messageLimit(10_000)],
            expected: 10_000
        ),
    ])
    static func parseMessageLimit(_ fixture: ParseMessageLimitFixture) {
        #expect(effectiveBatchSize(capabilities: fixture.capabilities) == fixture.expected)
    }
}
