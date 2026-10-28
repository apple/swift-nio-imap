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

/// Lets us limit concurrency.
actor TokenBucket {
    private var tokens: Int
    private var waiters: Deque<Waiter>
    private var nextWaiterID = 0

    private struct Waiter {
        var id: Int
        var continuation: CheckedContinuation<Void, any Swift.Error>
    }

    init(tokens: Int) {
        self.tokens = tokens
        self.waiters = Deque()
    }

    func withToken<ReturnType: Sendable>(
        _ body: () async throws -> ReturnType
    ) async throws -> ReturnType {
        try await self.getToken()
        defer {
            self.returnToken()
        }

        return try await body()
    }

    private func getToken() async throws {
        if self.tokens > 0 {
            self.tokens -= 1
            return
        }

        let id = self.nextWaiterID
        self.nextWaiterID += 1

        // Park until a token is returned to us — but honor cancellation, so a
        // cancelled task doesn't stay parked forever (and doesn't consume a
        // token it never received).
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Swift.Error>) in
                // If we were cancelled before parking, don't park at all.
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.waiters.append(Waiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    private func cancelWaiter(id: Int) {
        guard let index = self.waiters.firstIndex(where: { $0.id == id }) else {
            // The waiter was already granted a token by `returnToken`; that
            // path stays balanced via the holder's `defer returnToken()`.
            return
        }
        let waiter = self.waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func returnToken() {
        if let nextWaiter = self.waiters.popFirst() {
            nextWaiter.continuation.resume()
        } else {
            self.tokens += 1
        }
    }
}
