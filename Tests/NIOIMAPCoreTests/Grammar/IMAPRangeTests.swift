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

class IMAPRangeTests: EncodeTestClass {}

// MARK: - IMAP

extension IMAPRangeTests {
    func testIMAPEncoded_from() {
        let expected = "5:*"
        let size = self.testBuffer.writeSequenceRange(MessageIdentifierRange<SequenceNumber>(5...))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_range() {
        let expected = "2:4"
        let size = self.testBuffer.writeSequenceRange(MessageIdentifierRange<SequenceNumber>(2...4))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Range operators

extension IMAPRangeTests {
    func testRange_from() {
        let sut = MessageIdentifierRange<SequenceNumber>(7...)
        XCTAssertEqual(sut.range.lowerBound, 7)
        XCTAssertEqual(sut.range.upperBound, .max)
    }

    func testRange_to() {
        let sut = MessageIdentifierRange<SequenceNumber>(...7)
        XCTAssertEqual(sut.range.lowerBound, 1)
        XCTAssertEqual(sut.range.upperBound, 7)
    }

    func testRange_closed() {
        let sut = MessageIdentifierRange<SequenceNumber>(3...4)
        XCTAssertEqual(sut.range.lowerBound, 3)
        XCTAssertEqual(sut.range.upperBound, 4)
    }
}
