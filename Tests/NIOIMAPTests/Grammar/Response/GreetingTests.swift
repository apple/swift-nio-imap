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
@testable import IMAPCore
@testable import NIOIMAP

class GreetingTests: EncodeTestClass {

}

// MARK: - Encoding
extension GreetingTests {

    func testEncode() {
        let inputs: [(IMAPCore.Greeting, String, UInt)] = [
            (.auth(.ok(.code(nil, text: "text"))), "* OK \"text\"\r\n", #line),
            (.bye(.code(nil, text: "text")), "* BYE \"text\"\r\n", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeGreeting(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
