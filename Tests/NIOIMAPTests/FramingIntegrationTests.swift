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

@Suite struct FramingIntegrationTests {
    var channel: EmbeddedChannel!

    init() {
        self.channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), IMAPServerHandler()])
    }

    func writeInbound(_ buffer: ByteBuffer, line: UInt = #line) {
        #expect(throws: Never.self) { try self.channel.writeInbound(buffer) }
    }

    func assertInbound(_ command: CommandStreamPart, line: UInt = #line) {
        var _inbound: CommandStreamPart?
        #expect(throws: Never.self) { _inbound = try self.channel.readInbound(as: CommandStreamPart.self) }

        guard let inbound = _inbound else {
            #expect(Bool(false), "Expected non-nil inbound value")
            return
        }

        #expect(command == inbound)
    }
}

extension FramingIntegrationTests {
    @Test func `simple commands`() {
        self.writeInbound("A1 NOOP\r\n")
        self.assertInbound(.tagged(.init(tag: "A1", command: .noop)))
    }

    @Test func `literal dump`() {
        self.writeInbound("A1 LOGIN {3}\r\n123 {3}\r\n456\r\n")
        self.assertInbound(.tagged(.init(tag: "A1", command: .login(username: "123", password: "456"))))
    }

    @Test func `literal streaming`() {
        self.writeInbound("A1 LOGIN {3}\r\n123 ")
        self.writeInbound("{3}\r\n456\r\n")
        self.assertInbound(.tagged(.init(tag: "A1", command: .login(username: "123", password: "456"))))
    }
}
