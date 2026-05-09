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
import Synchronization

/// Manages the outbound part of the connection.
///
/// Coordinates sending commands to the server via a ``CommandStreamPartQueue``.
/// During an `APPEND` operation, all other writes are paused until the append completes.
final class OutboundQueue: Sendable {
    fileprivate let state = Mutex(State.normal(CommandStreamPartQueue()))

    init() {}

    fileprivate enum State {
        case normal(CommandStreamPartQueue)
        case runningAppend(Append)

        /// The state during an active `APPEND` operation.
        ///
        /// Only the ``IMAPConnection/AppendWriter`` can write to the queue. All other writes
        /// are held in the `pending` list until the append completes.
        struct Append {
            var queue: CommandStreamPartQueue
            var pending: [Pending]

            enum Pending {
                case write(CommandStreamPartQueue.PendingItem)
                case append(CheckedContinuation<_AppendWriter, any Swift.Error>)
            }
        }
    }
}

// MARK: - Run

extension OutboundQueue {
    func run(outbound: NIOAsyncChannelOutboundWriter<IMAPClientHandler.OutboundIn>) async throws {
        while let next = try await nextOutboundOut() {
            try await outbound.write(contentsOf: next.payload)
            for c in next.completions {
                c.resume()
            }
        }
    }
}

// MARK: - Close

extension OutboundQueue {
    func close() {
        state.withLock { state in
            state.close()
        }.run()
    }
}

extension OutboundQueue.State {
    /// Closes the underlying queue and, when an `APPEND` is in flight, also fails every
    /// operation parked in `pending` (regular writes and queued appends).
    ///
    /// Otherwise those continuations would be orphaned: `finishAppend()` only drains
    /// `pending` when the in-flight append completes, which never happens once the
    /// connection is torn down.
    mutating func close() -> CloseAction {
        switch self {
        case .normal(var queue):
            let queueAction = queue.close()
            self = .normal(queue)
            return CloseAction(queue: queueAction, pending: [])
        case .runningAppend(var append):
            let queueAction = append.queue.close()
            let pending = append.pending
            append.pending = []
            // Drop back to `.normal` (with the now-closed queue) so any later writes
            // fail fast rather than parking in a `pending` list nobody drains.
            self = .normal(append.queue)
            return CloseAction(queue: queueAction, pending: pending)
        }
    }

    struct CloseAction {
        var queue: CommandStreamPartQueue.CloseAction
        var pending: [OutboundQueue.State.Append.Pending]

        func run() {
            queue.run()
            for item in pending {
                switch item {
                case .write(let pendingItem):
                    pendingItem.completion.resume(throwing: CommandStreamPartQueue.DidClose())
                case .append(let continuation):
                    continuation.resume(throwing: OutboundQueue.Error.inFailedState)
                }
            }
        }
    }
}

// MARK: - Next `OutboundOut`

extension OutboundQueue {
    func nextOutboundOut() async throws -> CommandStreamPartQueue.Next? {
        let next = try await withCheckedThrowingContinuation { continuation in
            state.withLock {
                $0.nextOutboundOut(continuation)
            }.run()
        }
        return next
    }
}

extension OutboundQueue.State {
    mutating func nextOutboundOut(
        _ continuation: CheckedContinuation<CommandStreamPartQueue.Next?, any Swift.Error>
    ) -> CommandStreamPartQueue.NextAction {
        withQueue { queue in
            return queue.next(continuation)
        }
    }

    mutating func withQueue<R>(
        _ closure: (inout CommandStreamPartQueue) -> R
    ) -> R {
        switch self {
        case .normal(var queue):
            let r = closure(&queue)
            self = .normal(queue)
            return r
        case .runningAppend(var append):
            let r = closure(&append.queue)
            self = .runningAppend(append)
            return r
        }
    }
}

// MARK: - Encoding Options

extension OutboundQueue {
    func setEncodingOptions(
        _ new: IMAPClientHandler.EncodingOptions
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            state.withLock {
                $0.setEncodingOptions(new, completion: continuation)
            }.run()
        }
    }
}

