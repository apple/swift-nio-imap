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
import Testing

@Suite struct IMAPServerHandlerTests {
    var channel: EmbeddedChannel!
    var handler: IMAPServerHandler!

    init() {
        self.handler = IMAPServerHandler()
        self.channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), self.handler])
    }

    // MARK: - Tests

    @Test("simple command and response")
    func simpleCommandAndResponse() {
        defer {
            _ = try? self.channel.finish()
        }
        self.writeInbound("a LOGIN \"user\" \"password\"\r\n")
        self.assertInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")
    }

    @Test("simple command with continuation request works")
    func simpleCommandWithContinuationRequestWorks() {
        defer {
            _ = try? self.channel.finish()
        }
        self.writeInbound("a LOGIN {4}\r\n")
        var result: CommandStreamPart?
        #expect(throws: Never.self) {
            result = try self.channel.readInbound(as: CommandStreamPart.self)
        }
        #expect(result == nil)

        // Nothing happens until `read()`
        var outbound: ByteBuffer?
        #expect(throws: Never.self) {
            outbound = try self.channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(outbound == nil)

        self.channel.read()
        self.assertOutboundString("+ OK\r\n")

        self.writeInbound("user \"password\"\r\n")

        self.assertInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")
    }

    @Test("simple command with continuation request works even if client misbehaves and sends without waiting")
    func simpleCommandWithContinuationRequestWorksEvenIfClientMisbehavesAndSendsWithoutWaiting() {
        defer {
            _ = try? self.channel.finish()
        }
        self.writeInbound("a LOGIN {4}\r\nuser \"password\"\r\n")
        // Nothing happens until `read()`
        var outbound: ByteBuffer?
        #expect(throws: Never.self) {
            outbound = try self.channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(outbound == nil)

        self.assertInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")

        self.channel.read()
        self.assertOutboundString("+ OK\r\n")
    }

    @Test("setting continuation request on live handler")
    func settingContinuationRequestOnLiveHandler() {
        defer {
            _ = try? self.channel.finish()
        }
        self.handler.continuationRequest = ContinuationRequest.responseText(.init(text: "FoO"))

        self.writeInbound("a LOGIN {4}\r\n")
        var result: CommandStreamPart?
        #expect(throws: Never.self) {
            result = try self.channel.readInbound(as: CommandStreamPart.self)
        }
        #expect(result == nil)

        // Nothing happens until `read()`
        var outbound: ByteBuffer?
        #expect(throws: Never.self) {
            outbound = try self.channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(outbound == nil)

        self.channel.read()
        self.assertOutboundString("+ FoO\r\n")

        self.writeInbound("user \"password\"\r\n")

        self.assertInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")
    }

    @Test("setting continuation request in init")
    mutating func settingContinuationRequestInInit() {
        self.handler = IMAPServerHandler(continuationRequest: ContinuationRequest.responseText(.init(text: "FoO")))
        self.channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), self.handler])
        defer {
            _ = try? self.channel.finish()
        }

        self.writeInbound("a LOGIN {4}\r\n")
        var result: CommandStreamPart?
        #expect(throws: Never.self) {
            result = try self.channel.readInbound(as: CommandStreamPart.self)
        }
        #expect(result == nil)

        // Nothing happens until `read()`
        var outbound: ByteBuffer?
        #expect(throws: Never.self) {
            outbound = try self.channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(outbound == nil)

        self.channel.read()
        self.assertOutboundString("+ FoO\r\n")

        self.writeInbound("user \"password\"\r\n")

        self.assertInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        self.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        self.assertOutboundString("a OK yo\r\n")
    }

    // We previously had a bug where the response encode buffer was dropped with every
    // individual server response, meaning we lost the state. We need to state to insert
    // correct spaces in between streaming fetch attributes. This test prevents regression.
    @Test("fetch responses include spaces")
    mutating func fetchResponsesIncludeSpaces() {
        // note that the same handler (and therefore the same `ResponseEncodeBuffer` is used
        // throughout the test
        self.handler = IMAPServerHandler()
        self.channel = EmbeddedChannel(handler: self.handler)
        defer {
            _ = try? self.channel.finish()
        }

        // single attribute
        self.writeOutbound(.fetch(.start(1)), wait: false)
        self.assertOutboundString("* 1 FETCH (")

        // multiple attributes
        self.writeOutbound(.fetch(.start(2)), wait: false)
        self.assertOutboundString("* 2 FETCH (")
        self.writeOutbound(.fetch(.simpleAttribute(.flags([.answered, .draft]))), wait: false)
        self.assertOutboundString("FLAGS (\\Answered \\Draft)")
        self.writeOutbound(.fetch(.simpleAttribute(.uid(999))), wait: false)
        self.assertOutboundString(" UID 999")
        self.writeOutbound(.fetch(.simpleAttribute(.rfc822Size(876))), wait: false)
        self.assertOutboundString(" RFC822.SIZE 876")
        self.writeOutbound(.fetch(.finish), wait: false)
        self.assertOutboundString(")\r\n")

        // multiple attributes with streaming
        self.writeOutbound(.fetch(.start(2)), wait: false)
        self.assertOutboundString("* 2 FETCH (")
        self.writeOutbound(.fetch(.simpleAttribute(.flags([.answered, .draft]))), wait: false)
        self.assertOutboundString("FLAGS (\\Answered \\Draft)")
        self.writeOutbound(.fetch(.simpleAttribute(.uid(999))), wait: false)
        self.assertOutboundString(" UID 999")
        self.writeOutbound(.fetch(.streamingBegin(kind: .rfc822, byteCount: 5)), wait: false)
        self.assertOutboundString(" RFC822 {5}\r\n")
        self.writeOutbound(.fetch(.streamingBytes("12345")), wait: false)
        self.assertOutboundString("12345")
        self.writeOutbound(.fetch(.streamingEnd), wait: false)
        self.assertOutboundString("")
        self.writeOutbound(.fetch(.simpleAttribute(.rfc822Size(876))), wait: false)
        self.assertOutboundString(" RFC822.SIZE 876")
        self.writeOutbound(.fetch(.finish), wait: false)
        self.assertOutboundString(")\r\n")
    }

    @Test("authentication flow")
    mutating func authenticationFlow() {
        self.handler = IMAPServerHandler()
        self.channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), self.handler])
        defer {
            _ = try? self.channel.finish()
        }

        // client starts authentication
        self.writeInbound("A1 AUTHENTICATE GSSAPI\r\n")
        self.assertInbound(.tagged(.init(tag: "A1", command: .authenticate(mechanism: .gssAPI, initialResponse: nil))))

        // server sends challenge
        self.writeOutbound(.authenticationChallenge("challenge1"))
        self.assertOutboundBuffer("+ Y2hhbGxlbmdlMQ==\r\n")

        // client responds
        self.writeInbound("cmVzcG9uc2Ux\r\n")
        self.assertInbound(.continuationResponse("response1"))

        // server challenge 2
        self.writeOutbound(.authenticationChallenge("challenge2"))
        self.assertOutboundBuffer("+ Y2hhbGxlbmdlMg==\r\n")

        // client responds
        self.writeInbound("cmVzcG9uc2Uy\r\n")
        self.assertInbound(.continuationResponse("response2"))

        // server challenge 3 (empty)
        self.writeOutbound(.authenticationChallenge(""))
        self.assertOutboundBuffer("+ \r\n")

        // client responds
        self.writeInbound("cmVzcG9uc2Uz\r\n")
        self.assertInbound(.continuationResponse("response3"))

        // all done
        self.writeOutbound(.tagged(.init(tag: "A1", state: .ok(.init(text: "Success")))))
        self.assertOutboundBuffer("A1 OK Success\r\n")
    }

    @Test("append")
    mutating func append() {
        self.handler = IMAPServerHandler(
            continuationRequest: .responseText(ResponseText(text: "Ready for literal data"))
        )
        self.channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), self.handler])
        defer {
            _ = try? self.channel.finish()
        }

        self.writeInbound("A1 APPEND saved-messages (\\Seen) {12}\r\n")
        self.assertInbound(.append(.start(tag: "A1", appendingTo: MailboxName("saved-messages"))))
        self.assertInbound(
            .append(
                .beginMessage(
                    message: AppendMessage(
                        options: AppendOptions(flagList: [.seen]),
                        data: AppendData(byteCount: 12)
                    )
                )
            )
        )

        self.channel.read()
        self.assertOutboundBuffer("+ Ready for literal data\r\n")

        self.writeInbound("012345678901")
        self.assertInbound(.append(.messageBytes(ByteBuffer(string: "012345678901"))))

        self.writeInbound("\r\n")
        self.assertInbound(.append(.endMessage))
        self.assertInbound(.append(.finish))

        self.channel.read()
        self.assertOutboundBufferEmpty()

        self.writeOutbound(.tagged(TaggedResponse(tag: "A1", state: .ok(.init(text: "Done appending")))))
        self.assertOutboundBuffer("A1 OK Done appending\r\n")

        self.writeInbound("A2 NOOP\r\n")
        self.assertInbound(.tagged(.init(tag: "A2", command: .noop)))
        self.channel.read()
        self.assertOutboundBufferEmpty()
    }

}

