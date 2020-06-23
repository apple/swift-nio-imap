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

import XCTest

final class CommandDecoder_Tests: XCTestCase {}

extension CommandDecoder_Tests {
//    func testConsumeWhenReturningNotEnoughDataRegression() {
//        let channel = EmbeddedChannel(handler: ByteToMessageHandler(CommandDecoder()), loop: .init())
//
//        for feed in ["tag APPEND box (\\Seen) {1+}\r\na\r\n", "t"] {
//            XCTAssertNoThrow(try channel.writeInbound(self.buffer(feed)), feed)
//        }
//
//        XCTAssertNoThrow(
//            XCTAssertEqual(
//                CommandDecoder.PartialCommandStream(
//                    .command(
//                        .init(
//                            tag: "tag",
//                            command: .append(to: .init("box"), firstMessageMetadata: .init(
//                                options: .init(flagList: [.seen], extensions: []),
//                                data: .init(byteCount: 1, needs8BitCleanTransport: false, synchronizing: false)
//                            ))
//                        )
//                    )
//                ),
//                try channel.readInbound(as: CommandDecoder.PartialCommandStream.self)
//            )
//        )
//        XCTAssertNoThrow(XCTAssertEqual(CommandDecoder.PartialCommandStream(.bytes(self.buffer("a"))),
//                                        try channel.readInbound(as: CommandDecoder.PartialCommandStream.self)))
//        XCTAssertNoThrow(XCTAssertNil(try channel.readInbound(as: CommandDecoder.PartialCommandStream.self)))
//        XCTAssertNoThrow(XCTAssertTrue(try channel.finish().isClean))
//    }
}

extension CommandDecoder_Tests {
    func buffer(_ string: String) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        return buffer
    }
}
