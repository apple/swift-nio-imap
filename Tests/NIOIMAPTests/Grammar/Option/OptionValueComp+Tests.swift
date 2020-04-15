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

class OptionValueComp_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension OptionValueComp_Tests {

    func testEncode() {
        let inputs: [(IMAPCore.OptionValueComp, String, UInt)] = [
            (.string("test"), "\"test\"", #line),
            ([.string("test1"), .string("test2")], "(\"test1\" \"test2\")", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeOptionValueComp(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
