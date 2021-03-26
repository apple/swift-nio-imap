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
                               .referral(IMAPURL(server: IMAPServer(userInfo: nil, host: "hostname", port: nil),
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

    func testTwoContReqCommandsEnqueued() {
        let f1 = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
                                                                        command: .rename(from: .init("\\"),
                                                                                         to: .init("to"),
                                                                                         params: [:]))),
        wait: false)
        let f2 = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "y",
                                                                        command: .rename(from: .init("from"),
                                                                                         to: .init("\\"),
                                                                                         params: [:]))),
        wait: false)
        self.assertOutboundString("x RENAME {1}\r\n")
        self.writeInbound("+ OK\r\n")
        XCTAssertNoThrow(try f1.wait())
        self.assertOutboundString("\\ \"to\"\r\n")
        self.assertOutboundString("y RENAME \"from\" {1}\r\n")
        self.writeInbound("+ OK\r\n")
        XCTAssertNoThrow(try f2.wait())
        self.assertOutboundString("\\\r\n")
        self.writeInbound("x OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "x",
                                                 state: .ok(.init(code: nil, text: "ok")))))
        self.writeInbound("y OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "y",
                                                 state: .ok(.init(code: nil, text: "ok")))))
    }

    func testUnexpectedContinuationRequest() {
        let f = self.writeOutbound(CommandStream.command(TaggedCommand(tag: "x",
                                                                       command: .rename(from: .init("\\"),
                                                                                        to: .init("to"),
                                                                                        params: [:]))),
        wait: false)
        self.assertOutboundString("x RENAME {1}\r\n")
        XCTAssertThrowsError(try self.channel.writeInbound(self.buffer(string: "+ OK\r\n+ OK\r\n"))) { error in
            XCTAssertTrue(error is IMAPClientHandler.UnexpectedContinuationRequest)
        }
        self.assertOutboundString("\\ \"to\"\r\n")
        XCTAssertNoThrow(try f.wait())
        self.writeInbound("x OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "x",
                                                 state: .ok(.init(code: nil, text: "ok")))))
    }

    func testStateTransformation() {
        let handler = IMAPClientHandler()
        let channel = EmbeddedChannel(handler: handler, loop: .init())

        // move into an idle state
        XCTAssertNoThrow(try channel.writeOutbound(CommandStream.command(.init(tag: "1", command: .idleStart))))
        XCTAssertEqual(handler._state, .expectingContinuations)
        XCTAssertNoThrow(try channel.readOutbound(as: ByteBuffer.self))
        XCTAssertNoThrow(XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self)))

        // send some continuations
        // in this case, 2 idle reminders
        var inEncodeBuffer = ResponseEncodeBuffer(buffer: ByteBuffer(), capabilities: [])
        inEncodeBuffer.writeContinuationRequest(.responseText(.init(text: "Waiting")))
        XCTAssertNoThrow(try channel.writeInbound(inEncodeBuffer.readBytes()))
        XCTAssertNoThrow(XCTAssertEqual(try channel.readInbound(), Response.idleStarted))
        XCTAssertNoThrow(XCTAssertNil(try channel.readInbound(as: Response.self)))
        inEncodeBuffer = ResponseEncodeBuffer(buffer: ByteBuffer(), capabilities: [])
        inEncodeBuffer.writeContinuationRequest(.responseText(.init(text: "Waiting")))
        XCTAssertNoThrow(try channel.writeInbound(inEncodeBuffer.readBytes()))
        XCTAssertNoThrow(XCTAssertEqual(try channel.readInbound(), Response.idleStarted))
        XCTAssertNoThrow(XCTAssertNil(try channel.readInbound(as: Response.self)))

        // finish being idle
        XCTAssertNoThrow(try channel.writeOutbound(CommandStream.idleDone))
        XCTAssertEqual(handler._state, .expectingResponses)
        XCTAssertNoThrow(try channel.readOutbound(as: ByteBuffer.self))
        XCTAssertNoThrow(XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self)))

        // start authentication
        XCTAssertNoThrow(try channel.writeOutbound(CommandStream.command(.init(tag: "A001", command: .authenticate(method: .init("GSSAPI"), initialClientResponse: nil)))))
        XCTAssertEqual(handler._state, .expectingContinuations)
        XCTAssertNoThrow(try channel.readOutbound(as: ByteBuffer.self))
        XCTAssertNoThrow(XCTAssertNil(try channel.readOutbound(as: ByteBuffer.self)))

        // server sends a challenge
        inEncodeBuffer = ResponseEncodeBuffer(buffer: ByteBuffer(), capabilities: [])
        inEncodeBuffer.writeContinuationRequest(.data(""))
        XCTAssertNoThrow(try channel.writeInbound(inEncodeBuffer.readBytes()))
        XCTAssertNoThrow(XCTAssertEqual(try channel.readInbound(), Response.idleStarted))

        // client responds
        let authString1 = """
        YIIB+wYJKoZIhvcSAQICAQBuggHqMIIB5qADAgEFoQMCAQ6iBw
        MFACAAAACjggEmYYIBIjCCAR6gAwIBBaESGxB1Lndhc2hpbmd0
        b24uZWR1oi0wK6ADAgEDoSQwIhsEaW1hcBsac2hpdmFtcy5jYW
        Mud2FzaGluZ3Rvbi5lZHWjgdMwgdCgAwIBAaEDAgEDooHDBIHA
        cS1GSa5b+fXnPZNmXB9SjL8Ollj2SKyb+3S0iXMljen/jNkpJX
        AleKTz6BQPzj8duz8EtoOuNfKgweViyn/9B9bccy1uuAE2HI0y
        C/PHXNNU9ZrBziJ8Lm0tTNc98kUpjXnHZhsMcz5Mx2GR6dGknb
        I0iaGcRerMUsWOuBmKKKRmVMMdR9T3EZdpqsBd7jZCNMWotjhi
        vd5zovQlFqQ2Wjc2+y46vKP/iXxWIuQJuDiisyXF0Y8+5GTpAL
        pHDc1/pIGmMIGjoAMCAQGigZsEgZg2on5mSuxoDHEA1w9bcW9n
        FdFxDKpdrQhVGVRDIzcCMCTzvUboqb5KjY1NJKJsfjRQiBYBdE
        NKfzK+g5DlV8nrw81uOcP8NOQCLR5XkoMHC0Dr/80ziQzbNqhx
        O6652Npft0LQwJvenwDI13YxpwOdMXzkWZN/XrEqOWp6GCgXTB
        vCyLWLlWnbaUkZdEYbKHBPjd8t/1x5Yg==
        """
        XCTAssertNoThrow(try channel.writeOutbound(CommandStream.continuationResponse(ByteBuffer(string: authString1))))
        XCTAssertEqual(handler._state, .expectingContinuations)
        XCTAssertEqual(try channel.readOutbound(as: ByteBuffer.self), ByteBuffer(string: "\r\n" + authString1))

        // server sends another challenge
        let challengeString1: ByteBuffer = """
            YGgGCSqGSIb3EgECAgIAb1kwV6ADAgEFoQMCAQ+iSzBJoAMC
            AQGiQgRAtHTEuOP2BXb9sBYFR4SJlDZxmg39IxmRBOhXRKdDA0
            uHTCOT9Bq3OsUTXUlk0CsFLoa8j+gvGDlgHuqzWHPSQg==
        """
        inEncodeBuffer = ResponseEncodeBuffer(buffer: ByteBuffer(), capabilities: [])
        inEncodeBuffer.writeContinuationRequest(.data(challengeString1))
        XCTAssertNoThrow(try channel.writeInbound(inEncodeBuffer.readBytes()))
        XCTAssertNoThrow(XCTAssertEqual(try channel.readInbound(), Response.idleStarted))

        // client responds
        XCTAssertNoThrow(try channel.writeOutbound(CommandStream.continuationResponse("")))
        XCTAssertEqual(handler._state, .expectingContinuations)
        XCTAssertEqual(try channel.readOutbound(as: ByteBuffer.self), "\r\n")

        // server sends another challenge
        let challengeString2: ByteBuffer = """
            YDMGCSqGSIb3EgECAgIBAAD/////6jcyG4GE3KkTzBeBiVHe
            ceP2CWY0SR0fAQAgAAQEBAQ=
        """
        inEncodeBuffer = ResponseEncodeBuffer(buffer: ByteBuffer(), capabilities: [])
        inEncodeBuffer.writeContinuationRequest(.data(challengeString2))
        XCTAssertNoThrow(try channel.writeInbound(inEncodeBuffer.readBytes()))
        XCTAssertNoThrow(XCTAssertEqual(try channel.readInbound(), Response.idleStarted))

        // client responds
        let authString2 = """
            YDMGCSqGSIb3EgECAgIBAAD/////3LQBHXTpFfZgrejpLlLImP
            wkhbfa2QteAQAgAG1yYwE=
        """
        XCTAssertNoThrow(try channel.writeOutbound(CommandStream.continuationResponse(ByteBuffer(string: authString2))))
        XCTAssertEqual(handler._state, .expectingContinuations)
        XCTAssertEqual(try channel.readOutbound(as: ByteBuffer.self), ByteBuffer(string: "\r\n" + authString2))

        // server finished
        inEncodeBuffer = ResponseEncodeBuffer(buffer: ByteBuffer(), capabilities: [])
        inEncodeBuffer.writeResponse(.taggedResponse(.init(tag: "A001", state: .ok(.init(text: "GSSAPI authentication successful")))))
        XCTAssertNoThrow(try channel.writeInbound(inEncodeBuffer.readBytes()))
        XCTAssertNoThrow(XCTAssertEqual(try channel.readInbound(), Response.taggedResponse(.init(tag: "A001", state: .ok(.init(text: "GSSAPI authentication successful"))))))
        XCTAssertEqual(handler._state, .expectingResponses)
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
