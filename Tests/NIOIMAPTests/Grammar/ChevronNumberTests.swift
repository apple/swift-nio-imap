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
@testable import NIOIMAP

class ChevronNumberTests: EncodeTestClass {

}

// MARK: - ChevronNumber init
extension ChevronNumberTests {
    
    // pointless test, but I want the code coverage
    func testInit() {
        let num = NIOIMAP.Partial(left: 123, right: 456)
        XCTAssertEqual(num.left, 123)
        XCTAssertEqual(num.right, 456)
    }
    
}

// MARK: - ChevronNumber imapEncoded
extension ChevronNumberTests {
    
    func testImapEncode_basic() {
        let expected = "<123.456>"
        let size = self.testBuffer.writePartial(NIOIMAP.Partial(left: 123, right: 456))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
}
