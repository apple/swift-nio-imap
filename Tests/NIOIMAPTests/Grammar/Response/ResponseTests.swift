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

class ResponseTests: EncodeTestClass {

}

// MARK: - Encoding
extension ResponseTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Response, String, UInt)] = [
            (
                .parts([], done: .fatal(.code(.alert, text: "text"))),
                "* BYE [ALERT] text\r\n",
                #line
            ),
            (
                .parts([.responseData(.messageData(.expunge(4)))], done: .fatal(.code(.alert, text: "text"))),
                "* 4 EXPUNGE\r\n* BYE [ALERT] text\r\n",
                #line
            ),
            (
                .parts([.responseData(.messageData(.expunge(4))), .continueRequest(.base64("aa=="))], done: .fatal(.code(.alert, text: "text"))),
                "* 4 EXPUNGE\r\n+ aa==\r\n* BYE [ALERT] text\r\n",
                #line
            )
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeResponse(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
