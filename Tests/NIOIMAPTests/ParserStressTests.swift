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
import NIOIMAPCore
import NIOTestUtils

import XCTest

let CR = UInt8(ascii: "\r")
let LF = UInt8(ascii: "\n")
let CRLF = String(decoding: [CR, LF], as: Unicode.UTF8.self)

final class ParserStressTests: XCTestCase {
    private var channel: EmbeddedChannel!

    override func setUp() {
        XCTAssertNil(self.channel)
        self.channel = EmbeddedChannel(handler: ByteToMessageHandler(CommandDecoder(bufferLimit: 80_000)))
    }

    override func tearDown() {
        XCTAssertNotNil(self.channel)
        XCTAssertNoThrow(XCTAssertTrue(try self.channel.finish().isClean))
        self.channel = nil
    }

    // Test that we eventually stop parsing a single item
    // e.g. mailbox with name xxxxxxxxxxxxxxxxxx...
    func testArbitraryLongMailboxName() {
        var longBuffer = self.channel.allocator.buffer(capacity: 90_000)
        longBuffer.writeString("CREATE \"")
        for _ in 0 ..< 20_000 {
            longBuffer.writeString("xxxx")
        }

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { _error in
            guard let error = _error as? IMAPDecoderError else {
                XCTFail("\(_error)")
                return
            }
            XCTAssertEqual(error.parserError as? ParsingError, .lineTooLong)
        }
    }

    // Test that we eventually stop parsing infinite parameters
    // e.g. a sequence of numbers 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ...
    func testArbitraryNumberOfFlags() {
        var longBuffer = self.channel.allocator.buffer(capacity: 90_000)
        longBuffer.writeString("STORE 1, ")
        for i in 2 ..< 20_000 {
            longBuffer.writeString("\(i), ")
        }

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { _error in
            guard let error = _error as? IMAPDecoderError else {
                XCTFail("\(_error)")
                return
            }
            XCTAssertEqual(error.parserError as? ParsingError, .lineTooLong)
        }
    }

    // - MARK: ByteToMessageDecoderVerifier tests
    func testBasicDecodes() {
        let inoutPairs: [(String, [CommandStream])] = [
            // LOGIN
            (#"tag LOGIN "foo" "bar""# + CRLF, [.command(.init(type: .login("foo", "bar"), tag: "tag"))]),
            ("tag LOGIN \"\" {0}\r\n" + CRLF, [.command(.init(type: .login("", ""), tag: "tag"))]),
            (#"tag LOGIN "foo" "bar""# + CRLF, [.command(.init(type: .login("foo", "bar"), tag: "tag"))]),
            (#"tag LOGIN foo bar"# + CRLF, [.command(.init(type: .login("foo", "bar"), tag: "tag"))]),
            // RENAME
            (#"tag RENAME "foo" "bar""# + CRLF, [.command(TaggedCommand(type: .rename(from: MailboxName("foo"), to: MailboxName("bar"), params: []), tag: "tag"))]),
            (#"tag RENAME InBoX "inBOX""# + CRLF, [.command(TaggedCommand(type: .rename(from: .inbox, to: .inbox, params: []), tag: "tag"))]),
            ("tag RENAME {1}\r\n1 {1}\r\n2" + CRLF, [.command(TaggedCommand(type: .rename(from: MailboxName("1"), to: MailboxName("2"), params: []), tag: "tag"))]),
        ]
        do {
            try ByteToMessageDecoderVerifier.verifyDecoder(
                stringInputOutputPairs: inoutPairs,
                decoderFactory: { () -> CommandDecoder in
                    CommandDecoder(autoSendContinuations: false)
                }
            )
        } catch {
            switch error as? ByteToMessageDecoderVerifier.VerificationError<CommandStream> {
            case .some(let error):
                for input in error.inputs {
                    print(" input: \(String(decoding: input.readableBytesView, as: Unicode.UTF8.self))")
                }
                switch error.errorCode {
                case .underProduction(let command):
                    print("UNDER PRODUCTION")
                    print(command)
                case .wrongProduction(actual: let actualCommand, expected: let expectedCommand):
                    print("WRONG PRODUCTION")
                    print(actualCommand)
                    print(expectedCommand)
                default:
                    print(error)
                }
            case .none:
                ()
            }
            XCTFail("unhandled error: \(error)")
        }
    }

    // - MARK: Parser unit tests
    func testPreventInfiniteRecursion() {
        var longBuffer = self.channel.allocator.buffer(capacity: 80_000)
        longBuffer.writeString("tag SEARCH (")
        for _ in 0 ..< 3_000 {
            longBuffer.writeString(#"ALL ANSWERED BCC CC ("#)
        }
        for _ in 0 ..< 3_000 {
            longBuffer.writeString(")") // close the recursive brackets
        }
        longBuffer.writeString(")\r\n")

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { _error in
            guard let error = _error as? IMAPDecoderError else {
                XCTFail("\(_error)")
                return
            }
            XCTAssertTrue(error.parserError is TooDeep, "\(error)")
        }
    }

    func testWeNeverAttemptToParseSomethingThatIs80kWithoutANewline() {
        var longBuffer = self.channel.allocator.buffer(capacity: 90_000)
        longBuffer.writeString(String(repeating: "X", count: 80_001))

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { _error in
            guard let error = _error as? IMAPDecoderError else {
                XCTFail("\(_error)")
                return
            }
            XCTAssertEqual(error.parserError as? ParsingError, .lineTooLong, "\(error)")
        }
    }
}
