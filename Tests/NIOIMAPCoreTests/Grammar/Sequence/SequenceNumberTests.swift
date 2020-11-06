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

class SequenceNumberTests: EncodeTestClass {}

// MARK: - Integer literal

extension SequenceNumberTests {
    func testIntegerLiteral() {
        let num: SequenceNumber = 5
        XCTAssertEqual(num, 5)
    }
}

// MARK: - Comparable

extension SequenceNumberTests {
    func testComparable() {
        XCTAssertFalse(SequenceNumber.max < .max)
        XCTAssertFalse(SequenceNumber.max < 999)
        XCTAssertTrue(SequenceNumber.max > 999)
        XCTAssertTrue(SequenceNumber(1) < 999) // use .number to force type
    }
}

// MARK: - Encoding

extension SequenceNumberTests {
    func testEncode_max() {
        let expected = "4294967295"
        let size = self.testBuffer.writeSequenceNumber(.max)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testEncode_number() {
        let expected = "1234"
        let size = self.testBuffer.writeSequenceNumber(1234)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Strideable

extension SequenceNumberTests {
    func testAdvancedBy() {
        let min = SequenceNumber(1)
        let max = SequenceNumber(UInt32.max)
        XCTAssertEqual(max.advanced(by: 0), max)
        XCTAssertEqual(min.advanced(by: min.distance(to: max)), max)
        XCTAssertEqual(max.advanced(by: max.distance(to: min)), min)
    }
}

