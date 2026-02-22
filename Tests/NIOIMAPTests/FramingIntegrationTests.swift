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
    @Test("simple commands")
    func simpleCommands() {
        let helper = Helper()
        helper.writeInbound("A1 NOOP\r\n")
        helper.assertInbound(.tagged(.init(tag: "A1", command: .noop)))
    }

    @Test("literal dump")
    func literalDump() {
        let helper = Helper()
        helper.writeInbound("A1 LOGIN {3}\r\n123 {3}\r\n456\r\n")
        helper.assertInbound(.tagged(.init(tag: "A1", command: .login(username: "123", password: "456"))))
    }

    @Test("literal streaming")
    func literalStreaming() {
        let helper = Helper()
        helper.writeInbound("A1 LOGIN {3}\r\n123 ")
        helper.writeInbound("{3}\r\n456\r\n")
        helper.assertInbound(.tagged(.init(tag: "A1", command: .login(username: "123", password: "456"))))
    }
}

extension FramingIntegrationTests {
    struct Helper {
        var channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), IMAPServerHandler()])
    }
}

extension FramingIntegrationTests.Helper {
    func writeInbound(_ buffer: ByteBuffer, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: Never.self, sourceLocation: sourceLocation) { try self.channel.writeInbound(buffer) }
    }

    func assertInbound(_ command: CommandStreamPart, sourceLocation: SourceLocation = #_sourceLocation) {
        var _inbound: CommandStreamPart?
        #expect(throws: Never.self, sourceLocation: sourceLocation) { _inbound = try self.channel.readInbound(as: CommandStreamPart.self) }

        guard let inbound = _inbound else {
            Issue.record("Expected non-nil inbound value", sourceLocation: sourceLocation)
            return
        }

        #expect(command == inbound)
    }
}
