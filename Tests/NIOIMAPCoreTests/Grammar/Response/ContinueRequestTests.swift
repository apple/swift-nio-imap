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

class ContinueRequestTests: EncodeTestClass {}

// MARK: - Encoding

extension ContinueRequestTests {
    func testEncode() {
        let inputs: [(ContinueRequest, String, UInt)] = [
            (.base64("bb=="), "+ bb==\r\n", #line),
            (.responseText(.init(code: .alert, text: "text")), "+ [ALERT] text\r\n", #line),
        ]

        for (test, expectedString, line) in inputs {
            var buffer = ByteBufferAllocator().buffer(capacity: 128)
            let size = buffer.writeContinueRequest(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(String(buffer: buffer), expectedString, line: line)
        }
    }
}
