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

class ListSelectModOption_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ListSelectModOption_Tests {
    func testEncode() {
        let inputs: [(ListSelectModOption, String, UInt)] = [
            (.recursiveMatch, "RECURSIVEMATCH", #line),
            (.option(.init(type: .standard("extension"), value: nil)), "extension", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeListSelectModOption(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
