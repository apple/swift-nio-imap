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
import System

/// Downloads messages specified by `query` into the directory at `root`.
///
/// - Parameters:
///   - deleteUnknown: Whether to delete local message files that no longer exist on the server.
/// - Returns: All UIDs in the directory, including previously downloaded UIDs.
func download<C: ConnectionProtocol>(
    connection: C,
    mailboxMessageCount: Int,
    capabilities: [Capability],
    uidValidity: UIDValidity,
    query: FetchQuery,
    into root: FilePath,
    deleteUnknown: Bool
) async throws -> UIDSet {
    // Get all UIDs on the server:
    let uids = try await allUIDs(
        connection: connection,
        query: query,
        mailboxMessageCount: mailboxMessageCount,
        capabilities: capabilities
    )
    writeStatus("Did find \(uids.count) UID(s) in mailbox")

    var directory = try DownloadDirectory.openDeletingInvalidFiles(
        directory: root,
        uidValidity: uidValidity,
        deleteUnknown: deleteUnknown
    )

    // Delete local files no longer on the server:
    if deleteUnknown {
        directory.unlinkFiles(notIncludedIn: uids)
    }

    try await download(
        connection: connection,
        uids: uids,
        into: &directory
    )

    return directory.downloadedUIDs
}

/// Downloads a batch of UIDs with a concurrency limit.
func download<C: ConnectionProtocol>(
    connection: C,
    uids allUIDs: UIDSet,
    concurrencyLimit: Int = 11,
    into _directory: inout DownloadDirectory,
) async throws {
    let directory = DownloadDirectory.Helper(
        connection: connection,
        directory: _directory
    )

    // Loop over all UIDs and download them.
    try await withThrowingTaskGroup(
        of: Void.self,
        returning: Void.self
    ) { group in
        let previouslyDownloadedUIDs = await directory.directory.downloadedUIDs
        var remainingUIDs = allUIDs.subtracting(previouslyDownloadedUIDs)
        if remainingUIDs.count != allUIDs.count {
            writeStatus(
                "Downloading \(remainingUIDs.count) remaining message(s) out of \(allUIDs.count) total message(s) — \(previouslyDownloadedUIDs.count) already downloaded"
            )
        } else {
            writeStatus("Downloading \(remainingUIDs.count) message(s)")
        }

        func popNextUID() -> UID? {
            guard
                let uid = remainingUIDs.last
            else { return nil }
            remainingUIDs.remove(uid)
            return uid
        }

        func addTask() {
            guard let uid = popNextUID() else { return }
            group.addTask {
                try await directory.download(uid: uid)
            }
        }

        for _ in 0..<concurrencyLimit {
            addTask()
        }

        var throughputEstimator = ThroughputEstimator()

        for try await _ in group {
            // Every time a task completes, start another one
            addTask()
            if let throughput = throughputEstimator.didComplete() {
                let remainingCount = remainingUIDs.count + concurrencyLimit
                if let remainingTime = throughput.formattedTimeRemaining(
                    remainingCount: remainingCount,
                    remainingCountCutOff: max(20 + concurrencyLimit, 4 * concurrencyLimit)
                ) {
                    writeStatus(
                        "Downloading at \(throughput.formattedTasksPerSecond()) messages per second — \(remainingTime) remaining"
                    )
                } else {
                    writeStatus("Downloading at \(throughput.formattedTasksPerSecond()) messages per second")
                }
            }
        }
    }

    // Get the updated value out of the Mutex
    _directory = await directory.directory
}

extension DownloadDirectory {
    /// Provides concurrent access to a `DownloadDirectory` during downloads.
    actor Helper<C: ConnectionProtocol> {
        let connection: C
        var directory: DownloadDirectory

        init(
            connection: C,
            directory: DownloadDirectory
        ) {
            self.connection = connection
            self.directory = directory
        }

        func makeWriter(
            uid: UID
        ) throws -> DownloadDirectory.Writer {
            try directory.makeWriter(uid: uid)
        }

        func didDownload(uid: UID) {
            directory.didDownload(uid: uid)
        }
    }
}

