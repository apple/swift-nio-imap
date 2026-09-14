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

@Suite("FetchBatch — count honoring")
enum FetchBatchCountTests {

    /// Bug #6 (fixed): On a server without RFC 9394 `PARTIAL`, `makeBoundaryFetchBatch`
    /// used an early guard that only inspected `mailboxMessageCount` (not the requested
    /// `count`) and short-circuited to `.fixed([UID.min...UID.max])` for small mailboxes.
    /// So a `.last(count:)` request on a small mailbox fetched the *entire* mailbox,
    /// ignoring `--count`. Now the whole-mailbox shortcut applies only to `.all`, and
    /// `.last(count:)` issues a bounded SEARCH for the last `count` messages.
    ///
    /// Here `minimumFetchBatchSize` is 1,000, so `batchSize / 2 == 500 > 400`, which
    /// previously triggered the over-fetch: `.last(count: 100)` on 400 messages fetched
    /// all 400. It now searches sequence numbers `301...*` (the last 100 of 400).
    @Test
    static func lastCountDoesNotFetchWholeMailbox() async throws {
        let connection = TestConnection(expectedCommands: [
            .init(
                command: .uidSearch(
                    key: .sequenceNumbers(.set(.init(set: [301...])!)),
                    charset: nil,
                    returnOptions: []
                ),
                responses: [
                    .untagged(.mailboxData(.search([512, 4_096], nil)))
                ],
                completion: .ok(.init(text: "Done searching"))
            )
        ])
        let batches = try await makeBatches(
            connection: connection,
            query: .last(count: 100),
            mailboxMessageCount: 400,
            capabilities: [.imap4rev1]
        )
        #expect(
            Array(batches) != [.uidRange(.all)],
            "Requesting the last 100 of 400 messages must not fetch the entire mailbox."
        )
        #expect(Array(batches) == [.uidRange(512...4_096)])
        #expect(
            await connection.expectedCommands == [],
            "Should have issued the bounded boundary SEARCH for the last 100 messages."
        )
    }
}
