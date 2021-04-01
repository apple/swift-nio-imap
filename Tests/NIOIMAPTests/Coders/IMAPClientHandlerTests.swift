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
import XCTest

class IMAPClientHandlerTests: XCTestCase {
    var channel: EmbeddedChannel!
    var clientHandler: IMAPClientHandler!

    // MARK: - Tests

    func testBasicCommandAndResponse() {
        self.writeOutbound(.command(.init(tag: "a", command: .login(username: "foo", password: "bar"))))
        self.assertOutboundString("a LOGIN \"foo\" \"bar\"\r\n")
        self.writeInbound("a OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "a",
                                                 state: .ok(.init(code: nil, text: "ok")))))
    }

    func testReferralURLResponse() {
        let expectedResponse = Response.taggedResponse(
            TaggedResponse(tag: "tag",
                           state: .ok(ResponseText(code:
                               .referral(IMAPURL(server: IMAPServer(userAuthenticationMechanism: nil, host: "hostname", port: nil),
                                                 query: IPathQuery(command: ICommand.messagePart(
                                                     part: IMessagePart(
                                                         mailboxReference: IMailboxReference(encodeMailbox: EncodedMailbox(mailbox: "foo/bar"),
                                                                                             uidValidity: nil),
                                                         iUID: IUID(uid: 1234),
                                                         iSection: nil,
                                                         iPartial: nil
                                                     ),
                                                     authenticatedURL: nil
                                                 )))),
                               text: ""))))
        self.writeOutbound(.command(.init(tag: "a", command: .login(username: "foo", password: "bar"))))
        self.assertOutboundString("a LOGIN \"foo\" \"bar\"\r\n")
        self.writeInbound("tag OK [REFERRAL imap://hostname/foo/bar/;UID=1234]\r\na OK ok\r\n")
        self.assertInbound(expectedResponse)
        self.assertInbound(.taggedResponse(.init(tag: "a",
                                                 state: .ok(.init(code: nil, text: "ok")))))
    }

    func testCommandThatNeedsToWaitForContinuationRequest() {
        let f = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
                                                                       command: .rename(from: .init("\\"),
                                                                                        to: .init("to"),
                                                                                        params: [:]))),
        wait: false)
        self.assertOutboundString("x RENAME {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\\ \"to\"\r\n")
        XCTAssertNoThrow(try f.wait())
        self.writeInbound("x OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "x",
                                                 state: .ok(.init(code: nil, text: "ok")))))
    }

    func testCommandThatNeedsToWaitForTwoContinuationRequest() {
        let f = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
                                                                       command: .rename(from: .init("\\"),
                                                                                        to: .init("\""),
                                                                                        params: [:]))),
        wait: false)
        self.assertOutboundString("x RENAME {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\\ {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\"\r\n")
        XCTAssertNoThrow(try f.wait())
        self.writeInbound("x OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "x",
                                                 state: .ok(.init(code: nil, text: "ok")))))
    }

    // TODO: Make a new state machine that can handle pipelined commands and uncomment this test
