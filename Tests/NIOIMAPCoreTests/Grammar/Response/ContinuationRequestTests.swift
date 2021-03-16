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

class ContinuationRequestTests: EncodeTestClass {}

// MARK: - Encoding

extension ByteBuffer {
    fileprivate init(_ bytes: [UInt8]) {
        self.init()
        writeBytes(bytes)
    }
}

private let bufferA = ByteBuffer(
    [0x60, 0x33, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x12, 0x01, 0x02,
     0x02, 0x02, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xEA, 0x37, 0x32,
     0x1B, 0x81, 0x84, 0xDC, 0xA9, 0x13, 0xCC, 0x17, 0x81, 0x89, 0x51, 0xDE,
     0x71, 0xE3, 0xF6, 0x09, 0x66, 0x34, 0x49, 0x1D, 0x1F, 0x01, 0x00, 0x20,
     0x00, 0x04, 0x04, 0x04, 0x04]
)

private let fixtures: [(ContinuationRequest, String, UInt)] = [
    (.responseText(.init(text: ".")), "+ .\r\n", #line),
    (.responseText(.init(text: "Ok. Foo")), "+ Ok. Foo\r\n", #line),
    (.responseText(.init(code: .alert, text: "text")), "+ [ALERT] text\r\n", #line),
    (.data("a"), "+ YQ==\r\n", #line),
    (.data(bufferA), "+ YDMGCSqGSIb3EgECAgIBAAD/////6jcyG4GE3KkTzBeBiVHeceP2CWY0SR0fAQAgAAQEBAQ=\r\n", #line),
]

extension ContinuationRequestTests {
    func testEncode() {
        self.iterateInputs(inputs: fixtures, encoder: { req in
            var encoder = ResponseEncodeBuffer(buffer: self.testBuffer._buffer, options: ResponseEncodingOptions())
            defer {
                self.testBuffer = _EncodeBuffer._serverEncodeBuffer(buffer: encoder.bytes, options: ResponseEncodingOptions())
            }
            return encoder.writeContinuationRequest(req)
        })
    }

    func testParse() {
        for (expected, input, line) in fixtures {
            var buffer = ParseBuffer(ByteBuffer(string: input + "a"))
            do {
                let cont = try GrammarParser.parseContinuationRequest(buffer: &buffer, tracker: StackTracker(maximumParserStackDepth: 100))
                XCTAssertEqual(cont, expected, "parse", line: line)
                XCTAssertEqual(buffer.readableBytes, 1, "parse", line: line)
            } catch {
                XCTFail("'\(input)' -> \(error)", line: line)
                return
            }
        }
    }
}
