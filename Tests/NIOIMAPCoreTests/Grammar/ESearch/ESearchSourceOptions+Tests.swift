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

class ExtendedSearchSourceOptions_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ExtendedSearchSourceOptions_Tests {
    func testEncode() {
        let inputs: [(ExtendedSearchSourceOptions, String, UInt)] = [
            (
                ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])!,
                "IN (inboxes)",
                #line
            ),
            (
                ExtendedSearchSourceOptions(
                    sourceMailbox: [.inboxes],
                    scopeOptions: ExtendedSearchScopeOptions(["test": nil])
                )!,
                "IN (inboxes (test))",
                #line
            ),
            (
                ExtendedSearchSourceOptions(
                    sourceMailbox: [.inboxes, .personal],
                    scopeOptions: ExtendedSearchScopeOptions(["test": nil])
                )!,
                "IN (inboxes personal (test))",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeExtendedSearchSourceOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
