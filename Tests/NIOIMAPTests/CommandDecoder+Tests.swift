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

import NIO
@testable import NIOIMAP
@testable import NIOIMAPCore
import NIOTestUtils

import Testing

@Suite struct CommandDecoder_Tests {}

extension CommandDecoder_Tests {
    @Test func `consume when returning not enough data regression`() {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(CommandDecoder()), loop: .init())

        for feed in ["tag APPEND box (\\Seen) {1+}\r\na\r\n", "t"] {
            #expect(throws: Never.self) { try channel.writeInbound(self.buffer(feed)) }
        }

        let output: [(CommandStreamPart, UInt)] = [
            (.append(.start(tag: "tag", appendingTo: .init("box"))), #line),
            (
                .append(
                    .beginMessage(
                        message: .init(options: .init(flagList: [.seen], extensions: [:]), data: .init(byteCount: 1))
                    )
                ), #line
            ),
            (.append(.messageBytes("a")), #line),
            (.append(.endMessage), #line),
            (.append(.finish), #line),
        ]

        for (expected, line) in output {
            var result: SynchronizedCommand?
            #expect(throws: Never.self) {
                result = try channel.readInbound(as: SynchronizedCommand.self)
            }
            #expect(
                result == SynchronizedCommand(expected),
                sourceLocation: SourceLocation(fileID: #fileID, filePath: #filePath, line: Int(line), column: 1)
            )
        }
        var isClean = false
        #expect(throws: Never.self) {
            isClean = try channel.finish().isClean
        }
        #expect(isClean)
    }
}

extension CommandDecoder_Tests {
    func buffer(_ string: String) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        return buffer
    }
}
