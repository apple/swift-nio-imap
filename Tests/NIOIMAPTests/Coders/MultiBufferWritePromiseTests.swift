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

import NIO
import NIOIMAP
import NIOIMAPCore
import Testing

/// Holds every write it sees, with its promise, instead of passing it on — so a test decides when
/// each write completes.
private final class WriteHolder: ChannelOutboundHandler {
    typealias OutboundIn = ByteBuffer

    var promises: [EventLoopPromise<Void>?] = []

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        promises.append(promise)
    }
}

/// Whether, and how, a future has completed.
private enum Outcome: Equatable {
    case pending
    case succeeded
    case failed
}

/// Where a future's callback records its outcome. Only touched on the `EmbeddedEventLoop`, which runs
/// on the test's thread.
private final class OutcomeBox: @unchecked Sendable {
    var value = Outcome.pending
}

private struct WriteFailed: Error {}

/// A message the handlers write as several buffers resolves its promise with the last of them.
///
/// Output larger than one `IMAPOutputBuffer` segment is written as one buffer per segment. The
/// caller's promise must not succeed before every buffer has been written, and a failure of any of
/// them must reach it.
@Suite("Multi-buffer write promises")
struct MultiBufferWritePromiseTests {
    /// Encodes to well over one output segment, without a literal.
    private static let largeCommand = CommandStreamPart.tagged(
        TaggedCommand(tag: "A1", command: .search(key: .and(Array(repeating: .draft, count: 20_000))))
    )

    /// Encodes to well over one output segment.
    private static let largeResponse = Response.untagged(
        .mailboxData(.search((1...30_000).map { UnknownMessageIdentifier(integerLiteral: UInt32($0)) }))
    )

    private enum Direction {
        case client
        case server
    }

    /// Writes one large message through the handler for `direction`, and returns the promises of the
    /// writes it produced together with the outcome of the caller's future.
    private func writeLarge(
        _ direction: Direction
    ) throws -> (channel: EmbeddedChannel, writes: WriteHolder, outcome: () -> Outcome) {
        let holder = WriteHolder()
        let channel: EmbeddedChannel
        let future: EventLoopFuture<Void>
        switch direction {
        case .client:
            channel = EmbeddedChannel(handlers: [holder, IMAPClientHandler()])
            channel.pipeline.fireChannelActive()
            future = channel.writeAndFlush(IMAPClientHandler.Message.part(Self.largeCommand))
        case .server:
            channel = EmbeddedChannel(handlers: [holder, IMAPServerHandler()])
            channel.pipeline.fireChannelActive()
            future = channel.writeAndFlush(Self.largeResponse)
        }
        let outcome = OutcomeBox()
        future.whenComplete { result in
            switch result {
            case .success: outcome.value = .succeeded
            case .failure: outcome.value = .failed
            }
        }
        try #require(holder.promises.count > 1, "the message should be written as several buffers")
        return (channel, holder, { outcome.value })
    }

    @Test("the promise succeeds only after the last buffer is written", arguments: [Direction.client, .server])
    private func succeedsAfterLastBuffer(direction: Direction) throws {
        let (channel, writes, outcome) = try writeLarge(direction)
        defer { _ = try? channel.finish() }

        for promise in writes.promises.dropLast() {
            promise?.succeed()
            #expect(outcome() == .pending)
        }
        writes.promises.last??.succeed()
        #expect(outcome() == .succeeded)
    }

    @Test("a failed buffer fails the promise", arguments: [Direction.client, .server])
    private func failsWhenAnEarlierBufferFails(direction: Direction) throws {
        let (channel, writes, outcome) = try writeLarge(direction)
        defer { _ = try? channel.finish() }

        writes.promises.first??.fail(WriteFailed())
        #expect(outcome() == .failed)
        for promise in writes.promises.dropFirst() {
            promise?.succeed()
        }
        #expect(outcome() == .failed)
    }
}
