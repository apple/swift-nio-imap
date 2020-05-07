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

class ResponseTextTests: EncodeTestClass {}

// MARK: - Encoding

extension ResponseTextTests {
    func testEncode() {
        let inputs: [(NIOIMAP.ResponseText, String, UInt)] = [
            (.init(code: nil, text: "buffer"), "buffer", #line),
            (.init(code: .alert, text: "buffer"), "[ALERT] buffer", #line),
        ]

        for (code, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeResponseText(code)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
