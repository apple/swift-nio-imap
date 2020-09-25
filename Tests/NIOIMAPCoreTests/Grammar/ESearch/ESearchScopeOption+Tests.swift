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

class ESearchScopeOption_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ESearchScopeOption_Tests {
    func testEncode() {
        let inputs: [(ESearchScopeOption, String, UInt)] = [
            (.init(name: "test"), "test", #line),
            (.init(name: "test", value: .sequence(.lastCommand)), "test $", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeESearchScopeOption(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
