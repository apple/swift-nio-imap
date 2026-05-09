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
    /// finished. `withConnection` then hangs forever instead of failing the command.
    @Test(.timeLimit(.minutes(1)))
    static func gracefulEOFWhileAwaitingResponseDoesNotHang() async throws {
        let server = try await LoopbackServer.greetThenCloseOnFirstCommand()
        defer { server.shutdown() }

        let configuration = IMAPConnection.Configuration(
            hostname: "127.0.0.1",
            port: server.port,
            useTLS: false,
            logging: .noLogging
        )

        let outcome = Mutex<String>("did-not-run")
        let finished = await finishesWithoutHanging(within: 10) {
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
            "withConnection hung after the server closed the connection (graceful EOF) while a command was awaiting its tagged response."
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
    /// `withConnection` hangs instead of throwing the connection error.
    @Test(.timeLimit(.minutes(1)))
    static func connectFailureThrowsInsteadOfHanging() async throws {
        // Port 1 is (essentially) always closed on loopback, so the connect is refused.
        let configuration = IMAPConnection.Configuration(
            hostname: "127.0.0.1",
            port: 1,
            useTLS: false,
            logging: .noLogging
        )

        let outcome = Mutex<String>("did-not-run")
        let finished = await finishesWithoutHanging(within: 10) {
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
            "withConnection hung when the connection could not be established, instead of throwing the connection error."
        )
        #expect(
            outcome.withLock { $0 } == "threw",
            "Failing to connect should surface as a thrown error from withConnection."
        )
    }

    /// When the `AUTHENTICATE` handler throws mid-exchange there is no way to cleanly
    /// abort the exchange, so `sendAuthenticate` closes the connection. A subsequent
    /// command must then fail fast rather than write on a half-authenticated connection.
    @Test(.timeLimit(.minutes(1)))
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

        let finished = await finishesWithoutHanging(within: 10) {
            do {
                try await IMAPConnection.withConnection(configuration: configuration) { _, connection in
                    do {
                        try await connection.sendAuthenticate(mechanism: .plain, initialResponse: nil) { _, _, _ -> Void in
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

        #expect(finished, "withConnection hung after the AUTHENTICATE handler threw.")
        #expect(handlerThrew.withLock { $0 }, "The AUTHENTICATE handler error should propagate.")
        #expect(
            secondCommandFailed.withLock { $0 },
            "After the AUTHENTICATE handler threw, sendAuthenticate should have closed the connection so a subsequent command fails."
        )
    }
}
