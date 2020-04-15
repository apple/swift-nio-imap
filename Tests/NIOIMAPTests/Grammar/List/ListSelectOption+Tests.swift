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

class ListSelectOption_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension ListSelectOption_Tests {

    func testEncode() {
        let inputs: [(IMAPCore.ListSelectOption, String, UInt)] = [
            (.base(.subscribed), "SUBSCRIBED", #line),
            (.independent(.remote), "REMOTE", #line),
            (.mod(.recursiveMatch), "RECURSIVEMATCH", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeListSelectOption(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_multiple() {
        let inputs: [(IMAPCore.ListSelectOptions, String, UInt)] = [
            (nil, "()", #line),
            (.select([.base(.subscribed)], .subscribed), "(SUBSCRIBED SUBSCRIBED)", #line),
            (.selectIndependent([.remote, .option(.standard("SOME", value: nil))]), "(REMOTE SOME)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeListSelectOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
