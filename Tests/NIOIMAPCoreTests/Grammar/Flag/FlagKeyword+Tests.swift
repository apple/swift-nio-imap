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

class FlagKeyword_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension FlagKeyword_Tests {

    func testEncode() {
        let inputs: [(NIOIMAP.Flag.Keyword, String, UInt)] = [
            (.forwarded, "$Forwarded", #line),
            (.mdnSent, "$MDNSent", #line),
            (.colorBit0, "$MailFlagBit0", #line),
            (.colorBit1, "$MailFlagBit1", #line),
            (.colorBit2, "$MailFlagBit2", #line),
            (.junk, "$Junk", #line),
            (.notJunk, "$NotJunk", #line),
            (.unregistered_junk, "Junk", #line),
            (.unregistered_notJunk, "NotJunk", #line),
            (.unregistered_forwarded, "Forwarded", #line),
            (.unregistered_redirected, "Redirected", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeFlagKeyword(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

}
