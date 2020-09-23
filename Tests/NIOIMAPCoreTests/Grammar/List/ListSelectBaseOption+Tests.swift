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

class ListSelectBaseOption_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ListSelectBaseOption_Tests {
    func testEncode() {
        let inputs: [(ListSelectBaseOption, String, UInt)] = [
            (.subscribed, "SUBSCRIBED", #line),
            (.option(.init(kind: .standard("test"), value: nil)), "test", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeListSelectBaseOption(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncodeQuoted() {
        let inputs: [(ListSelectBaseOption, String, UInt)] = [
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
