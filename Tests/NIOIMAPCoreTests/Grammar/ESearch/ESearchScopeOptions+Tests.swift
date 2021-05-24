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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class ExtendedSearchScopeOptions_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ExtendedSearchScopeOptions_Tests {
    func testEncode() {
        let inputs: [(ExtendedSearchScopeOptions, String, UInt)] = [
            (ExtendedSearchScopeOptions(["test": nil])!, "test", #line),
            (
                ExtendedSearchScopeOptions(["test": .sequence(.lastCommand), "test2": nil])!,
                "test $ test2",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeExtendedSearchScopeOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
