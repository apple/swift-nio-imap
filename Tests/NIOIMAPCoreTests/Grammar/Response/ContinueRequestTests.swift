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
        let inputs: [(NIOIMAP.ContinueRequest, String, UInt)] = [
            (.base64("bb=="), "+ bb==\r\n", #line),
            (.responseText(.code(.alert, text: "text")), "+ [ALERT] text\r\n", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeContinueRequest(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
