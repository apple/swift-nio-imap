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

class PermanentFlagTests: EncodeTestClass {}

// MARK: - Encoding

extension PermanentFlagTests {
    func testEncoding_wildcard() {
        let expected = #"\*"#
        let flag = PermanentFlag.wildcard
        let size = self.testBuffer.writeFlagPerm(flag)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(self.testBufferString, expected)
    }

    func testEncoding_flag() {
        let expected = "\\Answered"
        let flag = PermanentFlag.flag(.answered)
        let size = self.testBuffer.writeFlagPerm(flag)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(self.testBufferString, expected)
    }
}
