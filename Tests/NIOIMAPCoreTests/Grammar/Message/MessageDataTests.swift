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

class MessageDataTests: EncodeTestClass {}

// MARK: - Encoding

extension MessageDataTests {
    func testEncode() {
        let inputs: [(MessageData, String, UInt)] = [
            (.expunge(123), "123 EXPUNGE", #line),
            (.vanished(.all), "VANISHED 1:*", #line),
            (.vanishedEarlier(.all), "VANISHED (EARLIER) 1:*", #line),
            (.generateAuthorizedURL(["test"]), "GENURLAUTH \"test\"", #line),
            (.generateAuthorizedURL(["test1", "test2"]), "GENURLAUTH \"test1\" \"test2\"", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer._clear()
            let size = self.testBuffer.writeMessageData(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
