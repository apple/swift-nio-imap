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
        self.writeOutbound(.tagged(.init(tag: "a", command: .login(username: "foo", password: "bar"))))
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
                                                 query: URLCommand.fetch(
                                                     path: MessagePath(
                                                         mailboxReference: MailboxUIDValidity(encodeMailbox: EncodedMailbox(mailbox: "foo/bar"),
                                                                                              uidValidity: nil),
                                                         iUID: IUID(uid: 1234),
                                                         section: nil,
                                                         range: nil
                                                     ),
                                                     authenticatedURL: nil
                                                 ))),
                               text: ""))))
        self.writeOutbound(.tagged(.init(tag: "a", command: .login(username: "foo", password: "bar"))))
        self.assertOutboundString("a LOGIN \"foo\" \"bar\"\r\n")
        self.writeInbound("tag OK [REFERRAL imap://hostname/foo/bar/;UID=1234]\r\na OK ok\r\n")
        self.assertInbound(expectedResponse)
        self.assertInbound(.taggedResponse(.init(tag: "a",
                                                 state: .ok(.init(code: nil, text: "ok")))))
    }

    func testCommandThatNeedsToWaitForContinuationRequest() {
        let f = self.writeOutbound(CommandStream.tagged(TaggedCommand(tag: "x",
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
        let f = self.writeOutbound(CommandStream.tagged(TaggedCommand(tag: "x",
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
        let f1 = self.writeOutbound(CommandStream.tagged(TaggedCommand(tag: "x",
                                                                        command: .rename(from: .init("\\"),
                                                                                         to: .init("to"),
                                                                                         params: [:]))),
        wait: false)
        let f2 = self.writeOutbound(CommandStream.tagged(TaggedCommand(tag: "y",
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

    // This makes sure that we successfully switch from responding to continuation
    // requests back to "simple" commands that can be written in one shot. This was a bug
    // in a previous implementation, so this test prevents regression.
    func testThreeContReqCommandsEnqueuedFollowedBy2BasicOnes() {
        let f1 = self.writeOutbound(.tagged(.init(tag: "1", command: .create(.init("\\"), []))), wait: false)
        let f2 = self.writeOutbound(.tagged(.init(tag: "2", command: .create(.init("\\"), []))), wait: false)
        let f3 = self.writeOutbound(.tagged(.init(tag: "3", command: .create(.init("\\"), []))), wait: false)
        let f4 = self.writeOutbound(.tagged(.init(tag: "4", command: .create(.init("a"), []))), wait: false)
        let f5 = self.writeOutbound(.tagged(.init(tag: "5", command: .create(.init("b"), []))), wait: false)

        self.assertOutboundString("1 CREATE {1}\r\n")
        self.writeInbound("+ OK\r\n")
        XCTAssertNoThrow(try f1.wait())
        self.assertOutboundString("\\\r\n")

        self.assertOutboundString("2 CREATE {1}\r\n")
        self.writeInbound("+ OK\r\n")
        XCTAssertNoThrow(try f2.wait())
        self.assertOutboundString("\\\r\n")

        self.assertOutboundString("3 CREATE {1}\r\n")
        self.writeInbound("+ OK\r\n")
        XCTAssertNoThrow(try f3.wait())
        self.assertOutboundString("\\\r\n")

        self.assertOutboundString("4 CREATE \"a\"\r\n")
        XCTAssertNoThrow(try f4.wait())
        self.assertOutboundString("5 CREATE \"b\"\r\n")
        XCTAssertNoThrow(try f5.wait())

        self.writeInbound("1 OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "1",
                                                 state: .ok(.init(code: nil, text: "ok")))))
        self.writeInbound("2 OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "2",
                                                 state: .ok(.init(code: nil, text: "ok")))))

        self.writeInbound("3 OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "3",
                                                 state: .ok(.init(code: nil, text: "ok")))))

        self.writeInbound("4 OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "4",
                                                 state: .ok(.init(code: nil, text: "ok")))))

        self.writeInbound("5 OK ok\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "5",
                                                 state: .ok(.init(code: nil, text: "ok")))))
    }

    func testContinueRequestCommandFollowedByAuthenticate() {
        self.writeOutbound(.tagged(.init(tag: "1", command: .move(.lastCommand, .init("\\")))), wait: false)
        self.writeOutbound(.tagged(.init(tag: "2", command: .authenticate(mechanism: .gssAPI, initialResponse: nil))), wait: false)

        // send the move command
        self.assertOutboundString("1 MOVE $ {1}\r\n")
        self.writeInbound("+ OK\r\n")

        // respond to the continuation, move straight to authentication
        self.assertOutboundString("\\\r\n")
        self.assertOutboundString("2 AUTHENTICATE GSSAPI\r\n")

        // server sends an auth challenge
        self.writeInbound("+\r\n")
        self.assertInbound(.authenticationChallenge(""))
    }

    func testUnexpectedContinuationRequest() {
        let f = self.writeOutbound(CommandStream.tagged(TaggedCommand(tag: "x",
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
        self.writeOutbound(.tagged(.init(tag: "A1", command: .authenticate(mechanism: .gssAPI, initialResponse: nil))))
        self.assertOutboundString("A1 AUTHENTICATE GSSAPI\r\n")

        // server sends challenge
        let challengeBytes1 = ""
        self.writeInbound("+ \(challengeBytes1)\r\n")
        self.assertInbound(.authenticationChallenge(ByteBuffer()))

        // client responds
        let responseBytes1 = "YIIB+wYJKoZIhvcSAQICAQBuggHqMIIB5qADAgEFoQMCAQ6iBwMFACAAAACjggEmYYIBIjCCAR6gAwIBBaESGxB1Lndhc2hpbmd0b24uZWR1oi0wK6ADAgEDoSQwIhsEaW1hcBsac2hpdmFtcy5jYWMud2FzaGluZ3Rvbi5lZHWjgdMwgdCgAwIBAaEDAgEDooHDBIHAcS1GSa5b+fXnPZNmXB9SjL8Ollj2SKyb+3S0iXMljen/jNkpJXAleKTz6BQPzj8duz8EtoOuNfKgweViyn/9B9bccy1uuAE2HI0yC/PHXNNU9ZrBziJ8Lm0tTNc98kUpjXnHZhsMcz5Mx2GR6dGknbI0iaGcRerMUsWOuBmKKKRmVMMdR9T3EZdpqsBd7jZCNMWotjhivd5zovQlFqQ2Wjc2+y46vKP/iXxWIuQJuDiisyXF0Y8+5GTpALpHDc1/pIGmMIGjoAMCAQGigZsEgZg2on5mSuxoDHEA1w9bcW9nFdFxDKpdrQhVGVRDIzcCMCTzvUboqb5KjY1NJKJsfjRQiBYBdENKfzK+g5DlV8nrw81uOcP8NOQCLR5XkoMHC0Dr/80ziQzbNqhxO6652Npft0LQwJvenwDI13YxpwOdMXzkWZN/XrEqOWp6GCgXTBvCyLWLlWnbaUkZdEYbKHBPjd8t/1x5Yg=="
        self.writeOutbound(.continuationResponse(ByteBuffer(bytes: [
            0x60, 0x82, 0x01, 0xFB, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x12, 0x01, 0x02, 0x02, 0x01, 0x00,
            0x6E, 0x82, 0x01, 0xEA, 0x30, 0x82, 0x01, 0xE6, 0xA0, 0x03, 0x02, 0x01, 0x05, 0xA1, 0x03, 0x02, 0x01,
            0x0E, 0xA2, 0x07, 0x03, 0x05, 0x00, 0x20, 0x00, 0x00, 0x00, 0xA3, 0x82, 0x01, 0x26, 0x61, 0x82, 0x01,
            0x22, 0x30, 0x82, 0x01, 0x1E, 0xA0, 0x03, 0x02, 0x01, 0x05, 0xA1, 0x12, 0x1B, 0x10, 0x75, 0x2E, 0x77,
            0x61, 0x73, 0x68, 0x69, 0x6E, 0x67, 0x74, 0x6F, 0x6E, 0x2E, 0x65, 0x64, 0x75, 0xA2, 0x2D, 0x30, 0x2B,
            0xA0, 0x03, 0x02, 0x01, 0x03, 0xA1, 0x24, 0x30, 0x22, 0x1B, 0x04, 0x69, 0x6D, 0x61, 0x70, 0x1B, 0x1A,
            0x73, 0x68, 0x69, 0x76, 0x61, 0x6D, 0x73, 0x2E, 0x63, 0x61, 0x63, 0x2E, 0x77, 0x61, 0x73, 0x68, 0x69,
            0x6E, 0x67, 0x74, 0x6F, 0x6E, 0x2E, 0x65, 0x64, 0x75, 0xA3, 0x81, 0xD3, 0x30, 0x81, 0xD0, 0xA0, 0x03,
            0x02, 0x01, 0x01, 0xA1, 0x03, 0x02, 0x01, 0x03, 0xA2, 0x81, 0xC3, 0x04, 0x81, 0xC0, 0x71, 0x2D, 0x46,
            0x49, 0xAE, 0x5B, 0xF9, 0xF5, 0xE7, 0x3D, 0x93, 0x66, 0x5C, 0x1F, 0x52, 0x8C, 0xBF, 0x0E, 0x96, 0x58,
            0xF6, 0x48, 0xAC, 0x9B, 0xFB, 0x74, 0xB4, 0x89, 0x73, 0x25, 0x8D, 0xE9, 0xFF, 0x8C, 0xD9, 0x29, 0x25,
            0x70, 0x25, 0x78, 0xA4, 0xF3, 0xE8, 0x14, 0x0F, 0xCE, 0x3F, 0x1D, 0xBB, 0x3F, 0x04, 0xB6, 0x83, 0xAE,
            0x35, 0xF2, 0xA0, 0xC1, 0xE5, 0x62, 0xCA, 0x7F, 0xFD, 0x07, 0xD6, 0xDC, 0x73, 0x2D, 0x6E, 0xB8, 0x01,
            0x36, 0x1C, 0x8D, 0x32, 0x0B, 0xF3, 0xC7, 0x5C, 0xD3, 0x54, 0xF5, 0x9A, 0xC1, 0xCE, 0x22, 0x7C, 0x2E,
            0x6D, 0x2D, 0x4C, 0xD7, 0x3D, 0xF2, 0x45, 0x29, 0x8D, 0x79, 0xC7, 0x66, 0x1B, 0x0C, 0x73, 0x3E, 0x4C,
            0xC7, 0x61, 0x91, 0xE9, 0xD1, 0xA4, 0x9D, 0xB2, 0x34, 0x89, 0xA1, 0x9C, 0x45, 0xEA, 0xCC, 0x52, 0xC5,
            0x8E, 0xB8, 0x19, 0x8A, 0x28, 0xA4, 0x66, 0x54, 0xC3, 0x1D, 0x47, 0xD4, 0xF7, 0x11, 0x97, 0x69, 0xAA,
            0xC0, 0x5D, 0xEE, 0x36, 0x42, 0x34, 0xC5, 0xA8, 0xB6, 0x38, 0x62, 0xBD, 0xDE, 0x73, 0xA2, 0xF4, 0x25,
            0x16, 0xA4, 0x36, 0x5A, 0x37, 0x36, 0xFB, 0x2E, 0x3A, 0xBC, 0xA3, 0xFF, 0x89, 0x7C, 0x56, 0x22, 0xE4,
            0x09, 0xB8, 0x38, 0xA2, 0xB3, 0x25, 0xC5, 0xD1, 0x8F, 0x3E, 0xE4, 0x64, 0xE9, 0x00, 0xBA, 0x47, 0x0D,
            0xCD, 0x7F, 0xA4, 0x81, 0xA6, 0x30, 0x81, 0xA3, 0xA0, 0x03, 0x02, 0x01, 0x01, 0xA2, 0x81, 0x9B, 0x04,
            0x81, 0x98, 0x36, 0xA2, 0x7E, 0x66, 0x4A, 0xEC, 0x68, 0x0C, 0x71, 0x00, 0xD7, 0x0F, 0x5B, 0x71, 0x6F,
            0x67, 0x15, 0xD1, 0x71, 0x0C, 0xAA, 0x5D, 0xAD, 0x08, 0x55, 0x19, 0x54, 0x43, 0x23, 0x37, 0x02, 0x30,
            0x24, 0xF3, 0xBD, 0x46, 0xE8, 0xA9, 0xBE, 0x4A, 0x8D, 0x8D, 0x4D, 0x24, 0xA2, 0x6C, 0x7E, 0x34, 0x50,
            0x88, 0x16, 0x01, 0x74, 0x43, 0x4A, 0x7F, 0x32, 0xBE, 0x83, 0x90, 0xE5, 0x57, 0xC9, 0xEB, 0xC3, 0xCD,
            0x6E, 0x39, 0xC3, 0xFC, 0x34, 0xE4, 0x02, 0x2D, 0x1E, 0x57, 0x92, 0x83, 0x07, 0x0B, 0x40, 0xEB, 0xFF,
            0xCD, 0x33, 0x89, 0x0C, 0xDB, 0x36, 0xA8, 0x71, 0x3B, 0xAE, 0xB9, 0xD8, 0xDA, 0x5F, 0xB7, 0x42, 0xD0,
            0xC0, 0x9B, 0xDE, 0x9F, 0x00, 0xC8, 0xD7, 0x76, 0x31, 0xA7, 0x03, 0x9D, 0x31, 0x7C, 0xE4, 0x59, 0x93,
            0x7F, 0x5E, 0xB1, 0x2A, 0x39, 0x6A, 0x7A, 0x18, 0x28, 0x17, 0x4C, 0x1B, 0xC2, 0xC8, 0xB5, 0x8B, 0x95,
            0x69, 0xDB, 0x69, 0x49, 0x19, 0x74, 0x46, 0x1B, 0x28, 0x70, 0x4F, 0x8D, 0xDF, 0x2D, 0xFF, 0x5C, 0x79,
            0x62,
        ])))
        self.assertOutboundString("\(responseBytes1)\r\n")

        // server challenge 2
        let challengeBytes2 = "YGgGCSqGSIb3EgECAgIAb1kwV6ADAgEFoQMCAQ+iSzBJoAMCAQGiQgRAtHTEuOP2BXb9sBYFR4SJlDZxmg39IxmRBOhXRKdDA0uHTCOT9Bq3OsUTXUlk0CsFLoa8j+gvGDlgHuqzWHPSQg=="
        self.writeInbound("+ \(challengeBytes2)\r\n")
        self.assertInbound(.authenticationChallenge(ByteBuffer(bytes: [
            0x60, 0x68, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x12, 0x01, 0x02, 0x02, 0x02, 0x00, 0x6F, 0x59,
            0x30, 0x57, 0xA0, 0x03, 0x02, 0x01, 0x05, 0xA1, 0x03, 0x02, 0x01, 0x0F, 0xA2, 0x4B, 0x30, 0x49, 0xA0,
            0x03, 0x02, 0x01, 0x01, 0xA2, 0x42, 0x04, 0x40, 0xB4, 0x74, 0xC4, 0xB8, 0xE3, 0xF6, 0x05, 0x76, 0xFD,
            0xB0, 0x16, 0x05, 0x47, 0x84, 0x89, 0x94, 0x36, 0x71, 0x9A, 0x0D, 0xFD, 0x23, 0x19, 0x91, 0x04, 0xE8,
            0x57, 0x44, 0xA7, 0x43, 0x03, 0x4B, 0x87, 0x4C, 0x23, 0x93, 0xF4, 0x1A, 0xB7, 0x3A, 0xC5, 0x13, 0x5D,
            0x49, 0x64, 0xD0, 0x2B, 0x05, 0x2E, 0x86, 0xBC, 0x8F, 0xE8, 0x2F, 0x18, 0x39, 0x60, 0x1E, 0xEA, 0xB3,
            0x58, 0x73, 0xD2, 0x42,
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

        self.writeOutbound(.tagged(.init(tag: "A1", command: .login(username: "\\", password: "\\"))), wait: false)
        self.assertOutboundString("A1 LOGIN {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\\ {1}\r\n")
        self.writeInbound("+ OK\r\n")
        self.assertOutboundString("\\\r\n")

        // send some capabilities
        self.writeInbound("A1 OK [CAPABILITY LITERAL+]\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "A1", state: .ok(.init(code: .capability([.literalPlus]), text: "")))))

        // send the server ID (client sends a noop
        self.writeOutbound(.tagged(.init(tag: "A2", command: .noop)), wait: false)
        self.assertOutboundString("A2 NOOP\r\n")
        self.writeInbound("* ID (\"name\" \"NIOIMAP\")\r\n")
        self.assertInbound(.untaggedResponse(.id(["name": "NIOIMAP"])))
        wait(for: [turnOnLiteralPlusExpectation], timeout: 1.0)
        self.writeInbound("A2 OK NOOP complete\r\n")
        self.assertInbound(.taggedResponse(.init(tag: "A2", state: .ok(.init(text: "NOOP complete")))))

        // now we should have literal+ turned on
        self.writeOutbound(.tagged(.init(tag: "A3", command: .login(username: "\\", password: "\\"))), wait: false)
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
        self.writeOutbound(.tagged(.init(tag: "A1", command: .login(username: "\\", password: "\\"))), wait: false)
        self.assertOutboundString("A1 LOGIN {1}\r\n")
        self.writeInbound("+ 1\r\n")
        try! eventExpectation1.futureResult.wait()
        self.assertOutboundString("\\ {1}\r\n")
        self.writeInbound("+ 2\r\n")
        try! eventExpectation2.futureResult.wait()
        self.assertOutboundString("\\\r\n")

        // now confirm idle
        self.writeOutbound(.tagged(.init(tag: "A2", command: .idleStart)), wait: false)
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
        self.writeOutbound(.tagged(.init(tag: "A1", command: .idleStart)))
    }

//    func testProtectAgainstReentrancyWithContinuation() {
//        struct MyOutboundEvent {}
//
//        class PreTestHandler: ChannelDuplexHandler {
//            typealias InboundIn = ByteBuffer
//            typealias InboundOut = ByteBuffer
//            typealias OutboundIn = ByteBuffer
//
//            func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
//                let data = self.wrapInboundOut(ByteBuffer(string: "+ \r\n"))
//                context.fireChannelRead(data)
//                promise?.succeed(())
//            }
//
//            func triggerUserOutboundEvent(context: ChannelHandlerContext, event: Any, promise: EventLoopPromise<Void>?) {
//                XCTAssert(event is MyOutboundEvent)
//                let data = self.wrapInboundOut(ByteBuffer(string: "A1 OK NOOP complete\r\n"))
//                context.fireChannelRead(data)
//                promise?.succeed(())
//            }
//        }
//
//        class PostTestHandler: ChannelDuplexHandler {
//            typealias InboundIn = Response
//            typealias OutboundIn = Response
//
//            var callCount = 0
//
//            func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//                self.callCount += 1
//                if self.callCount < 3 {
//                    context.triggerUserOutboundEvent(MyOutboundEvent(), promise: nil)
//                }
//            }
//
//            func errorCaught(context: ChannelHandlerContext, error: Error) {
//                XCTFail("Unexpected error \(error)")
//            }
//        }
//
//        XCTAssertNoThrow(try self.channel.pipeline.addHandlers([
//            PreTestHandler(),
//            IMAPClientHandler(),
//            PostTestHandler(),
//        ]).wait())
//        self.writeOutbound(.command(.init(tag: "A1", command: .create(.init("\\"), []))), wait: false)
//        self.writeOutbound(.command(.init(tag: "A2", command: .noop)), wait: true)
//    }

    func testWriteCascadesPromiseFailure() {
        struct TestError: Error {}
        class TestOutboundHandlerThatFails: ChannelOutboundHandler {
            typealias OutboundIn = ByteBuffer
            func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
                XCTAssertNotNil(promise)
                promise?.fail(TestError())
            }
        }

        try! self.channel.pipeline.addHandler(TestOutboundHandlerThatFails(), position: .first).wait()

        // writing a command that has a continuation
        var didComplete = false
        self.writeOutbound(.tagged(.init(tag: "A1", command: .create(.init("\\"), []))), wait: false).whenFailure { error in
            XCTAssertTrue(error is TestError)
            didComplete = true
        }
        XCTAssertTrue(didComplete)
    }

    func testWriteCascadesContinuationPromiseFailure() {
        struct TestError: Error {}
        class TestOutboundHandlerThatFails: ChannelOutboundHandler {
            var failNextWrite: Bool = false
            typealias OutboundIn = ByteBuffer
            func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
                if self.failNextWrite {
                    XCTAssertNotNil(promise)
                    promise?.fail(TestError())
                    return
                }
                context.write(data, promise: promise)
            }
        }

        let testHandler = TestOutboundHandlerThatFails()
        try! self.channel.pipeline.addHandler(testHandler, position: .first).wait()

        // writing a command that has a continuation
        let future = self.channel.writeAndFlush(CommandStream.tagged(.init(tag: "A1", command: .rename(from: .init("\\"), to: .init("\\"), params: [:]))))
        self.assertOutboundString("A1 RENAME {1}\r\n")

        testHandler.failNextWrite = true
        self.writeInbound("+ OK\r\n")

        var didComplete = false
        future.whenFailure { error in
            XCTAssertTrue(error is TestError)
            didComplete = true
        }
        XCTAssertTrue(didComplete)
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
