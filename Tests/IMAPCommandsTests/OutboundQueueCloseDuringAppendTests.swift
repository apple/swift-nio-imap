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
import Testing

@Suite("Outbound Queue — close during APPEND")
enum OutboundQueueCloseDuringAppendTests {

    /// Bug #3: While an `APPEND` is in flight, regular writes are held in
    /// `Append.pending`. `close()` only closes the append's inner queue and leaves
    /// `pending` untouched, so any continuation parked there is orphaned. If the
    /// in-flight append never returns (so `finishAppend()` never drains `pending`), the
    /// parked write hangs forever instead of failing when the connection is closed.
    @Test(.timeLimit(.minutes(1)))
    static func closeResumesWritesParkedDuringAppend() async throws {
        let sut = OutboundQueue()

        let enteredAppend = CompletionGate()  // resolves once we're in `.runningAppend`
        let holdAppend = CompletionGate()  // never resolved until cleanup: holds the append open
        let writeFinished = CompletionGate()  // resolves when the parked write returns/throws

        // Hold an APPEND open. This keeps the queue in `.runningAppend`, so
        // `finishAppend()` (which would drain `pending`) never runs until we release it.
        let holder = Task {
            try? await sut.withAppendWriter { _ in
                await enteredAppend.resolve(true)
                _ = await holdAppend.wait()
            }
        }
        _ = await enteredAppend.wait()

        // Issue a regular write. Since we're in `.runningAppend`, it parks in `pending`.
        let writer = Task {
            _ = try? await sut.write([TaggedCommand(tag: "A", command: .noop)])
            await writeFinished.resolve(true)
        }

        // Give the write a moment to park in `pending` before we close.
        try await Task.sleep(for: .milliseconds(200))

        // Tear the connection down. A correct `close()` must resume everything parked
        // in `pending`, not wait for the (possibly stuck) in-flight append to finish.
        sut.close()

        // The parked write must now complete; if it hangs, the timer resolves `false`.
        let timer = Task {
            try? await Task.sleep(for: .seconds(5))
            await writeFinished.resolve(false)
        }
        let finished = await writeFinished.wait()
        timer.cancel()

        // Cleanup: release the holder so no tasks leak once the assertion is recorded.
        await holdAppend.resolve(true)
        _ = await holder.value
        writer.cancel()

        #expect(
            finished,
            "close() during an in-flight APPEND must resume writes parked in `pending`, not orphan them."
        )
    }
}
