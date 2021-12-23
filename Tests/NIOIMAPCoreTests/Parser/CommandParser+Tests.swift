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
@testable import NIOIMAPCore
import XCTest

class CommandParser_Tests: XCTestCase {}

// MARK: - init

extension CommandParser_Tests {
    func testInit_defaultBufferSize() {
        let parser = CommandParser()
        XCTAssertEqual(parser.bufferLimit, 8_192)
    }

    func testInit_customBufferSize() {
        let parser = CommandParser(bufferLimit: 80_000)
        XCTAssertEqual(parser.bufferLimit, 80_000)
    }
}

// MARK: - Test normal usage

extension CommandParser_Tests {
    // test that we don't just get returned an empty byte case if
    // we haven't yet recieved any literal data from the network
    func testParseEmptyByteBufferAppend() {
        var input = ByteBuffer("1 APPEND INBOX {5}\r\n") // everything except the literal data
        var parser = CommandParser()
        XCTAssertNoThrow(XCTAssertNotNil(try parser.parseCommandStream(buffer: &input)))
        XCTAssertNoThrow(XCTAssertNotNil(try parser.parseCommandStream(buffer: &input)))

        // At this point we should have parse off all the metadata
        // so should be ready for the literal
        var literalBuffer = ByteBuffer(string: "")
        XCTAssertNoThrow(XCTAssertNil(try parser.parseCommandStream(buffer: &literalBuffer)))
    }

    func testNormalUsage() {
        var input = ByteBuffer("")
        var parser = CommandParser()

        XCTAssertNoThrow(XCTAssertNil(try parser.parseCommandStream(buffer: &input)))

        input = "1 NOOP\r\n"
        XCTAssertNoThrow(
            XCTAssertEqual(
                try parser.parseCommandStream(buffer: &input),
                .init(.tagged(.init(tag: "1", command: .noop)), numberOfSynchronisingLiterals: 0)
            )
        )
        XCTAssertEqual(input, "")

        input = "2 LOGIN {0}\r\n {0}\r\n\r\n"
        XCTAssertNoThrow(
            XCTAssertEqual(
                try parser.parseCommandStream(buffer: &input),
                .init(.tagged(.init(tag: "2", command: .login(username: "", password: ""))), numberOfSynchronisingLiterals: 2)
            )
        )
        XCTAssertEqual(input, "")

        input = "3 APPEND INBOX {3+}\r\n123 {3+}\r\n456 {3+}\r\n789\r\n"
        XCTAssertEqual(try! parser.parseCommandStream(buffer: &input), .init(.append(.start(tag: "3", appendingTo: .inbox)), numberOfSynchronisingLiterals: 0))
        XCTAssertEqual(input, " {3+}\r\n123 {3+}\r\n456 {3+}\r\n789\r\n")
    }

    func testRandomDataDoesntCrash() {
        let inputs: [[UInt8]] = [
            Array("+000000000000000000000000000000000000000000000000000000000}\n".utf8),
            Array("eSequence468117eY SEARCH 4:1 000,0\n000059?000000600=)O".utf8),
            [0x41, 0x5D, 0x20, 0x55, 0x49, 0x44, 0x20, 0x43, 0x4F, 0x50, 0x59, 0x20, 0x35, 0x2C, 0x35, 0x3A, 0x34, 0x00, 0x3D, 0x0C, 0x0A, 0x43, 0x20, 0x22, 0xE8],
        ]

        for input in inputs {
            var parser = CommandParser()
            do {
                var buffer = ByteBuffer(bytes: input)
                var lastReadableBytes = buffer.readableBytes
                var newReadableBytes = 0
                while newReadableBytes < lastReadableBytes {
                    lastReadableBytes = buffer.readableBytes
                    _ = try parser.parseCommandStream(buffer: &buffer)
                    newReadableBytes = buffer.readableBytes
                }
            } catch {
                // do nothing, we don't care
            }
        }
    }
}
