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

/// Tests for the command stream an `APPEND` produces.
///
/// These drive `OutboundQueue` and `IMAPConnection.AppendWriter` against a testing writer, so
/// they need no socket and no server.
@Suite("APPEND writer", .timeLimit(.minutes(1)))
enum AppendWriterTests {
    static let mailbox = MailboxName(Array("INBOX".utf8))

    static let message = AppendMessage(
        options: AppendOptions(),
        data: AppendData(byteCount: 3)
    )

    /// The happy path: `.start` and `.finish` bracket the message the closure writes.
    @Test
    static func appendBracketsTheMessageWithStartAndFinish() async throws {
        let result = await runAppend(expectedPartCount: 5) { writer in
            try await writer.write(message: message) { messageWriter in
                try await messageWriter.write(messageBytes: ByteBuffer(string: "abc"))
            }
        }

        #expect(result.error == nil)
        #expect(
            result.parts == [
                .part(.append(.start(tag: "A1", appendingTo: mailbox))),
                .part(.append(.beginMessage(message: message))),
                .part(.append(.messageBytes(ByteBuffer(string: "abc")))),
                .part(.append(.endMessage)),
                .part(.append(.finish)),
            ]
        )
    }

    /// A closure that writes no message can not produce a valid `APPEND`: `.finish` is only
    /// legal after at least one message. Rather than writing it — which traps in the client
    /// state machine — the writer throws.
    @Test
    static func appendWithoutAMessageThrowsInsteadOfWritingFinish() async throws {
        let result = await runAppend(expectedPartCount: 1) { _ in
            // Write nothing at all.
        }

        #expect(result.error as? IMAPConnection.IncompleteAppend == .init(reason: .noMessage))
        // Only the command itself was written; no `.finish`.
        #expect(result.parts == [.part(.append(.start(tag: "A1", appendingTo: mailbox)))])
    }

    /// A closure that throws part-way through leaves the command unfinished: `.finish` must not
    /// be written, and the error is propagated.
    @Test
    static func appendClosureErrorPropagatesWithoutFinishing() async throws {
        struct WriterError: Swift.Error {}

        let result = await runAppend(expectedPartCount: 2) { writer in
            try await writer.write(message: message) { _ in
                throw WriterError()
            }
        }

        #expect(result.error is WriterError)
        #expect(
            result.parts == [
                .part(.append(.start(tag: "A1", appendingTo: mailbox))),
                .part(.append(.beginMessage(message: message))),
            ]
        )
    }

    /// Swallowing a mid-message failure must not let the command be completed: `.finish` after
    /// a half-written message traps in the client state machine.
    @Test
    static func swallowedMidMessageErrorStillFailsTheAppend() async throws {
        struct WriterError: Swift.Error {}

        let result = await runAppend(expectedPartCount: 2) { writer in
            try? await writer.write(message: message) { _ in
                throw WriterError()
            }
        }

        #expect(result.error as? IMAPConnection.IncompleteAppend == .init(reason: .unfinishedMessage))
        #expect(
            result.parts == [
                .part(.append(.start(tag: "A1", appendingTo: mailbox))),
                .part(.append(.beginMessage(message: message))),
            ]
        )
    }

    /// … and nothing more can be written after such a failure, either.
    @Test
    static func writingAfterAnUnfinishedMessageThrows() async throws {
        struct WriterError: Swift.Error {}

        let secondWriteError = Mutex<(any Swift.Error)?>(nil)
        let result = await runAppend(expectedPartCount: 2) { writer in
            try? await writer.write(message: message) { _ in
                throw WriterError()
            }
            do {
                try await writer.write(message: message) { messageWriter in
                    try await messageWriter.write(messageBytes: ByteBuffer(string: "abc"))
                }
            } catch {
                secondWriteError.withLock { $0 = error }
            }
        }

        #expect(
            secondWriteError.withLock { $0 } as? IMAPConnection.IncompleteAppend
                == .init(reason: .unfinishedMessage),
            "Writing another message after an unfinished one must fail rather than emit invalid data."
        )
        #expect(result.error as? IMAPConnection.IncompleteAppend == .init(reason: .unfinishedMessage))
        // The second message was never begun.
        #expect(
            result.parts == [
                .part(.append(.start(tag: "A1", appendingTo: mailbox))),
                .part(.append(.beginMessage(message: message))),
            ]
        )
    }

    /// `CATENATE` needs at least one URL or one piece of data.
    @Test
    static func emptyCatenateThrows() async throws {
        let result = await runAppend(expectedPartCount: 2) { writer in
            try await writer.catenate(options: AppendOptions()) { _ in
                // Add nothing.
            }
        }

        #expect(result.error as? IMAPConnection.IncompleteAppend == .init(reason: .noMessage))
        #expect(
            result.parts == [
                .part(.append(.start(tag: "A1", appendingTo: mailbox))),
                .part(.append(.beginCatenate(options: AppendOptions()))),
            ]
        )
    }

    /// A catenated message of a URL and some data is bracketed just like a plain message.
    @Test
    static func catenateWritesURLsAndData() async throws {
        let result = await runAppend(expectedPartCount: 8) { writer in
            try await writer.catenate(options: AppendOptions()) { catenateWriter in
                try await catenateWriter.writeURL(ByteBuffer(string: "/INBOX;UID=1"))
                try await catenateWriter.writeData(byteCount: 3) { dataWriter in
                    try await dataWriter.write(ByteBuffer(string: "abc"))
                }
            }
        }

        #expect(result.error == nil)
        #expect(
            result.parts == [
                .part(.append(.start(tag: "A1", appendingTo: mailbox))),
                .part(.append(.beginCatenate(options: AppendOptions()))),
                .part(.append(.catenateURL(ByteBuffer(string: "/INBOX;UID=1")))),
                .part(.append(.catenateData(.begin(size: 3)))),
                .part(.append(.catenateData(.bytes(ByteBuffer(string: "abc"))))),
                .part(.append(.catenateData(.end))),
                .part(.append(.endCatenate)),
                .part(.append(.finish)),
            ]
        )
    }

    // MARK: - `finish()`

    /// Finishing explicitly — which is what a closure has to do before it can wait for the
    /// command's tagged response — writes `.finish` there, and the implicit finish afterwards
    /// is a no-op rather than a second `.finish`.
    @Test
    static func explicitFinishIsIdempotent() async throws {
        let result = await runAppend(expectedPartCount: 5) { writer in
            try await writer.write(message: message) { messageWriter in
                try await messageWriter.write(messageBytes: ByteBuffer(string: "abc"))
            }
            try await writer.finish()
            try await writer.finish()
        }

        #expect(result.error == nil)
        #expect(result.didComplete)
        #expect(result.parts.filter { $0 == .part(.append(.finish)) }.count == 1)
    }

    /// Writing more data after finishing would be a protocol violation.
    @Test
    static func writingAfterFinishThrows() async throws {
        let secondWriteError = Mutex<(any Swift.Error)?>(nil)
        let result = await runAppend(expectedPartCount: 5) { writer in
            try await writer.write(message: message) { messageWriter in
                try await messageWriter.write(messageBytes: ByteBuffer(string: "abc"))
            }
            try await writer.finish()
            do {
                try await writer.write(message: message) { _ in }
            } catch {
                secondWriteError.withLock { $0 = error }
            }
        }

        #expect(secondWriteError.withLock { $0 } is IMAPConnection.AppendAlreadyFinished)
        #expect(result.error == nil)
        #expect(result.didComplete)
        #expect(result.parts.last == .part(.append(.finish)))
    }

    /// An error thrown _after_ the command was completed reports the command as complete, so
    /// that `append` rethrows it without closing the connection.
    @Test
    static func errorAfterFinishStillCompletesTheCommand() async throws {
        struct HandlerError: Swift.Error {}

        let result = await runAppend(expectedPartCount: 5) { writer in
            try await writer.write(message: message) { messageWriter in
                try await messageWriter.write(messageBytes: ByteBuffer(string: "abc"))
            }
            try await writer.finish()
            throw HandlerError()
        }

        #expect(result.error is HandlerError)
        #expect(result.didComplete, "The command was written in full, so the connection stays usable.")
    }

    /// … whereas an error before that reports it as incomplete.
    @Test
    static func errorBeforeFinishLeavesTheCommandIncomplete() async throws {
        struct WriterError: Swift.Error {}

        let result = await runAppend(expectedPartCount: 4) { writer in
            try await writer.write(message: message) { messageWriter in
                try await messageWriter.write(messageBytes: ByteBuffer(string: "abc"))
            }
            throw WriterError()
        }

        #expect(result.error is WriterError)
        #expect(!result.didComplete)
        #expect(result.parts.contains(.part(.append(.finish))) == false)
    }

    // MARK: - Helper

    /// Runs `body` as the closure of an `APPEND` on a queue backed by a testing writer, and
    /// returns the parts that reached the writer along with the error `body` produced, if any.
    ///
    /// `expectedPartCount` is how many parts the collector waits for before it stops; the
    /// queue's writes only complete once the runner has handed them to the writer, so all
    /// parts have been produced by the time `body` returns.
    private static func runAppend(
        expectedPartCount: Int,
        _ body: (inout IMAPConnection.AppendWriter) async throws -> Void
    ) async -> (parts: [IMAPClientHandler.OutboundIn], error: (any Swift.Error)?, didComplete: Bool) {
        let (outbound, sink) = NIOAsyncChannelOutboundWriter<IMAPClientHandler.OutboundIn>.makeTestingWriter()
        let queue = OutboundQueue()
        let parts = Mutex<[IMAPClientHandler.OutboundIn]>([])
        let thrownError = Mutex<(any Swift.Error)?>(nil)
        var didCompleteCommand = false

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await queue.run(outbound: outbound)
            }

            group.addTask {
                var collected = 0
                for await part in sink {
                    parts.withLock { $0.append(part) }
                    collected += 1
                    guard collected < expectedPartCount else { break }
                }
            }

            // The append itself runs here, in the parent task: `body` is non-escaping.
            do {
                try await queue.withAppendWriter { (writer: consuming OutboundQueue.AppendQueueWriter) in
                    try await IMAPConnection.AppendWriter.withAppendWriter(
                        tag: "A1",
                        appendingTo: mailbox,
                        underlying: writer,
                        didCompleteCommand: &didCompleteCommand
                    ) { appendWriter in
                        try await body(&appendWriter)
                    }
                }
            } catch {
                thrownError.withLock { $0 = error }
            }
            queue.close()
        }

        return (parts.withLock { $0 }, thrownError.withLock { $0 }, didCompleteCommand)
    }
}