extension DownloadDirectory.Helper {
    func download(uid: UID) async throws {
        let section = SectionSpecifier(part: [], kind: .complete)
        let command = Command.uidFetch(
            .set(UIDSetNonEmpty(range: uid...uid)),
            [.uid, .bodySection(peek: true, section, nil)],
            []
        )

        let writer = try makeWriter(uid: uid)
        let byteCount = try await connection.send(command) { tag, responses -> Int? in
            writeStatus("Did send \(tag) UID FETCH \(uid) for complete message")

            var state = FetchState.waiting

            for try await response in responses {
                let action = state.update(
                    uid: uid,
                    section: section,
                    response: response
                )
                switch action {
                case .none:
                    break
                case .writeData(let data):
                    writer.write(data)
                case .closeAndFail:
                    writer.closeAndFail()
                case .closeAndSucceed:
                    writer.closeAndSucceed()
                }
            }

            // Wait for the writer to have completed.
            await writer.waitForCompletion()
            return state.byteCount
        }

        guard
            let byteCount
        else {
            writeStatus("Did not receive any data for UID \(uid) — message might have been deleted")
            return
        }
        writeStatus("Did write \(byteCount) bytes for UID \(uid)")
        directory.didDownload(uid: uid)
    }
}

/// Keeps track of where we are wrt. receiving `FetchResponse` for a particular message.
///
/// State transitions, driven by `update(uid:section:response:)`:
///
/// ```
///                   .fetch(.start)
///   waiting ─────────────────────────────────► didStart
///
///                   .simpleAttribute(.uid(matching))
///   didStart ───────────────────────────────────────────► didMatchUID
///
///                   .streamingBegin(.body(section, nil))
///   didMatchUID ──────────────────────────────────────────► didBeginStream
///
///                                .streamingBytes  (→ writeData)
///   didBeginStream ◄─────self loop──────────
///                  │
///                  │   .streamingEnd
///                  └──────────────────────► didEndStream
///
///                   .finish (→ closeAndSucceed)
///   didEndStream ─────────────────────────► done
///                  │
///                  │   anything else (→ closeAndFail)
///                  └──────────────────────► failed
/// ```
///
/// Any unmatched `(state, response)` pair returns `.none` and leaves the state
/// untouched — the iterator simply waits for the next response.
private enum FetchState: Equatable, Sendable {
    case waiting
    case didStart
    case didMatchUID
    case didBeginStream(byteCount: Int)
    case didEndStream(byteCount: Int)
    case done(byteCount: Int)
    case failed
}

extension FetchState {
    /// If writing completed (successfully), return the written byte count.
    var byteCount: Int? {
        guard
            case .done(let c) = self
        else { return nil }
        return c
    }

    enum UpdateAction: Sendable {
        case none
        case writeData(DispatchData)
        case closeAndFail
        case closeAndSucceed
    }

    mutating func update(
        uid: UID,
        section: SectionSpecifier,
        response: Response
    ) -> UpdateAction {
        guard case .fetch(let fetch) = response else { return .none }
        switch (self, fetch) {
        case (.waiting, .start):
            self = .didStart
            return .none
        case (.didStart, .simpleAttribute(.uid(uid))):
            self = .didMatchUID
            return .none
        case (
            .didMatchUID,
            .streamingBegin(kind: StreamingKind.body(section: section, offset: nil), byteCount: let byteCount)
        ):
            self = .didBeginStream(byteCount: byteCount)
            return .none
        case (.didBeginStream, .streamingBytes(let bytes)):
            let data = bytes.withUnsafeReadableBytes {
                DispatchData(bytesNoCopy: $0, deallocator: .custom(nil, { _ = bytes }))
            }
            return .writeData(data)
        case (.didBeginStream(byteCount: let byteCount), .streamingEnd):
            self = .didEndStream(byteCount: byteCount)
            return .none
        case (.didEndStream(byteCount: let byteCount), .finish):
            self = .done(byteCount: byteCount)
            return .closeAndSucceed
        case (.didEndStream, _):
            self = .failed
            return .closeAndFail
        default:
            return .none
        }
    }
}
