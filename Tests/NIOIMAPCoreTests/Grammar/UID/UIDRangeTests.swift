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

class UIDRangeTests: EncodeTestClass {}

// MARK: - last

extension UIDRangeTests {
    func testWildcard() {
        let range = MessageIdentifierRange<UID>.all.range
        XCTAssertEqual(range.lowerBound, UID.min)
        XCTAssertEqual(range.upperBound, UID.max)
    }
}

// MARK: - single

extension UIDRangeTests {
    func testSingle() {
        let range = MessageIdentifierRange<UID>(999).range
        XCTAssertEqual(range.lowerBound, 999)
        XCTAssertEqual(range.upperBound, 999)
    }
}

// MARK: - init

extension UIDRangeTests {
    // here we always expect the smaller number on the left

    func testInit_range() {
        let range = MessageIdentifierRange<UID>(1 ... 999).range
        XCTAssertEqual(range.lowerBound, 1)
        XCTAssertEqual(range.upperBound, 999)
    }

    func testInit_integer() {
        let range: MessageIdentifierRange<UID> = 654
        XCTAssertEqual(range.range.lowerBound, 654)
        XCTAssertEqual(range.range.upperBound, 654)
    }
}

// MARK: - Encoding

extension UIDRangeTests {
    func testEncode() {
        let inputs: [(MessageIdentifierRange<UID>, String, UInt)] = [
            (33 ... 44, "33:44", #line),
            (5, "5", #line),
            (MessageIdentifierRange<UID>(.max), "*", #line),
            (.all, "1:*", #line),
            (...55, "1:55", #line),
            (66..., "66:*", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMessageIdentifierRange(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
            XCTAssertEqual("\(test)", expectedString, line: line)
        }
    }
}

// MARK: - Range operators

extension UIDRangeTests {
    func testRangeOperator_prefix() {
        let expected = "5:*"
        let size = self.testBuffer.writeMessageIdentifierRange(MessageIdentifierRange<UID>(5 ... (.max)))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testRangeOperator_postfix() {
        let expected = "5:*"
        let size = self.testBuffer.writeMessageIdentifierRange(MessageIdentifierRange<UID>(5 ... (.max)))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testRangeOperator_postfix_complete_right_larger() {
        let expected = "44:55"
        let size = self.testBuffer.writeMessageIdentifierRange(MessageIdentifierRange<UID>(44 ... 55))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
