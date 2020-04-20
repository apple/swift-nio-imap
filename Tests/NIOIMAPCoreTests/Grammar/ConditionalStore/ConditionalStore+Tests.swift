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

class ConditionalStore_Tests: EncodeTestClass {

    func testConditionalStoreParameter_encode() {
        let expected = "CONDSTORE"
        let size = self.testBuffer.writeConditionalStoreParameter()
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(self.testBufferString, expected)
    }
    
}
