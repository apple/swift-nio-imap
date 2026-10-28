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

import DequeModule
import NIO
import NIOIMAP

/// A back-pressured queue of command stream parts flowing toward the channel’s outbound writer.
///
/// Writers push parts into this queue, and the outbound runner pops them for writing to the channel.
struct CommandStreamPartQueue: Sendable {
    var writeState: WriteState = .writing([])
    var readState: ReadState = .idle

    enum WriteState {
        case closed
        case failed
        case writing(Deque<PendingItem>)
    }

    /// The `run(outbound:)` / `next()` method uses this to mark that it is waiting for more
    /// data in the `InboundState`.
    enum ReadState: Sendable {
        case idle
        /// When adding items to `pending`, if we’re in this state, run the continuation.
        case waitingForItem(CheckedContinuation<Next?, any Swift.Error>)
    }
}

extension CommandStreamPartQueue {
    /// An item waiting to be written to the outbound writer.
    struct PendingItem: Sendable {
        var payload: [IMAPClientHandler.OutboundIn]
        var completion: CheckedContinuation<Void, any Swift.Error>
    }

    /// An item popped from the queue, ready to be written to the outbound writer.
    ///
    /// Run the `completions` after the write finishes.
    struct Next: Sendable {
        var payload: [IMAPClientHandler.OutboundIn]
        var completions: [CheckedContinuation<Void, any Swift.Error>]
    }
}

// MARK: Close

extension CommandStreamPartQueue {
    struct CloseAction {
        var writeCompletions: [CheckedContinuation<Void, any Swift.Error>]
        var pendingRead: CheckedContinuation<Next?, any Swift.Error>?

        func run() {
            for c in writeCompletions {
                c.resume(throwing: DidClose())
            }
            pendingRead?.resume(returning: nil)
        }
    }

    struct DidClose: Swift.Error {}

    mutating func close() -> CloseAction {
        let pendingWrites: Deque<PendingItem>?

        switch writeState {
        case .closed:
            pendingWrites = nil
        case .failed:
            writeState = .closed
            pendingWrites = nil
        case .writing(let p):
            // Must end up `.closed`: the pending items' completions are failed below, so
            // leaving them in a `.writing` deque would let `next()` pop them and resume
            // the same continuations a second time. It also makes any later `write()`
            // park in a queue nobody drains instead of failing fast.
            writeState = .closed
            pendingWrites = p
        }

        let pendingRead: CheckedContinuation<Next?, any Swift.Error>?
        switch readState {
        case .idle:
            pendingRead = nil
        case .waitingForItem(let p):
            pendingRead = p
        }
        readState = .idle

        return CloseAction(
            writeCompletions: pendingWrites?.reduce(into: []) {
                $0.append($1.completion)
            } ?? [],
            pendingRead: pendingRead
        )
    }
}

// MARK: - Pop & Merge

extension Deque<CommandStreamPartQueue.PendingItem> {
    /// Pops pending items from the deque, merging small items up to a target write weight.
    ///
    /// Always pops at least one complete item. Continues merging while
    /// the total weight stays below the target.
    mutating func popAndMerge(
        weightTarget: WriteWeight = WriteWeight(2 * 1_400)
    ) -> CommandStreamPartQueue.Next? {
        // We will always pop the complete, first item:
        guard
            let item = popFirst()
        else { return nil }
        var result = CommandStreamPartQueue.Next(
            payload: item.payload,
            completions: [item.completion]
        )
        var totalWeight: WriteWeight = result.payload.reduce(into: WriteWeight(0)) {
            $0 += $1.writeWeight
        }
        // We’ll then continue appending `parts` until we’ve
        // reached the desired weight.
        while var next = self.popFirst() {
            result.moveParts(
                from: &next.payload,
                totalWeight: &totalWeight,
                weightTarget: weightTarget
            )
            // If there’s nothing left in `next`, add the
            // completion continuation. Otherwise, write it back.
            guard
                next.payload.isEmpty
            else {
                self.prepend(next)
                break
            }
            result.completions.append(next.completion)
        }
        return result
    }
}