//    func testTwoContReqCommandsEnqueued() {
//        let f1 = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
//                                                                        command: .rename(from: .init("\\"),
//                                                                                         to: .init("to"),
//                                                                                         params: [:]))),
//        wait: false)
//        let f2 = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "y",
//                                                                        command: .rename(from: .init("from"),
//                                                                                         to: .init("\\"),
//                                                                                         params: [:]))),
//        wait: false)
//        self.assertOutboundString("x RENAME {1}\r\n")
//        self.writeInbound("+ OK\r\n")
//        XCTAssertNoThrow(try f1.wait())
//        self.assertOutboundString("\\ \"to\"\r\n")
//        self.assertOutboundString("y RENAME \"from\" {1}\r\n")
//        self.writeInbound("+ OK\r\n")
//        XCTAssertNoThrow(try f2.wait())
//        self.assertOutboundString("\\\r\n")
//        self.writeInbound("x OK ok\r\n")
//        self.assertInbound(.taggedResponse(.init(tag: "x",
//                                                 state: .ok(.init(code: nil, text: "ok")))))
//        self.writeInbound("y OK ok\r\n")
//        self.assertInbound(.taggedResponse(.init(tag: "y",
//                                                 state: .ok(.init(code: nil, text: "ok")))))
//    }

    func testUnexpectedContinuationRequest() {
        let f = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
                                                                       command: .rename(from: .init("\\"),
                                                                                        to: .init("to"),
                                                                                        params: [:]))),
        wait: false)
        self.assertOutboundString("x RENAME {1}\r\n")
        XCTAssertThrowsError(try self.channel.writeInbound(self.buffer(string: "+ OK\r\n+ OK\r\n"))) { error in
            XCTAssertTrue(error is IMAPClientHandler.UnexpectedContinuationRequest, "Error is \(error)")
        }
        self.assertOutboundString("\\ \"to\"\r\n")
        XCTAssertNoThrow(try f.wait())
        self.writeInbound("x OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "x",
                                                 state: .ok(.init(code: nil, text: "ok")))))
    }

    func testAuthenticationFlow() {
        // client starts authentication
        self.writeOutbound(.command(.init(tag: "A1", command: .authenticate(method: .gssAPI, initialClientResponse: nil))))
        self.assertOutboundString("A1 AUTHENTICATE GSSAPI\r\n")

        // server sends challenge
        self.writeInbound("+ Y2hhbGxlbmdlMQ==\r\n")
        self.assertInbound(.authenticationChallenge("challenge1"))

        // client responds
        self.writeOutbound(.continuationResponse("response1"))
        self.assertOutboundString("cmVzcG9uc2Ux\r\n")

        // server challenge 2
        self.writeInbound("+ Y2hhbGxlbmdlMg==\r\n")
        self.assertInbound(.authenticationChallenge("challenge2"))

        // client responds
        self.writeOutbound(.continuationResponse("response2"))
        self.assertOutboundString("cmVzcG9uc2Uy\r\n")

        // server challenge 3 (empty)
        self.writeInbound("+ \r\n")
        self.assertInbound(.authenticationChallenge(""))

        // client responds
        self.writeOutbound(.continuationResponse("response3"))
        self.assertOutboundString("cmVzcG9uc2Uz\r\n")

        // all done
        self.writeInbound("A1 OK Success\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "A1", state: .ok(.init(text: "Success")))))
    }

    func testCanChangeEncodingOnCallback() {
        let turnOnLiteralPlusExpectation = XCTestExpectation(description: "Turn on literal +")

        self.clientHandler = IMAPClientHandler(encodingChangeCallback: { info, options in
            if info["name"] == "NIOIMAP" {
                turnOnLiteralPlusExpectation.fulfill()
            } else {
                XCTFail("No idea where this info was sent from, but we didn't send it")
            }
            options.useNonSynchronizingLiteralPlus = true
        })
        self.channel = EmbeddedChannel(handler: self.clientHandler, loop: .init())

        self.writeOutbound(.command(.init(tag: "A1", command: .login(username: "\\", password: "\\"))), wait: false)
        self.assertOutboundString("A1 LOGIN {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\\ {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\\\r\n")

        // send some capabilities
        self.writeInbound("A1 OK [CAPABILITY LITERAL+]\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "A1", state: .ok(.init(code: .capability([.literalPlus]), text: "")))))

        // send the server ID (client sends a noop
        self.writeOutbound(.command(.init(tag: "A2", command: .noop)), wait: false)
        self.assertOutboundString("A2 NOOP\r\n")
        self.writeInbound("* ID (\"name\" \"NIOIMAP\")\r\n")
        self.assertInbound(.untaggedResponse(.id(["name": "NIOIMAP"])))
        wait(for: [turnOnLiteralPlusExpectation], timeout: 1.0)
        self.writeInbound("A2 OK NOOP complete\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "A2", state: .ok(.init(text: "NOOP complete")))))

        // now we should have literal+ turned on
        self.writeOutbound(.command(.init(tag: "A3", command: .login(username: "\\", password: "\\"))), wait: false)
        self.assertOutboundString("A3 LOGIN {1+}\r\n\\ {1+}\r\n\\\r\n")
    }

    func testContinuationRequestsAsUserEvents() {
        let eventExpectation1 = self.channel.eventLoop.makePromise(of: Void.self)
        let eventExpectation2 = self.channel.eventLoop.makePromise(of: Void.self)
        let eventExpectation3 = self.channel.eventLoop.makePromise(of: Void.self)

        class UserEventHandler: ChannelDuplexHandler {
            typealias InboundIn = Response

            typealias OutboundIn = CommandStream

            var expectation1: EventLoopPromise<Void>
            var expectation2: EventLoopPromise<Void>
            var expectation3: EventLoopPromise<Void>

            init(expectation1: EventLoopPromise<Void>, expectation2: EventLoopPromise<Void>, expectation3: EventLoopPromise<Void>) {
                self.expectation1 = expectation1
                self.expectation2 = expectation2
                self.expectation3 = expectation3
            }

            public func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
                guard let event = event as? ContinuationRequest, case .responseText(let textEvent) = event else {
                    XCTFail()
                    return
                }
                switch textEvent.text {
                case "1": self.expectation1.succeed(())
                case "2": self.expectation2.succeed(())
                case "3": self.expectation3.succeed(())
                default:
                    XCTFail("Not sure who sent this event, but it wasn't us")
                }
            }
        }

        try! self.channel.pipeline.addHandler(UserEventHandler(
            expectation1: eventExpectation1,
            expectation2: eventExpectation2,
            expectation3: eventExpectation3
        )).wait()

        // confirm it works for literals
        self.writeOutbound(.command(.init(tag: "A1", command: .login(username: "\\", password: "\\"))), wait: false)
        self.assertOutboundString("A1 LOGIN {1}\r\n")
        self.writeInbound("+ 1\r\n")
        try! eventExpectation1.futureResult.wait()
        self.assertOutboundString("\\ {1}\r\n")
        self.writeInbound("+ 2\r\n")
        try! eventExpectation2.futureResult.wait()
        self.assertOutboundString("\\\r\n")

        // now confirm idle
        self.writeOutbound(.command(.init(tag: "A2", command: .idleStart)), wait: false)
        self.assertOutboundString("A2 IDLE\r\n")
        self.writeInbound("+ 3\r\n")
        try! eventExpectation3.futureResult.wait()
        self.assertInbound(.idleStarted)
        self.writeOutbound(.idleDone)
        self.assertOutboundString("DONE\r\n")
    }
    
    func testProtectAgainstReentrancy() {
        
        struct MyOutboundEvent {}
        
        class PreTestHandler: ChannelDuplexHandler {
            typealias InboundIn = ByteBuffer
            typealias InboundOut = ByteBuffer
            typealias OutboundIn = ByteBuffer
            
            func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
                let data = self.wrapInboundOut(ByteBuffer(string: "+ \r\n"))
                context.fireChannelRead(data)
                promise?.succeed(())
            }
            
            func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
                XCTAssert(event is MyOutboundEvent)
                let data = self.wrapInboundOut(ByteBuffer(string: "A1 OK NOOP complete\r\n"))
                context.fireChannelRead(data)
                promise?.succeed(())
            }
        }
        
        
        class PostTestHandler: ChannelDuplexHandler {
            typealias InboundIn = Response
            typealias OutboundIn = Response
            
            var callCount = 0
            
            func channelRead(context: ChannelHandlerContext, data: NIOAny) {
                self.callCount += 1
                if self.callCount < 3 {
                    context.triggerUserOutboundEvent(MyOutboundEvent(), promise: nil)
                }
            }
            
            func errorCaught(context: ChannelHandlerContext, error: Error) {
                XCTFail("Unexpected error \(error)")
            }
        }
        
        XCTAssertNoThrow(try self.channel.pipeline.addHandlers([
            PreTestHandler(),
            IMAPClientHandler(),
            PostTestHandler(),
        ]).wait())
        self.writeOutbound(.command(.init(tag: "A1", command: .idleStart)))
    }

    // MARK: - setup / tear down

    override func setUp() {
        XCTAssertNil(self.channel)
        self.clientHandler = IMAPClientHandler()
        self.channel = EmbeddedChannel(handler: self.clientHandler)
    }

    override func tearDown() {
        XCTAssertNotNil(self.channel)
        XCTAssertNoThrow(XCTAssertTrue(try self.channel.finish().isClean))
        self.channel = nil
    }
}

// MARK: - Helpers

extension IMAPClientHandlerTests {
    private func assertInbound(_ response: Response, line: UInt = #line) {
        var maybeRead: Response?
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
