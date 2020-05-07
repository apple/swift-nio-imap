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

class ID_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ID_Tests {
    func testEncode() {
        let inputs: [(NIOIMAP.IDParameter, String, UInt)] = [
            (.init(key: "key", value: "value"), #""key" "value""#, #line),
            (.init(key: "key", value: nil), #""key" NIL"#, #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeIDParameter(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_array() {
        let inputs: [([IDParameter], String, UInt)] = [
            ([], "NIL", #line),
            ([.init(key: "key", value: "value")], #"("key" "value")"#, #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeIDParameters(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
