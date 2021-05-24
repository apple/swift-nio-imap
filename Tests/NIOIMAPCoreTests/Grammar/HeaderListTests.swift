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

class HeaderListsTests: EncodeTestClass {}

// MARK: - IMAP

extension HeaderListsTests {
    func testArray_empty() {
        let expected = "()"
        let size = self.testBuffer.writeHeaderList([])
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testArray_full() {
        let expected = "(\"hello\" \"there\" \"world\")"
        let size = self.testBuffer.writeHeaderList(["hello", "there", "world"])
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
