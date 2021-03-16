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
        XCTAssertEqual(parser.bufferLimit, 1_000)
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
        var input = ByteBuffer("1 APPEND INBOX {5}\r\n") // everything except the
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
                .init(numberOfSynchronisingLiterals: 0, command: .command(.init(tag: "1", command: .noop)))
            )
        )
        XCTAssertEqual(input, "")

        input = "2 LOGIN {0}\r\n {0}\r\n\r\n"
        XCTAssertNoThrow(
            XCTAssertEqual(
                try parser.parseCommandStream(buffer: &input),
                .init(numberOfSynchronisingLiterals: 2, command: .command(.init(tag: "2", command: .login(username: "", password: ""))))
            )
        )
        XCTAssertEqual(input, "")

        input = "3 APPEND INBOX {3+}\r\n123 {3+}\r\n456 {3+}\r\n789\r\n"
        XCTAssertEqual(try! parser.parseCommandStream(buffer: &input), .init(numberOfSynchronisingLiterals: 0, command: .append(.start(tag: "3", appendingTo: .inbox))))
        XCTAssertEqual(input, " {3+}\r\n123 {3+}\r\n456 {3+}\r\n789\r\n")
    }
}
