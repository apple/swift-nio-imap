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

class UIDSetTests: EncodeTestClass {}

// MARK: - UIDSetTests imapEncoded

extension UIDSetTests {
    func testIMAPEncoded_one() {
        let expected = "5:22"
        let size = self.testBuffer.writeUIDSet(UIDSet(5...22))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_all() {
        let expected = "*"
        let size = self.testBuffer.writeUIDSet(.all)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testIMAPEncoded_full() {
        let expected = "1,2:3,4,5,6:*"
        let size = self.testBuffer.writeUIDSet(UIDSet([
            UIDRange(1),
            UIDRange(2...3),
            UIDRange(4),
            UIDRange(5),
            UIDRange(6...),
        ])!)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
