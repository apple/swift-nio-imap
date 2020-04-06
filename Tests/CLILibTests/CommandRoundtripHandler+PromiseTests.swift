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

import XCTest
import NIO
import Logging
import NIOIMAP
@testable import CLILib

class CommandRoundtripHandler_PromiseTests: XCTestCase {
    
    var channel: EmbeddedChannel!
    
    override func setUp() {
        let logger = Logger(label: "test")
        channel = EmbeddedChannel(handler: CommandRoundtripHandler(logger: logger))
    }

    override func tearDown() {
        channel = nil
    }
    
    func testPromiseIsNotDropped_shouldThrow() {
        var buffer = channel.allocator.buffer(capacity: 0)
        buffer.writeString("definitely not IMAP\r\n")
        XCTAssertThrowsError(try self.channel.writeOutbound(buffer)) { e in
            XCTAssertTrue(e is ParserError, "Error \(e)")
        }
        XCTAssertNoThrow(XCTAssertNil(try self.channel.readOutbound(as: ByteBuffer.self)))
    }
    
    func testPromiseIsNotDropped_shouldNotThrow() {
        var buffer = channel.allocator.buffer(capacity: 0)
        buffer.writeString("1 NOOP\r\n")
        XCTAssertNoThrow(try self.channel.writeOutbound(buffer))
        XCTAssertEqual(try self.channel.readOutbound(as: ByteBuffer.self), buffer)
        XCTAssertNoThrow(XCTAssertTrue(try self.channel.finish().isClean))
    }
    
}
