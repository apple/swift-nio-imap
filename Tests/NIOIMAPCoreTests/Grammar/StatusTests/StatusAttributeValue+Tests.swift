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
@testable import NIOIMAPCore

class StatusAttributeValue_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension StatusAttributeValue_Tests {

    func testEncode_statusOption() {
        let inputs: [([NIOIMAP.StatusAttribute], String, UInt)] = [
            ([.messages], "STATUS (MESSAGES)", #line),
            ([.messages, .size, .recent], "STATUS (MESSAGES SIZE RECENT)", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeStatusOption(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_statusAttributeValue() {
        let inputs: [(NIOIMAP.StatusAttributeValue, String, UInt)] = [
            (.messages(12), "MESSAGES 12", #line),
            (.uidNext(23), "UIDNEXT 23", #line),
            (.uidValidity(34), "UIDVALIDITY 34", #line),
            (.unseen(45), "UNSEEN 45", #line),
            (.deleted(56), "DELETED 56", #line),
            (.size(67), "SIZE 67", #line),
            (.modSequence(.zero), "HIGHESTMODSEQ 0", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeStatusAttributeValue(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_statusAttributeList() {
        let inputs: [([NIOIMAP.StatusAttributeValue], String, UInt)] = [
            ([.messages(12)], "MESSAGES 12", #line),
            ([.messages(12), .deleted(34)], "MESSAGES 12 DELETED 34", #line),
            ([.messages(12), .deleted(34), .size(56)], "MESSAGES 12 DELETED 34 SIZE 56", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeStatusAttributeList(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

}