extension CommandStreamPartQueue.Next {
    mutating func moveParts(
        from payload: inout [IMAPClientHandler.OutboundIn],
        totalWeight: inout WriteWeight,
        weightTarget: WriteWeight
    ) {
        Self.merge(
            next: &self,
            payload: &payload,
            totalWeight: &totalWeight,
            weightTarget: weightTarget
        )
    }

    /// Moves parts from the given payload into `next` while the total weight stays below the target.
    static func merge(
        next: inout CommandStreamPartQueue.Next,
        payload: inout [IMAPClientHandler.OutboundIn],
        totalWeight: inout WriteWeight,
        weightTarget: WriteWeight
    ) {
        var remaining = payload[...]

        while let part = remaining.first {
            let weight = part.writeWeight
            guard
                totalWeight + weight < weightTarget
            else { break }
            _ = remaining.removeFirst()
            totalWeight += weight
        }

        // Now move the payload from `payload` to `next`:
        next.payload.append(contentsOf: payload[payload.startIndex..<remaining.startIndex])
        payload = Array(remaining)
    }
}

// MARK: `next()`

extension CommandStreamPartQueue {
    enum NextAction {
        case none
        case resumeContinuation(CheckedContinuation<Next?, any Swift.Error>, Result<Next?, OutboundQueue.Error>)

        func run() {
            switch self {
            case .none:
                break
            case .resumeContinuation(let continuation, let result):
                continuation.resume(with: result)
            }
        }
    }

    mutating func next(
        _ continuation: CheckedContinuation<Next?, any Swift.Error>
    ) -> NextAction {
        guard
            case .idle = readState
        else {
            // `run(outbound:)` calls this serially, so we should always be
            // `.idle` here. Fail the continuation rather than trapping if that
            // invariant is ever violated.
            return .resumeContinuation(continuation, .failure(.calledNextRecursively))
        }

        switch writeState {
        case .closed:
            return .resumeContinuation(continuation, .success(nil))
        case .failed:
            return .resumeContinuation(continuation, .failure(.inFailedState))
        case .writing(var items):
            // Pop the first item
            guard
                let item = items.popAndMerge()
            else {
                readState = .waitingForItem(continuation)
                return .none
            }
            // Copy-on-write exclusivity dance: assigning the payload-free `.failed`
            // case first drops `self`'s reference to the deque, so `items` is uniquely
            // referenced when it is stored back and no copy-on-write copy is made.
            writeState = .failed
            writeState = .writing(items)
            return .resumeContinuation(continuation, .success(.some(item)))
        }
    }
}

// MARK: `write()`

extension CommandStreamPartQueue {
    enum WriteAction {
        case none
        case failWrite(CheckedContinuation<Void, any Swift.Error>, OutboundQueue.Error)
        /// The `next()` function is waiting. Complete its continuation with the new data.
        case resumeNext(CheckedContinuation<CommandStreamPartQueue.Next?, any Swift.Error>, CommandStreamPartQueue.Next)

        func run() {
            switch self {
            case .none:
                break
            case .failWrite(let completion, let error):
                completion.resume(throwing: error)
            case .resumeNext(let nextContinuation, let next):
                nextContinuation.resume(returning: next)
            }
        }
    }

    mutating func write(
        payload: [IMAPClientHandler.OutboundIn],
        continuation: CheckedContinuation<Void, any Swift.Error>
    ) -> WriteAction {
        write(
            item: PendingItem(
                payload: payload,
                completion: continuation
            )
        )
    }

    mutating func write(
        item: PendingItem
    ) -> WriteAction {
        switch writeState {
        case .failed, .closed:
            return .failWrite(item.completion, .inFailedState)
        case .writing(var pending):
            pending.append(item)

            // Check if `nextOutboundOut` is currently waiting for more items:
            let action: WriteAction
            switch readState {
            case .idle:
                action = .none
            case .waitingForItem(let readContinuation):
                if let next = pending.popAndMerge() {
                    readState = .idle
                    action = .resumeNext(readContinuation, next)
                } else {
                    // Unreachable: we just appended an item, so `popAndMerge`
                    // always yields something. Leave the reader parked rather
                    // than trapping; a later write or `close()` will resume it.
                    action = .none
                }
            }

            writeState = .writing(pending)

            return action
        }
    }
}
