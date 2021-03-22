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

class IMAPServerHandlerTests: XCTestCase {
    var channel: EmbeddedChannel!
    var handler: IMAPServerHandler!

    // MARK: - Tests

    func testSimpleCommandAndResponse() {
        self.writeInbound("a LOGIN \"user\" \"password\"\r\n")
        self.assertInbound(.command(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.taggedResponse(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")
    }

    func testSimpleCommandWithContinuationRequestWorks() {
        self.writeInbound("a LOGIN {4}\r\n")
        XCTAssertNoThrow(XCTAssertNil(try self.channel.readInbound(as: CommandStream.self)))

        // Nothing happens until `read()`
        XCTAssertNoThrow(XCTAssertNil(try self.channel.readOutbound(as: ByteBuffer.self)))

        self.channel.read()
        self.assertOutboundString("+ OK\r\n")

        self.writeInbound("user \"password\"\r\n")

        self.assertInbound(.command(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.taggedResponse(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")
    }

    func testSimpleCommandWithContinuationRequestWorksEvenIfClientMisbehavesAndSendsWithoutWaiting() {
        self.writeInbound("a LOGIN {4}\r\nuser \"password\"\r\n")
        // Nothing happens until `read()`
        XCTAssertNoThrow(XCTAssertNil(try self.channel.readOutbound(as: ByteBuffer.self)))

        self.assertInbound(.command(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.taggedResponse(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")

        self.channel.read()
        self.assertOutboundString("+ OK\r\n")
    }

    func testSettingContinuationRequestOnLiveHandler() {
        self.handler.continuationRequest = ContinuationRequest.responseText(.init(text: "FoO"))

        self.writeInbound("a LOGIN {4}\r\n")
        XCTAssertNoThrow(XCTAssertNil(try self.channel.readInbound(as: CommandStream.self)))

        // Nothing happens until `read()`
        XCTAssertNoThrow(XCTAssertNil(try self.channel.readOutbound(as: ByteBuffer.self)))

        self.channel.read()
        self.assertOutboundString("+ FoO\r\n")

        self.writeInbound("user \"password\"\r\n")

        self.assertInbound(.command(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.taggedResponse(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")
    }

    func testSettingContinuationRequestInInit() {
        self.handler = IMAPServerHandler(continuationRequest: ContinuationRequest.responseText(.init(text: "FoO")))
        self.channel = EmbeddedChannel(handler: self.handler)

        self.writeInbound("a LOGIN {4}\r\n")
        XCTAssertNoThrow(XCTAssertNil(try self.channel.readInbound(as: CommandStream.self)))

        // Nothing happens until `read()`
        XCTAssertNoThrow(XCTAssertNil(try self.channel.readOutbound(as: ByteBuffer.self)))

        self.channel.read()
        self.assertOutboundString("+ FoO\r\n")

        self.writeInbound("user \"password\"\r\n")

        self.assertInbound(.command(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.taggedResponse(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")
    }
    
    // We previously had a bug where the response encode buffer was dropped with every
    // individual server response, meaning we lost the state. We need to state to insert
    // correct spaces in between streaming fetch attributes. This test prevents regression.
    func testFetchResponsesIncludeSpaces() {
        
        // note that the same handler (and therefore the same `ResponseEncodeBuffer` is used
        // throughout the test
        self.handler = IMAPServerHandler()
        self.channel = EmbeddedChannel(handler: self.handler)
        
        // single attribute
        self.writeOutbound(.fetchResponse(.start(1)), wait: false)
        self.assertOutboundString("* 1 FETCH (")
        self.writeOutbound(.fetchResponse(.simpleAttribute(.flags([.answered, .draft]))), wait: false)
        self.assertOutboundString("FLAGS (\\Answered \\Draft)")
        self.writeOutbound(.fetchResponse(.finish), wait: false)
        self.assertOutboundString(")\r\n")
        
        // multiple attributes
        self.writeOutbound(.fetchResponse(.start(2)), wait: false)
        self.assertOutboundString("* 2 FETCH (")
        self.writeOutbound(.fetchResponse(.simpleAttribute(.flags([.answered, .draft]))), wait: false)
        self.assertOutboundString("FLAGS (\\Answered \\Draft)")
        self.writeOutbound(.fetchResponse(.simpleAttribute(.uid(999))), wait: false)
        self.assertOutboundString(" UID 999")
        self.writeOutbound(.fetchResponse(.simpleAttribute(.rfc822Size(876))), wait: false)
        self.assertOutboundString(" RFC822.SIZE 876")
        self.writeOutbound(.fetchResponse(.finish), wait: false)
        self.assertOutboundString(")\r\n")
        
        // multiple attributes with streaming
        self.writeOutbound(.fetchResponse(.start(2)), wait: false)
        self.assertOutboundString("* 2 FETCH (")
        self.writeOutbound(.fetchResponse(.simpleAttribute(.flags([.answered, .draft]))), wait: false)
        self.assertOutboundString("FLAGS (\\Answered \\Draft)")
        self.writeOutbound(.fetchResponse(.simpleAttribute(.uid(999))), wait: false)
        self.assertOutboundString(" UID 999")
        self.writeOutbound(.fetchResponse(.streamingBegin(kind: .rfc822, byteCount: 5)), wait: false)
        self.assertOutboundString(" RFC822 {5}\r\n")
        self.writeOutbound(.fetchResponse(.streamingBytes("12345")), wait: false)
        self.assertOutboundString("12345")
        self.writeOutbound(.fetchResponse(.streamingEnd), wait: false)
        self.assertOutboundString("")
        self.writeOutbound(.fetchResponse(.simpleAttribute(.rfc822Size(876))), wait: false)
        self.assertOutboundString(" RFC822.SIZE 876")
        self.writeOutbound(.fetchResponse(.finish), wait: false)
        self.assertOutboundString(")\r\n")
    }

    // MARK: - setup/tear down

    override func setUp() {
        XCTAssertNil(self.handler)
        XCTAssertNil(self.channel)
        self.handler = IMAPServerHandler()
        self.channel = EmbeddedChannel(handler: self.handler)
    }

    override func tearDown() {
        XCTAssertNotNil(self.channel)
        XCTAssertNotNil(self.handler)
        XCTAssertNoThrow(XCTAssertTrue(try self.channel.finish().isClean))
        self.channel = nil
        self.handler = nil
    }
}

// MARK: - Helpers

extension IMAPServerHandlerTests {
    private func assertInbound(_ response: CommandStream, line: UInt = #line) {
        var maybeRead: CommandStream?
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
    private func writeOutbound(_ command: Response, wait: Bool = true, line: UInt = #line) -> EventLoopFuture<Void> {
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
