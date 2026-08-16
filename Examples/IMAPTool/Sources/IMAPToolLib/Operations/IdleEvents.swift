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

/// Runs an `IDLE` command and passes the event stream to the given closure.
func runIdle<Result: Sendable>(
    connection: IMAPConnection,
    _ closure: (IMAPConnection.Tag, IdleEventStream) async throws -> Result
) async throws -> Result {
    try await connection.sendIdle { tag, responses in
        writeStatus("Running IDLE as \(tag)")
        let r = try await closure(tag, IdleEventStream(underlying: responses))
        writeStatus("Did run IDLE")
        return r
    }
}

// MARK: Event

/// An event received during an `IDLE` session.
enum IdleEvent: Equatable, Sendable {
    /// The mailbox now contains this many messages.
    case exists(Int)
    /// The message at this sequence number was expunged.
    case expunge(SequenceNumber)
    /// The given UIDs were removed (via `VANISHED`).
    case vanished(UIDSet)
    /// A `FETCH` response with the given attributes.
    case fetch(SequenceNumber?, [MessageAttribute])
}

extension IdleEvent: Encodable {
    /// Encodes the event into a format that is straightforward to read and parse.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .exists(let count):
            try container.encode(count, forKey: .count)
        case .expunge(let seq):
            try container.encode(UInt32(seq), forKey: .sequenceNumber)
        case .vanished(let uids):
            // Two encodings:
            // - `uids`     — the canonical IMAP wire form (e.g. `"1:5,7,9:12"`),
            //               for clients that prefer the compact range syntax.
            // - `uidsList` — a fully-expanded JSON array of UIDs, for clients
            //               that don't want to parse the IMAP grammar.
            //
            // `debugDescription` on `MessageIdentifierSet` produces the wire
            // form by running its IMAP encoder, so this is stable across runs.
            try container.encode(uids.debugDescription, forKey: .uids)
            try container.encode(uids.map { UInt32($0) }, forKey: .uidsList)
        case .fetch(let seq, let attributes):
            try container.encodeIfPresent(seq.map { UInt32($0) }, forKey: .sequenceNumber)
            // We need to keep track of what (which keys) we’ve already added.
            // We might receive the same key multiple times, but we can only encode it once.
            var allKeys = Set<CodingKeys>()

            func check(key: CodingKeys) -> Bool {
                guard !allKeys.contains(key) else { return false }
                allKeys.insert(key)
                return true
            }

            for attr in attributes {
                switch attr {
                case .flags(let flags):
                    guard check(key: .flags) else { continue }
                    try container.encode(flags.map { String($0) }, forKey: .flags)
                case .uid(let uid):
                    guard check(key: .uid) else { continue }
                    try container.encode(UInt32(uid), forKey: .uid)
                case .rfc822Size(let count):
                    guard check(key: .rfc822Size) else { continue }
                    try container.encode(count, forKey: .rfc822Size)
                case .fetchModificationSequence(let modSeq):
                    guard check(key: .fetchModificationResponse) else { continue }
                    try container.encode(UInt64(modSeq), forKey: .fetchModificationResponse)
                case .gmailMessageID(let id):
                    guard check(key: .gmailMessageID) else { continue }
                    try container.encode(id, forKey: .gmailMessageID)
                case .gmailThreadID(let id):
                    guard check(key: .gmailThreadID) else { continue }
                    try container.encode(id, forKey: .gmailThreadID)
                case .gmailLabels(let labels):
                    guard check(key: .gmailLabels) else { continue }
                    try container.encode(labels.map { $0.makeDisplayString() }, forKey: .gmailLabels)
                case .preview(let preview):
                    guard check(key: .preview) else { continue }
                    try container.encode(preview.map { String($0) }, forKey: .preview)
                case .emailID(let id):
                    guard check(key: .emailID) else { continue }
                    try container.encode(String(id), forKey: .emailID)
                case .threadID(let id):
                    guard check(key: .threadID) else { continue }
                    try container.encode(id.map { String($0) }, forKey: .threadID)
                default:
                    continue
                }
            }
        }
    }

    var kind: String {
        switch self {
        case .exists: "exists"
        case .expunge: "expunge"
        case .vanished: "vanished"
        case .fetch: "fetch"
        }
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case count
        case sequenceNumber
        case uids
        case uidsList

        case flags
        case uid
        case rfc822Size
        case fetchModificationResponse
        case gmailMessageID
        case gmailThreadID
        case gmailLabels
        case preview
        case emailID
        case threadID

    }
}

// MARK: Event Decoder

enum IdleEventDecoder: Sendable {
    case normal
    case fetch(SequenceNumber?, [MessageAttribute])
}

extension IdleEventDecoder {
    mutating func update(
        _ response: Response
    ) -> IdleEvent? {
        switch (self, response) {
        case (.normal, .fetch(.start(let seq))):
            self = .fetch(seq, [])
            return nil
        case (.normal, .fetch(.startUID(let uid))):
            self = .fetch(nil, [.uid(uid)])
            return nil
        case (.fetch(let seq, var attr), .fetch(.simpleAttribute(let new))):
            attr.append(new)
            self = .fetch(seq, attr)
            return nil
        case (.fetch(let seq, let attr), .fetch(.finish)):
            self = .normal
            return .fetch(seq, attr)
        case (.fetch, .fetch(.streamingBegin)),
            (.fetch, .fetch(.streamingBytes)),
            (.fetch, .fetch(.streamingEnd)):
            // Ignore bytes being streamed
            return nil
        case (.fetch, _):
            // We received something that’s not part of FETCH. Should not happen, but ignore.
            return nil
        case (.normal, .fetch):
            // Should not happen, but ignore.
            return nil
        case (.normal, .untagged(.mailboxData(.exists(let count)))):
            return .exists(count)
        case (.normal, .untagged(.messageData(.expunge(let seq)))):
            return .expunge(seq)
        case (.normal, .untagged(.messageData(.vanished(let uids)))):
            return .vanished(uids)
        case (.normal, _):
            return nil
        }
    }
}

// MARK: Idle Stream

/// An async sequence that transforms raw IMAP responses into `IdleEvent` values.
struct IdleEventStream: AsyncSequence, Sendable {
    /// The iterator that decodes responses into idle events.
    struct AsyncIterator: AsyncIteratorProtocol {
        typealias Element = IdleEvent

        var underlying: IMAPConnection.ResponseStream.AsyncIterator
        var decoder = IdleEventDecoder.normal

        mutating func next() async throws -> IdleEvent? {
            while let response = try await underlying.next() {
                guard
                    let event = decoder.update(response)
                else { continue }
                writeStatus("Did receive '\(event.kind)' during IDLE")
                return event
            }
            return nil
        }
    }

    typealias Element = IdleEvent

    let underlying: IMAPConnection.ResponseStream

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(underlying: underlying.makeAsyncIterator())
    }
}
