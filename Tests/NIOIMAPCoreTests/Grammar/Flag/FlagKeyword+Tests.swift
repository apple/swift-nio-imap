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

class FlagKeyword_Tests: EncodeTestClass {}

// MARK: - Equatable

extension FlagKeyword_Tests {
    func testEquatable() {
        let flag1 = NIOIMAP.Flag.Keyword("flag")
        let flag2 = NIOIMAP.Flag.Keyword("FLAG")
        XCTAssertEqual(flag1, flag2)
    }
}

// MARK: - Encoding

extension FlagKeyword_Tests {
    func testEncode() {
        let inputs: [(NIOIMAP.Flag.Keyword, String, UInt)] = [
            (.forwarded, "$FORWARDED", #line),
            (.mdnSent, "$MDNSENT", #line),
            (.colorBit0, "$MAILFLAGBIT0", #line),
            (.colorBit1, "$MAILFLAGBIT1", #line),
            (.colorBit2, "$MAILFLAGBIT2", #line),
            (.junk, "$JUNK", #line),
            (.notJunk, "$NOTJUNK", #line),
            (.unregistered_junk, "JUNK", #line),
            (.unregistered_notJunk, "NOTJUNK", #line),
            (.unregistered_forwarded, "FORWARDED", #line),
            (.unregistered_redirected, "REDIRECTED", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeFlagKeyword(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
