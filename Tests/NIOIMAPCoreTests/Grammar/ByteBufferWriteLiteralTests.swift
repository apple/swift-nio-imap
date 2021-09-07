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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class ByteBufferWriteLiteralTests: EncodeTestClass {}

// MARK: writeIMAPString

extension ByteBufferWriteLiteralTests {
    func testWriteIMAPString_client() {
        let inputs: [(ByteBuffer, CommandEncodingOptions, [String], UInt)] = [
            ("", .rfc3501, ["\"\""], #line),
            ("", .noQuoted, ["{0}\r\n", ""], #line),
            ("abc", .rfc3501, [#""abc""#], #line),
            (ByteBuffer(ByteBufferView(repeating: UInt8(ascii: "\""), count: 1)), .rfc3501, ["{1}\r\n", "\""], #line),
            (ByteBuffer(ByteBufferView(repeating: UInt8(ascii: "\\"), count: 1)), .rfc3501, ["{1}\r\n", "\\"], #line),
            (ByteBuffer(ByteBufferView(repeating: UInt8(ascii: "\\"), count: 1)), .literalPlus, ["{1+}\r\n\\"], #line),
            ("\\\"", .rfc3501, ["{2}\r\n", "\\\""], #line),
            ("a", .rfc3501, ["\"a\""], #line),
            ("båd", .literalPlus, ["{4+}\r\nbåd"], #line),
            ("パリ", .literalPlus, ["{6+}\r\nパリ"], #line),
            (
                "01234567890123456789012345678901234567890123456789012345678901234567890",
                .rfc3501,
                ["{71}\r\n", "01234567890123456789012345678901234567890123456789012345678901234567890"],
                #line
            ),
            (ByteBuffer(string: String(repeating: "a", count: 4096)), .literalMinus, ["{4096-}\r\n" + String(repeating: "a", count: 4096)], #line),
            (ByteBuffer(string: String(repeating: "a", count: 4097)), .literalMinus, ["{4097}\r\n", String(repeating: "a", count: 4097)], #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIMAPString($0) })
    }

    func testWriteIMAPString_server() {
        let inputs: [(ByteBuffer, ResponseEncodingOptions, String, UInt)] = [
            ("", .rfc3501, "\"\"", #line),
            ("abc", .rfc3501, #""abc""#, #line),
            (ByteBuffer(ByteBufferView(repeating: UInt8(ascii: "\""), count: 1)), .rfc3501, "{1}\r\n\"", #line),
            (ByteBuffer(ByteBufferView(repeating: UInt8(ascii: "\\"), count: 1)), .rfc3501, "{1}\r\n\\", #line),
            ("\\\"", .rfc3501, "{2}\r\n\\\"", #line),
            ("a", .rfc3501, "\"a\"", #line),
            ("båd", .rfc3501, "{4}\r\nbåd", #line),
            ("パリ", .rfc3501, "{6}\r\nパリ", #line),
            (
                "01234567890123456789012345678901234567890123456789012345678901234567890",
                .rfc3501,
                "{71}\r\n01234567890123456789012345678901234567890123456789012345678901234567890",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIMAPString($0) })
    }
}

// MARK: writeLiteral8

extension ByteBufferWriteLiteralTests {
    func testWriteLiteral8() {
        let inputs: [(ByteBuffer, CommandEncodingOptions, [String], UInt)] = [
            ("", .rfc3501, ["~{0}\r\n", ""], #line),
            ("abc", .rfc3501, ["~{3}\r\n", "abc"], #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeLiteral8($0.readableBytesView) })
    }
}
