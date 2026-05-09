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

@testable import IMAPToolLib
import Testing

@Suite
struct TokenBucketTests {
    @Test
    func acquireAndReleaseSingleToken() async throws {
        let bucket = TokenBucket(tokens: 1)
        let result = try await bucket.withToken { 42 }
        #expect(result == 42)

        // The token was returned, so we can acquire again.
        let again = try await bucket.withToken { 7 }
        #expect(again == 7)
    }

    @Test
    func tokenIsReturnedAfterThrowing() async throws {
        let bucket = TokenBucket(tokens: 1)
        struct Boom: Swift.Error {}

        await #expect(throws: Boom.self) {
            try await bucket.withToken { throw Boom() }
        }

        // After a throwing body the token should still be back in the bucket.
        let value = try await bucket.withToken { "ok" }
        #expect(value == "ok")
    }

    @Test
    func boundsConcurrencyToTokenCount() async {
        let tokens = 3
        let bucket = TokenBucket(tokens: tokens)
        let observer = ConcurrencyObserver()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try? await bucket.withToken {
                        await observer.didEnter()
                        // A short sleep so several tasks can pile up while
                        // another is holding a token.
                        try? await Task.sleep(for: .milliseconds(5))
                        await observer.didExit()
                    }
                }
            }
        }

        let peak = await observer.peak
        #expect(peak <= tokens)
        // Sanity: the bucket should also be saturated at some point.
        #expect(peak >= 1)
    }

    @Test
    func allWaitersEventuallyComplete() async {
        // With one token and many waiters, every task must still finish —
        // i.e. each release wakes exactly one waiter, no waiters are dropped.
        let bucket = TokenBucket(tokens: 1)
        let counter = CompletionCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<25 {
                group.addTask {
                    try? await bucket.withToken {
                        await counter.increment()
                    }
                }
            }
        }

        let completed = await counter.value
        #expect(completed == 25)
    }

    @Test
    func cancellingAParkedWaiterThrowsPromptly() async throws {
        // No tokens -> any `withToken` parks immediately. A cancelled waiter
        // must throw `CancellationError` rather than hang forever.
        let bucket = TokenBucket(tokens: 0)
        let task = Task {
            try await bucket.withToken {}
        }
        task.cancel()

        // Race the result against a timeout so a regression fails the test
        // instead of hanging the whole suite.
        let threwCancellation = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                do {
                    try await task.value
                    return false
                } catch is CancellationError {
                    return true
                } catch {
                    return false
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return false  // timed out
            }
            let first = await group.next()!
            group.cancelAll()
            return first
        }
        #expect(threwCancellation)
    }

    @Test
    func cancellingAWaiterKeepsAccountingBalanced() async throws {
        let bucket = TokenBucket(tokens: 1)

        let acquired = AsyncStream.makeStream(of: Void.self)
        let release = AsyncStream.makeStream(of: Void.self)

        // A holder that takes the only token and keeps it until released.
        let holder = Task {
            try await bucket.withToken {
                acquired.continuation.yield(())
                var it = release.stream.makeAsyncIterator()
                _ = await it.next()
            }
        }

        // Wait until the holder actually holds the token.
        var acquiredIterator = acquired.stream.makeAsyncIterator()
        _ = await acquiredIterator.next()

        // With the token held, this waiter parks; cancelling it must throw.
        let waiter = Task { try await bucket.withToken {} }
        waiter.cancel()
        await #expect(throws: CancellationError.self) {
            try await waiter.value
        }

        // Release the holder; the token must be back in the bucket.
        release.continuation.yield(())
        _ = try await holder.value

        let value = try await bucket.withToken { 99 }
        #expect(value == 99)
    }
}

private actor ConcurrencyObserver {
    private(set) var current = 0
    private(set) var peak = 0

    func didEnter() {
        current += 1
        if current > peak { peak = current }
    }

    func didExit() {
        current -= 1
    }
}

private actor CompletionCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