extension OutboundQueue.State {
    mutating func setEncodingOptions(
        _ new: IMAPClientHandler.EncodingOptions,
        completion: CheckedContinuation<Void, any Swift.Error>
    ) -> CommandStreamPartQueue.WriteAction {
        write(
            [.setEncodingOptions(new)],
            completion: completion
        )
    }
}

// MARK: - Write (regular) Command

extension OutboundQueue {
    func write(
        _ command: TaggedCommand
    ) async throws {
        try await write(CollectionOfOne(command))
    }

    func write(
        _ commands: some Sequence<TaggedCommand>
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            state.withLock {
                $0.write(commands, completion: continuation)
            }.run()
        }
    }

    func writeIdleDone() async throws {
        try await withCheckedThrowingContinuation { continuation in
            state.withLock {
                $0.writeIdleDone(completion: continuation)
            }.run()
        }
    }
}

extension OutboundQueue.State {
    mutating func writeIdleDone(
        completion: CheckedContinuation<Void, any Swift.Error>
    ) -> CommandStreamPartQueue.WriteAction {
        write(
            [IMAPClientHandler.OutboundIn.part(.idleDone)],
            completion: completion
        )
    }

    mutating func write(
        _ commands: some Sequence<TaggedCommand>,
        completion: CheckedContinuation<Void, any Swift.Error>
    ) -> CommandStreamPartQueue.WriteAction {
        write(
            commands.map {
                .part(.tagged($0))
            },
            completion: completion
        )
    }

    mutating func write(
        _ parts: [IMAPClientHandler.OutboundIn],
        completion: CheckedContinuation<Void, any Swift.Error>
    ) -> CommandStreamPartQueue.WriteAction {
        switch self {
        case .normal(var queue):
            let action = queue.write(
                payload: parts,
                continuation: completion
            )
            self = .normal(queue)
            return action
        case .runningAppend(var append):
            append.pending.append(
                .write(
                    .init(
                        payload: parts,
                        completion: completion
                    )
                )
            )
            self = .runningAppend(append)
            return .none
        }
    }
}

// MARK: - Write Continuation Data (during authentication)

extension OutboundQueue {
    func writeContinuationResponse(
        _ bytes: ByteBuffer
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            state.withLock {
                $0.write([.part(.continuationResponse(bytes))], completion: continuation)
            }.run()
        }
    }
}

// MARK: - APPEND

extension OutboundQueue {
    fileprivate struct _AppendWriter {}

    /// A writer for sending ``AppendCommand`` values during an `APPEND` operation.
    ///
    /// Writes append command parts into the ``OutboundQueue``.
    struct AppendQueueWriter: ~Copyable {
        fileprivate let queue: OutboundQueue

        fileprivate init(
            writer: _AppendWriter,
            queue: OutboundQueue
        ) {
            self.queue = queue
        }

        func write(
            _ parts: [AppendCommand]
        ) async throws {
            try await withCheckedThrowingContinuation { continuation in
                queue.state.withLock {
                    $0.writeAppend(
                        parts: parts,
                        continuation: continuation
                    )
                }.run()
            }
        }
    }

    func withAppendWriter<R>(
        _ closure: (consuming AppendQueueWriter) async throws -> R
    ) async throws -> R {
        // Try to create a writer:
        let writer = try await AppendQueueWriter(
            writer: makeAppendWriter(),
            queue: self
        )
        let result: Result<R, any Swift.Error>
        do {
            result = .success(try await closure(writer))
        } catch {
            result = .failure(error)
        }
        await finishAppend()
        return try result.get()
    }
}

extension OutboundQueue.State {
    mutating func writeAppend(
        parts: [AppendCommand],
        continuation: CheckedContinuation<Void, any Swift.Error>
    ) -> CommandStreamPartQueue.WriteAction {
        switch self {
        case .normal:
            // We _must_ be in the `.runningAppend` state
            // at this point since the lifetime of the
            // AppendQueueWriter is managed as such.
            return .failWrite(continuation, .tryingToAppendButNotInWritingAppendState)
        case .runningAppend(var append):
            defer {
                self = .runningAppend(append)
            }
            return append.queue.write(
                payload: parts.map { .part(.append($0)) },
                continuation: continuation
            )
        }
    }
}

