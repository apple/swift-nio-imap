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

class MessageAttributesTests: EncodeTestClass {

}

// MARK: - Encoding
extension MessageAttributesTests {

    func testEncode() {
        let inputs: [([NIOIMAP.MessageAttributeType], String, UInt)] = [
            ([.dynamic([.draft])], "(FLAGS (\\Draft))", #line),
            ([.dynamic([.flagged]), .static(.rfc822Size(123))], "(FLAGS (\\Flagged) RFC822.SIZE 123)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMessageAttributes(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
