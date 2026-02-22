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
    @Test("simple command and response")
    func simpleCommandAndResponse() {
        let helper = Helper()
        defer {
            _ = try? helper.channel.finish()
        }
        helper.writeInbound("a LOGIN \"user\" \"password\"\r\n")
        helper.expectInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        helper.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        helper.expectOutboundString("a OK yo\r\n")
    }

    @Test("simple command with continuation request works")
    func simpleCommandWithContinuationRequestWorks() {
        let helper = Helper()
        defer {
            _ = try? helper.channel.finish()
        }
        helper.writeInbound("a LOGIN {4}\r\n")
        var result: CommandStreamPart?
        #expect(throws: Never.self) {
            result = try helper.channel.readInbound(as: CommandStreamPart.self)
        }
        #expect(result == nil)

        // Nothing happens until `read()`
        var outbound: ByteBuffer?
        #expect(throws: Never.self) {
            outbound = try helper.channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(outbound == nil)

        helper.channel.read()
        helper.expectOutboundString("+ OK\r\n")

        helper.writeInbound("user \"password\"\r\n")

        helper.expectInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        helper.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        helper.expectOutboundString("a OK yo\r\n")
    }

    @Test("simple command with continuation request works even if client misbehaves and sends without waiting")
    func simpleCommandWithContinuationRequestWorksEvenIfClientMisbehavesAndSendsWithoutWaiting() {
        let helper = Helper()
        defer {
            _ = try? helper.channel.finish()
        }
        helper.writeInbound("a LOGIN {4}\r\nuser \"password\"\r\n")
        // Nothing happens until `read()`
        var outbound: ByteBuffer?
        #expect(throws: Never.self) {
            outbound = try helper.channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(outbound == nil)

        helper.expectInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        helper.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        helper.expectOutboundString("a OK yo\r\n")

        helper.channel.read()
        helper.expectOutboundString("+ OK\r\n")
    }

    @Test("setting continuation request on live handler")
    func settingContinuationRequestOnLiveHandler() {
        let helper = Helper()
        defer {
            _ = try? helper.channel.finish()
        }
        helper.handler.continuationRequest = ContinuationRequest.responseText(.init(text: "FoO"))

        helper.writeInbound("a LOGIN {4}\r\n")
        var result: CommandStreamPart?
        #expect(throws: Never.self) {
            result = try helper.channel.readInbound(as: CommandStreamPart.self)
        }
        #expect(result == nil)

        // Nothing happens until `read()`
        var outbound: ByteBuffer?
        #expect(throws: Never.self) {
            outbound = try helper.channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(outbound == nil)

        helper.channel.read()
        helper.expectOutboundString("+ FoO\r\n")

        helper.writeInbound("user \"password\"\r\n")

        helper.expectInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        helper.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        helper.expectOutboundString("a OK yo\r\n")
    }

    @Test("setting continuation request in init")
    mutating func settingContinuationRequestInInit() {
        let handler = IMAPServerHandler(continuationRequest: ContinuationRequest.responseText(.init(text: "FoO")))
        let helper = Helper(
            channel: EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), handler]),
            handler: handler
        )
        defer {
            _ = try? helper.channel.finish()
        }

        helper.writeInbound("a LOGIN {4}\r\n")
        var result: CommandStreamPart?
        #expect(throws: Never.self) {
            result = try helper.channel.readInbound(as: CommandStreamPart.self)
        }
        #expect(result == nil)

        // Nothing happens until `read()`
        var outbound: ByteBuffer?
        #expect(throws: Never.self) {
            outbound = try helper.channel.readOutbound(as: ByteBuffer.self)
        }
        #expect(outbound == nil)

        helper.channel.read()
        helper.expectOutboundString("+ FoO\r\n")

        helper.writeInbound("user \"password\"\r\n")

        helper.expectInbound(.tagged(.init(tag: "a", command: .login(username: "user", password: "password"))))
        helper.writeOutbound(.tagged(.init(tag: "a", state: .ok(.init(text: "yo")))))
        helper.expectOutboundString("a OK yo\r\n")
    }

    // We previously had a bug where the response encode buffer was dropped with every
    // individual server response, meaning we lost the state. We need to state to insert
    // correct spaces in between streaming fetch attributes. This test prevents regression.
    @Test("fetch responses include spaces")
    mutating func fetchResponsesIncludeSpaces() {
        // note that the same handler (and therefore the same `ResponseEncodeBuffer` is used
        // throughout the test
        let handler = IMAPServerHandler()
        let helper = Helper(
            channel: EmbeddedChannel(handler: handler),
            handler: handler
        )
        defer {
            _ = try? helper.channel.finish()
        }

        // single attribute
        helper.writeOutbound(.fetch(.start(1)), wait: false)
        helper.expectOutboundString("* 1 FETCH (")

        // multiple attributes
        helper.writeOutbound(.fetch(.start(2)), wait: false)
        helper.expectOutboundString("* 2 FETCH (")
        helper.writeOutbound(.fetch(.simpleAttribute(.flags([.answered, .draft]))), wait: false)
        helper.expectOutboundString("FLAGS (\\Answered \\Draft)")
        helper.writeOutbound(.fetch(.simpleAttribute(.uid(999))), wait: false)
        helper.expectOutboundString(" UID 999")
        helper.writeOutbound(.fetch(.simpleAttribute(.rfc822Size(876))), wait: false)
        helper.expectOutboundString(" RFC822.SIZE 876")
        helper.writeOutbound(.fetch(.finish), wait: false)
        helper.expectOutboundString(")\r\n")

        // multiple attributes with streaming
        helper.writeOutbound(.fetch(.start(2)), wait: false)
        helper.expectOutboundString("* 2 FETCH (")
        helper.writeOutbound(.fetch(.simpleAttribute(.flags([.answered, .draft]))), wait: false)
        helper.expectOutboundString("FLAGS (\\Answered \\Draft)")
        helper.writeOutbound(.fetch(.simpleAttribute(.uid(999))), wait: false)
        helper.expectOutboundString(" UID 999")
        helper.writeOutbound(.fetch(.streamingBegin(kind: .rfc822, byteCount: 5)), wait: false)
        helper.expectOutboundString(" RFC822 {5}\r\n")
        helper.writeOutbound(.fetch(.streamingBytes("12345")), wait: false)
        helper.expectOutboundString("12345")
        helper.writeOutbound(.fetch(.streamingEnd), wait: false)
        helper.expectOutboundString("")
        helper.writeOutbound(.fetch(.simpleAttribute(.rfc822Size(876))), wait: false)
        helper.expectOutboundString(" RFC822.SIZE 876")
        helper.writeOutbound(.fetch(.finish), wait: false)
        helper.expectOutboundString(")\r\n")
    }

    @Test("authentication flow")
    mutating func authenticationFlow() {
        let handler = IMAPServerHandler()
        let helper = Helper(
            channel: EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), handler]),
            handler: handler
        )
        defer {
            _ = try? helper.channel.finish()
        }

        // client starts authentication
        helper.writeInbound("A1 AUTHENTICATE GSSAPI\r\n")
        helper.expectInbound(.tagged(.init(tag: "A1", command: .authenticate(mechanism: .gssAPI, initialResponse: nil))))

        // server sends challenge
        helper.writeOutbound(.authenticationChallenge("challenge1"))
        helper.expectOutboundBuffer("+ Y2hhbGxlbmdlMQ==\r\n")

        // client responds
        helper.writeInbound("cmVzcG9uc2Ux\r\n")
        helper.expectInbound(.continuationResponse("response1"))

        // server challenge 2
        helper.writeOutbound(.authenticationChallenge("challenge2"))
        helper.expectOutboundBuffer("+ Y2hhbGxlbmdlMg==\r\n")

        // client responds
        helper.writeInbound("cmVzcG9uc2Uy\r\n")
        helper.expectInbound(.continuationResponse("response2"))

        // server challenge 3 (empty)
        helper.writeOutbound(.authenticationChallenge(""))
        helper.expectOutboundBuffer("+ \r\n")

        // client responds
        helper.writeInbound("cmVzcG9uc2Uz\r\n")
        helper.expectInbound(.continuationResponse("response3"))

        // all done
        helper.writeOutbound(.tagged(.init(tag: "A1", state: .ok(.init(text: "Success")))))
        helper.expectOutboundBuffer("A1 OK Success\r\n")
    }

    @Test("append")
    mutating func append() {
        let handler = IMAPServerHandler(
            continuationRequest: .responseText(ResponseText(text: "Ready for literal data"))
        )
        let helper = Helper(
            channel: EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), handler]),
            handler: handler
        )
        defer {
            _ = try? helper.channel.finish()
        }

        helper.writeInbound("A1 APPEND saved-messages (\\Seen) {12}\r\n")
        helper.expectInbound(.append(.start(tag: "A1", appendingTo: MailboxName("saved-messages"))))
        helper.expectInbound(
            .append(
                .beginMessage(
                    message: AppendMessage(
                        options: AppendOptions(flagList: [.seen]),
                        data: AppendData(byteCount: 12)
                    )
                )
            )
        )

        helper.channel.read()
        helper.expectOutboundBuffer("+ Ready for literal data\r\n")

        helper.writeInbound("012345678901")
        helper.expectInbound(.append(.messageBytes(ByteBuffer(string: "012345678901"))))

        helper.writeInbound("\r\n")
        helper.expectInbound(.append(.endMessage))
        helper.expectInbound(.append(.finish))

        helper.channel.read()
        helper.expectOutboundBufferEmpty()

        helper.writeOutbound(.tagged(TaggedResponse(tag: "A1", state: .ok(.init(text: "Done appending")))))
        helper.expectOutboundBuffer("A1 OK Done appending\r\n")

        helper.writeInbound("A2 NOOP\r\n")
        helper.expectInbound(.tagged(.init(tag: "A2", command: .noop)))
        helper.channel.read()
        helper.expectOutboundBufferEmpty()
    }

}

