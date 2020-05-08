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
        XCTAssertFalse(SequenceNumber.last < .last)
        XCTAssertFalse(SequenceNumber.last < 999)
        XCTAssertTrue(SequenceNumber.last > 999)
        XCTAssertTrue(SequenceNumber.number(1) < 999) // use .number to force type
    }
}

// MARK: - Encoding

extension SequenceNumberTests {
    func testEncode_wildcard() {
        let expected = "*"
        let size = self.testBuffer.writeSequenceNumber(.last)
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