// MARK: - Helpers

extension IMAPServerHandlerTests {
    private func assertInbound(_ command: CommandStreamPart, line: UInt = #line) {
        var maybeRead: CommandStreamPart?
        #expect(throws: Never.self) {
            maybeRead = try self.channel.readInbound()
        }
        guard let read = maybeRead else {
            Issue.record("Inbound buffer empty")
            return
        }
        #expect(command == read)
    }

    private func assertOutboundBuffer(_ buffer: ByteBuffer, line: UInt = #line) {
        var maybeRead: ByteBuffer?
        #expect(throws: Never.self) {
            maybeRead = try self.channel.readOutbound()
        }
        guard let read = maybeRead else {
            Issue.record("Outbound buffer empty")
            return
        }
        #expect(buffer == read, "\(String(buffer: buffer)) != \(String(buffer: read))")
    }

    private func assertOutboundBufferEmpty(line: UInt = #line) {
        var maybeRead: ByteBuffer?
        #expect(throws: Never.self) {
            maybeRead = try self.channel.readOutbound()
        }
        #expect(maybeRead.map { String(buffer: $0) } == nil)
    }

    private func assertOutboundString(_ string: String, line: UInt = #line) {
        var buffer = self.channel.allocator.buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        self.assertOutboundBuffer(buffer, line: line)
    }

    private func writeInbound(_ string: String, line: UInt = #line) {
        #expect(throws: Never.self) {
            try self.channel.writeInbound(self.buffer(string: string))
        }
    }

    @discardableResult
    private func writeOutbound(_ response: Response, wait: Bool = true, line: UInt = #line) -> EventLoopFuture<Void> {
        let result = self.channel.writeAndFlush(response)
        if wait {
            #expect(throws: Never.self) {
                try result.wait()
            }
        }
        return result
    }

    private func buffer(string: String) -> ByteBuffer {
        var buffer = self.channel.allocator.buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        return buffer
    }
}