// MARK: - Helper

extension IMAPServerHandlerTests {
    struct Helper {
        var channel: EmbeddedChannel
        var handler: IMAPServerHandler
    }
}

extension IMAPServerHandlerTests.Helper {
    init() {
        let handler = IMAPServerHandler()
        self.channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), handler])
        self.handler = handler
    }

    func expectInbound(_ command: CommandStreamPart, sourceLocation: SourceLocation = #_sourceLocation) {
        var maybeRead: CommandStreamPart?
        #expect(throws: Never.self, sourceLocation: sourceLocation) {
            maybeRead = try self.channel.readInbound()
        }
        guard let read = maybeRead else {
            Issue.record("Inbound buffer empty", sourceLocation: sourceLocation)
            return
        }
        #expect(command == read, sourceLocation: sourceLocation)
    }

    func expectOutboundBuffer(_ buffer: ByteBuffer, sourceLocation: SourceLocation = #_sourceLocation) {
        var maybeRead: ByteBuffer?
        #expect(throws: Never.self, sourceLocation: sourceLocation) {
            maybeRead = try self.channel.readOutbound()
        }
        guard let read = maybeRead else {
            Issue.record("Outbound buffer empty", sourceLocation: sourceLocation)
            return
        }
        #expect(buffer == read, "\(String(buffer: buffer)) != \(String(buffer: read))", sourceLocation: sourceLocation)
    }

    func expectOutboundBufferEmpty(sourceLocation: SourceLocation = #_sourceLocation) {
        var maybeRead: ByteBuffer?
        #expect(throws: Never.self, sourceLocation: sourceLocation) {
            maybeRead = try self.channel.readOutbound()
        }
        #expect(maybeRead.map { String(buffer: $0) } == nil, sourceLocation: sourceLocation)
    }

    func expectOutboundString(_ string: String, sourceLocation: SourceLocation = #_sourceLocation) {
        var buffer = self.channel.allocator.buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        self.expectOutboundBuffer(buffer, sourceLocation: sourceLocation)
    }

    func writeInbound(_ string: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: Never.self, sourceLocation: sourceLocation) {
            try self.channel.writeInbound(self.buffer(string: string))
        }
    }

    @discardableResult
    func writeOutbound(_ response: Response, wait: Bool = true, sourceLocation: SourceLocation = #_sourceLocation) -> EventLoopFuture<Void> {
        let result = self.channel.writeAndFlush(response)
        if wait {
            #expect(throws: Never.self, sourceLocation: sourceLocation) {
                try result.wait()
            }
        }
        return result
    }

    func buffer(string: String) -> ByteBuffer {
        var buffer = self.channel.allocator.buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        return buffer
    }
}
