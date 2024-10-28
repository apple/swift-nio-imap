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

class ExtendedSearchOptions_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ExtendedSearchOptions_Tests {
    func testEncode() {
        let inputs: [(ExtendedSearchOptions, String, UInt)] = [
            (
                ExtendedSearchOptions(key: .all),
                " ALL",
                #line
            ),
            (
                ExtendedSearchOptions(key: .all, returnOptions: [.min]),
                " RETURN (MIN) ALL",
                #line
            ),
            (
                ExtendedSearchOptions(key: .deleted, returnOptions: [.min, .all]),
                " RETURN (MIN ALL) DELETED",
                #line
            ),
            (
                ExtendedSearchOptions(key: .deleted, returnOptions: [.all]),
                " RETURN (ALL) DELETED",
                #line
            ),
            (
                ExtendedSearchOptions(key: .all, charset: "Alien"),
                " CHARSET Alien ALL",
                #line
            ),
            (
                ExtendedSearchOptions(key: .all, sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])),
                " IN (inboxes) ALL",
                #line
            ),
            (
                ExtendedSearchOptions(
                    key: .all,
                    charset: "Alien",
                    sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                ),
                " IN (inboxes) CHARSET Alien ALL",
                #line
            ),
            (
                ExtendedSearchOptions(
                    key: .all,
                    returnOptions: [.min],
                    sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                ),
                " IN (inboxes) RETURN (MIN) ALL",
                #line
            ),
            (
                ExtendedSearchOptions(
                    key: .all,
                    charset: "Alien",
                    returnOptions: [.min]
                ),
                " RETURN (MIN) CHARSET Alien ALL",
                #line
            ),
            (
                ExtendedSearchOptions(
                    key: .all,
                    charset: "Alien",
                    returnOptions: [.min],
                    sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                ),
                " IN (inboxes) RETURN (MIN) CHARSET Alien ALL",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeExtendedSearchOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
