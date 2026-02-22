//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import CLILib
import Logging
import NIO
import NIOIMAP
import NIOIMAPCore
import Testing

private func makeEmbeddedChannel() -> EmbeddedChannel {
    let logger = Logger(label: "test")
    return EmbeddedChannel(handler: CommandRoundtripHandler(logger: logger))
}

@Suite("CommandRoundtripHandler promise tests")
struct CommandRoundtripHandler_PromiseTests {
    @Test("promise is not dropped - should throw")
    func promiseIsNotDroppedShouldThrow() {
        let channel = makeEmbeddedChannel()

        let buffer = channel.allocator.buffer(capacity: 0)
        #expect(
            performing: {
                try channel.writeOutbound(buffer)
            },
            throws: {
                guard
                    let error = $0 as? CommandRoundtripError,
                    error == .incompleteCommand
                else { Issue.record("\($0)"); return false }
                return true
            }
        )

        var maybeRead: ByteBuffer?
        #expect(throws: Never.self) {
            maybeRead = try channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(maybeRead == nil)
    }

    @Test("promise is not dropped - should not throw")
    func promiseIsNotDroppedShouldNotThrow() {
        let channel = makeEmbeddedChannel()

        var buffer = channel.allocator.buffer(capacity: 0)
        buffer.writeString("1 NOOP\r\n")
        #expect(throws: Never.self) {
            try channel.writeOutbound(buffer)
        }

        var maybeRead: ByteBuffer?
        #expect(throws: Never.self) {
            maybeRead = try channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(maybeRead == buffer)
    }
}
