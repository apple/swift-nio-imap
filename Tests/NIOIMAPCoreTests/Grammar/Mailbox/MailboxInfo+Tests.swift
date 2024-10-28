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

class MailboxInfo_Tests: EncodeTestClass {}

// MARK: - Attribute

extension MailboxInfo_Tests {
    func testAttribute_hashable() {
        var testSet = Set<MailboxInfo.Attribute>()
        let attribute1 = MailboxInfo.Attribute("test")
        let attribute2 = MailboxInfo.Attribute("TEST")

        // hashing should be case insensitive
        testSet.insert(attribute1)
        XCTAssertTrue(testSet.contains(attribute2))
    }
}

// MARK: - Encoding

extension MailboxInfo_Tests {
    func testEncode() {
        let inputs: [(MailboxInfo, String, UInt)] = [
            (MailboxInfo(attributes: [], path: try! .init(name: .inbox), extensions: [:]), "() NIL \"INBOX\"", #line),
            (
                MailboxInfo(attributes: [], path: try! .init(name: .inbox, pathSeparator: "a"), extensions: [:]),
                "() \"a\" \"INBOX\"", #line
            ),
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
            ([.marked], "\\Marked", #line),
            ([.noInferiors], "\\Noinferiors", #line),
            ([.marked, .noInferiors, .init("\\test")], "\\Marked \\Noinferiors \\test", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxListFlags(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
