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
@testable import IMAPCore
@testable import NIOIMAP

class SequenceNumberTests: EncodeTestClass {

}

// MARK: - Integer literal
extension SequenceNumberTests {
    
    func testIntegerLiteral() {
        let num: IMAPCore.SequenceNumber = 5
        XCTAssertEqual(num, 5)
    }
    
}

// MARK: - Comparable
extension SequenceNumberTests {

    func testComparable() {
        XCTAssertFalse(IMAPCore.SequenceNumber.last < .last)
        XCTAssertFalse(IMAPCore.SequenceNumber.last < 999)
        XCTAssertTrue(999 < IMAPCore.SequenceNumber.last)
        XCTAssertTrue(IMAPCore.SequenceNumber.number(1) < 999) // use .number to force type
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
