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
        let range = SequenceRange.wildcard
        XCTAssertEqual(range.from, .last)
        XCTAssertEqual(range.to, .last)
    }
}

// MARK: - single

extension SequenceRangeTests {
    func testSingle() {
        let range = SequenceRange.single(999)
        XCTAssertEqual(range.from, 999)
        XCTAssertEqual(range.to, 999)
    }
}

// MARK: - init

extension SequenceRangeTests {
    // here we always expect the smaller number on the left

    func testInit_range() {
        let range = SequenceRange(1 ... 999)
        XCTAssertEqual(range.from, 1)
        XCTAssertEqual(range.to, 999)
    }

    // expected to re-order to right-largest
    func testInit_left_larger() {
        let range = SequenceRange(from: 999, to: 1)
        XCTAssertEqual(range.from, 1)
        XCTAssertEqual(range.to, 999)
    }

    func testInit_right_larger() {
        let range = SequenceRange(from: 1, to: 999)
        XCTAssertEqual(range.from, 1)
        XCTAssertEqual(range.to, 999)
    }

    func testInit_integer() {
        let range: SequenceRange = 654
        XCTAssertEqual(range.from, 654)
        XCTAssertEqual(range.to, 654)
    }
}

// MARK: - Encoding

extension SequenceRangeTests {
    func testEncode_single() {
        let expected = "5"
        let size = self.testBuffer.writeSequenceRange(.single(5))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testEncode_range() {
        let expected = "12:34"
        let size = self.testBuffer.writeSequenceRange(SequenceRange(from: 12, to: 34))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Range operators

extension SequenceRangeTests {
    func testRangeOperator_prefix() {
        let expected = "5:*"
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
        let size = self.testBuffer.writeSequenceRange(44 ... 55)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testRangeOperator_postfix_complete_left_larger() {
        let expected = "44:55"
        let size = self.testBuffer.writeSequenceRange(55 ... 44)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
