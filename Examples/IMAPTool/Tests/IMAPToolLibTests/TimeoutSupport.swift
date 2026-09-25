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

/// A one-shot async gate.
///
/// Used to race an operation against a timeout *without* structured `await`-ing the
/// operation task, so an operation that stalls on a non-cancellable continuation
/// surfaces as a deterministic test failure instead of freezing the whole suite.
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
        return await withCheckedContinuation { c in
            waiters.append(c)
        }
    }
}

/// Runs `operation` and returns `true` if it finished within `seconds`, `false` if it
/// timed out (i.e. stalled).
///
/// The operation runs in an unstructured task. On timeout that task is cancelled and
/// abandoned — if it is stuck on a non-cancellable continuation it will leak, which is
/// acceptable for a bug-reproduction test that would otherwise stall forever.
func finishesWithoutStalling(
    within seconds: Double = 5,
    _ operation: @escaping @Sendable () async -> Void
) async -> Bool {
    let gate = CompletionGate()
    let work = Task {
        await operation()
        await gate.resolve(true)
    }
    let timer = Task {
        try? await Task.sleep(for: .seconds(seconds))
        await gate.resolve(false)
    }
    let finished = await gate.wait()
    work.cancel()
    timer.cancel()
    return finished
}
