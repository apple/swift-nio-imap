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
import NIO
import NIOIMAP
import Testing

/// `sendIdle(_:)` against a scripted server, for the exchanges other than
/// `IDLE` → `+` → `DONE` → tagged `OK`.
///
/// - Important: These open real sockets, so they cannot run in a sandboxed
///   environment. Run them manually.
@Suite("IMAPConnection IDLE")
enum IMAPConnectionIdleTests {
    /// A server may refuse `IDLE` with a tagged `NO` instead of `+`. `sendIdle(_:)` still sends
    /// `DONE` once its handler returns. That `DONE` has nothing to end, so it must not reach the
    /// wire, and the connection must remain usable.
    @Test(.timeLimit(.minutes(3)))
    static func rejectedIdleLeavesConnectionUsable() async throws {
        let (server, transcript) = try await LoopbackServer.scripted { line in
            switch Self.tagAndCommand(line) {
            case (let tag?, "IDLE"): ["\(tag) NO IDLE not permitted"]
            case (let tag?, "NOOP"): ["\(tag) OK NOOP completed"]
            default: []
            }
        }
        defer { server.shutdown() }
        let port = server.port

        let tags = LockedBox<[String]>([])
        let failure = LockedBox<String?>(nil)
        let finished = await finishesWithoutStalling {
            do {
                try await IMAPConnection.withConnection(configuration: .loopback(port: port)) { _, connection in
                    let idle = try await connection.sendIdle { tag, responses in
                        tags.withLock { $0.append(String(tag)) }
                        return try await responses.waitForCompletion()
                    }
                    #expect(idle.state == .no(.init(text: "IDLE not permitted")))

                    let noop = try await connection.send(.noop) { tag, responses in
                        tags.withLock { $0.append(String(tag)) }
                        return try await responses.waitForCompletion()
                    }
                    #expect(noop.state == .ok(.init(text: "NOOP completed")))
                }
            } catch {
                failure.withLock { $0 = "\(error)" }
            }
        }

        #expect(finished)
        #expect(failure.withLock { $0 } == nil)
        let (idle, noop) = tags.withLock { ($0.first ?? "?", $0.last ?? "?") }
        #expect(
            transcript.withLock { $0 } == [
                "C: \(idle) IDLE",
                "S: \(idle) NO IDLE not permitted",
                "C: \(noop) NOOP",
                "S: \(noop) OK NOOP completed",
            ]
        )
    }

    /// A handler may return before the server has confirmed `IDLE`. `DONE` answers the server's
    /// `+`, so `sendIdle(_:)` must hold it until the `+` arrives.
    ///
    /// The server delays its replies so the handler has returned — and `DONE` is pending — well
    /// before the `+` arrives.
    @Test(.timeLimit(.minutes(3)))
    static func doneWaitsForIdleConfirmation() async throws {
        let idleTag = LockedBox<String?>(nil)
        let (server, transcript) = try await LoopbackServer.scripted(replyDelay: .milliseconds(100)) { line in
            switch Self.tagAndCommand(line) {
            case (let tag?, "IDLE"):
                idleTag.withLock { $0 = tag }
                return ["+ idling"]
            case (nil, "DONE"):
                return ["\(idleTag.withLock { $0 } ?? "?") OK IDLE terminated"]
            case (let tag?, "NOOP"):
                return ["\(tag) OK NOOP completed"]
            default:
                return []
            }
        }
        defer { server.shutdown() }
        let port = server.port

        let tags = LockedBox<[String]>([])
        let failure = LockedBox<String?>(nil)
        let finished = await finishesWithoutStalling {
            do {
                try await IMAPConnection.withConnection(configuration: .loopback(port: port)) { _, connection in
                    try await connection.sendIdle { tag, _ in
                        tags.withLock { $0.append(String(tag)) }
                    }
                    let noop = try await connection.send(.noop) { tag, responses in
                        tags.withLock { $0.append(String(tag)) }
                        return try await responses.waitForCompletion()
                    }
                    #expect(noop.state == .ok(.init(text: "NOOP completed")))
                }
            } catch {
                failure.withLock { $0 = "\(error)" }
            }
        }

        #expect(finished)
        #expect(failure.withLock { $0 } == nil)
        let (idle, noop) = tags.withLock { ($0.first ?? "?", $0.last ?? "?") }
        let lines = transcript.withLock { $0 }
        // How the server's replies interleave with the client's lines depends on timing.
        #expect(lines.filter { $0.hasPrefix("C: ") } == ["C: \(idle) IDLE", "C: DONE", "C: \(noop) NOOP"])
        // DONE answers the `+`, so the server must have sent that first.
        let confirmed = try #require(lines.firstIndex(of: "S: + idling"))
        let done = try #require(lines.firstIndex(of: "C: DONE"))
        #expect(confirmed < done)
    }

    /// Splits `A1 NOOP` into `("A1", "NOOP")`, and `DONE` into `(nil, "DONE")`.
    private static func tagAndCommand(_ line: String) -> (tag: String?, command: String) {
        let words = line.split(separator: " ", maxSplits: 1).map(String.init)
        guard words.count == 2 else { return (nil, line) }
        return (words[0], words[1])
    }
}

extension IMAPConnection.Configuration {
    fileprivate static func loopback(port: UInt16) -> Self {
        IMAPConnection.Configuration(hostname: "127.0.0.1", port: port, useTLS: false, logging: .noLogging)
    }
}
