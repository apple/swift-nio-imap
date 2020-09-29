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

class MailboxInfo_Tests: EncodeTestClass {}

// MARK: - Encoding

extension MailboxInfo_Tests {
    func testEncode() {
        let inputs: [(MailboxInfo, String, UInt)] = [
            (MailboxInfo(attributes: [], path: .init(name: .inbox), extensions: []), "() \"INBOX\"", #line),
            (MailboxInfo(attributes: [], path: .init(name: .inbox, pathSeparator: "a"), extensions: []), "() a \"INBOX\"", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxInfo(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_flags() {
        let inputs: [([MailboxInfo.Attribute], String, UInt)] = [
            ([], "", #line),
            ([.marked], "\\marked", #line),
            ([.noInferiors], "\\noinferiors", #line),
            ([.marked, .noInferiors, .init("\\test")], "\\marked \\noinferiors \\test", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxListFlags(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
