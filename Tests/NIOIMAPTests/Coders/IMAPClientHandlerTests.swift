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
        let challengeBytes1 = ""
        self.writeInbound("+ \(challengeBytes1)\r\n")
        self.assertInbound(.authenticationChallenge(ByteBuffer()))

        // client responds
        let responseBytes1 = "YIIB+wYJKoZIhvcSAQICAQBuggHqMIIB5qADAgEFoQMCAQ6iBwMFACAAAACjggEmYYIBIjCCAR6gAwIBBaESGxB1Lndhc2hpbmd0b24uZWR1oi0wK6ADAgEDoSQwIhsEaW1hcBsac2hpdmFtcy5jYWMud2FzaGluZ3Rvbi5lZHWjgdMwgdCgAwIBAaEDAgEDooHDBIHAcS1GSa5b+fXnPZNmXB9SjL8Ollj2SKyb+3S0iXMljen/jNkpJXAleKTz6BQPzj8duz8EtoOuNfKgweViyn/9B9bccy1uuAE2HI0yC/PHXNNU9ZrBziJ8Lm0tTNc98kUpjXnHZhsMcz5Mx2GR6dGknbI0iaGcRerMUsWOuBmKKKRmVMMdR9T3EZdpqsBd7jZCNMWotjhivd5zovQlFqQ2Wjc2+y46vKP/iXxWIuQJuDiisyXF0Y8+5GTpALpHDc1/pIGmMIGjoAMCAQGigZsEgZg2on5mSuxoDHEA1w9bcW9nFdFxDKpdrQhVGVRDIzcCMCTzvUboqb5KjY1NJKJsfjRQiBYBdENKfzK+g5DlV8nrw81uOcP8NOQCLR5XkoMHC0Dr/80ziQzbNqhxO6652Npft0LQwJvenwDI13YxpwOdMXzkWZN/XrEqOWp6GCgXTBvCyLWLlWnbaUkZdEYbKHBPjd8t/1x5Yg=="
        self.writeOutbound(.continuationResponse(ByteBuffer(bytes: [
            0x60,0x82,0x01,0xfb,0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x12,0x01,0x02,0x02,0x01,0x00,
            0x6e,0x82,0x01,0xea,0x30,0x82,0x01,0xe6,0xa0,0x03,0x02,0x01,0x05,0xa1,0x03,0x02,0x01,
            0x0e,0xa2,0x07,0x03,0x05,0x00,0x20,0x00,0x00,0x00,0xa3,0x82,0x01,0x26,0x61,0x82,0x01,
            0x22,0x30,0x82,0x01,0x1e,0xa0,0x03,0x02,0x01,0x05,0xa1,0x12,0x1b,0x10,0x75,0x2e,0x77,
            0x61,0x73,0x68,0x69,0x6e,0x67,0x74,0x6f,0x6e,0x2e,0x65,0x64,0x75,0xa2,0x2d,0x30,0x2b,
            0xa0,0x03,0x02,0x01,0x03,0xa1,0x24,0x30,0x22,0x1b,0x04,0x69,0x6d,0x61,0x70,0x1b,0x1a,
            0x73,0x68,0x69,0x76,0x61,0x6d,0x73,0x2e,0x63,0x61,0x63,0x2e,0x77,0x61,0x73,0x68,0x69,
            0x6e,0x67,0x74,0x6f,0x6e,0x2e,0x65,0x64,0x75,0xa3,0x81,0xd3,0x30,0x81,0xd0,0xa0,0x03,
            0x02,0x01,0x01,0xa1,0x03,0x02,0x01,0x03,0xa2,0x81,0xc3,0x04,0x81,0xc0,0x71,0x2d,0x46,
            0x49,0xae,0x5b,0xf9,0xf5,0xe7,0x3d,0x93,0x66,0x5c,0x1f,0x52,0x8c,0xbf,0x0e,0x96,0x58,
            0xf6,0x48,0xac,0x9b,0xfb,0x74,0xb4,0x89,0x73,0x25,0x8d,0xe9,0xff,0x8c,0xd9,0x29,0x25,
            0x70,0x25,0x78,0xa4,0xf3,0xe8,0x14,0x0f,0xce,0x3f,0x1d,0xbb,0x3f,0x04,0xb6,0x83,0xae,
            0x35,0xf2,0xa0,0xc1,0xe5,0x62,0xca,0x7f,0xfd,0x07,0xd6,0xdc,0x73,0x2d,0x6e,0xb8,0x01,
            0x36,0x1c,0x8d,0x32,0x0b,0xf3,0xc7,0x5c,0xd3,0x54,0xf5,0x9a,0xc1,0xce,0x22,0x7c,0x2e,
            0x6d,0x2d,0x4c,0xd7,0x3d,0xf2,0x45,0x29,0x8d,0x79,0xc7,0x66,0x1b,0x0c,0x73,0x3e,0x4c,
            0xc7,0x61,0x91,0xe9,0xd1,0xa4,0x9d,0xb2,0x34,0x89,0xa1,0x9c,0x45,0xea,0xcc,0x52,0xc5,
            0x8e,0xb8,0x19,0x8a,0x28,0xa4,0x66,0x54,0xc3,0x1d,0x47,0xd4,0xf7,0x11,0x97,0x69,0xaa,
            0xc0,0x5d,0xee,0x36,0x42,0x34,0xc5,0xa8,0xb6,0x38,0x62,0xbd,0xde,0x73,0xa2,0xf4,0x25,
            0x16,0xa4,0x36,0x5a,0x37,0x36,0xfb,0x2e,0x3a,0xbc,0xa3,0xff,0x89,0x7c,0x56,0x22,0xe4,
            0x09,0xb8,0x38,0xa2,0xb3,0x25,0xc5,0xd1,0x8f,0x3e,0xe4,0x64,0xe9,0x00,0xba,0x47,0x0d,
            0xcd,0x7f,0xa4,0x81,0xa6,0x30,0x81,0xa3,0xa0,0x03,0x02,0x01,0x01,0xa2,0x81,0x9b,0x04,
            0x81,0x98,0x36,0xa2,0x7e,0x66,0x4a,0xec,0x68,0x0c,0x71,0x00,0xd7,0x0f,0x5b,0x71,0x6f,
            0x67,0x15,0xd1,0x71,0x0c,0xaa,0x5d,0xad,0x08,0x55,0x19,0x54,0x43,0x23,0x37,0x02,0x30,
            0x24,0xf3,0xbd,0x46,0xe8,0xa9,0xbe,0x4a,0x8d,0x8d,0x4d,0x24,0xa2,0x6c,0x7e,0x34,0x50,
            0x88,0x16,0x01,0x74,0x43,0x4a,0x7f,0x32,0xbe,0x83,0x90,0xe5,0x57,0xc9,0xeb,0xc3,0xcd,
            0x6e,0x39,0xc3,0xfc,0x34,0xe4,0x02,0x2d,0x1e,0x57,0x92,0x83,0x07,0x0b,0x40,0xeb,0xff,
            0xcd,0x33,0x89,0x0c,0xdb,0x36,0xa8,0x71,0x3b,0xae,0xb9,0xd8,0xda,0x5f,0xb7,0x42,0xd0,
            0xc0,0x9b,0xde,0x9f,0x00,0xc8,0xd7,0x76,0x31,0xa7,0x03,0x9d,0x31,0x7c,0xe4,0x59,0x93,
            0x7f,0x5e,0xb1,0x2a,0x39,0x6a,0x7a,0x18,0x28,0x17,0x4c,0x1b,0xc2,0xc8,0xb5,0x8b,0x95,
            0x69,0xdb,0x69,0x49,0x19,0x74,0x46,0x1b,0x28,0x70,0x4f,0x8d,0xdf,0x2d,0xff,0x5c,0x79,
            0x62
        ])))
        self.assertOutboundString("\(responseBytes1)\r\n")

        // server challenge 2
        let challengeBytes2 = "YGgGCSqGSIb3EgECAgIAb1kwV6ADAgEFoQMCAQ+iSzBJoAMCAQGiQgRAtHTEuOP2BXb9sBYFR4SJlDZxmg39IxmRBOhXRKdDA0uHTCOT9Bq3OsUTXUlk0CsFLoa8j+gvGDlgHuqzWHPSQg=="
        self.writeInbound("+ \(challengeBytes2)\r\n")
        self.assertInbound(.authenticationChallenge(ByteBuffer(bytes: [
            0x60,0x68,0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x12,0x01,0x02,0x02,0x02,0x00,0x6f,0x59,
            0x30,0x57,0xa0,0x03,0x02,0x01,0x05,0xa1,0x03,0x02,0x01,0x0f,0xa2,0x4b,0x30,0x49,0xa0,
            0x03,0x02,0x01,0x01,0xa2,0x42,0x04,0x40,0xb4,0x74,0xc4,0xb8,0xe3,0xf6,0x05,0x76,0xfd,
            0xb0,0x16,0x05,0x47,0x84,0x89,0x94,0x36,0x71,0x9a,0x0d,0xfd,0x23,0x19,0x91,0x04,0xe8,
            0x57,0x44,0xa7,0x43,0x03,0x4b,0x87,0x4c,0x23,0x93,0xf4,0x1a,0xb7,0x3a,0xc5,0x13,0x5d,
            0x49,0x64,0xd0,0x2b,0x05,0x2e,0x86,0xbc,0x8f,0xe8,0x2f,0x18,0x39,0x60,0x1e,0xea,0xb3,
            0x58,0x73,0xd2,0x42
        ])))

        // client responds
        self.writeOutbound(.continuationResponse(""))
        self.assertOutboundString("\r\n")

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
    
    private func writeInbound(_ bytes: ByteBuffer, line: UInt = #line) {
        XCTAssertNoThrow(try self.channel.writeInbound(bytes), line: line)
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
