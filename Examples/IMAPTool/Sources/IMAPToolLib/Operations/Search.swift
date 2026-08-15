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

import IMAPCommands
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO
import NIOIMAP

/// Returns all UIDs matching the given fetch query.
func allUIDs<C: ConnectionProtocol>(
    connection: C,
    query: FetchQuery,
    mailboxMessageCount: Int,
    capabilities: [Capability]
) async throws -> UIDSet {
    try await batchedSearch(
        connection: connection,
        key: .all,
        query: query,
        mailboxMessageCount: mailboxMessageCount,
        capabilities: capabilities
    )
}

extension SearchKey {
    static func messageID(_ id: MessageID) -> SearchKey {
        .header("message-id", ByteBuffer(string: String(id)))
    }

    static func messageID(_ ids: some Sequence<MessageID>) -> SearchKey? {
        ids.reduce(
            into: SearchKey?.none,
            { all, id in
                let new = SearchKey.messageID(id)
                if let a = all {
                    all = SearchKey.or(a, new)
                } else {
                    all = new
                }
            }
        )
    }

    /// Will match the last `count` messages in a mailbox with `mailboxMessageCount` messages.
    static func lastMessages(
        count: Int,
        mailboxMessageCount: Int
    ) -> SearchKey {
        guard
            count < mailboxMessageCount
        else { return .all }
        let end = SequenceNumber
            .min
            .advanced(by: Int64(mailboxMessageCount))
            .advanced(by: -Int64(count))
        let range = MessageIdentifierSetNonEmpty<SequenceNumber>(range: end...SequenceNumber.max)
        return .sequenceNumbers(.set(range))
    }
}

// MARK: -

/// Performs a search for the given `SearchKey`, but splits the messages into batches
/// and runs multiple searches, one on each batch.
func batchedSearch<C: ConnectionProtocol>(
    connection: C,
    key searchKey: SearchKey,
    query: FetchQuery,
    mailboxMessageCount: Int,
    capabilities: [Capability]
) async throws -> UIDSet {
    try await batched(
        connection: connection,
        query: query,
        mailboxMessageCount: mailboxMessageCount,
        capabilities: capabilities,
        fetch: { batch in
            try await searchBatch(
                connection: connection,
                capabilities: capabilities,
                key: searchKey,
                query: query,
                batch: batch
            ) ?? UIDSet()
        },
        into: UIDSet(),
        update: {
            $0.formUnion($1)
        }
    )
}

extension SearchKey {
    /// Combine the given `SearchKey` with a predicate that limits the UIDs to the ones in the given `FetchBatch`.
    static func combine(
        key searchKey: SearchKey,
        query: FetchQuery,
        batch: FetchBatch
    ) -> Self {
        let uids = batch.makeUIDs(query)
        guard uids != .all else { return searchKey }
        guard let set = UIDSetNonEmpty(set: uids) else { return .not(.all) }
        let uidKey = SearchKey.uid(.set(set))
        guard searchKey != .all else { return uidKey }
        return SearchKey.and([uidKey, searchKey])
    }
}

/// Sends a `UID SEARCH` command.
///
/// Depending on the server capabilities, a normal (RFC 3501), an extended, or a partial
/// search command may be used.
func searchBatch<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    key searchKey: SearchKey,
    query: FetchQuery,
    batch: FetchBatch
) async throws -> UIDSet? {
    let combined = SearchKey.combine(
        key: searchKey,
        query: query,
        batch: batch
    )

    switch batch {
    case .uidRange:
        return try await search(
            connection: connection,
            capabilities: capabilities,
            kind: .nonPartial(combined)
        )
    case .partialLast(let partialRange):
        return try await search(
            connection: connection,
            capabilities: capabilities,
            kind: .partial(partialRange, combined)
        )
    }
}

// MARK: -

