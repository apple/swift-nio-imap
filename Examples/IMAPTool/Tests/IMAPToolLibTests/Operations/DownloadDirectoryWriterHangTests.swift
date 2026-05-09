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

import Dispatch
import Foundation
@testable import IMAPToolLib
import NIOIMAP
import Synchronization
import System
import Testing

@Suite("DownloadDirectory.Writer hang")
enum DownloadDirectoryWriterHangTests {

    /// Bug #4: The `Writer` state machine never assigns `.didComplete`. The DispatchIO
    /// cleanup handler runs exactly once; it resumes any parked continuations but leaves
    /// the state as `.writing`/`.doneWriting`/`.failed`. If `waitForCompletion()` parks
    /// its continuation *after* that one-shot handler has already fired, nothing will
    /// ever resume it and the download task hangs forever.
    ///
    /// This test forces the "cleanup ran first" ordering by waiting until the temp file
    /// has been renamed into place (which happens inside the cleanup handler) before
    /// calling `waitForCompletion()`.
    @Test(.timeLimit(.minutes(1)))
    static func waitForCompletionDoesNotHangWhenCleanupRanFirst() async throws {
        try await withTemporaryDirectory { dir in
            let uid: UID = 42
            let uidValidity: UIDValidity = 1
            let finalPath = dir.appending(.message(uid, uidValidity))

            let setupError = Mutex<String?>(nil)
            let reachedWait = Mutex<Bool>(false)

            let finished = await finishesWithoutHanging(within: 10) {
                do {
                    let tempPath = dir.appending(.temporary("hangtest.\(uid)"))
                    let writer = try DownloadDirectory.Writer(
                        uid: uid,
                        path: tempPath,
                        finalPath: finalPath
                    )
                    // Write some bytes so DispatchIO actually creates the temp file
                    // (it defers open() until the first write). Otherwise the cleanup
                    // handler's rename has nothing to move and never creates finalPath.
                    let bytes: [UInt8] = Array("From: test\r\n\r\nbody\r\n".utf8)
                    let data = bytes.withUnsafeBytes { DispatchData(bytes: $0) }
                    writer.write(data)
                    writer.closeAndSucceed()

                    // Wait until the one-shot cleanup handler has fired. It renames the
                    // temp file into place, so the final file's existence means the
                    // handler has run (and will never run again).
                    var attempts = 0
                    while !FileManager.default.fileExists(atPath: finalPath.string) {
                        attempts += 1
                        if attempts > 1_000 {
                            setupError.withLock { $0 = "cleanup handler never ran (final file was not created)" }
                            return
                        }
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    // Let the cleanup handler's continuation-resuming section finish.
                    try await Task.sleep(for: .milliseconds(50))

                    reachedWait.withLock { $0 = true }
                    // With the bug, the state never reached `.didComplete`, so this parks
                    // a continuation the (already-fired) cleanup handler cannot resume.
                    await writer.waitForCompletion()
                } catch {
                    setupError.withLock { $0 = "\(error)" }
                }
            }

            #expect(
                setupError.withLock { $0 } == nil,
                "Test setup failed: \(setupError.withLock { $0 } ?? "")"
            )
            #expect(
                reachedWait.withLock { $0 },
                "Test never reached waitForCompletion()."
            )
            #expect(
                finished,
                "Writer.waitForCompletion() hung: the cleanup handler ran before the continuation parked, and the state never reached .didComplete."
            )
        }
    }
}
