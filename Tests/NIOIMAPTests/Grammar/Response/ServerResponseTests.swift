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

class ServerResponseTests: EncodeTestClass {

}

// MARK: - Encoding
extension ServerResponseTests {

    func testEncode() {
        let inputs: [(NIOIMAP.ServerResponse, String, UInt)] = [
            (
                .greeting(.bye(.code(.alert, text: "text"))),
                "* BYE [ALERT] text\r\n",
                #line
            ),
            (
                .response(.init(parts: [.responseData(.messageData(.expunge(6)))], done: .tagged(.init(tag: "a1", state: .ok(.code(nil, text: "response")))))),
                "* 6 EXPUNGE\r\na1 OK response\r\n",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeServerResponse(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
