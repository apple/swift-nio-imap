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
import DequeModule
import Testing
import NIO
import NIOIMAP
import Synchronization

private typealias PendingItem = CommandStreamPartQueue.PendingItem
private typealias Next = CommandStreamPartQueue.Next

@Suite("CommandStreamPartQueue Tests")
private enum CommandStreamPartQueueTests {
    @Test
    static func closeWithPendingWrites() async throws {
        // If we append a write, and then close
        // the queue, the pending write completions
        // should get run.
        var sut = CommandStreamPartQueue()
        do {
            try await withCheckedThrowingContinuation { completion in
                sut.writeState = .writing([
                    PendingItem(
                        payload: [.part(.tagged(.init(tag: "A1", command: .noop)))],
                        completion: completion
                    )
                ])
                sut.close().run()
            }
            Issue.record("Should have thrown an error.")
        } catch {
            // Ignore.
        }
    }

    @Test
    static func closeWithPendingRead() async throws {
        // If we’re waiting for items to be output,
        // That closure should return `nil`.
        var sut = CommandStreamPartQueue()
        do {
            let next: Next? = try await withCheckedThrowingContinuation { completion in
                sut.readState = .waitingForItem(completion)
                sut.close().run()
            }
            #expect(next == nil)
        } catch {
            Issue.record(error, "Should not have thrown an error.")
        }
    }

    @Test
    static func closeWithoutPending() async throws {
        var sut = CommandStreamPartQueue()
        sut.close().run()
    }

    struct PopAndMergeFixture: CustomTestStringConvertible, CustomTestArgumentEncodable {
        var original: [[IMAPClientHandler.OutboundIn]]
        var popped: [IMAPClientHandler.OutboundIn]?
        var remainder: [[IMAPClientHandler.OutboundIn]]

        var testDescription: String {
            "["
                + original
                .map {
                    $0
                        .map { String(reflecting: $0) }
                        .joined(separator: ",")
                }
                .map {
                    #""\#($0)""#
                }
                .joined(separator: "; ") + "]"
        }

        func encodeTestArgument(to encoder: some Encoder) throws {
            try testDescription.encode(to: encoder)
        }
    }

    @Test(arguments: [
        PopAndMergeFixture(
            original: [],
            popped: nil,
            remainder: []
        ),
        PopAndMergeFixture(
            original: [
                []
            ],
            popped: [],
            remainder: []
        ),
        PopAndMergeFixture(
            original: [
                [.part(.tagged(.init(tag: "A1", command: .noop)))],
                [.part(.tagged(.init(tag: "A2", command: .noop)))],
            ],
            popped: [
                .part(.tagged(.init(tag: "A1", command: .noop))),
                .part(.tagged(.init(tag: "A2", command: .noop))),
            ],
            remainder: []
        ),
    ])
    static func popAndMergePendingItems(
        fixture: PopAndMergeFixture
    ) async throws {
        try await withPendingItems(
            original: fixture.original
        ) { pendingItems in
            var sut = Deque<PendingItem>(pendingItems)
            let next = sut.popAndMerge()
            #expect(next?.payload == fixture.popped)
            next?.completions.forEach { c in
                c.resume()
            }
            #expect(sut.map { $0.payload } == fixture.remainder)
            sut.map { $0.completion }.forEach { c in
                c.resume()
            }
        }
    }

    @Test
    static func nextWaitsForItems() async throws {
        // If we try to get the next item, that should
        // record the closure.
        var sut = CommandStreamPartQueue()
        do {
            let next: Next? = try await withCheckedThrowingContinuation { continuation in
                let action = sut.next(continuation)
                switch action {
                case .none: break
                case .resumeContinuation: Issue.record()
                }
                action.run()

                switch sut.readState {
                case .idle: Issue.record("Should be waiting")
                case .waitingForItem(let checkedContinuation):
                    checkedContinuation.resume(returning: nil)
                }
            }
            #expect(next == nil)
        } catch {
            Issue.record(error, "Should not have thrown an error.")
        }
    }
}

/// Recursively maps `[CommandStreamPart]` to `PendingItem`, creating completion closures.
///
/// Waits for all closures to complete.
private func withPendingItems(
    original: [[IMAPClientHandler.OutboundIn]],
    pendingItems: [PendingItem] = [],
    do closure: @Sendable @escaping ([PendingItem]) async -> Void
) async throws {
    guard
        let payload = original.first
    else {
        return await closure(pendingItems)
    }
    return try await withCheckedThrowingContinuation { completion in
        var p = pendingItems
        p.append(
            PendingItem(
                payload: payload,
                completion: completion
            )
        )
        let o = Array(original.suffix(from: 1))
        Task {
            do {
                try await withPendingItems(
                    original: o,
                    pendingItems: p,
                    do: closure
                )
            } catch {
                Issue.record(error)
            }
        }
    }
}
