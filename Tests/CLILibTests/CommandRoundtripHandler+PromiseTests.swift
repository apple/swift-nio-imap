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
import XCTest

class CommandRoundtripHandler_PromiseTests: XCTestCase {
    var channel: EmbeddedChannel!

    override func setUp() {
        let logger = Logger(label: "test")
        channel = EmbeddedChannel(handler: CommandRoundtripHandler(logger: logger))
    }

    override func tearDown() {
        self.channel = nil
    }

    func testPromiseIsNotDropped_shouldThrow() {
        let buffer = self.channel.allocator.buffer(capacity: 0)
        XCTAssertThrowsError(try self.channel.writeOutbound(buffer)) { e in
            XCTAssertTrue(e is ImapError, "Error \(e)")
        }
        XCTAssertNoThrow(XCTAssertNil(try self.channel.readOutbound(as: ByteBuffer.self)))
    }

    func testPromiseIsNotDropped_shouldNotThrow() {
        var buffer = self.channel.allocator.buffer(capacity: 0)
        buffer.writeString("1 NOOP\r\n")
        XCTAssertNoThrow(try self.channel.writeOutbound(buffer))
        XCTAssertEqual(try self.channel.readOutbound(as: ByteBuffer.self), buffer)
        XCTAssertNoThrow(XCTAssertTrue(try self.channel.finish().isClean))
    }
}
