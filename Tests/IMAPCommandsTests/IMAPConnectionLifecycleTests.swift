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
import NIO
import NIOIMAP
import Synchronization
import Testing

/// Regression tests for `IMAPConnection`'s connection lifecycle.
///
/// - Important: These open real sockets, so they cannot run in a sandboxed
///   environment (socket `bind`/`connect` fail with errno 1). Run them manually.
@Suite("IMAPConnection lifecycle")
enum IMAPConnectionLifecycleTests {

    /// Bug #1: When the server closes the connection gracefully (EOF) while a command
    /// is in flight, the inbound read loop exits without calling `close()`, so the
    /// outbound task stays parked and the in-flight command's response stream is never
    /// finished. `withConnection` then stalls forever instead of failing the command.
    @Test(.timeLimit(.minutes(3)))
    static func gracefulEOFWhileAwaitingResponseDoesNotStall() async throws {
        let server = try await LoopbackServer.greetThenCloseOnFirstCommand()
        defer { server.shutdown() }

        let configuration = IMAPConnection.Configuration(
            hostname: "127.0.0.1",
            port: server.port,
            useTLS: false,
            logging: .noLogging
        )

        let outcome = Mutex<String>("did-not-run")
        let finished = await finishesWithoutStalling {
            do {
                try await IMAPConnection.withConnection(configuration: configuration) { _, connection in
                    try await connection.send(.noop) { _, responses in
                        _ = try await responses.waitForCompletion()
                    }
                }
                outcome.withLock { $0 = "returned" }
            } catch {
                outcome.withLock { $0 = "threw" }
            }
        }

        #expect(
            finished,
            "withConnection stalled after the server closed the connection (graceful EOF) while a command was awaiting its tagged response."
        )
        // Once fixed, the in-flight command fails with a connection-closed error, so
        // `withConnection` propagates that error rather than completing successfully.
        #expect(
            outcome.withLock { $0 } == "threw",
            "The in-flight command should fail with a connection-closed error."
        )
    }

    /// Bug #2: When the channel fails to open (e.g. connection refused), `run()`
    /// propagates the error before `close()` is ever called, so the greeting
    /// continuation the `body` task is parked on is never resumed. Because the greeting
    /// getter is not cancellation-aware, the structured task group can never finish and
    /// `withConnection` stalls instead of throwing the connection error.
    @Test(.timeLimit(.minutes(3)))
    static func connectFailureThrowsInsteadOfStalling() async throws {
        // Port 1 is (essentially) always closed on loopback, so the connect is refused.
        let configuration = IMAPConnection.Configuration(
            hostname: "127.0.0.1",
            port: 1,
            useTLS: false,
            logging: .noLogging
        )

        let outcome = Mutex<String>("did-not-run")
        let finished = await finishesWithoutStalling {
            do {
                try await IMAPConnection.withConnection(configuration: configuration) { _, _ in
                    // Should never get here — the connection can't be established.
                }
                outcome.withLock { $0 = "returned" }
            } catch {
                outcome.withLock { $0 = "threw" }
            }
        }

        #expect(
            finished,
            "withConnection stalled when the connection could not be established, instead of throwing the connection error."
        )
        #expect(
            outcome.withLock { $0 } == "threw",
            "Failing to connect should surface as a thrown error from withConnection."
        )
    }

    /// When the `AUTHENTICATE` handler throws mid-exchange there is no way to cleanly
    /// abort the exchange, so `sendAuthenticate` closes the connection. A subsequent
    /// command must then fail fast rather than write on a half-authenticated connection.
    @Test(.timeLimit(.minutes(3)))
    static func authenticateHandlerThrowClosesConnection() async throws {
        let server = try await LoopbackServer.greetThenStayOpen()
        defer { server.shutdown() }

        let configuration = IMAPConnection.Configuration(
            hostname: "127.0.0.1",
            port: server.port,
            useTLS: false,
            logging: .noLogging
        )

        struct HandlerError: Swift.Error {}

        let handlerThrew = Mutex(false)
        let secondCommandFailed = Mutex(false)

        let finished = await finishesWithoutStalling {
            do {
                try await IMAPConnection.withConnection(configuration: configuration) { _, connection in
                    do {
                        try await connection.sendAuthenticate(
                            mechanism: .plain,
                            initialResponse: nil
                        ) { _, _, _ -> Void in
                            throw HandlerError()
                        }
                    } catch is HandlerError {
                        handlerThrew.withLock { $0 = true }
                    }
                    // sendAuthenticate should have closed the connection, so a follow-up
                    // command must fail fast rather than run on a half-authenticated
                    // connection.
                    do {
                        try await connection.send(.noop) { _, responses in
                            _ = try await responses.waitForCompletion()
                        }
                    } catch {
                        secondCommandFailed.withLock { $0 = true }
                    }
                }
            } catch {
                // withConnection may also rethrow once the connection is closed.
            }
        }

        #expect(finished, "withConnection stalled after the AUTHENTICATE handler threw.")
        #expect(handlerThrew.withLock { $0 }, "The AUTHENTICATE handler error should propagate.")
        #expect(
            secondCommandFailed.withLock { $0 },
            "After the AUTHENTICATE handler threw, sendAuthenticate should have closed the connection so a subsequent command fails."
        )
    }

    /// A failing connection must not cancel the `body`. The failure has to surface through
    /// the connection instead: the in-flight command fails, and so does every command after
    /// it — but `body` keeps running and its result is what `withConnection` returns.
    @Test(.timeLimit(.minutes(3)))
    static func connectionFailureSurfacesThroughTheConnectionRatherThanCancellingTheBody() async throws {
        let server = try await LoopbackServer.greetThenCloseOnFirstCommand()
        defer { server.shutdown() }

        let configuration = IMAPConnection.Configuration(
            hostname: "127.0.0.1",
            port: server.port,
            useTLS: false,
            logging: .noLogging
        )

        let outcome = Mutex<String>("did-not-run")
        let finished = await finishesWithoutStalling {
            do {
                // Note that `steps` is a plain, mutable local: the body is neither
                // `@Sendable` nor `@escaping`, so it can capture non-`Sendable` state.
                var steps: [String] = []
                let result = try await IMAPConnection.withConnection(configuration: configuration) { _, connection in
                    do {
                        try await connection.send(.noop) { _, responses in
                            _ = try await responses.waitForCompletion()
                        }
                        steps.append("first-succeeded")
                    } catch {
                        steps.append("first-failed")
                    }
                    // The connection failed, but this task was not cancelled by it.
                    steps.append(Task.isCancelled ? "cancelled" : "still-running")
                    // Interacting with the failed connection keeps failing.
                    do {
                        try await connection.send(.noop) { _, responses in
                            _ = try await responses.waitForCompletion()
                        }
                        steps.append("second-succeeded")
                    } catch {
                        steps.append("second-failed")
                    }
                    return steps.joined(separator: ",")
                }
                outcome.withLock { $0 = result }
            } catch {
                outcome.withLock { $0 = "threw: \(error)" }
            }
        }

        #expect(finished, "withConnection stalled after the server closed the connection.")
        #expect(
            outcome.withLock { $0 } == "first-failed,still-running,second-failed",
            "The connection failure should surface through the connection, not as cancellation of the body."
        )
    }

    /// A closure that throws part-way through an `APPEND` leaves the command unfinished, and
    /// the protocol offers no way to abort it. `append` therefore closes the connection, so
    /// that a subsequent command fails instead of being written into the middle of the
    /// half-sent `APPEND`.
    @Test(.timeLimit(.minutes(3)))
    static func appendClosureThrowClosesConnection() async throws {
        let server = try await LoopbackServer.greetThenStayOpen()
        defer { server.shutdown() }

        let configuration = IMAPConnection.Configuration(
            hostname: "127.0.0.1",
            port: server.port,
            useTLS: false,
            logging: .noLogging
        )

        struct WriterError: Swift.Error {}

        let outcome = Mutex<String>("did-not-run")
        let finished = await finishesWithoutStalling {
            do {
                var steps: [String] = []
                let result = try await IMAPConnection.withConnection(configuration: configuration) { _, connection in
                    do {
                        _ = try await connection.append(to: MailboxName(Array("INBOX".utf8))) { _, _, _ in
                            throw WriterError()
                        }
                        steps.append("append-succeeded")
                    } catch is WriterError {
                        steps.append("append-threw")
                    }
                    do {
                        try await connection.send(.noop) { _, responses in
                            _ = try await responses.waitForCompletion()
                        }
                        steps.append("noop-succeeded")
                    } catch {
                        steps.append("noop-failed")
                    }
                    return steps.joined(separator: ",")
                }
                outcome.withLock { $0 = result }
            } catch {
                outcome.withLock { $0 = "threw: \(error)" }
            }
        }

        #expect(finished, "withConnection stalled after the APPEND closure threw.")
        #expect(
            outcome.withLock { $0 } == "append-threw,noop-failed",
            "An aborted APPEND should propagate its error and close the connection."
        )
    }
}
