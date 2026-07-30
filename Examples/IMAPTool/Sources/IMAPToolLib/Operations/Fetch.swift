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

// MARK: - Message Info

/// Get ``MessageInfo`` for all messages specified by `query`.
func fetchMessageInfo<C: ConnectionProtocol>(
    connection: C,
    mailboxMessageCount: Int,
    capabilities: [Capability],
    query: FetchQuery
) async throws -> [MessageInfo] {
    // Store into a dictionary to make sure the values
    // are unique per UID -- in case the server returns multiple
    // replies (commands running in parallel).
    let all: [UID: MessageInfo]
    all = try await batchedFetchSimpleAttributes(
        connection: connection,
        mailboxMessageCount: mailboxMessageCount,
        capabilities: capabilities,
        query: query,
        attributes: [.uid, .flags, .envelope],
        into: [:],
        update: { result, batchResult in
            for (uid, attr) in batchResult {
                guard
                    let info = MessageInfo(
                        uid: uid,
                        attributes: attr
                    )
                else { continue }
                result[info.uid] = info
            }
        }
    )
    return all
        .values
        .sorted(by: { $0.uid < $1.uid })
}

/// Fetches the given `attributes` for messages specified by `query`, in batches.
///
/// The `update` closure merges one batch's results into `result`.
///
/// - Parameters:
///   - mailboxMessageCount: The number of messages in the mailbox.
///   - capabilities: The server capabilities.
func batchedFetchSimpleAttributes<C: ConnectionProtocol, Result: Sendable>(
    connection: C,
    mailboxMessageCount: Int,
    capabilities: [Capability],
    query: FetchQuery,
    attributes: [FetchAttribute],
    into result: Result,
    update: @Sendable (inout Result, [UID: [MessageAttribute]]) throws -> Void
) async throws -> Result {
    return try await batched(
        connection: connection,
        query: query,
        mailboxMessageCount: mailboxMessageCount,
        capabilities: capabilities,
        fetch: { batch in
            let r: [UID: [MessageAttribute]] = try await fetchSimpleAttributes(
                connection: connection,
                capabilities: capabilities,
                uids: batch.makeUIDs(query),
                attributes: attributes,
                modifiers: batch.fetchModifiers,
                into: [:]
            ) { all, uid, _, attributes in
                all[uid] = attributes
            }
            return r
        },
        into: result,
        update: update
    )
}

// MARK: - Simple Attributes

/// Sends a `UID FETCH` command for non-streaming message attributes.
///
/// The `update` closure runs for each `* FETCH` response received.
/// Due to command pipelining, responses for other commands may also arrive.
func fetchSimpleAttributes<C: ConnectionProtocol, Result: Sendable>(
    connection: C,
    capabilities: [Capability],
    uids: UIDSet,
    attributes _attributes: [FetchAttribute],
    modifiers: [FetchModifier],
    into result: Result,
    update: @Sendable (inout Result, UID, SequenceNumber?, [MessageAttribute]) throws -> Void
) async throws -> Result {
    guard
        _attributes.allSatisfy({ $0.isSimpleAttribute })
    else {
        throw FetchAttributeIsNotSimpleAttribute(
            attributes: _attributes.filter { !$0.isSimpleAttribute }
        )
    }

    // Make sure we’re requesting the UID:
    let attributes: [FetchAttribute] = (_attributes.contains(.uid) ? _attributes : [.uid] + _attributes)

    return try await fetch(
        connection: connection,
        capabilities: capabilities,
        uids: uids,
        attributes: attributes,
        modifiers: modifiers,
        into: ResultWithState(
            state: .noMessage,
            result: result
        )
    ) { result, response in
        switch (result.state, response) {
        case (.noMessage, .start(let seq)):
            result.state = .message(seq, [])
        case (.noMessage, .startUID(let uid)):
            result.state = .message(nil, [.uid(uid)])
        case (_, .start), (_, .startUID):
            break
        case (.message(let seq, var attributes), .simpleAttribute(let new)):
            attributes.append(new)
            result.state = .message(seq, attributes)
        case (.noMessage, .simpleAttribute):
            break
        case (_, .streamingBegin), (_, .streamingBytes), (_, .streamingEnd):
            break
        case (.noMessage, .finish):
            break
        case (.message(let seq, let attributes), .finish):
            defer {
                result.state = .noMessage
            }
            let uid: UID? = attributes
                .lazy
                .compactMap {
                    guard case .uid(let uid) = $0 else { return nil }
                    return uid
                }
                .first
            guard
                let uid,
                uids.contains(uid)
            else { break }
            try update(&result.result, uid, seq, attributes)
        }
    }.result
}

private struct ResultWithState<Result: Sendable>: Sendable {
    var state: State
    var result: Result

    enum State: Sendable {
        case noMessage
        case message(SequenceNumber?, [MessageAttribute])
    }
}

// MARK: Returns Data

struct FetchAttributeIsNotSimpleAttribute: Swift.Error {
    var attributes: [FetchAttribute]
}

extension FetchAttribute {
    var isSimpleAttribute: Bool {
        switch self {
        case .binarySize,
            .bodyStructure,
            .emailID,
            .envelope,
            .flags,
            .gmailLabels,
            .gmailMessageID,
            .gmailThreadID,
            .internalDate,
            .modificationSequence,
            .modificationSequenceValue,
            .preview,
            .rfc822Size,
            .threadID,
            .uid:
            true
        case .binary,
            .bodySection,
            .rfc822,
            .rfc822Header,
            .rfc822Text:
            false
        }
    }
}

// MARK: - Generic

/// Sends a `UID FETCH` command.
///
/// The `update` closure runs for each ``FetchResponse`` received.
/// Due to command pipelining, responses for other commands may also arrive.
func fetch<C: ConnectionProtocol, Result: Sendable>(
    connection: C,
    capabilities: [Capability],
    uids _uids: UIDSet,
    attributes: [FetchAttribute],
    modifiers: [FetchModifier],
    into _result: Result,
    update: @Sendable (inout Result, FetchResponse) throws -> Void
) async throws -> Result {
    guard
        let uids = UIDSetNonEmpty(set: _uids)
    else { return _result }

    let command = Command.uidFetch(
        .set(uids),
        attributes,
        modifiers
    )
    return try await connection.send(command, isolation: #isolation) { tag, responses -> Result in
        writeStatus("Did send \(tag) \(command)")
        var result = _result
        for try await response in responses {
            guard
                case .fetch(let fetch) = response
            else { continue }
            try update(&result, fetch)
        }
        return result
    }
}
