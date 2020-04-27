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

class FetchModifierName_Tests: EncodeTestClass {}

// MARK: - Encoding

extension FetchModifierName_Tests {
    func testEncode() {
        let inputs: [(String, String, UInt)] = [
            ("test", "test", #line),
        ]

        for (input, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeFetchModifierName(input)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
