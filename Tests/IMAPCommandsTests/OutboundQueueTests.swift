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
import Testing
import NIO
import NIOIMAP
import Synchronization

@Suite("Outbound Queue")
enum OutboundQueueTests {
    @Test(.timeLimit(.minutes(1)))
    static func simpleRoundTrip() async throws {
        let (outbound, sink) = NIOAsyncChannelOutboundWriter<IMAPClientHandler.OutboundIn>.makeTestingWriter()

        let sut = OutboundQueue()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await sut.run(outbound: outbound)
            }

            group.addTask {
                var s = sink.makeAsyncIterator()
                let a = await s.next()
                sut.close()
                #expect(a == .part(.tagged(.init(tag: "A", command: .noop))))
            }

            group.addTask {
                await #expect(throws: Never.self) {
                    try await sut.write([.init(tag: "A", command: .noop)])
                }
            }
        }
    }

    /// `close()` must leave the queue closed, so a write issued afterwards fails
    /// immediately. If the queue stays in its writing state, the write is appended to a
    /// deque that nobody drains any more (the outbound runner has stopped), and its
    /// continuation is parked forever.
    @Test(.timeLimit(.minutes(3)))
    static func writeAfterCloseFailsInsteadOfStalling() async throws {
        let sut = OutboundQueue()
        sut.close()

        let threw = Mutex(false)
        let finished = await finishesWithoutStalling {
            do {
                try await sut.write([TaggedCommand(tag: "A", command: .noop)])
            } catch {
                threw.withLock { $0 = true }
            }
        }

        #expect(finished, "A write issued after close() must not park in a queue nobody drains.")
        #expect(threw.withLock { $0 }, "A write issued after close() must fail.")
    }
}
