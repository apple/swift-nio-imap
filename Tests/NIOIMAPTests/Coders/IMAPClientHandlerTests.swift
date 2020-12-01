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
import NIOIMAP
import XCTest

class IMAPClientHandlerTests: XCTestCase {
    var channel: EmbeddedChannel!

    // MARK: - Tests

    func testBasicCommandAndResponse() {
        self.writeOutbound(.command(.init(tag: "a", command: .login(username: "foo", password: "bar"))))
        self.assertOutboundString("a LOGIN \"foo\" \"bar\"\r\n")
        self.writeInbound("a OK ok\r\n")
        self.assertInbound(.response(.taggedResponse(.init(tag: "a",
                                                 state: .ok(.init(code: nil, text: "ok"))))))
    }

    func testCommandThatNeedsToWaitForContinuationRequest() {
        let f = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
                                                                       command: .rename(from: .init("\n"),
                                                                                        to: .init("to"),
                                                                                        params: []))),
                                   wait: false)
        self.assertOutboundString("x RENAME {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\n \"to\"\r\n")
        XCTAssertNoThrow(try f.wait())
        self.writeInbound("x OK ok\r\n")
        self.assertInbound(.response(.taggedResponse(.init(tag: "x",
                                                 state: .ok(.init(code: nil, text: "ok"))))))
    }

    func testCommandThatNeedsToWaitForTwoContinuationRequest() {
        let f = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
                                                                       command: .rename(from: .init("\n"),
                                                                                        to: .init("\r"),
                                                                                        params: []))),
                                   wait: false)
        self.assertOutboundString("x RENAME {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\n {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\r\r\n")
        XCTAssertNoThrow(try f.wait())
        self.writeInbound("x OK ok\r\n")
        self.assertInbound(.response(.taggedResponse(.init(tag: "x",
                                                 state: .ok(.init(code: nil, text: "ok"))))))
    }

    func testTwoContReqCommandsEnqueued() {
        let f1 = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
                                                                        command: .rename(from: .init("\n"),
                                                                                         to: .init("to"),
                                                                                         params: []))),
                                    wait: false)
        let f2 = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "y",
                                                                        command: .rename(from: .init("from"),
                                                                                         to: .init("\n"),
                                                                                         params: []))),
                                    wait: false)
        self.assertOutboundString("x RENAME {1}\r\n")
        self.writeInbound("+ OK\r\n")
        XCTAssertNoThrow(try f1.wait())
        self.assertOutboundString("\n \"to\"\r\n")
        self.assertOutboundString("y RENAME \"from\" {1}\r\n")
        self.writeInbound("+ OK\r\n")
        XCTAssertNoThrow(try f2.wait())
        self.assertOutboundString("\n\r\n")
        self.writeInbound("x OK ok\r\n")
        self.assertInbound(.response(.taggedResponse(.init(tag: "x",
                                                 state: .ok(.init(code: nil, text: "ok"))))))
        self.writeInbound("y OK ok\r\n")
        self.assertInbound(.response(.taggedResponse(.init(tag: "y",
                                                 state: .ok(.init(code: nil, text: "ok"))))))
    }

    func testUnexpectedContinuationRequest() {
        let f = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
                                                                       command: .rename(from: .init("\n"),
                                                                                        to: .init("to"),
                                                                                        params: []))),
                                   wait: false)
        self.assertOutboundString("x RENAME {1}\r\n")
        XCTAssertThrowsError(try self.channel.writeInbound(self.buffer(string: "+ OK\r\n+ OK\r\n"))) { error in
            XCTAssertTrue(error is IMAPClientHandler.UnexpectedContinuationRequest)
        }
        self.assertOutboundString("\n \"to\"\r\n")
        XCTAssertNoThrow(try f.wait())
        self.writeInbound("x OK ok\r\n")
        self.assertInbound(.response(.taggedResponse(.init(tag: "x",
                                                 state: .ok(.init(code: nil, text: "ok"))))))
    }

    // MARK: - setup / tear down

    override func setUp() {
        XCTAssertNil(self.channel)
        self.channel = EmbeddedChannel(handler: IMAPClientHandler())
    }

    override func tearDown() {
        XCTAssertNotNil(self.channel)
        XCTAssertNoThrow(XCTAssertTrue(try self.channel.finish().isClean))
        self.channel = nil
    }
}

// MARK: - Helpers

extension IMAPClientHandlerTests {
    private func assertInbound(_ response: ResponseOrContinuationRequest, line: UInt = #line) {
        var maybeRead: ResponseOrContinuationRequest?
        XCTAssertNoThrow(maybeRead = try self.channel.readInbound(), line: line)
        guard let read = maybeRead else {
            XCTFail("Inbound buffer empty", line: line)
            return
        }
        XCTAssertEqual(response, read, line: line)
    }

    private func assertOutboundBuffer(_ buffer: ByteBuffer, line: UInt = #line) {
        var maybeRead: ByteBuffer?
        XCTAssertNoThrow(maybeRead = try self.channel.readOutbound(), line: line)
        guard let read = maybeRead else {
            XCTFail("Outbound buffer empty", line: line)
            return
        }
        XCTAssertEqual(buffer, read, "\(String(buffer: buffer)) != \(String(buffer: read))", line: line)
    }

    private func assertOutboundString(_ string: String, line: UInt = #line) {
        var buffer = self.channel.allocator.buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        self.assertOutboundBuffer(buffer, line: line)
    }

    private func writeInbound(_ string: String, line: UInt = #line) {
        XCTAssertNoThrow(try self.channel.writeInbound(self.buffer(string: string)), line: line)
    }

    @discardableResult
    private func writeOutbound(_ command: CommandStream, wait: Bool = true, line: UInt = #line) -> EventLoopFuture<Void> {
        let result = self.channel.writeAndFlush(command)
        if wait {
            XCTAssertNoThrow(try result.wait(), line: line)
        }
        return result
    }

    private func buffer(string: String) -> ByteBuffer {
        var buffer = self.channel.allocator.buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        return buffer
    }
}
