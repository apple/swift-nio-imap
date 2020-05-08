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

class IMAPRangeTests: EncodeTestClass {}

// MARK: - IMAP

extension IMAPRangeTests {
    func testImapEncoded_from() {
        let expected = "5:*"
        let size = self.testBuffer.writeSequenceRange(SequenceRange(5 ... .last))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testImapEncoded_range() {
        let expected = "2:4"
        let size = self.testBuffer.writeSequenceRange(SequenceRange(2 ... 4))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}

// MARK: - Range operators

extension IMAPRangeTests {
    func testRange_from() {
        let expected = SequenceRange(7 ... .last)
        let actual: SequenceRange = 7...
        XCTAssertEqual(expected, actual)
    }

    func testRange_closed() {
        let expected = SequenceRange(3 ... 4)
        let actual: SequenceRange = 3 ... 4
        XCTAssertEqual(expected, actual)
    }
}
