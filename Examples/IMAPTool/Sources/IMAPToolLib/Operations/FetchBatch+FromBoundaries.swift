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

// MARK: - `UIDBatchFromBoundaries` strategy
//
// Used on servers without RFC 9394 `PARTIAL` support for `.all` and `.last(n)`
// queries. Because UIDs are not contiguous, we first issue a `SEARCH` on sequence
// numbers at batch boundaries (e.g. every 1,000th message) to learn the actual
// boundary UIDs, then emit one `.uidRange(low...high)` batch per gap.
//
// Striding is anchored at the *max* sequence number so the newest batch is full —
// callers may use that property to restrict follow-up tasks to the latest batch.

/// Returns batches by first asking the server for boundary UIDs.
///
/// Used for `.all` / `.last(n)` queries on servers without RFC 9394 `PARTIAL`.
func makeBoundaryFetchBatch<C: ConnectionProtocol>(
    connection: C,
    query: FetchQuery,
    mailboxMessageCount: Int,
    batchSize: SequenceNumber,
    capabilities: [Capability],
) async throws -> FetchBatches {
    func make(count: Int) async throws -> FetchBatches {
        guard
            Int(UInt32(batchSize)) / 2 < count
        else {
            writeStatus("Requesting list of latest \(count) UIDs from server")
            // Run a search to get the UIDs:
            let uids = try await search(
                connection: connection,
                capabilities: capabilities,
                key: .lastMessages(
                    count: count,
                    mailboxMessageCount: mailboxMessageCount
                )
            )
            guard
                let a = uids.min(),
                let b = uids.max()
            else {
                writeStatus("No UIDs — mailbox is empty?")
                return .empty
            }
            return .singleBatch(a...b)
        }
        // Split up into batches.
        guard
            let boundarySequenceNumbers = sequenceNumbersForMessageBatches(
                mailboxMessageCount: mailboxMessageCount,
                maximumCount: count,
                batchSize: batchSize
            )
        else {
            writeStatus("No UIDs — mailbox is empty?")
            return .empty
        }
        writeStatus("Searching for message batches UID boundaries")
        let boundaryUIDs = try await search(
            connection: connection,
            capabilities: capabilities,
            key: .sequenceNumbers(.set(boundarySequenceNumbers))
        )
        writeStatus("Message batch UID boundaries (for \(count) messages): \(boundaryUIDs)")
        return .fromBoundaries(UIDBatchFromBoundaries(boundaries: boundaryUIDs))
    }

    switch query {
    case .last(count: let count):
        // Honor `count` even on a small mailbox: fetching the whole mailbox to satisfy
        // a `.last(n)` request would over-fetch. `make(count:)` issues a bounded SEARCH
        // for (at most) the last `count` messages.
        return try await make(count: min(count, mailboxMessageCount))
    case .all:
        // The whole mailbox is wanted. If it is small enough, fetch it in a single batch
        // without a boundary SEARCH.
        guard
            Int(UInt32(batchSize)) / 2 < mailboxMessageCount
        else {
            writeStatus("Mailbox has very few messages — using a single batch")
            return .fixed([UID.min...UID.max])
        }
        return try await make(count: mailboxMessageCount)
    case .uids(let uids):
        let ranges = splitUIDsIntoRanges(
            uids: uids,
            maximumCount: Int(batchSize)
        )
        writeStatus("Did split FETCH for \(uids.count) UIDs into \(ranges.count) batch(es) / range(s)")
        return .fixed(ranges)
    }
}

/// Calculate the sequence numbers that should be queried for UIDs, based on the message count.
/// - Parameters:
///   - mailboxMessageCount: The total number of messages in the mailbox.
///   - maximumCount: The number of messages of interest, that is, the number of messages that
///       the returned UIDs should span.
///   - batchSize: The number of messages in each batch.
func sequenceNumbersForMessageBatches(
    mailboxMessageCount: Int,
    maximumCount: Int?,
    batchSize: SequenceNumber
) -> MessageIdentifierSetNonEmpty<SequenceNumber>? {
    let min: SequenceNumber
    if let maximumCount, let m = SequenceNumber(exactly: mailboxMessageCount - maximumCount + 1) {
        min = m
    } else {
        min = SequenceNumber.min
    }
    guard
        let max = SequenceNumber(exactly: mailboxMessageCount)
    else { return nil }

    // We stride starting from max. That way the last (newest) batch
    // will be (close to) the desired batch size, and we can then
    // subsequently use that when we want to limit tasks to only operate
    // on messages in that last batch.
    var next: SequenceNumber? = max
    let step = Int64(batchSize)
    let boundaries = AnyIterator {
        defer {
            if let n = next, step <= min.distance(to: n) {
                next = n.advanced(by: -step)
            } else {
                next = nil
            }
        }
        return next
    }
    var result = SequenceSet(boundaries)
    result.insert(min)
    return MessageIdentifierSetNonEmpty(set: result)
}

/// A sequence of `FetchBatch` based on boundary UIDs.
///
/// The boundary UIDs should be the result of `sequenceNumbersForMessageBatches()`.
struct UIDBatchFromBoundaries: Hashable, Sendable {
    let boundaries: UIDSet
}

extension UIDBatchFromBoundaries: Sequence {
    typealias Element = FetchBatch

    struct Iterator: IteratorProtocol {
        let start: UID?
        var boundaries: ReversedCollection<UIDSet>.Iterator
        var last: UID?

        mutating func next() -> FetchBatch? {
            while true {
                guard
                    let uid = boundaries.next()
                else { return nil }
                guard
                    let last
                else {
                    last = uid
                    continue
                }
                self.last = uid
                guard uid == start else {
                    return .uidRange(uid.advanced(by: 1)...last)
                }
                // The last range has to include the last UID
                return .uidRange(uid...last)
            }
        }
    }

    func makeIterator() -> Iterator {
        Iterator(
            start: boundaries.first,
            boundaries: boundaries.reversed().makeIterator()
        )
    }
}
