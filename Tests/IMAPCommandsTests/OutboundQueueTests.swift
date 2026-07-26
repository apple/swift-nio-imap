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

@Suite("Outbound Queue")
enum OutboundQueueTests {
    @Test(.timeLimit(.minutes(1)))
    static func simpleRoundTrip() async throws {
        let (outbound, sink) = NIOAsyncChannelOutboundWriter<IMAPClientHandler.OutboundIn>.makeTestingWriter()

        let sut = OutboundQueue()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await sut.run(outbound: outbound)
                print("A")
            }

            group.addTask {
                var s = sink.makeAsyncIterator()
                let a = await s.next()
                sut.close()
                #expect(a == .part(.tagged(.init(tag: "A", command: .noop))))
                print("B")
            }

            group.addTask {
                await #expect(throws: Never.self) {
                    try await sut.write([.init(tag: "A", command: .noop)])
                }
                print("C")
            }
        }
    }
}
