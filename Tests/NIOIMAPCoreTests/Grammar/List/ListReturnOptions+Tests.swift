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

class ListReturnOptions_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ListReturnOptions_Tests {
    func testEncode() {
        let inputs: [([ReturnOption], String, UInt)] = [
            ([], "RETURN ()", #line),
            ([.subscribed], "RETURN (SUBSCRIBED)", #line),
            ([.subscribed, .children], "RETURN (SUBSCRIBED CHILDREN)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeListReturnOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
