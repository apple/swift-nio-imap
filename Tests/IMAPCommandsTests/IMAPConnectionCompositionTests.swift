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

/// Pins the composability contract of `IMAPConnection`'s closure-based API: none of the
/// closures are `@Sendable` or `@escaping`, and they are all `nonisolated(nonsending)`, so they
/// run in the caller's isolation domain.
///
/// These are primarily _compile-time_ tests. Each one passes a closure that captures and
/// mutates non-`Sendable` state — a plain local `var`, or a class instance isolated to the
/// caller's actor — which only type-checks if the closure is neither `@Sendable` nor
/// `@escaping` and runs in the caller's isolation domain.
///
/// They connect to port 1, which is closed, so the connection always fails and the bodies
/// never run: the assertion is that the API surface compiles and that the connection
/// failure surfaces as a thrown error.
@Suite("IMAPConnection API composition")
struct IMAPConnectionCompositionTests {

    /// Not `Sendable`, and only usable from the isolation domain it was created in.
    final class Recorder {
        var lines: [String] = []

        func record(_ line: String) {
            lines.append(line)
        }
    }

    static var unreachableConfiguration: IMAPConnection.Configuration {
        // Port 1 is (essentially) always closed on loopback, so the connect is refused.
        IMAPConnection.Configuration(
            hostname: "127.0.0.1",
            port: 1,
            useTLS: false,
            logging: .noLogging
        )
    }

    static let mailbox = MailboxName(Array("INBOX".utf8))

    /// The whole API surface, exercised from a `@MainActor` context with a non-`Sendable`
    /// `Recorder` shared between every closure.
    @MainActor
    @Test(.timeLimit(.minutes(1)))
    func mainActorIsolatedClosuresCanUseNonSendableState() async throws {
        let recorder = Recorder()

        await #expect(throws: (any Swift.Error).self) {
            try await IMAPConnection.withConnection(
                configuration: Self.unreachableConfiguration
            ) { greeting, connection in
                recorder.record("greeting: \(greeting.status)")

                try await connection.send(.noop) { tag, responses in
                    recorder.record("noop: \(tag)")
                    _ = try await responses.forEach { response in
                        recorder.record("response: \(response)")
                    }
                }

                try await connection.sendIdle { tag, responses in
                    recorder.record("idle: \(tag)")
                    for try await response in responses {
                        recorder.record("idle response: \(response)")
                    }
                }

                try await connection.sendAuthenticate(
                    mechanism: .plain,
                    initialResponse: nil
                ) { tag, _, writer in
                    recorder.record("authenticate: \(tag)")
                    try await writer.writeContinuation(ByteBuffer(string: "secret"))
                }

                _ = try await connection.append(to: Self.mailbox) { tag, responses, writer in
                    recorder.record("append: \(tag)")
                    try await writer.write(
                        message: AppendMessage(
                            options: AppendOptions(),
                            data: AppendData(byteCount: 3)
                        )
                    ) { messageWriter in
                        recorder.record("message bytes")
                        try await messageWriter.write(messageBytes: ByteBuffer(string: "abc"))
                    }
                    try await writer.catenate(options: AppendOptions()) { catenateWriter in
                        recorder.record("catenate")
                        try await catenateWriter.writeURL(ByteBuffer(string: "/INBOX;UID=1"))
                    }
                    // Completing the command explicitly is what makes waiting for its tagged
                    // response inside the closure possible.
                    try await writer.finish()
                    return try await responses.waitForCompletion()
                }

                // The two-closure convenience, with the same non-`Sendable` recorder.
                _ = try await connection.append(
                    to: Self.mailbox,
                    writing: { tag, writer in
                        recorder.record("append: \(tag)")
                        try await writer.write(
                            message: AppendMessage(
                                options: AppendOptions(),
                                data: AppendData(byteCount: 3)
                            )
                        ) { messageWriter in
                            try await messageWriter.write(messageBytes: ByteBuffer(string: "abc"))
                        }
                    },
                    reading: { _, responses in
                        try await responses.waitForCompletion()
                    }
                )
            }
        }

