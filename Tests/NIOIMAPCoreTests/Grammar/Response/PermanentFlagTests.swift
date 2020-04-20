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
@testable import NIOIMAPCore

class PermanentFlagTests: EncodeTestClass {

}

// MARK: - Encoding
extension PermanentFlagTests {

    func testEncoding_wildcard() {
        let expected = #"\*"#
        let flag = NIOIMAP.PermanentFlag.wildcard
        let size = self.testBuffer.writeFlagPerm(flag)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(self.testBufferString, expected)
    }

    func testEncoding_flag() {
        let expected = #"\Answered"#
        let flag = NIOIMAP.PermanentFlag.flag(.answered)
        let size = self.testBuffer.writeFlagPerm(flag)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(self.testBufferString, expected)
    }

}
