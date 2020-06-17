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

class ByteBufferWriteLiteralTests: EncodeTestClass {}

// MARK: writeIMAPString

extension ByteBufferWriteLiteralTests {
    func testWriteIMAPString() {
        let inputs: [(ByteBuffer, EncodingCapabilities, String, UInt)] = [
            ("", [], "\"\"", #line),
            ("abc", [], #""abc""#, #line),
            (ByteBuffer(ByteBufferView(repeating: UInt8(ascii: "\""), count: 1)), [], "{1}\r\n\"", #line),
            (ByteBuffer(ByteBufferView(repeating: UInt8(ascii: "\\"), count: 1)), [], "{1}\r\n\\", #line),
            ("\\\"", [], "{2}\r\n\\\"", #line),
            ("a", [], "\"a\"", #line),
            (
                "01234567890123456789012345678901234567890123456789012345678901234567890",
                [],
                "{71}\r\n01234567890123456789012345678901234567890123456789012345678901234567890",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIMAPString($0) })
    }
}

// MARK: writeLiteral

extension ByteBufferWriteLiteralTests {
    func testWriteLiteral() {
        let inputs: [(ByteBuffer, String, UInt)] = [
            ("", "{0}\r\n", #line),
            ("abc", "{3}\r\nabc", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeLiteral(Array(test.readableBytesView))
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}

// MARK: writeLiteral8

extension ByteBufferWriteLiteralTests {
    func testWriteLiteral8() {
        let inputs: [(ByteBuffer, EncodingCapabilities, String, UInt)] = [
            ("", [.binary], "~{0}\r\n", #line),
            ("abc", [.binary], "~{3}\r\nabc", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeLiteral8($0.readableBytesView) })
    }
}
