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

class CoreTypealiasesTests: EncodeTestClass {}

// MARK: - nstring imapEncoded

extension CoreTypealiasesTests {
    func testNil() {
        let expected = "NIL"
        let input: String? = nil
        let size = self.testBuffer.writeNString(input)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testNotNil() {
        let expected = "\"hello\""
        let size = self.testBuffer.writeNString("hello")
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
