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
        self.channel = EmbeddedChannel(handler: IMAPServerHandler())
    }

    override func tearDown() {
        XCTAssertNotNil(self.channel)
        XCTAssertNoThrow(XCTAssertTrue(try self.channel.finish().isClean))
        self.channel = nil
    }

    // Test that we eventually stop parsing a single item
    // e.g. mailbox with name xxxxxxxxxxxxxxxxxx...
    func testArbitraryLongMailboxName() {
        let longBuffer = self.channel.allocator.buffer(repeating: UInt8(ascii: "x"), count: 60 * 1024)
        XCTAssertNoThrow(try self.channel.writeInbound(self.channel.allocator.buffer(string: "CREATE \"")))

        XCTAssertThrowsError(
            try {
                while true {
                    try self.channel.writeInbound(longBuffer)
                }
            }()
        ) { error in
            XCTAssertTrue(error is ByteToMessageDecoderError.PayloadTooLargeError)
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

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { error in
            XCTAssertTrue(error is ByteToMessageDecoderError.PayloadTooLargeError)
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
            XCTAssertTrue(error.parserError is TooMuchRecursion, "\(error)")
        }
    }

    func testWeNeverAttemptToParseSomethingThatIs80kWithoutANewline() {
        var longBuffer = self.channel.allocator.buffer(capacity: 90_000)
        longBuffer.writeString(String(repeating: "X", count: 80_001))

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { error in
            XCTAssertTrue(error is ByteToMessageDecoderError.PayloadTooLargeError)
        }
    }

    func testManyShortCommands() {
        var longBuffer = self.channel.allocator.buffer(capacity: 80_000)
        for _ in 1 ... 1_000 {
            longBuffer.writeString("1 NOOP\r\n")
        }
        XCTAssertNoThrow(try self.channel.writeInbound(longBuffer))
        for _ in 1 ... 1_000 {
            XCTAssertNoThrow(XCTAssertEqual(
                CommandStream.command(.init(tag: "1", command: .noop)),
                try self.channel.readInbound(as: CommandStream.self)
            ))
        }
    }
}
