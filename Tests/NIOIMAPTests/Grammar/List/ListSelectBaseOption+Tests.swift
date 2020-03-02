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

class ListSelectBaseOption_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension ListSelectBaseOption_Tests {

    func testEncode() {
        let inputs: [(NIOIMAP.ListSelectBaseOption, String, UInt)] = [
            (.subscribed, "SUBSCRIBED", #line),
            (.option(.standard("test", value: nil)), "test", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeListSelectBaseOption(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncodeQuoted() {
        let inputs: [(NIOIMAP.ListSelectBaseOptionQuoted, String, UInt)] = [
            (.subscribed, #""SUBSCRIBED""#, #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeListSelectBaseOptionQuoted(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
