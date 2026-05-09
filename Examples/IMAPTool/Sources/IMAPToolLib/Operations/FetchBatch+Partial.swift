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

import NIOIMAP

// MARK: - `PartialFetchBatches` strategy (RFC 9394 “Partial”)
//
// Used when the server supports RFC 9394 `PARTIAL`. Each batch is a
// `.partialLast(start...end)` referring to a window counted from the *end* of the
// mailbox (so `1` is the newest message). This avoids any preliminary SEARCH —
// the server resolves the window itself.
//
// `PartialFetchBatches` is the `Sequence` that walks from the newest message
// back to `last`, emitting one `.partialLast` batch per step of `batchSize`.

/// Returns batches based on RFC 9394 “Partial” ranges.
///
/// No preliminary `SEARCH` is needed — each batch resolves on the server.
func makePartialFetchBatch(
    query: FetchQuery,
    mailboxMessageCount: Int,
    batchSize: SequenceNumber
) -> FetchBatches {
    guard
        let batches = PartialFetchBatches(
            query: query,
            mailboxMessageCount: mailboxMessageCount,
            batchSize: batchSize
        )
    else { return .empty }
    return .partial(batches)
}

/// A sequence of `FetchBatch` for a server that supports RFC 9394 “Partial”.
struct PartialFetchBatches: Hashable, Sendable {
    /// The last message to include in the sequence.
    ///
    /// Note that 1 (`.min`) refers to the last message in the mailbox, whereas e.g
    /// 1,000 would refer to the 1,000th message _from the end_ of the mailbox.
    let last: SequenceNumber
    let batchSize: SequenceNumber
}

extension PartialFetchBatches {
    init?(
        query: FetchQuery,
        mailboxMessageCount: Int,
        batchSize: SequenceNumber
    ) {
        guard
            0 < mailboxMessageCount
        else { return nil }
        switch query {
        case .last(count: let c):
            guard
                let l = SequenceNumber(exactly: Swift.min(c, mailboxMessageCount))
            else { return nil }
            self.last = l
        case .uids(let uids):
            guard
                let l = SequenceNumber(exactly: Swift.min(uids.count, mailboxMessageCount))
            else { return nil }
            self.last = l
        case .all:
            self.last = SequenceNumber.min.advanced(by: Int64(mailboxMessageCount - 1))
        }
        self.batchSize = batchSize
    }
}

extension PartialFetchBatches: Sequence {
    typealias Element = FetchBatch

    struct Iterator: IteratorProtocol {
        let last: SequenceNumber
        let batchSize: SequenceNumber
        var index = 0

        mutating func next() -> FetchBatch? {
            let start = SequenceNumber.min.advanced(by: Int64(index) * Int64(batchSize))
            guard
                start <= last
            else { return nil }
            let offset = Int64(index + 1) * Int64(batchSize) - 1
            let end = Swift.min(
                last,
                SequenceNumber.min.advanced(by: offset)
            )
            index += 1
            return .partialLast(NIOIMAP.PartialRange.last(start...end))
        }

        typealias Element = FetchBatch
    }

    func makeIterator() -> Iterator {
        Iterator(
            last: last,
            batchSize: batchSize
        )
    }
}
