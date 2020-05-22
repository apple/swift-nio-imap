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

class SequenceRangeTests: EncodeTestClass {}

// MARK: - last

extension SequenceRangeTests {
    func testWildcard() {
        let range = SequenceRange.all.range
        XCTAssertEqual(range.lowerBound, SequenceNumber.min)
        XCTAssertEqual(range.upperBound, SequenceNumber.max)
    }
}

// MARK: - single

extension SequenceRangeTests {
    func testSingle() {
        let range = SequenceRange(999).range
        XCTAssertEqual(range.lowerBound, 999)
        XCTAssertEqual(range.upperBound, 999)
    }
}

// MARK: - init

extension SequenceRangeTests {
    // here we always expect the smaller number on the left

    func testInit_range() {
        let range = SequenceRange(1 ... 999).range
        XCTAssertEqual(range.lowerBound, 1)
        XCTAssertEqual(range.upperBound, 999)
    }

    func testInit_integer() {
        let range: SequenceRange = 654
        XCTAssertEqual(range.range.lowerBound, 654)
        XCTAssertEqual(range.range.upperBound, 654)
    }
}

// MARK: - Encoding

extension SequenceRangeTests {
    func testEncode() {
        let inputs: [(SequenceRange, String, UInt)] = [
            (33 ... 44, "33:44", #line),
            (5, "5", #line),
            (.all, "*", #line),
            (...55, "1:55", #line),
            (66..., "66:*", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeSequenceRange(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}

// MARK: - Range operators

extension SequenceRangeTests {
    func testRangeOperator_prefix() {
        let expected = "1:5"
        let size = self.testBuffer.writeSequenceRange(...5)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testRangeOperator_postfix() {
        let expected = "5:*"
        let size = self.testBuffer.writeSequenceRange(5...)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testRangeOperator_postfix_complete_right_larger() {
        let expected = "44:55"
        let size = self.testBuffer.writeSequenceRange(SequenceRange(left: 44, right: 55))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testRangeOperator_postfix_complete_left_larger() {
        let expected = "44:55"
        let size = self.testBuffer.writeSequenceRange(SequenceRange(left: 55, right: 44))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
