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

class Response_Tests: EncodeTestClass {}

// MARK: - Encoding

extension Response_Tests {
    func testEncode_fetchResponse_multiple() {
        let inputs: [([NIOIMAPCore.FetchResponse], String, UInt)] = [
            ([.start(1), .simpleAttribute(.rfc822Size(123)), .finish], "* 1 FETCH (RFC822.SIZE 123)\r\n", #line),
            ([.start(2), .simpleAttribute(.uid(123)), .simpleAttribute(.rfc822Size(456)), .finish], "* 2 FETCH (UID 123 RFC822.SIZE 456)\r\n", #line),
            (
                [.start(3), .simpleAttribute(.uid(123)), .streamingBegin(kind: .rfc822Text, byteCount: 0), .streamingEnd, .simpleAttribute(.uid(456)), .finish],
                "* 3 FETCH (UID 123 RFC822.TEXT {0}\r\n UID 456)\r\n",
                #line
            ),
            (
                [.start(3), .simpleAttribute(.uid(123)), .streamingBegin(kind: .rfc822Header, byteCount: 0), .streamingEnd, .simpleAttribute(.uid(456)), .finish],
                "* 3 FETCH (UID 123 RFC822.HEADER {0}\r\n UID 456)\r\n",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer._clear()
            var encoder = ResponseEncodeBuffer(buffer: self.testBuffer._buffer, options: ResponseEncodingOptions())
            let size = test.reduce(into: 0) { (size, response) in
                size += encoder.writeFetchResponse(response)
            }
            self.testBuffer = _EncodeBuffer._serverEncodeBuffer(buffer: encoder.bytes, options: ResponseEncodingOptions())
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
