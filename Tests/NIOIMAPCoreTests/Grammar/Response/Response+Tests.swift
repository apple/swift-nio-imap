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
            ([.start(1), .simpleAttribute(.rfc822Size(123)), .finish], "(RFC822.SIZE 123)", #line),
            ([.start(1), .simpleAttribute(.uid(123)), .simpleAttribute(.rfc822Size(456)), .finish], "(UID 123 RFC822.SIZE 456)", #line),
        ]
        
        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = test.reduce(into: 0) { (size, response) in
                size += self.testBuffer.writeFetchResponse(response)
            }
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
    
    
}
