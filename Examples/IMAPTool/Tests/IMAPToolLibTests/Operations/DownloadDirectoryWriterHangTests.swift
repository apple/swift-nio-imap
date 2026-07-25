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

import Foundation
import NIOCore
@testable import IMAPToolLib
import NIOIMAP
import Synchronization
import SystemPackage
import Testing

@Suite("DownloadDirectory.Writer hang")
enum DownloadDirectoryWriterHangTests {

    /// Bug #4 (regression): `waitForCompletion()` must return even when the writer has
    /// already finished everything — including moving the file into place — before it is
    /// called. The original DispatchIO implementation parked a continuation that the
    /// already-fired, one-shot cleanup handler could never resume, hanging the download.
    ///
    /// This test forces that ordering by waiting until the file exists at its final path
    /// before calling `waitForCompletion()`.
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
                    writer.write(ByteBuffer(string: "From: test\r\n\r\nbody\r\n"))
                    writer.closeAndSucceed()

                    // Wait until the writing task has moved the file into place, so that
                    // it has finished before `waitForCompletion()` is called.
                    var attempts = 0
                    while !FileManager.default.fileExists(atPath: finalPath.string) {
                        attempts += 1
                        if attempts > 1_000 {
                            setupError.withLock { $0 = "writing task never ran (final file was not created)" }
                            return
                        }
                        try await Task.sleep(for: .milliseconds(10))
                    }
                    // Let the writing task finish completely.
                    try await Task.sleep(for: .milliseconds(50))

                    reachedWait.withLock { $0 = true }
                    // With the bug, this parked a continuation that nothing could resume.
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
                "Writer.waitForCompletion() hung after the writer had already completed."
            )
        }
    }
}