extension OutboundQueue {
    fileprivate func makeAppendWriter() async throws -> _AppendWriter {
        try await withCheckedThrowingContinuation { continuation in
            let action = state.withLock {
                $0.makeAppendWriter(continuation)
            }
            switch action {
            case .none:
                break
            case .resumeContinuation:
                continuation.resume(with: .success(_AppendWriter()))
            case .failContinuation:
                continuation.resume(throwing: OutboundQueue.Error.inFailedState)
            }
        }
    }

    fileprivate func finishAppend() async {
        state.withLock {
            $0.finishAppend()
        }.run()
    }
}

extension OutboundQueue.State {
    enum MakeAppendWriterAction {
        case none
        case resumeContinuation
        case failContinuation
    }

    mutating func makeAppendWriter(
        _ continuation: CheckedContinuation<OutboundQueue._AppendWriter, any Swift.Error>
    ) -> MakeAppendWriterAction {
        switch self {
        case .normal(let queue):
            switch queue.writeState {
            case .failed, .closed:
                return .failContinuation
            case .writing:
                self = .runningAppend(
                    Append(
                        queue: queue,
                        pending: []
                    )
                )
                return .resumeContinuation
            }
        case .runningAppend(var append):
            append.pending.append(.append(continuation))
            self = .runningAppend(append)
            return .none
        }
    }

    enum FinishAppendAction {
        case drainActions([OutboundQueue.State.Append.DrainAction])

        func run() {
            switch self {
            case .drainActions(let actions):
                for a in actions {
                    a.run()
                }
            }
        }
    }

    mutating func finishAppend() -> FinishAppendAction {
        switch self {
        case .normal:
            // Defensive: the `AppendQueueWriter` lifetime should guarantee we're
            // in `.runningAppend` here. If not, there's nothing to drain.
            return .drainActions([])
        case .runningAppend(let append):
            // We now attempt to drain the pending queue
            let (new, actions) = append.drainPending()
            self = new
            return .drainActions(actions)
        }
    }
}

extension OutboundQueue.State.Append {
    fileprivate enum DrainAction {
        case none
        case resumeNewAppend(CheckedContinuation<OutboundQueue._AppendWriter, any Swift.Error>)
        case writeAction(CommandStreamPartQueue.WriteAction)

        func run() {
            switch self {
            case .none:
                break
            case .resumeNewAppend(let continuation):
                continuation.resume(returning: .init())
            case .writeAction(let writeAction):
                writeAction.run()
            }
        }
    }

    /// Moves pending items into the ``CommandStreamPartQueue``.
    ///
    /// Returns a `.normal` state if all items are writes.
    /// Stops and returns a new `.runningAppend` state upon encountering a pending append.
    fileprivate func drainPending() -> (OutboundQueue.State, [DrainAction]) {
        var actions: [DrainAction] = []
        var queue = self.queue
        var remaining = pending[...]
        while let r = remaining.popFirst() {
            switch r {
            case .write(let item):
                actions.append(.writeAction(queue.write(item: item)))
            case .append(let appendContinuation):
                // There’a a pending append. We'll return this and stop
                // moving items into the queue.
                actions.append(.resumeNewAppend(appendContinuation))
                return (
                    .runningAppend(
                        .init(
                            queue: queue,
                            pending: Array(remaining)
                        )
                    ),
                    actions
                )
            }
        }
        // We’ve (completely) drained the pending queue.
        // Go back into `.normal` state:
        return (
            .normal(queue),
            actions
        )
    }
}

// MARK: - Error

extension OutboundQueue {
    enum Error: Swift.Error {
        case inFailedState
        case tryingToAppendButNotInWritingAppendState
        case calledNextRecursively
    }
}
