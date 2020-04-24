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

class SearchReturnOption_Tests: EncodeTestClass {}

// MARK: - Encoding

extension SearchReturnOption_Tests {
    func testEncode() {
        let inputs: [(NIOIMAP.SearchReturnOption, String, UInt)] = [
            (.min, "MIN", #line),
            (.max, "MAX", #line),
            (.all, "ALL", #line),
            (.count, "COUNT", #line),
            (.save, "SAVE", #line),
            (.optionExtension(.modifier("modifier", params: nil)), "modifier", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeSearchReturnOption(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_multiple() {
        let inputs: [([NIOIMAP.SearchReturnOption], String, UInt)] = [
            ([], "", #line),
            ([.min], " RETURN (MIN)", #line),
            ([.min, .max, .count], " RETURN (MIN MAX COUNT)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeSearchReturnOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
