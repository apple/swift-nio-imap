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

class ESearchSourceOptions_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ESearchSourceOptions_Tests {
    func testEncode() {
        let inputs: [(ESearchSourceOptions, String, UInt)] = [
            (
                ESearchSourceOptions(sourceMailbox: [.inboxes])!,
                "IN (inboxes)",
                #line
            ),
            (
                ESearchSourceOptions(sourceMailbox: [.inboxes],
                                     scopeOptions: ESearchScopeOptions([.init(key: "test", value: nil)]))!,
                "IN (inboxes (test))",
                #line
            ),
            (
                ESearchSourceOptions(sourceMailbox: [.inboxes, .personal],
                                     scopeOptions: ESearchScopeOptions([.init(key: "test", value: nil)]))!,
                "IN (inboxes personal (test))",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeESearchSourceOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