/// Sends a `UID SEARCH` command.
///
/// Depending on the server capabilities, a normal (RFC 3501), an extended, or a partial
/// search command may be used.
func search<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    key searchKey: SearchKey
) async throws -> UIDSet {
    guard capabilities.contains(.partial) else {
        return try await search(
            connection: connection,
            capabilities: capabilities,
            kind: .nonPartial(searchKey)
        ) ?? UIDSet()
    }
    let batchSize = effectiveBatchSize(capabilities: capabilities)

    var uids = UIDSet()
    for batch in 0... {
        let range: NIOIMAP.PartialRange = {
            let start = SequenceNumber.min.advanced(by: Int64(batch) * Int64(batchSize))
            let end = SequenceNumber.min.advanced(by: Int64(batch + 1) * Int64(batchSize) - 1)
            return NIOIMAP.PartialRange.last(start...end)
        }()
        writeStatus("[PARTIAL SEARCH] searching range \(range)")
        let newUIDs = try await search(
            connection: connection,
            capabilities: capabilities,
            kind: .partial(range, searchKey)
        )
        guard let newUIDs, !newUIDs.isEmpty else { break }
        writeStatus("[PARTIAL SEARCH] Batch \(batch + 1) returned \(newUIDs.count) UIDs")
        uids.formUnion(newUIDs)
    }
    writeStatus("Did find \(uids.count) UIDs using PARTIAL SEARCH")
    return uids
}

/// Minimum batch size when partitioning UIDs for `FETCH` / `SEARCH` requests.
///
/// When a server advertises a smaller `MESSAGELIMIT`, we still use this floor as
/// the batch size — the server's `MESSAGELIMIT` caps how many results may be
/// returned in a single response, not how many UIDs we may include in a request.
let minimumFetchBatchSize: UInt32 = 1_000

/// The batch size to use when partitioning UIDs for `FETCH` / `SEARCH`.
///
/// Returns `max(minimumFetchBatchSize, serverMessageLimit)`. When the server
/// does not advertise `MESSAGELIMIT` (RFC 9738), returns `minimumFetchBatchSize`.
func effectiveBatchSize(
    capabilities: [Capability]
) -> UInt32 {
    guard
        let limitA = capabilities.first(where: {
            $0.name == "MESSAGELIMIT"
        })?.value,
        let limitB = UInt32(limitA)
    else { return minimumFetchBatchSize }
    return max(minimumFetchBatchSize, limitB)
}

struct NoUntaggedSearchResponse: Swift.Error {}

// MARK: -

enum SearchKind: Hashable, Sendable {
    case nonPartial(SearchKey)
    case partial(NIOIMAP.PartialRange, SearchKey)
}

func search<C: ConnectionProtocol>(
    connection: C,
    capabilities: [Capability],
    kind: SearchKind,
) async throws -> UIDSet? {
    let searchKey: SearchKey
    let returnOptions: [SearchReturnOption]
    switch kind {
    case .partial(let range, let key):
        searchKey = key
        returnOptions = [.partial(range)]
    case .nonPartial(let key):
        searchKey = key
        returnOptions = capabilities.contains(.extendedSearch) ? [.all] : []
    }

    guard returnOptions.isEmpty else {
        let uids = try await sendUIDSearch(
            connection: connection,
            key: searchKey,
            returnOptions: returnOptions
        ) { tag, response in
            guard
                case .untagged(.mailboxData(.extendedSearch(let result))) = response,
                let c = result.correlator,
                c.tag == "\(tag)"
            else { return nil }
            return result.matchedUIDs ?? UIDSet()
        }
        writeStatus("Did find \(uids?.count ?? 0) UIDs using extended UID SEARCH")
        return uids
    }
    let uids = try await sendUIDSearch(
        connection: connection,
        key: searchKey,
        returnOptions: []
    ) { _, response in
        guard
            case .untagged(.mailboxData(.search(let ids, _))) = response
        else { return nil }
        return UIDSet(MessageIdentifierSet(ids))
    }
    writeStatus("Did find \(uids?.count ?? 0) UIDs using UID SEARCH")
    return uids
}

/// Sends a `UID SEARCH` command and extracts matching UIDs from untagged responses
/// using `extract`. Throws `NoUntaggedSearchResponse` if no matching untagged response
/// arrived before the tagged completion.
private func sendUIDSearch<C: ConnectionProtocol>(
    connection: C,
    key searchKey: SearchKey,
    returnOptions: [SearchReturnOption],
    extract: @Sendable @escaping (IMAPConnection.Tag, Response) -> UIDSet?
) async throws -> UIDSet? {
    try await connection.send(
        .uidSearch(
            key: searchKey,
            charset: nil,
            returnOptions: returnOptions
        )
    ) { tag, responses in
        var didFind = false
        var uids: UIDSet?
        try await responses.forEach { response in
            guard let extracted = extract(tag, response) else { return }
            didFind = true
            uids = extracted
        }.checkOK()
        guard didFind else { throw NoUntaggedSearchResponse() }
        return uids
    }
}
