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
import Synchronization

// MARK: - Shared state

/// A `Sendable` reference wrapper around a `Mutex`.
///
/// A `Mutex` is non-copyable, so a closure that uses one captures the *enclosing scope's*
/// binding by reference. Swift 6.4 accepts that for the `sending` closures
/// `TaskGroup.addTask` takes, but earlier compilers reject it as a potential data race —
/// even though the mutex is what makes the access safe in the first place. Boxing the mutex
/// in a class gives such a closure a copyable reference to capture instead.
final class LockedBox<Value: Sendable>: Sendable {
    private let storage: Mutex<Value>

    init(_ initialValue: Value) {
        self.storage = Mutex(initialValue)
    }

    @discardableResult
    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        try self.storage.withLock { try body(&$0) }
    }
}

// MARK: - Timeout support

/// A one-shot async gate.
///
/// Used to race an operation against a timeout *without* structured `await`-ing the
/// operation task. If the operation stalls on a non-cancellable continuation (which is
/// exactly what the connection-lifecycle bugs cause), a structured `withTaskGroup`
/// timeout would itself stall on scope exit while awaiting the stuck child. This gate
/// lets a stalled operation surface as a deterministic test failure instead of freezing
/// the whole suite.
actor CompletionGate {
    private var resolved: Bool?
    private var waiters: [CheckedContinuation<Bool, Never>] = []

    func resolve(_ value: Bool) {
        guard resolved == nil else { return }
        resolved = value
        for w in waiters {
            w.resume(returning: value)
        }
        waiters = []
    }

    func wait() async -> Bool {
        if let resolved { return resolved }
        // Waiting is cancellation-aware so that a caller which is itself timed out (e.g.
        // by swift-testing's `.timeLimit`) can never be left parked here forever, which
        // would stall the whole test process rather than fail a single test.
        return await withTaskCancellationHandler {
            await withCheckedContinuation { c in
                // `onCancel` may have resolved the gate before the continuation was
                // installed, so re-check instead of parking unconditionally.
                if let resolved {
                    c.resume(returning: resolved)
                } else {
                    waiters.append(c)
                }
            }
        } onCancel: {
            Task { await self.resolve(false) }
        }
    }
}

/// Runs `operation` and returns `true` if it finished within `seconds`, `false` if it
/// timed out (i.e. stalled).
///
/// The operation runs in an unstructured task. On timeout that task is cancelled and
/// abandoned — if it is stuck on a non-cancellable continuation it will leak, which is
/// acceptable for a bug-reproduction test that would otherwise stall forever.
///
/// - Important: `seconds` is a *wall-clock* budget for detecting a deadlock, not a
///   performance assertion. The rest of the test suite runs in parallel on the same
///   cooperative thread pool, so on a busy or CPU-starved machine (a CI container with
///   few cores) these tasks can be left unscheduled for many seconds at a time. The
///   clock therefore only starts once `operation` actually begins running, and the
///   budget is deliberately generous: the operations under test need milliseconds of
///   work, so anything close to the budget is a stall, whereas a tight budget only
///   produces spurious failures. Keep the budget well below the enclosing `.timeLimit`
///   so this gate — and not the test harness — is what reports a stall.
func finishesWithoutStalling(
    within seconds: Double = 60,
    _ operation: @escaping @Sendable () async -> Void
) async -> Bool {
    let gate = CompletionGate()
    let started = CompletionGate()
    let work = Task {
        await started.resolve(true)
        await operation()
        await gate.resolve(true)
    }
    let timer = Task {
        _ = await started.wait()
        try? await Task.sleep(for: .seconds(seconds))
        await gate.resolve(false)
    }
    let finished = await gate.wait()
    work.cancel()
    timer.cancel()
    return finished
}

// MARK: - Loopback server

/// A minimal TCP server on `127.0.0.1` used to exercise `IMAPConnection`'s lifecycle
/// without a real IMAP server.
///
/// - Note: Binding a socket fails in sandboxed environments. These tests are intended
///   to be run manually where sockets are available.
final class LoopbackServer {
    let channel: Channel
    private let group: MultiThreadedEventLoopGroup

    private init(channel: Channel, group: MultiThreadedEventLoopGroup) {
        self.channel = channel
        self.group = group
    }

    var port: UInt16 {
        UInt16(channel.localAddress?.port ?? 0)
    }

    /// Starts a server that sends an IMAP greeting on connect and then closes the
    /// connection (a graceful EOF) as soon as the client sends its first command —
    /// without ever sending a tagged response.
    static func greetThenCloseOnFirstCommand() async throws -> LoopbackServer {
        try await start { GreetThenCloseHandler() }
    }

    /// Starts a server that sends an IMAP greeting on connect and then stays open,
    /// ignoring anything the client sends and never replying. The connection only
    /// closes when the client closes it.
    static func greetThenStayOpen() async throws -> LoopbackServer {
        try await start { GreetAndStayOpenHandler() }
    }

    private static func start(
        _ makeHandler: @escaping @Sendable () -> any ChannelInboundHandler
    ) async throws -> LoopbackServer {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let channel = try await ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 16)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(makeHandler())
                }
            }
            .bind(host: "127.0.0.1", port: 0)
            .get()
        return LoopbackServer(channel: channel, group: group)
    }

    /// Synchronously tears the server down. Safe to call from a test's `defer`.
    func shutdown() {
        try? channel.close().wait()
        try? group.syncShutdownGracefully()
    }
}

/// Writes an IMAP greeting on `channelActive`, then closes the connection on the first
/// inbound read (the client's first command), producing a graceful EOF for the client.
private final class GreetThenCloseHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    func channelActive(context: ChannelHandlerContext) {
        var buffer = context.channel.allocator.buffer(capacity: 64)
        buffer.writeString("* OK [CAPABILITY IMAP4rev1] Loopback test server ready\r\n")
        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
        context.fireChannelActive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // The client has sent its first command. Close without replying so the client
        // observes an end-of-stream while it is still awaiting the tagged response.
        context.close(promise: nil)
    }
}

/// Writes an IMAP greeting on `channelActive`, then stays open, ignoring all inbound
/// data and never replying.
private final class GreetAndStayOpenHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    func channelActive(context: ChannelHandlerContext) {
        var buffer = context.channel.allocator.buffer(capacity: 64)
        buffer.writeString("* OK [CAPABILITY IMAP4rev1] Loopback test server ready\r\n")
        context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
        context.fireChannelActive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // Ignore everything the client sends; stay open until the client disconnects.
    }
}
