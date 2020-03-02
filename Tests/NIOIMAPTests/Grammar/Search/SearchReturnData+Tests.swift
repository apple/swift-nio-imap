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

class SearchReturnData_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension SearchReturnData_Tests {

    func testEncode() {
        let inputs: [(NIOIMAP.SearchReturnData, String, UInt)] = [
            (.min(1), "MIN 1", #line),
            (.max(1), "MAX 1", #line),
            (.all([1...3]), "ALL 1:3", #line),
            (.count(1), "COUNT 1", #line),
            (.dataExtension(.modifier("modifier", returnValue: .simple(.number(3)))), "modifier 3", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeSearchReturnData(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

}
