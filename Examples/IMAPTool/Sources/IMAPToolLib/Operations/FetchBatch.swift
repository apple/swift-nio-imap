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

// MARK: - How batching works
//
// IMAP `UID FETCH` and `UID SEARCH` operate on potentially huge mailboxes. To stay
// within server limits (`MESSAGELIMIT`, RFC 9738) and to keep memory bounded, we
// partition the messages of interest into a sequence of `FetchBatch` values and
// issue one server round-trip per batch.
//
// `makeBatches(...)` picks one of three strategies based on the server capabilities
// and the shape of the request:
//
//   ┌──────────────────────────────────────────────────────────────────────┐
//   │ Server supports RFC 9394 `PARTIAL` ?                                 │
//   │                                                                      │
//   │   yes ──► `PartialFetchBatches`  ── see `FetchBatch+Partial.swift`   │
//   │           (`.partialLast(range)`, no extra SEARCH needed)            │
//   │                                                                      │
//   │   no  ──► one of two `UID range` strategies:                         │
//   │                                                                      │
//   │     query = .uids(_) ──► fixed `[UIDRange]` from the requested UIDs  │
//   │                          ── see `FetchBatch+Fixed.swift`             │
//   │                                                                      │
//   │     query = .all / .last(n) ──► `UIDBatchFromBoundaries`             │
//   │                                 ── see `FetchBatch+FromBoundaries`   │
//   │                                 (one SEARCH for boundary UIDs first) │
//   └──────────────────────────────────────────────────────────────────────┘
//
// Each strategy is implemented as its own `Sequence` of `FetchBatch` in a sibling
// file. `FetchBatches` is the enum that unifies them so callers can iterate without
// caring which strategy was chosen.

/// Describes a batch of messages to fetch or search with `UID FETCH` or `UID SEARCH`.
///
/// Supports RFC 9394 partial ranges or regular UID ranges.
/// Create batches using the `makeBatches()` function, which selects the best strategy
/// based on server capabilities.
enum FetchBatch: Hashable, Sendable {
    /// A range of UIDs.
    case uidRange(UIDRange)
    /// A range using RFC 9394 “Partial”
    case partialLast(NIOIMAP.PartialRange)
}

extension FetchBatch {
    func makeUIDs(_ query: FetchQuery) -> UIDSet {
        switch (self, query) {
        case (.uidRange(let range), .last),
            (.uidRange(let range), .all):
            return UIDSet(range)
        case (.uidRange(let range), .uids(let allUIDs)):
            return allUIDs.intersection(UIDSet(range))
        case (.partialLast, .last),
            (.partialLast, .all):
            return .all
        case (.partialLast, .uids(let allUIDs)):
            return allUIDs
        }
    }

    var fetchModifiers: [FetchModifier] {
        switch self {
        case .uidRange: []
        case .partialLast(let range): [FetchModifier.partial(range)]
        }
    }
}

// MARK: Make Sequence

/// Returns a `FetchBatches` (that is, a `Sequence` of `FetchBatch`) based on the server capabilities.
///
/// This spans the messages based on `query` and `mailboxMessageCount`.
func makeBatches<C: ConnectionProtocol>(
    connection: C,
    query: FetchQuery,
    mailboxMessageCount: Int,
    capabilities: [Capability]
) async throws -> FetchBatches {
    let batchSize =
        SequenceNumber(exactly: effectiveBatchSize(capabilities: capabilities))
        ?? SequenceNumber(exactly: minimumFetchBatchSize)!
    guard capabilities.contains(.partial) else {
        return try await makeBoundaryFetchBatch(
            connection: connection,
            query: query,
            mailboxMessageCount: mailboxMessageCount,
            batchSize: batchSize,
            capabilities: capabilities
        )
    }
    return makePartialFetchBatch(
        query: query,
        mailboxMessageCount: mailboxMessageCount,
        batchSize: batchSize
    )
}

// MARK: Sequence(s)

/// Describes the batches that we split the `FETCH` into.
enum FetchBatches {
    case fixed([UIDRange])
    case partial(PartialFetchBatches)
    case fromBoundaries(UIDBatchFromBoundaries)

    static var empty: FetchBatches {
        FetchBatches.fixed([])
    }

    static func singleBatch(_ r: UIDRange) -> FetchBatches {
        FetchBatches.fixed([r])
    }
}

extension FetchBatches: Sequence {
    func makeIterator() -> Iterator {
        switch self {
        case .fixed(let u):
            Iterator(underlying: u.map { FetchBatch.uidRange($0) }.makeIterator())
        case .partial(let u):
            Iterator(underlying: u.makeIterator())
        case .fromBoundaries(let u):
            Iterator(underlying: u.makeIterator())
        }
    }

    struct Iterator: IteratorProtocol {
        var underlying: any IteratorProtocol<FetchBatch>
        typealias Element = FetchBatch
        mutating func next() -> FetchBatch? {
            underlying.next()
        }
    }
}
