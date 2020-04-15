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

class ID_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension ID_Tests {

    func testEncode() {
        let inputs: [(IMAPCore.IDParameter, String, UInt)] = [
            (.key("key", value: "value"), #""key" "value""#, #line),
            (.key("key", value: nil), #""key" NIL"#, #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeIDParameter(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
    
    func testEncode_array() {
        let inputs: [([IMAPCore.IDParameter], String, UInt)] = [
            ([], "NIL", #line),
            ([.key("key", value: "value")], #"("key" "value")"#, #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeIDParameters(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
    
}