        // The connection never came up, so nothing was recorded — the point of the test is
        // that all of the above type-checks against `Recorder`, which is not `Sendable`.
        #expect(recorder.lines.isEmpty)
    }

    /// The same, from a nonisolated context, capturing a mutable local instead.
    @Test(.timeLimit(.minutes(1)))
    func nonisolatedClosuresCanMutateCapturedLocals() async throws {
        var steps: [String] = []

        await #expect(throws: (any Swift.Error).self) {
            try await IMAPConnection.withConnection(
                configuration: Self.unreachableConfiguration
            ) { _, connection in
                steps.append("body")
                try await connection.send(.noop) { _, responses in
                    steps.append("noop")
                    _ = try await responses.waitForCompletion()
                }
            }
        }

        #expect(steps.isEmpty)
    }

    // A closure may also _return_ non-`Sendable` state: it runs in the caller's isolation
    // domain, so what it returns never leaves that domain. Swift 6.0 and 6.1 reject that and
    // require the result to be `Sendable` — see ``_IMAPClosureResult`` — which is why this one
    // is compiled conditionally.
    #if compiler(>=6.2)
    /// Closures return their results into the caller's isolation domain, so a non-`Sendable`
    /// result is fine.
    @Test(.timeLimit(.minutes(1)))
    func closuresCanReturnNonSendableResults() async throws {
        await #expect(throws: (any Swift.Error).self) {
            let recorder = try await IMAPConnection.withConnection(
                configuration: Self.unreachableConfiguration
            ) { _, connection in
                try await connection.send(.noop) { _, responses in
                    let recorder = Recorder()
                    _ = try await responses.waitForCompletion()
                    return recorder
                }
            }
            // Never reached: the connection always fails.
            #expect(recorder.lines.isEmpty)
        }
    }
    #endif

    /// And from a custom actor, whose isolation the closures pick up.
    @Test(.timeLimit(.minutes(1)))
    func actorIsolatedClosuresCanUseActorState() async throws {
        actor Session {
            let recorder = Recorder()

            func run() async throws {
                try await IMAPConnection.withConnection(
                    configuration: IMAPConnectionCompositionTests.unreachableConfiguration
                ) { _, connection in
                    // `recorder` is isolated to `self`, and so is this closure.
                    recorder.record("body")
                    try await connection.send(.noop) { _, responses in
                        _ = try await responses.waitForCompletion()
                    }
                }
            }
        }

        let session = Session()
        await #expect(throws: (any Swift.Error).self) {
            try await session.run()
        }
    }

    /// A `body` that wants concurrency asks for it explicitly — the API doesn't impose it.
    @Test(.timeLimit(.minutes(1)))
    func bodyCanPipelineCommandsInATaskGroup() async throws {
        await #expect(throws: (any Swift.Error).self) {
            try await IMAPConnection.withConnection(
                configuration: Self.unreachableConfiguration
            ) { _, connection in
                try await withThrowingTaskGroup(of: TaggedResponse.self) { group in
                    for command in [Command.noop, .capability] {
                        group.addTask {
                            try await connection.send(command) { _, responses in
                                try await responses.waitForCompletion()
                            }
                        }
                    }
                    return try await group.reduce(into: []) { $0.append($1) }
                }
            }
        }
    }

    /// The same for `append`: reading the command's responses _while_ writing it is the caller's
    /// own task group, with the writer staying in the parent task. The `ResponseStream` is
    /// `Sendable`, the `AppendWriter` is not — and being `inout` it can only be captured by a
    /// non-escaping closure, so this is the one shape that compiles.
    @Test(.timeLimit(.minutes(1)))
    func appendBodyCanReadResponsesWhileWriting() async throws {
        // What crosses into a child task still has to be `Sendable` — only the closures the
        // connection itself calls are relieved of that.
        let responseCount = LockedBox(0)

        await #expect(throws: (any Swift.Error).self) {
            try await IMAPConnection.withConnection(
                configuration: Self.unreachableConfiguration
            ) { _, connection in
                try await connection.append(to: Self.mailbox) { _, responses, writer in
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for try await _ in responses {
                                responseCount.withLock { $0 += 1 }
                            }
                        }
                        try await writer.write(
                            message: AppendMessage(
                                options: AppendOptions(),
                                data: AppendData(byteCount: 3)
                            )
                        ) { messageWriter in
                            try await messageWriter.write(messageBytes: ByteBuffer(string: "abc"))
                        }
                        // Completing the command lets the reader see the tagged response and
                        // finish, so the group can be awaited here.
                        try await writer.finish()
                        try await group.waitForAll()
                    }
                }
            }
        }

        #expect(responseCount.withLock { $0 } == 0)
    }
}
