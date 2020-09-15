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

class SequenceSetTests: EncodeTestClass {}

// MARK: - SequenceSetTests imapEncoded

extension SequenceSetTests {
    func testIMAPEncoded_one() {
        let expected = "5:22"
        let size = self.testBuffer.writeSequenceSet(SequenceSet(5 ... 22))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_all() {
        let expected = "*"
        let size = self.testBuffer.writeSequenceSet(.all)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_full() {
        let expected = "1,2:3,4,5,6:*"
        let size = self.testBuffer.writeSequenceSet(SequenceSet([
            SequenceRange(1),
            2 ... 3,
            SequenceRange(4),
            SequenceRange(5),
            6...,
        ])!)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testEncodeLastCommand() {
        let expected = "$"
        let size = self.testBuffer.writeSequenceSet(.lastCommand)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
