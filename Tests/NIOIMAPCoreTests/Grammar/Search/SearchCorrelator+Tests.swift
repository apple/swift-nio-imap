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

class SearchCorrelator_Tests: EncodeTestClass {}

// MARK: - Encoding

extension SearchCorrelator_Tests {
    func testEncode() {
        let inputs: [(SearchCorrelator, String, UInt)] = [
            (SearchCorrelator(tag: "some"), " (TAG \"some\")", #line),
            (SearchCorrelator(tag: "some", mailbox: MailboxName("mb"), uidValidity: 5), " (TAG \"some\" MAILBOX \"mb\" UIDVALIDITY 5)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeSearchCorrelator(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
