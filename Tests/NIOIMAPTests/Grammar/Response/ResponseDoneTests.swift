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

import XCTest
import NIO
@testable import NIOIMAP

class ResponseDoneTests: EncodeTestClass {

}

// MARK: - Encoding
extension ResponseDoneTests {

    func testEncode() {
        let inputs: [(NIOIMAP.ResponseDone, String, UInt)] = [
            (.tagged(.tag("tag1", state: .bad(.code(.alert, text: "test1")))), "tag1 BAD [ALERT] \"test1\"\r\n", #line),
            (.fatal(.code(.parse, text: "test2")), "* BYE [PARSE] \"test2\"\r\n", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeResponseDone(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
