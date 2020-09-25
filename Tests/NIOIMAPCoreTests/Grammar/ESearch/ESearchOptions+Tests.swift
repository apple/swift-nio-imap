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

class ESearchOptions_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ESearchOptions_Tests {
    func testEncode() {
        let inputs: [(ESearchOptions, String, UInt)] = [
            (
                ESearchOptions(key: .all),
                " ALL",
                #line
            ),
            (
                ESearchOptions(key: .all, returnOptions: [.min]),
                " RETURN (MIN) ALL",
                #line
            ),
            (
                ESearchOptions(key: .all, charset: "Alien"),
                " CHARSET Alien ALL",
                #line
            ),
            (
                ESearchOptions(key: .all, sourceOptions: ESearchSourceOptions(sourceMailbox: [.inboxes])),
                " IN (inboxes) ALL",
                #line
            ),
            (
                ESearchOptions(key: .all,
                               charset: "Alien",
                               sourceOptions: ESearchSourceOptions(sourceMailbox: [.inboxes])),
                " IN (inboxes) CHARSET Alien ALL",
                #line
            ),
            (
                ESearchOptions(key: .all,
                               returnOptions: [.min],
                               sourceOptions: ESearchSourceOptions(sourceMailbox: [.inboxes])),
                " IN (inboxes) RETURN (MIN) ALL",
                #line
            ),
            (
                ESearchOptions(key: .all,
                               charset: "Alien",
                               returnOptions: [.min]),
                " RETURN (MIN) CHARSET Alien ALL",
                #line
            ),
            (
                ESearchOptions(key: .all,
                               charset: "Alien",
                               returnOptions: [.min],
                               sourceOptions: ESearchSourceOptions(sourceMailbox: [.inboxes])),
                " IN (inboxes) RETURN (MIN) CHARSET Alien ALL",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeESearchOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
