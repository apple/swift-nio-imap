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

class ResponseTaggedTests: EncodeTestClass {

}

// MARK: - Encoding
extension ResponseTaggedTests {

    func testEncode() {
        let inputs: [(IMAPCore.ResponseTagged, String, UInt)] = [
            (IMAPCore.ResponseTagged(tag: "tag", state: .bad(.code(.parse, text: "something"))), "tag BAD [PARSE] \"something\"\r\n", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeResponseTagged(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
