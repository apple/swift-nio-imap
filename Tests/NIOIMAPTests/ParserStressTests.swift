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

import Testing

let CR = UInt8(ascii: "\r")
let LF = UInt8(ascii: "\n")
let CRLF = String(decoding: [CR, LF], as: Unicode.UTF8.self)

@Suite struct ParserStressTests {
    var channel: EmbeddedChannel!

    init() {
        self.channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), IMAPServerHandler()])
    }

    // Test that we eventually stop parsing a single item
    // e.g. mailbox with name xxxxxxxxxxxxxxxxxx...
    @Test("arbitrary long mailbox name")
    func arbitraryLongMailboxName() {
        let longBuffer = self.channel.allocator.buffer(repeating: UInt8(ascii: "x"), count: 60 * 1024)
        #expect(throws: Never.self) {
            try self.channel.writeInbound(self.channel.allocator.buffer(string: "CREATE \""))
        }

        do {
            while true {
                try self.channel.writeInbound(longBuffer)
            }
            Issue.record("Expected error to be thrown")
        } catch is ByteToMessageDecoderError.PayloadTooLargeError {
            // Expected error type
        } catch {
            Issue.record("Expected ByteToMessageDecoderError.PayloadTooLargeError but got \(error)")
        }
    }

    // Test that we eventually stop parsing infinite parameters
    // e.g. a sequence of numbers 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ...
    @Test("arbitrary number of flags")
    func arbitraryNumberOfFlags() {
        var longBuffer = self.channel.allocator.buffer(capacity: 90_000)
        longBuffer.writeString("STORE 1, ")
        for i in 2..<20_000 {
            longBuffer.writeString("\(i), ")
        }

        do {
            try self.channel.writeInbound(longBuffer)
            Issue.record("Expected error to be thrown")
        } catch is ByteToMessageDecoderError.PayloadTooLargeError {
            // Expected error type
        } catch {
            Issue.record("Expected ByteToMessageDecoderError.PayloadTooLargeError but got \(error)")
        }
    }

    // - MARK: Parser unit tests
    @Test("prevent infinite recursion")
    func preventInfiniteRecursion() {
        var longBuffer = self.channel.allocator.buffer(capacity: 80_000)
        longBuffer.writeString("tag SEARCH (")
        for _ in 0..<3_000 {
            longBuffer.writeString(#"ALL ANSWERED BCC CC ("#)
        }
        for _ in 0..<3_000 {
            longBuffer.writeString(")")  // close the recursive brackets
        }
        longBuffer.writeString(")\r\n")

        do {
            try self.channel.writeInbound(longBuffer)
            Issue.record("Expected error to be thrown")
        } catch let error as IMAPDecoderError {
            #expect(error.parserError is TooMuchRecursion)
        } catch {
            Issue.record("Expected IMAPDecoderError but got \(error)")
        }
    }

    @Test("we never attempt to parse something that is 80k without a newline")
    func weNeverAttemptToParseSomethingThatIs80kWithoutANewline() {
        var longBuffer = self.channel.allocator.buffer(capacity: 90_000)
        longBuffer.writeString(String(repeating: "X", count: 80_001))

        do {
            try self.channel.writeInbound(longBuffer)
            Issue.record("Expected error to be thrown")
        } catch is ByteToMessageDecoderError.PayloadTooLargeError {
            // Expected error type
        } catch {
            Issue.record("Expected ByteToMessageDecoderError.PayloadTooLargeError but got \(error)")
        }
    }

    @Test("many short commands")
    func manyShortCommands() {
        var longBuffer = self.channel.allocator.buffer(capacity: 80_000)
        for _ in 1...1_000 {
            longBuffer.writeString("1 NOOP\r\n")
        }
        #expect(throws: Never.self) { try self.channel.writeInbound(longBuffer) }
        for _ in 1...1_000 {
            var result: CommandStreamPart?
            #expect(throws: Never.self) {
                result = try self.channel.readInbound(as: CommandStreamPart.self)
            }
            #expect(result == CommandStreamPart.tagged(.init(tag: "1", command: .noop)))
        }
    }
}
