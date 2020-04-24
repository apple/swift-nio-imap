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

class BodyTypeTextTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyTypeTextTests {
    func testEncode() {
        let inputs: [(NIOIMAP.Body.TypeText, String, UInt)] = [
            (.mediaText("subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 123), lines: 456), "\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 123 456", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeText(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
