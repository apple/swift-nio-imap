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

final class FramingIntegrationTests: XCTestCase {
    
    var channel: EmbeddedChannel!
    
    override func setUp() {
        self.channel = EmbeddedChannel(handlers: [ByteToMessageHandler(ClientFrameDecoder()), IMAPServerHandler()])
    }
    
    func writeInbound(_ buffer: ByteBuffer, line: UInt = #line) {
        XCTAssertNoThrow(try self.channel.writeInbound(buffer), line: line)
    }
    
    func assertInbound(_ command: CommandStreamPart, line: UInt = #line) {
        var _inbound: CommandStreamPart?
        XCTAssertNoThrow(_inbound = try self.channel.readInbound(as: CommandStreamPart.self), line: line)
        
        guard let inbound = _inbound else {
            XCTAssertNotNil(nil, line: line)
            return
        }
        
        XCTAssertEqual(command, inbound, line: line)
    }
    
}

extension FramingIntegrationTests {
    
    func testSimpleCommands() {
        self.writeInbound("A1 NOOP\r\n")
        self.assertInbound(.tagged(.init(tag: "A1", command: .noop)))
    }
    
    func testLiteralDump() {
        self.writeInbound("A1 LOGIN {3}\r\n123 {3}\r\n456\r\n")
        self.assertInbound(.tagged(.init(tag: "A1", command: .login(username: "123", password: "456"))))
    }
    
    func testLiteralstreaming() {
        self.writeInbound("A1 LOGIN {3}\r\n123 ")
        self.writeInbound("{3}\r\n456\r\n")
        self.assertInbound(.tagged(.init(tag: "A1", command: .login(username: "123", password: "456"))))
    }
    
}
